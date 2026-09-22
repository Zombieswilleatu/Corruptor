#!/usr/bin/env python3
"""Hunger-aware anti-Kroni Hunt valuation; full gameplay kit unchanged."""
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


def pressure_bonus(attributes, result):
    if attributes.get('lord_id') != 'Kroni' or not attributes.get('alive'):
        return 0
    tier = min(3, max(0, attributes.get('hunger', 0)))
    if result['banished']:
        return 8*tier
    return 3*tier*min(2, result['guards'])


def install_doctrine():
    import inspect
    import textwrap
    from u13_doctrine.facts import Facts
    from u13_doctrine import common
    from u13_doctrine.lords import deimos
    assert not hasattr(__import__('u13_doctrine.facts', fromlist=['kroni_hunt_bonus']), 'kroni_hunt_bonus'), 'Historical experiment requires pre-integration source 964a495; do not double-apply the Hunt bonus.'
    attack, value, artillery_value = Facts.attack, Facts.attack_value, deimos.attack_value

    def weighted_attack(self, action, target, ids, excluded_waiters=()):
        result = attack(self, action, target, ids, excluded_waiters)
        result['kroni_pressure_bonus'] = (pressure_bonus(self.lord[self.enemy]['attributes'], result)
                                            if action == 'Hunt' else 0)
        return result

    def weighted_value(self, action, target, ids, weights):
        return value(self, action, target, ids, weights)+self.attack(action, target, ids)['kroni_pressure_bonus']

    Facts.attack = weighted_attack
    Facts.attack_value = weighted_value
    deimos.attack_value = lambda result, weights: artillery_value(result, weights)+result.get('kroni_pressure_bonus', 0)
    # Apply the same delta when Rites spend the Supplicants counted by a proposal.
    source = textwrap.dedent(inspect.getsource(common.CommonSmartCore.decide))
    needle = "score += (self.weights.damage*(adjusted['damage']-baseline['damage'])"
    assert source.count(needle) == 1
    source = source.replace(needle, "score += (adjusted.get('kroni_pressure_bonus', 0)-baseline.get('kroni_pressure_bonus', 0)+self.weights.damage*(adjusted['damage']-baseline['damage'])")
    scope = dict(common.CommonSmartCore.decide.__globals__)
    exec(compile(source, '<anti-kroni-hunt-doctrine>', 'exec'), scope)
    common.CommonSmartCore.decide = scope['decide']


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
    hunt_decisions = []

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
            if kind == 'HUNT_RESOLVED' and d['player_id'] != seat:
                counts['opponent_hunts'] += 1
                counts['kroni_banishments'] += int(d['banished'])
                counts['opponent_hunt_guards'] += d['guards_defeated']
            if kind == 'SIEGE_RESOLVED' and d['player_id'] == seat:
                counts['siege_targets_destroyed'] += int(d.get('destroyed', False))

    from u13_doctrine.facts import Facts
    class HuntPolicy(TracedPolicy):
        def decide(self, view, preview):
            decision = super().decide(view, preview)
            if view['player_id'] != seat:
                f = Facts(view)
                order = decision['plan']['order']
                row = dict(round=view['round'], hunger=f.lord[f.enemy]['attributes']['hunger'],
                           action=order.get('action', 'Pass'), kroni_alive=f.lord[f.enemy]['attributes']['alive'])
                if order.get('action') == 'Hunt':
                    excluded = [k for spend in order.get('rites', {}).get('waiter_spends', []) for k in spend['marcher_ids']]
                    row['estimate'] = f.attack('Hunt', order['target_id'], order['card_ids'], excluded)
                hunt_decisions.append(row)
            return decision
    policy = HuntPolicy(Weights(**weights))
    semantic, timing, operations = planner_probe.run_case(
        dict(spec, name=spec['name']+'_hunger_hunt_doctrine'), policy, observer_factory=Observer)
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
        counts=dict(counts), meals=meals, hunt_decisions=hunt_decisions,
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
    report = dict(schema='U13_HUNGER_HUNT_DOCTRINE_SAMPLE_V1', workers=2, repeat=a.repeat,
        scope='Full gameplay kit unchanged. Hunt versus living Kroni: extra 8*min(Hunger,3) if predicted banish, otherwise 3*min(Hunger,3)*min(guards_removed,2). No bonus to ineffective Hunt, Siege or Hunger0. Same bonus in artillery and spent-Supplicant corrections.',
        runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        source_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        source_sha256=before, weights=weights, games=[], failures=[])
    with ProcessPoolExecutor(max_workers=2, initializer=install_doctrine, mp_context=multiprocessing.get_context('spawn')) as pool:
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
