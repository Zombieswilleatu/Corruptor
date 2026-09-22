#!/usr/bin/env python3
"""Summarize added-monster effects; seat reflections are validation, not samples."""
import argparse
from collections import Counter, defaultdict
import gzip
import json
from pathlib import Path

from u13_pysim import monsters, dotra_shroud
from audit_u13_monsters import read_rows, name


def read(path):
    with (gzip.open(path, 'rt') if path.suffix == '.gz' else path.open()) as f:
        return json.load(f)


def score(battle):
    return 0.5 if battle['winner'] is None else float(battle['winner'] == 0)


def outcomes(battles):
    return dict(fights=len(battles), wins=sum(b['winner'] == 0 for b in battles),
                losses=sum(b['winner'] == 1 for b in battles),
                draws=sum(b['winner'] is None and not b['round_cap'] for b in battles),
                capped=sum(b['round_cap'] for b in battles))


def contrast(pairs):
    resolved = [(b, a) for b, a in pairs if not b['round_cap'] and not a['round_cap']]
    n = len(resolved)
    assert n, 'No resolved matched cases'
    base_wins = sum(b['winner'] == 0 for b, a in resolved)
    with_wins = sum(a['winner'] == 0 for b, a in resolved)
    return dict(pairs=len(pairs), resolved_pairs=n, excluded_capped_pairs=len(pairs)-n,
                without=outcomes([b for b, a in pairs]), with_monster=outcomes([a for b, a in pairs]),
                baseline_win_percent=100*base_wins/n, added_win_percent=100*with_wins/n,
                win_delta_pp=100*(with_wins-base_wins)/n,
                score_delta_pp=100*sum(score(a)-score(b) for b, a in resolved)/n,
                improved=sum(score(a) > score(b) for b, a in resolved),
                worsened=sum(score(a) < score(b) for b, a in resolved),
                unchanged=sum(score(a) == score(b) for b, a in resolved))


def controlled_summary(data):
    mirrors = defaultdict(list)
    for b in data['battles']:
        mirrors[b['case'], b['seed_index']].append(b)
    for key, pair in mirrors.items():
        assert len(pair) == 2 and {b['reflected'] for b in pair} == {False, True}, key
        assert all(pair[0][field] == pair[1][field]
                   for field in ('winner', 'round_cap', 'rounds', 'goals', 'surviving_forces', 'metrics')), key
    pairs = defaultdict(dict)
    ordinary = defaultdict(list)
    for b in data['battles']:
        if b['reflected']:
            continue
        if b['group'] == 'additive':
            pairs[b['focus'], b['opponent'], b['seed_index']][b['variant']] = b
        elif all(who in ('Penitent', 'Butcher', 'Vulture', 'Wright') for who in b['case'].split(':')[1:]):
            ordinary[b['case']].append(b)
    grouped = defaultdict(list)
    scenarios = defaultdict(lambda: defaultdict(list))
    for (who, opponent, seed), variants in pairs.items():
        assert set(variants) == {'with', 'without'}, (who, opponent, seed)
        b, a = variants['without'], variants['with']
        assert b['recipe_hand'] == a['recipe_hand']
        assert b['initial'][1] == a['initial'][1]
        expected = dict(b['initial'][0]); expected[who] = a['added_bodies']
        assert expected == a['initial'][0], (who, opponent, seed)
        grouped[who].append((b, a))
        scenarios[who][opponent].append((b, a))
    roster = {}
    for who in monsters.NAMES:
        matched = grouped[who]
        if not matched:
            continue  # Focused follow-ups may cover only the changed summons.
        metrics = Counter()
        for b, a in matched:
            metrics.update(a['metrics'].get(who, {}))
        roster[who] = dict(tier=monsters.ROSTER[who]['tier'], **contrast(matched),
                           scenarios={k: contrast(v) for k, v in scenarios[who].items()},
                           monster_metrics=dict(metrics),
                           recorded_hp_damage_per_summon=metrics['recorded_hp_damage']/len(matched))
    return dict(battles=len(data['battles']), intervals=sum(b['rounds'] for b in data['battles']),
                mirrored_pairs=len(mirrors), round_caps=sum(b['round_cap'] for b in data['battles']),
                seeds=data['seeds'], normal_seat_additive_pairs=len(pairs), monsters=roster,
                ordinary={key: outcomes(v) for key, v in ordinary.items()})


def continuous_summary(data):
    mirrors = defaultdict(list)
    for game in data['games']:
        mirrors[game['seed']].append(game)
    for seed, pair in mirrors.items():
        assert len(pair) == 2 and {g['swapped'] for g in pair} == {False, True}, seed
        assert pair[0]['totals'] == pair[1]['totals'][::-1], seed
        assert pair[0]['metrics'] == pair[1]['metrics'] and pair[0]['cohorts'] == pair[1]['cohorts'], seed
    normal = [g for g in data['games'] if not g['swapped']]
    roster = {}
    for who in monsters.NAMES:
        metrics, cohorts = Counter(), Counter()
        for g in normal:
            metrics.update(g['metrics'].get(who, {}))
            cohorts.update(g['cohorts'][who])
        roster[who] = dict(metrics=dict(metrics), cohorts=dict(cohorts))
        if who == 'Fyra':
            roster[who]['charms_per_completed_summon'] = cohorts['completed_charms']/cohorts['completed_bodies'] if cohorts['completed_bodies'] else None
    recovery = []
    for game in normal:
        signs = []
        for r in data['history']:
            if r['seed'] != game['seed'] or r['swapped']:
                continue
            gap = r['goals'][0]-r['goals'][1]
            if gap:
                signs.append(1 if gap > 0 else -1)
        recovery.append(dict(seed=game['seed'], goals=[t['reached_goal'] for t in game['totals']],
                             changed_leader=len(set(signs)) > 1,
                             initial_leader_lost_lead=bool(signs and signs[-1] != signs[0])))
    return dict(games=len(data['games']), intervals=len(data['history']), independent_seeds=len(normal),
                mirrored_pairs=len(mirrors), monsters=roster, recovery=recovery)


def army_summary(data):
    mirrors, roster = defaultdict(list), {who: dict(totals=Counter(), opponents={}) for who in monsters.NAMES}
    for b in data['battles']:
        mirrors[b['case'], b['seed_index']].append(b)
        if b['reflected']:
            continue
        pair = b['case'].split(':')[1:]
        assert len(pair) == 2 and all(who in monsters.NAMES for who in pair)
        for pid, who in enumerate(pair):
            opponent = pair[1-pid]
            stats = dict(fights=1, wins=int(b['winner'] == pid),
                         losses=int(b['winner'] == 1-pid),
                         draws=int(b['winner'] is None and not b['round_cap']), capped=int(b['round_cap']))
            roster[who]['totals'].update(stats)
            roster[who]['opponents'].setdefault(opponent, Counter()).update(stats)
    for key, pair in mirrors.items():
        assert len(pair) == 2 and {b['reflected'] for b in pair} == {False, True}, key
        assert all(pair[0][field] == pair[1][field]
                   for field in ('winner', 'round_cap', 'rounds', 'goals', 'surviving_forces', 'metrics')), key
    return dict(battles=len(data['battles']), intervals=sum(b['rounds'] for b in data['battles']),
                mirrored_pairs=len(mirrors), round_caps=sum(b['round_cap'] for b in data['battles']),
                seeds=data['seeds'], monsters=roster)


def native_powers(directory):
    """Inspect independent event tapes for collateral and real power timing."""
    counts = Counter()
    banished = {'allies': Counter(), 'enemies': Counter()}
    for path in sorted(directory.glob('waves-*-0.jsonl')):
        portals, dashes, ambushes, pulses = {}, set(), set(), set()
        last_kind = ''
        for record in read_rows(path):
            last_kind = record['kind']
            if last_kind != 'round':
                continue
            for event in record['events']:
                kind, d = event['type'], event['data']
                clock = record['round']*200+d.get('tick', 0)
                if kind == 'MONSTER_FIELD_CREATED' and d['field']['kind'] == 'portal':
                    portals[d['field']['id']] = d['field']
                elif kind == 'MONSTER_BANISHED':
                    portal = portals[d['portal_id']]
                    side = 'allies' if portal['owner'] == d['unit']['owner'] else 'enemies'
                    banished[side][name(d['unit'])] += 1
                elif kind == 'MONSTER_PULSE':
                    key = (d['unit_id'], clock)
                    assert key not in pulses and d['tick'] in (0, 133), (path, d)
                    pulses.add(key)
                    if d['healing']:
                        assert d['healed'], 'Empty healing pulse'
                        counts['useful_heal_pulses'] += 1
                if kind in ('MARCHER_MELEE_ATTACK', 'MARCHER_RANGED_ATTACK', 'MONSTER_ATTACK'):
                    source, target = d['attacker'], d['target']
                    aimed = kind != 'MONSTER_ATTACK' or d['ability'] in ('Muno', 'Ambush')
                    if aimed:
                        assert not dotra_shroud.active(target['attributes'], clock), (path, d)
                    if dotra_shroud.active(source['attributes'], clock) and kind != 'MONSTER_ATTACK':
                        counts['dotra_attacks_while_shrouded'] += 1
                    if kind == 'MONSTER_ATTACK' and d['ability'] == 'Muno':
                        key = (source['id'], record['round'])
                        assert key not in dashes, (path, d)
                        dashes.add(key); counts['muno_strikes'] += 1
                    if kind == 'MONSTER_ATTACK' and d['ability'] == 'Ambush':
                        assert source['id'] not in ambushes, (path, d)
                        ambushes.add(source['id'])
                        a = source['attributes']
                        assert a['dotra_shroud_from_tick'] == clock and a['dotra_shroud_until_tick'] == clock+67
                        counts['dotra_ambushes_and_shrouds'] += 1
                    if kind == 'MONSTER_ATTACK' and d['ability'] == 'Beam':
                        side = 'ally' if source['owner'] == target['owner'] else 'enemy'
                        counts['sooge_'+side+'_recorded_hp_damage'] += d['damage_dealt']
                elif kind == 'MARCHER_DEFEATED' and name(d.get('attacker') or {}) == 'Sooge':
                    side = 'ally' if d['attacker']['owner'] == d['victim']['owner'] else 'enemy'
                    counts['sooge_'+side+'_kills'] += 1
        assert last_kind == 'finished', path
        counts['independent_games'] += 1
    return dict(counts=dict(counts), portal_banishments_by_type={k: dict(v) for k, v in banished.items()},
                direct_hits_against_shrouded_dotra=0, all_observed_power_timing_checks_passed=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--controlled', type=Path, required=True)
    parser.add_argument('--continuous', type=Path)
    parser.add_argument('--native', type=Path)
    parser.add_argument('--armies', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    data = read(args.controlled)
    result = dict(schema='U13_WHOLESALE_ADDITIVE_SUMMARY_V1', rules_version=data['rules_version'],
                  scope='Normal seats only for performance; mirrored seats verify symmetry. Curated lane fights, no Lord powers.',
                  controlled=controlled_summary(data))
    if args.continuous:
        result['continuous'] = continuous_summary(read(args.continuous))
    if args.native:
        result['native_powers'] = native_powers(args.native)
    if args.armies:
        result['monster_armies'] = army_summary(read(args.armies))
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    for who, r in sorted(result['controlled']['monsters'].items(), key=lambda x: -x[1]['score_delta_pp']):
        print(f"{who:9} {r['baseline_win_percent']:5.1f}% -> {r['added_win_percent']:5.1f}%  "
              f"win {r['win_delta_pp']:+5.1f}pp  score {r['score_delta_pp']:+5.1f}pp  "
              f"better/worse {r['improved']}/{r['worsened']}")


if __name__ == '__main__':
    main()
