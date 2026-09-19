#!/usr/bin/env python3
"""Verify the fresh V11/V12 Humbaba comparison and separate forecasts/effects."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

from u13_doctrine.comparison import paired_cases
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.facts import Facts
from u13_doctrine.lords.humbaba import BREATH, MUSTER
from u13_doctrine.reference_probe import harness_hash
from u13_doctrine.survey import atomic_json, read_record
from u13_pysim.verify import source_identity


def run(directory):
    directory = Path(directory); root = Path(__file__).resolve().parents[2]
    manifest = json.loads((directory/'manifest.json').read_text())
    assert manifest['focused_lord'] == 'Humbaba'
    assert manifest['candidate_policy'] == 'U13_COMMON_SMART_CORE_ALPHA_V12_HUMBABA_PRESSURE'
    assert manifest['baseline_policy'] == 'U13_COMMON_SMART_CORE_ALPHA_V11_ROUT_HUMBABA'
    assert source_identity(root)[1] == manifest['engine_source_sha256']
    assert harness_hash(root) == manifest['harness_source_sha256']
    specs = list(paired_cases(manifest['repeats'], manifest['namespace'], 'Humbaba'))
    grouped = defaultdict(list)
    for spec in specs: grouped[spec['pair_id']].append(spec)
    totals, paired, direct, repeats = Counter(), Counter(), Counter(), defaultdict(Counter)
    behavior, effects, maximum = defaultdict(Counter), defaultdict(Counter), defaultdict(Counter)
    pairs, inventory = [], []
    for pair_id, pair_specs in sorted(grouped.items()):
        records = []
        for spec in sorted(pair_specs, key=lambda s:s['candidate_seat']):
            path = directory/'games'/(spec['name']+'.json.gz')
            record = read_record(path, manifest, spec)
            assert record['status'] == 'complete', record['error']
            records.append(record); semantic = record['semantic']
            inventory.append(dict(name=path.name, bytes=path.stat().st_size,
                sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                semantic_sha256=record['semantic_sha256'], trace_sha256=record['trace_sha256']))
            won = semantic['outcome']['winner'] == spec['candidate_seat']
            winner = 'V12' if won else 'V11'
            totals['games'] += 1; totals[winner+'_wins'] += 1
            totals['rounds'] += semantic['rounds']; totals['operations'] += semantic['operations']
            totals['rejected_previews'] += len(semantic['diagnostics']['rejected_previews'])
            repeats[spec['repeat']][winner] += 1
            for item in record['trace']:
                decision, view = item['decision'], item['view']
                arm = 'V12' if decision['policy'] == manifest['candidate_policy'] else 'V11'
                limits = decision['budget']['limits']
                assert limits == dict(complete_plans=32, generated_per_category=16, previews=8, retained_per_category=4)
                for key, count in decision['budget']['used'].items():
                    limit = key.split(':')[0]+'_per_category' if ':' in key else key
                    assert 0 <= count <= limits[limit]
                    maximum[arm][key] = max(maximum[arm][key], count)
                f = Facts(view)
                if f.kind != 'Humbaba': continue
                stats = behavior[arm]; stats['decisions'] += 1
                powers = {s['power_id']:s for s in decision['plan']['powers']}
                ready = f.available(BREATH)[0]
                stats['breath_ready'] += ready
                stats['breath_held_when_ready'] += ready and BREATH not in powers
                if MUSTER in powers:
                    stats['muster_selected'] += 1
                    if view['round'] == 1: stats['opening_muster_'+powers[MUSTER]['target']['lane']] += 1
                    aura = f.active(BREATH)
                    stats['muster_into_active_breath'] += bool(aura and aura['target']['lane'] == powers[MUSTER]['target']['lane'])
                stats['opening_breath'] += view['round'] == 1 and BREATH in powers
                if BREATH not in powers: continue
                stats['breath_selected'] += 1
                stats['same_lane_muster_breath'] += MUSTER in powers and powers[MUSTER]['target'] == powers[BREATH]['target']
                forecast = next(r for r in decision['coordination']['selected']['powers'] if r['power'] == BREATH)
                stats['zero_immediate_healing_forecast'] += forecast['immediate_healing'] == 0
                for key in ('immediate_healing', 'next_regen_bonus', 'movement_windows', 'ordinary_recruits', 'muster_recruits'):
                    stats['forecast_'+key] += forecast[key]
                if 'pressure_movement_windows' in forecast:
                    stats['pressure_forecast_measured_decisions'] += 1
                    stats['forecast_pressure_movement_windows'] += forecast['pressure_movement_windows']
                    stats['forecast_unpressured_movement_windows'] += forecast['unpressured_movement_windows']
            for group in semantic['diagnostics']['groups']:
                if group['lord'] != 'Humbaba' or group['term'] != BREATH: continue
                arm = 'V12' if group['policy_id'] == manifest['candidate_policy'] else 'V11'
                effects[arm].update(group['metrics'])
        lords = records[0]['spec']['setup']['lords']
        wins = [r['semantic']['outcome']['winner'] == r['spec']['candidate_seat'] for r in records]
        result = 'V12_wins_both' if all(wins) else 'V11_wins_both' if not any(wins) else 'split'
        paired[result] += 1
        row = dict(pair_id=pair_id, lords=lords, repeat=pair_specs[0]['repeat'], result=result,
                   outcomes=[r['semantic']['outcome'] for r in records])
        if len(set(lords)) == 2:
            seat = lords.index('Humbaba')
            new_won = records[seat]['semantic']['outcome']['winner'] == seat
            old_won = records[1-seat]['semantic']['outcome']['winner'] == seat
            direct['matched_setups'] += 1; direct['V12_humbaba_wins'] += new_won; direct['V11_humbaba_wins'] += old_won
            direct['gained_wins'] += new_won and not old_won; direct['lost_wins'] += old_won and not new_won
            direct['same_result'] += old_won == new_won
            row.update(V12_humbaba_won=new_won, V11_humbaba_won=old_won)
        pairs.append(row)
    assert totals['games'] == len(specs) and totals['rejected_previews'] == 0
    report = dict(schema='U13_HUMBABA_PRESSURE_AUDIT_V1', manifest=manifest,
        auditor_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        totals=totals, paired_results=paired, wins_by_repeat=dict(repeats), single_changed_lord_pairs=direct,
        behavior=dict(behavior), observed_breath_effects=dict(effects), maximum_work=dict(maximum),
        pairs=pairs, record_inventory=inventory,
        scope='Fresh fixed-loadout Python comparison. Opposite Lord seats share seeds; pairs are dependent. '
              'Forecast pressure is not observed contact or damage. Power totals follow diverging games. '
              'Only observed_breath_effects records actual pulse effects. No native parity or Lord balance claim.')
    report['analysis_sha256'] = fingerprint(report)
    atomic_json(directory/'analysis.json', report)
    print(json.dumps({k:report[k] for k in ('totals', 'paired_results', 'wins_by_repeat', 'single_changed_lord_pairs', 'behavior', 'observed_breath_effects')}, indent=2))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    run(parser.parse_args().directory)
