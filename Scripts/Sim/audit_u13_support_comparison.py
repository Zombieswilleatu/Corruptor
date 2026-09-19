#!/usr/bin/env python3
"""Verify and describe the fixed V10/V11 support campaign without retuning it."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

from u13_doctrine.coordination import context
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.facts import Facts, LANES
from u13_doctrine.lords.deimos import rout_value
from u13_doctrine.lords.humbaba import BREATH, MUSTER, breath_value
from u13_doctrine.reference_probe import harness_hash
from u13_doctrine.survey import atomic_json, read_record
from u13_pysim.verify import source_identity

FOCUS = {'Deimos', 'Humbaba'}


def opening_review(pairs):
    """Post-run diagnostic of initial lane concentration, not causal attribution."""
    counts, losses = Counter(), []
    for pair in pairs:
        difference = pair['first_difference']
        if not difference or difference.get('round') != 1: continue
        for row in difference.get('seats', []):
            if row['lord'] != 'Humbaba': continue
            old = {p['power']: p['target'] for p in row['v10_powers']}
            new = {p['power']: p['target'] for p in row['v11_powers']}
            counts['opening_observations'] += 1
            counts['V10_muster_'+old[MUSTER]['lane']] += 1
            counts['V11_muster_'+new[MUSTER]['lane']] += 1
            counts['opening_muster_lane_changed'] += old[MUSTER]['lane'] != new[MUSTER]['lane']
            if len(set(pair['lords'])) == 2 and 'Deimos' not in pair['lords'] and pair['result'] == 'V10_wins_both':
                losses.append(dict(pair_id=pair['pair_id'], old_muster=old[MUSTER]['lane'],
                                   new_muster=new[MUSTER]['lane'], changed_order_fields=row['changed_order_fields']))
    return dict(openings=counts, matched_lost_wins=losses,
                scope='Post-run description of first differences; no isolated causal claim or additional games.')


def trace_measurements(record, measurements):
    for item in record['trace']:
        view, decision = item['view'], item['decision']
        f = Facts(view)
        if f.kind not in FOCUS: continue
        arm = 'V11' if 'V11_' in decision['policy'] else 'V10'
        stats = measurements[(arm, f.kind)]
        stats['decisions'] += 1
        plan = decision['plan']
        powers = {p['power_id']: p for p in plan['powers']}
        if f.kind == 'Deimos':
            ready = f.available('Rout')[0]
            stats['rout_ready_decisions'] += ready
            if ready and 'Rout' not in powers:
                stats['rout_ready_held'] += 1
                stats['rout_held_without_public_pressure'] += not any(rout_value(f, lane)['score'] for lane in LANES)
            if 'Rout' in powers:
                lane = powers['Rout']['target']['lane']
                estimate = rout_value(f, lane)
                stats['rout_selected'] += 1
                stats['rout_selected_without_public_pressure'] += estimate['score'] == 0
                stats['rout_selected_visible_threats'] += len(estimate['threats'])
                stats['rout_selected_visible_gate_threats'] += len(estimate['gate_threats'])
        else:
            stats['breath_ready_decisions'] += f.available(BREATH)[0]
            stats['support_variants_selected'] += decision.get('support', {}).get('selected', False)
            if MUSTER in powers:
                stats['muster_selected'] += 1
                aura = f.active(BREATH)
                stats['muster_into_active_breath'] += bool(aura and aura['target']['lane'] == powers[MUSTER]['target']['lane'])
            if BREATH in powers:
                lane = powers[BREATH]['target']['lane']
                estimate = breath_value(f, lane, context(f, plan))
                stats['breath_selected'] += 1
                stats['breath_first_round'] += view['round'] == 1
                stats['breath_with_same_lane_muster'] += MUSTER in powers and powers[MUSTER]['target']['lane'] == lane
                stats['breath_in_initially_empty_lane'] += not f.units(f.pid, lane)
                stats['breath_zero_forecast_immediate_healing'] += estimate['immediate_healing'] == 0
                for key in ('immediate_healing', 'next_regen_bonus', 'movement_windows',
                            'waiting_excluded', 'ordinary_recruits', 'muster_recruits'):
                    stats['forecast_'+key] += estimate[key]


def first_difference(first, second):
    a, b = first['operations'], second['operations']
    index = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
    if index == len(a) == len(b): return None
    row = dict(operation_index=index, common_prefix_sha256=fingerprint(a[:index]),
               first_kind=a[index]['kind'] if index < len(a) else 'end',
               second_kind=b[index]['kind'] if index < len(b) else 'end')
    if row['first_kind'] == row['second_kind'] == 'submit':
        number = sum(op['kind'] == 'submit' for op in a[:index])+1
        row['round'] = number
        row['seats'] = []
        for seat in (0, 1):
            old, new = (second, first) if first['spec']['candidate_seat'] == seat else (first, second)
            old_plan, new_plan = old['operations'][index]['plans'][seat], new['operations'][index]['plans'][seat]
            if old_plan == new_plan: continue
            old_view = next(t['view'] for t in old['trace'] if t['view']['round'] == number and t['view']['player_id'] == seat)
            new_view = next(t['view'] for t in new['trace'] if t['view']['round'] == number and t['view']['player_id'] == seat)
            assert old_view == new_view, 'Different public views before first plan difference'
            row['seats'].append(dict(seat=seat, lord=first['spec']['setup']['lords'][seat],
                public_view_sha256=fingerprint(old_view), ordinary_order_changed=old_plan['order'] != new_plan['order'],
                changed_order_fields=sorted(k for k in old_plan['order'].keys() | new_plan['order'].keys()
                                            if old_plan['order'].get(k) != new_plan['order'].get(k)),
                v10_plan_sha256=fingerprint(old_plan), v11_plan_sha256=fingerprint(new_plan),
                v10_powers=[dict(power=p['power_id'], target=p['target']) for p in old_plan['powers']],
                v11_powers=[dict(power=p['power_id'], target=p['target']) for p in new_plan['powers']]))
    return row


def run(directory):
    directory = Path(directory)
    manifest = json.loads((directory/'manifest.json').read_text())
    root = Path(__file__).resolve().parents[2]
    assert source_identity(root)[1] == manifest['engine_source_sha256'], 'Different analysis engine'
    assert harness_hash(root) == manifest['harness_source_sha256'], 'Different analysis policy helpers'
    specs = json.loads((directory/'specs.json').read_text())
    assert fingerprint(specs) == manifest['cases_sha256']
    grouped = defaultdict(list)
    for spec in specs: grouped[spec['pair_id']].append(spec)
    totals, by_repeat, by_lord, pairs, power_groups = Counter(), defaultdict(Counter), defaultdict(Counter), [], {}
    measurements, interventions, routes = defaultdict(Counter), defaultdict(Counter), defaultdict(Counter)
    matchup_groups = defaultdict(Counter)
    inventory, maximum = [], defaultdict(Counter)
    for pair_id, pair_specs in sorted(grouped.items()):
        assert sorted(s['candidate_seat'] for s in pair_specs) == [0, 1]
        records = []
        for spec in sorted(pair_specs, key=lambda s: s['candidate_seat']):
            path = directory/'games'/(spec['name']+'.json.gz')
            record = read_record(path, manifest, spec)
            assert record['status'] == 'complete', (spec['name'], record['error'])
            semantic = record['semantic']
            assert semantic['outcome']['winner'] in (0, 1)
            records.append(record)
            inventory.append(dict(name=path.name, bytes=path.stat().st_size,
                                  sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                                  semantic_sha256=record['semantic_sha256'], trace_sha256=record['trace_sha256']))
            totals[spec['purpose']+'_games'] += 1
            totals[spec['purpose']+'_rounds'] += semantic['rounds']
            totals[spec['purpose']+'_operations'] += semantic['operations']
            totals['rejected_previews'] += len(semantic['diagnostics']['rejected_previews'])
            if spec['purpose'] != 'primary': continue
            won = semantic['outcome']['winner'] == spec['candidate_seat']
            winner = 'V11' if won else 'V10'
            totals[winner+'_wins'] += 1
            lords = spec['setup']['lords']
            group = (lords[0]+'_mirror' if lords[0] == lords[1] else 'Deimos_Humbaba'
                     if set(lords) == FOCUS else next(iter(set(lords) & FOCUS))+'_other')
            matchup_groups[group]['games'] += 1
            matchup_groups[group][winner+'_wins'] += 1
            by_repeat[spec['repeat']][winner] += 1
            by_lord[spec['setup']['lords'][spec['candidate_seat']]][winner] += 1
            routes[winner][semantic['outcome']['win_by']] += 1
            trace_measurements(record, measurements)
            for item in record['trace']:
                arm = 'V11' if item['decision']['policy'] == manifest['candidate_policy'] else 'V10'
                limits = item['decision']['budget']['limits']
                assert limits == dict(complete_plans=32, generated_per_category=16,
                                      previews=8, retained_per_category=4)
                for key, used in item['decision']['budget']['used'].items():
                    limit_key = key.split(':')[0]+'_per_category' if ':' in key else key
                    assert 0 <= used <= limits[limit_key], (spec['name'], key, used)
                    maximum[arm][key] = max(maximum[arm][key], used)
            for group in semantic['diagnostics']['groups']:
                if group['term'] not in ('Rout', BREATH, MUSTER) or group['lord'] not in FOCUS: continue
                arm = 'V11' if group['policy_id'] == manifest['candidate_policy'] else 'V10'
                key = (arm, group['lord'], group['term'])
                row = power_groups.setdefault(key, dict(policy=arm, lord=group['lord'], power=group['term'],
                    selected=0, outcomes=Counter(), metrics=Counter(), outcomes_unobserved=0))
                row['selected'] += group['flags']['selected']['true']
                row['outcomes'].update(group['outcomes']); row['metrics'].update(group['metrics'])
                row['outcomes_unobserved'] += group['outcome_unobserved']
        same_operations = records[0]['operations'] == records[1]['operations']
        same_final = records[0]['semantic']['final_state_sha256'] == records[1]['semantic']['final_state_sha256']
        if pair_specs[0]['purpose'] == 'control':
            assert same_operations and same_final, 'Unchanged-Lord control diverged: '+pair_id
            totals['identical_control_pairs'] += 1
            continue
        wins = [r['semantic']['outcome']['winner'] == r['spec']['candidate_seat'] for r in records]
        result = 'V11_wins_both' if all(wins) else 'V10_wins_both' if not any(wins) else 'split'
        totals[result] += 1
        totals['identical_primary_pairs'] += same_operations and same_final
        lords = records[0]['spec']['setup']['lords']
        row = dict(pair_id=pair_id, lords=lords, repeat=pair_specs[0]['repeat'], result=result,
                   same_operations=same_operations, same_final_state=same_final,
                   outcomes=[r['semantic']['outcome'] for r in records],
                   first_difference=first_difference(*records))
        pairs.append(row)
        if len(set(lords)) == 2 and len(set(lords) & FOCUS) == 1:
            lord = next(iter(set(lords) & FOCUS)); seat = lords.index(lord)
            new, old = records[seat], records[1-seat]
            new_won = new['semantic']['outcome']['winner'] == seat
            old_won = old['semantic']['outcome']['winner'] == seat
            stats = interventions[lord]
            stats['paired_setups'] += 1
            stats['V11_lord_wins'] += new_won; stats['V10_lord_wins'] += old_won
            stats['gained_wins'] += new_won and not old_won
            stats['lost_wins'] += old_won and not new_won
            stats['same_result'] += old_won == new_won
    assert totals['primary_games'] == manifest['primary_games']
    assert totals['control_games'] == manifest['control_games']
    report = dict(schema='U13_SUPPORT_COMPARISON_AUDIT_V1', manifest=manifest, totals=totals,
        auditor_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
        wins_by_repeat=dict(sorted(by_repeat.items())),
        wins_by_candidate_lord=dict(sorted(by_lord.items())), victory_routes=dict(routes),
        matchup_groups=dict(sorted(matchup_groups.items())),
        exploratory_opening_review=opening_review(pairs),
        single_changed_lord_pairs=dict(interventions),
        trace_measurements=[dict(policy=k[0], lord=k[1], **v) for k, v in sorted(measurements.items())],
        observed_powers=[power_groups[k] for k in sorted(power_groups)], maximum_work=dict(maximum),
        pairs=pairs, record_inventory=inventory,
        interpretation='Controls excluded from outcomes. Opposite Lord seats share a seed, so these are '
            'not 192 independent trials. Per-power counts follow diverging games and do not isolate '
            'which component caused a win. Public pressure and movement/healing forecasts are conditional '
            'estimates; only observed_powers.metrics report executed effects.')
    report['analysis_sha256'] = fingerprint(report)
    atomic_json(directory/'analysis.json', report)
    print(json.dumps(dict(totals=totals, wins_by_repeat=report['wins_by_repeat'],
                          single_changed_lord_pairs=report['single_changed_lord_pairs']), indent=2))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    run(parser.parse_args().directory)
