#!/usr/bin/env python3
"""Audit paired Rout continuations and report measured, conditional effects."""
import argparse
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path

from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.survey import atomic_json, read_record


def load(path):
    with gzip.open(path,'rt',encoding='utf-8') as stream:
        return json.load(stream)


def board_at(record, number, hook):
    return next((c['board'] for c in record['checkpoints']
                 if c['board']['round']==number and c['completed_hook']==hook),None)


def totals(board, seat, lane):
    units = [u for u in board['units'] if u['owner']==seat and u['lane']==lane and u['hp']>0]
    return dict(bodies=len(units),hp=sum(u['hp'] for u in units),
        waiting=sum(bool(u['waiting']) for u in units),
        castle_integrity=sum(c['integrity'] for c in board['castles'] if c['owner']==seat))


def first_attack(record, identities, number):
    ticks = [(e['data']['round']-number)*200+e['data']['tick'] for e in record['measured_events']
             if e['type'] in ('MARCHER_MELEE_ATTACK','MARCHER_RANGED_ATTACK')
             and e['data']['attacker']['id'] in identities]
    return min(ticks) if ticks else None


def run(directory, pressure=False):
    manifest = json.loads((directory/'manifest.json').read_text())
    selection = json.loads((directory/('positions-pressure.json' if pressure else 'positions.json')).read_text())
    if pressure:
        assert selection['parent_manifest_sha256']==fingerprint(manifest)
    positions = selection['selected']
    bases = {s['name']:read_record(directory/'games'/(s['name']+'.json.gz'),manifest,s) for s in manifest['specs']}
    totals_count = Counter(source_games=len(bases),
        source_rounds=sum(r['semantic']['rounds'] for r in bases.values()),
        source_operations=sum(r['semantic']['operations'] for r in bases.values()))
    for base in bases.values():
        assert base['trace_sha256']==fingerprint(base['trace'])
        assert base['semantic']['decisions_sha256']==fingerprint(base['operations'])
    rows, inventory = [], []
    for position in positions:
        pair = []
        for cast in (False,True):
            path = directory/'continuations'/(position['name']+('__cast' if cast else '__hold')+'.json.gz')
            r = load(path)
            assert r['spec']==dict(position,cast=cast)
            assert r['manifest_sha256']==fingerprint(manifest) and r['status']=='complete',r.get('error')
            assert r['operations_sha256']==fingerprint(r['operations'])
            assert r['trace_sha256']==fingerprint(r['trace'])
            assert r['intervention']['order']==r['original_plan']['order']
            # Protocol identities must be resequenced when an earlier Rout is
            # removed. Every semantic field of other declarations stays fixed.
            def other_powers(plan):
                return [{k:v for k,v in p.items() if k not in ('queue_index','declaration_id')}
                        for p in plan['powers'] if p['power_id']!='Rout']
            before,after = [other_powers(p) for p in (r['original_plan'],r['intervention'])]
            assert before==after
            base = bases[position['source']]
            if r['control']:
                assert r['operations']==base['operations']
                assert r['final_state_sha256']==base['semantic']['final_state_sha256']
            for item in r['trace']:
                d = item['decision']; assert not d['rejected_previews']
                for key,value in d['budget']['used'].items():
                    limit = d['budget']['limits'][key.split(':')[0]+'_per_category' if ':' in key else key]
                    assert 0<=value<=limit
            totals_count['continuations']+=1
            totals_count['exact_controls']+=r['control']
            totals_count['continuation_rounds']+=r['outcome']['round']
            totals_count['continuation_operations']+=len(r['operations'])
            inventory.append(dict(filename=path.name,bytes=path.stat().st_size,
                                  sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
            pair.append(r)
        held,cast = pair
        assert held['prefix_sha256']==cast['prefix_sha256']
        assert held['opponent_plan_sha256']==cast['opponent_plan_sha256']
        assert sum(r['control'] for r in pair)==1
        control = next(r for r in pair if r['control'])
        totals_count['original_control_wins' if control['won'] else 'original_control_losses']+=1
        number,seat,lane = position['round'],position['seat'],position['lane']
        def artillery(record):
            return [dict(type=e['type'],data={k:v for k,v in e['data'].items() if k!='shot'})
                    for e in record['measured_events'] if e['type'].startswith('ARTILLERY_')
                    and e['data']['round']==number]
        # Artillery resolves before Rout. Resequencing War Machine's protocol
        # identity must not change any of its actual targets or damage here.
        assert artillery(held)==artillery(cast)
        fired = next(e['data'] for e in cast['measured_events'] if e['type']=='ROUT_APPLIED'
                     and e['data']['round']==number and e['data']['player_id']==seat)
        ids = set(fired['affected_ids'])
        row = dict(position=position,held_won=held['won'],cast_won=cast['won'],
                   held_outcome=held['outcome'],cast_outcome=cast['outcome'],
                   affected=len(ids),pre_rout_artillery_unchanged=True,effects=[])
        for n in range(number,number+3):
            left,right = [board_at(r,n,'marching') for r in pair]
            if not left or not right:
                continue
            a,b = [{u['id']:u for u in board['units'] if u['id'] in ids and u['owner']==1-seat and u['hp']>0} for board in (left,right)]
            common = sorted(a.keys()&b.keys())
            # Positive means these shared survivors advanced less with Rout.
            displacement = sum((a[k]['x_fp']-b[k]['x_fp'])*(1 if seat==1 else -1) for k in common)
            ours = [totals(board,seat,lane) for board in (left,right)]
            theirs = [totals(board,1-seat,lane) for board in (left,right)]
            row['effects'].append(dict(round=n,offset=n-number,
                hold_own=ours[0],cast_own=ours[1],hold_enemy=theirs[0],cast_enemy=theirs[1],
                own_hp_delta=ours[1]['hp']-ours[0]['hp'],
                own_bodies_delta=ours[1]['bodies']-ours[0]['bodies'],
                castle_integrity_delta=ours[1]['castle_integrity']-ours[0]['castle_integrity'],
                hold_cohort_survivors=len(a),cast_cohort_survivors=len(b),shared_cohort_survivors=len(common),
                shared_survivor_delay_fp=displacement,
                mean_shared_survivor_delay_fp=displacement/len(common) if common else None))
        row['first_ordinary_attack_tick'] = dict(hold=first_attack(held,ids,number),cast=first_attack(cast,ids,number),
            scope='Only ordinary melee/ranged attacks by the routed cohort over the intervention round and two following rounds; null means none observed.')
        row['following_decisions'] = {label:[dict(round=t['view']['round'],
                hand_cards=len(t['view']['hand']),
                hand_value=sum(c['attributes']['value'] for c in t['view']['hand']),
                order=t['decision']['plan']['order'],
                powers=t['decision']['plan']['powers'])
            for t in r['trace'] if t['view']['player_id']==seat and t['view']['round']<=number+2]
            for label,r in zip(('hold','cast'),pair)}
        row['result'] = 'cast_gained_win' if cast['won'] and not held['won'] else 'cast_lost_win' if held['won'] and not cast['won'] else 'same_winner'
        totals_count[row['result']]+=1
        totals_count[position['original']+'_positions']+=1
        totals_count[position['original']+'_'+row['result']]+=1
        rows.append(row)
    assert totals_count['exact_controls']==len(positions)
    report = dict(manifest=manifest,selection=selection,totals=totals_count,positions=rows,records=inventory,
        interpretation='Selected diagnostics, not independent win-rate evidence. Later policies react normally; HP, reinforcement and castle differences after divergence are conditional outcomes. Positional delay compares only cohort members alive in both branches, with survivor counts reported separately. A changed win alone does not justify earlier Rout.')
    atomic_json(directory/('analysis-pressure.json' if pressure else 'analysis.json'),report)
    print(json.dumps(totals_count,sort_keys=True))
    for row in rows:
        print(row['position']['name'],row['position']['original'],row['position']['lane'],row['result'],
              [(e['offset'],e['own_hp_delta'],e['mean_shared_survivor_delay_fp']) for e in row['effects']])
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=Path)
    parser.add_argument('--pressure',action='store_true')
    args=parser.parse_args()
    run(args.directory,args.pressure)
