#!/usr/bin/env python3
"""Bounded, seat-paired Kroni sample against immutable archived controls."""
import argparse
from concurrent.futures import ProcessPoolExecutor, as_completed
import gzip
import hashlib
import json
import multiprocessing
from pathlib import Path
import subprocess
from collections import Counter

from u13_doctrine import planner_probe
from u13_doctrine.common import Weights
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.survey import TracedPolicy


def worker(path, weights, output):
    path = Path(path)
    with gzip.open(path, 'rt') as f:
        record = json.load(f)
    assert record['status'] == 'complete'
    assert fingerprint(record['semantic']) == record['semantic_sha256']
    assert fingerprint(record['operations']) == record['semantic']['decisions_sha256']
    spec = record['spec']
    seat = spec['setup']['lords'].index('Kroni')
    meals, counts = [], Counter()

    class Observer(planner_probe.PlannerObserver):
        def event(self, index, event, number):
            super().event(index, event, number)
            d, kind = event['data'], event['type']
            if kind == 'GUARD_DEVOURED' and d['player_id'] == seat:
                if d['cause'] == 'Consume':
                    assert 'guard_bounce' in d
                    enemy = d['before']['owner'] != seat
                    counts['enemy_meals' if enemy else 'friendly_meals'] += 1
                    meals.append(dict(round=d['round'], enemy=enemy,
                        lane=d['before']['attributes']['lane'],
                        value=d['before']['attributes']['value'], flight=d['guard_bounce']))
                else:
                    counts['cannibal_guards'] += 1
            if kind == 'CONSUME_MISSED':
                counts['consume_misses'] += 1
            if kind == 'RAVENOUS_ARMED' and d['actor']['owner'] == seat:
                counts['ravenous_uses'] += 1
            if kind == 'RAVENOUS_REWARDED' and d['player_id'] == seat:
                assert d['enemy_consumed'] >= 11
                counts['ravenous_rewards'] += 1
            if kind == 'SIEGE_RESOLVED' and d['player_id'] == seat:
                counts['siege_targets_destroyed'] += int(d.get('destroyed', False))

    policy = TracedPolicy(Weights(**weights))
    semantic, timing, operations = planner_probe.run_case(
        dict(spec, name=spec['name']+'_guard_bounce'), policy, observer_factory=Observer)
    for op in operations:
        if op['kind'] == 'submit':
            for plan in op['plans']:
                for power in plan['powers']:
                    if power['power_id'] == 'Consume':
                        assert power['target'] == {'mode': 'guard_bounce'}
    baseline_groups = record['semantic']['diagnostics']['groups']
    old_consume = [g for g in baseline_groups if g['lord'] == 'Kroni' and g['term'] == 'Consume']
    new_consume = [g for g in semantic['diagnostics']['groups'] if g['lord'] == 'Kroni' and g['term'] == 'Consume']
    result = dict(name=spec['name'], setup=spec['setup'], kroni_seat=seat,
        opponent=spec['setup']['lords'][1-seat], baseline=record['semantic']['outcome'],
        outcome=semantic['outcome'], baseline_consume=old_consume, consume=new_consume,
        baseline_victory_race=record['semantic']['diagnostics']['victory_race'],
        counts=dict(counts), meals=meals,
        rejected_previews=semantic['diagnostics']['rejected_previews'], timing=timing,
        archived_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    trace = dict(result=result, operations=operations, semantic=semantic,
                 semantic_sha256=fingerprint(semantic), trace=policy.trace)
    with gzip.open(Path(output)/(spec['name']+'.json.gz'), 'wt') as f:
        json.dump(trace, f)
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--baseline', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--repeat', choices=['00', '01'], default='01')
    a = p.parse_args()
    paths = sorted(path for path in (a.baseline/'games').glob('*_'+a.repeat+'_tempo.json.gz')
                   if path.name.split('_')[:2].count('kroni') == 1)
    assert len(paths) == 16
    a.output.mkdir(parents=True, exist_ok=True)
    weights = json.loads((a.baseline/'manifest.json').read_text())['weights']
    root = Path(__file__).resolve().parent
    def hashes():
        return {str(f.relative_to(root)): hashlib.sha256(f.read_bytes()).hexdigest()
                for folder in ('u13_pysim', 'u13_doctrine') for f in sorted((root/folder).rglob('*.py'))}
    before = hashes()
    report = dict(schema='U13_GUARD_CONSUME_SAMPLE_V1', workers=2, repeat=a.repeat,
        scope='Historical matched controls versus current bouncing Consume plus eleven-enemy Ravenous; no isolated Consume causal estimate.',
        runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        source_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        source_sha256=before, weights=weights, games=[], failures=[])
    with ProcessPoolExecutor(max_workers=2, mp_context=multiprocessing.get_context('spawn')) as pool:
        futures = {pool.submit(worker, str(path), weights, str(a.output)): path for path in paths}
        for future in as_completed(futures):
            path = futures[future]
            try:
                game = future.result()
                report['games'].append(game)
                print(json.dumps(dict(completed=len(report['games']), name=game['name'],
                    baseline=game['baseline'], outcome=game['outcome'], counts=game['counts'])), flush=True)
            except Exception as exc:
                report['failures'].append(dict(name=path.name, error=repr(exc)))
                print('FAILED '+path.name+' '+repr(exc), flush=True)
            (a.output/'summary.json').write_text(json.dumps(report, indent=2)+'\n')
    assert hashes() == before, 'Simulation source changed during batch'
    assert not report['failures'], report['failures']
    assert len(report['games']) == 16

if __name__ == '__main__':
    main()
