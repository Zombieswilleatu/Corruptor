#!/usr/bin/env python3
"""Twelve fresh paired games, two recycled workers; Python experiment only."""
import argparse
from collections import Counter
from dataclasses import asdict
import gc
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time
import traceback

from run_u13_lord_balance import freeze, verify_frozen, package
from u13_pysim.split_ward import VERSION
from u13_doctrine.common import Weights
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.planner_probe import run_case, PlannerObserver
from u13_doctrine.process_memory import sample
from u13_doctrine.survey import (TracedPolicy, cases, atomic_json, pooled_results,
                                read_record, manifest)

NAMESPACE = 'u13-split-ward-screen-20260921'
PAIRS = (('Gremory', 'Kanifous'), ('Kalligan', 'Deimos'), ('Humbaba', 'Kroni'))


def specs():
    selected = {pair for left, right in PAIRS for pair in ((left, right), (right, left))}
    for case in cases(1, NAMESPACE):
        if tuple(case['setup']['lords']) not in selected: continue
        for arm in ('current', 'split'):
            spec = dict(case, name=case['name']+'_'+arm, arm=arm, setup=dict(case['setup']))
            if arm == 'split': spec['setup']['ward_experiment'] = VERSION
            yield spec


class Observer(PlannerObserver):
    def __init__(self, *args):
        super().__init__(*args)
        self.trial = Counter()
        self.wards = []

    def accepted(self, number, seat, decision):
        super().accepted(number, seat, decision)
        order = decision['plan']['order']
        self.trial['decisions'] += 1
        self.trial['action:'+order.get('action', 'Pass')] += 1
        ward = order if order.get('action') == 'Ward' else order.get('ward', {})
        self.trial['ward_decisions'] += bool(ward)
        self.trial['split_decisions'] += bool(order.get('ward'))
        self.trial['ward_cards'] += len(ward.get('card_ids', []))
        self.trial['attack_cards'] += len(order.get('card_ids', [])) if order.get('action') in ('Hunt', 'Siege') else 0
        self.trial['split_candidates'] += decision.get('split_ward', {}).get('candidates', 0)

    def event(self, index, event, current_round):
        super().event(index, event, current_round)
        kind, data = event['type'], event['data']
        if kind == 'MARCHER_SPAWNED':
            self.trial['monster_bodies' if 'monster_id' in data['attributes'] else 'normal_recruits'] += 1
        if kind == 'MONSTER_SUMMONED': self.trial['monster_summons'] += 1
        if kind == 'WARD_CONTESTED':
            self.trial['ward_contested'] += 1
            self.trial['ward_saved'] += data['saved']
            self.wards.append(data)
        if kind == 'WARD_SOUL_GAINED': self.trial['ward_souls'] += data['amount']

    def report(self):
        return dict(super().report(), split_trial=dict(self.trial), ward_audit=self.wards)


def worker(spec, identity, directory):
    started = time.perf_counter(); cpu = time.process_time()
    memory = sample()
    policy = TracedPolicy(Weights(**identity['weights']))
    try:
        semantic, timing, operations = run_case(spec, policy, observer_factory=Observer)
        status, error = 'complete', None
    except Exception:
        semantic, timing, operations = {}, {}, []
        status, error = 'failed', traceback.format_exc()
    record = dict(manifest_sha256=fingerprint(identity), spec=spec, status=status,
        semantic=semantic, semantic_sha256=fingerprint(semantic), timing=timing,
        operations=operations, trace=policy.trace, trace_sha256=fingerprint(policy.trace),
        error=error, wall_seconds=time.perf_counter()-started)
    atomic_json(Path(directory)/(spec['name']+'.json.gz'), record, compressed=True)
    result = dict(name=spec['name'], status=status, rounds=semantic.get('rounds'), error=error,
                  wall_seconds=time.perf_counter()-started)
    del record, policy, semantic, timing, operations
    gc.collect()
    result['performance'] = dict(start=memory, after_gc=sample(), cpu_seconds=time.process_time()-cpu)
    return result


def execute(output):
    verify_frozen(output)
    identity = manifest(Path(__file__).resolve().parents[2], NAMESPACE, Weights())
    identity.update(experiment=VERSION, scope='Python-only opt-in rules trial; no native/UI parity claim',
                    frozen_source=fingerprint(json.loads((output/'frozen-source.json').read_text())))
    atomic_json(output/'manifest.json', identity)
    case_list = list(specs())
    atomic_json(output/'split-config.json', dict(cases=case_list, workers=2, worker_batch_size=4,
        source_revision=identity['source_revision'], runtime=platform.python_implementation(),
        rule='One nonempty Ward plus optional Hunt/Siege, disjoint cards, no Sigils, lane-only screen, at most one causal-save soul'))
    games = output/'games'; games.mkdir()
    for result in pooled_results(case_list, identity, str(games), 2, 4, task=worker):
        if result is None: print('Two workers still running.', flush=True); continue
        print(json.dumps(result), flush=True)
        atomic_json(output/(result['name']+'-performance.json'), result)
        if result['status'] != 'complete': raise RuntimeError(result['error'])
    arms = {name: Counter() for name in ('current', 'split')}
    paired = {}
    for spec in case_list:
        record = read_record(games/(spec['name']+'.json.gz'), identity, spec)
        game = record['semantic']; diagnostics = game['diagnostics']
        stats = Counter(diagnostics['split_trial'])
        stats.update(games=1, rounds=game['rounds'], rejected_previews=len(diagnostics['rejected_previews']),
                     banishments=diagnostics['event_counts'].get('LORD_BANISHED', 0))
        arms[spec['arm']].update(stats)
        paired.setdefault(spec['name'].rsplit('_', 1)[0], {})[spec['arm']] = dict(stats)
    report = dict(arms=arms, paired=paired, scope='Six seed/loadout/seat pairs; exploratory, not roster balance evidence')
    atomic_json(output/'split-comparison.json', report)
    print(json.dumps(report, indent=2), flush=True)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--frozen', action='store_true', help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.frozen: return execute(args.output)
    root = Path(__file__).resolve().parents[2]
    output = (args.output or Path.home()/'Downloads/Corruptor/Balance'/
              time.strftime('split-ward-%Y%m%d-%H%M%S')).resolve()
    output.mkdir(parents=True, exist_ok=False)
    frozen = freeze(root, output)
    env = dict(os.environ); env.pop('PYTHONPATH', None)
    checks = subprocess.run([sys.executable, '-m', 'unittest', 'u13_doctrine.test_split_ward',
        'u13_doctrine.test_ward_recipes', 'u13_doctrine.test_reserved_recipes',
        'u13_doctrine.test_recipes_veil'], cwd=frozen/'Scripts/Sim', env=env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (output/'focused-python.log').write_text(checks.stdout)
    print(checks.stdout, flush=True)
    if checks.returncode: return checks.returncode
    print(f'Prepared 12 games, two workers, recycle every four games: {output}', flush=True)
    if args.prepare_only: return 0
    code = 1
    try:
        with (output/'run.log').open('w') as log:
            proc = subprocess.Popen([sys.executable, '-u', str(frozen/'Scripts/Sim/run_u13_split_ward_experiment.py'),
                '--frozen', '--output', str(output)], cwd=frozen, env=env,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            for line in proc.stdout: print(line, end='', flush=True); log.write(line); log.flush()
            code = proc.wait()
        return code
    finally:
        atomic_json(output/'run-status.json', dict(status='complete' if code == 0 else 'failed_or_interrupted', exit_code=code))
        package(output)


if __name__ == '__main__': raise SystemExit(main())
