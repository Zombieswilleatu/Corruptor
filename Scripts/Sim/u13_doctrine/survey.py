"""Reproducible full-roster behavior survey, separate from tuning/parity gates.

Every ordered matchup gets the same repeat count. Opposite seats share a seed
per unordered Lord pair/repeat. Both use the ordinary five-castle loadout. This
controls seat/seed coverage; it does not match hidden draws to Lord identities.
"""
from collections import Counter
from concurrent.futures import ProcessPoolExecutor, wait, FIRST_COMPLETED
from dataclasses import asdict
import gzip
import gc
import hashlib
import json
import multiprocessing
from pathlib import Path
import platform
import sys
import time
import traceback

from u13_pysim.opening import LORDS
from u13_pysim.verify import source_identity
from .common import CommonSmartCore, Weights, VERSION
from .diagnostics import fingerprint
from .planner_probe import run_case
from .reference_probe import harness_hash
from .process_memory import sample as memory_sample

SCHEMA = 'U13_DOCTRINE_SURVEY_V1'
LOADOUT = ['Keep', 'Stockpile', 'SummoningCircle', 'SiegeEngine', 'Bastion']


def cases(repeats, namespace='u13-common-v3-survey-2026-09-17'):
    if type(repeats) is not int or repeats < 1:
        raise ValueError('repeats must be positive')
    for repeat in range(repeats):
        for left in LORDS:
            for right in LORDS:
                pair = ':'.join(sorted((left, right)))
                yield dict(name=f'{left.lower()}_{right.lower()}_{repeat:02d}', repeat=repeat,
                    setup=dict(seed=f'{namespace}:{pair}:{repeat:02d}', lords=[left, right],
                               castles=[LOADOUT[:], LOADOUT[:]]))


def atomic_json(path, value, compressed=False):
    path = Path(path)
    temporary = path.with_name(path.name+'.tmp')
    if compressed:
        with gzip.open(temporary, 'wt', encoding='utf-8') as stream:
            json.dump(value, stream, sort_keys=True, separators=(',', ':'), allow_nan=False)
    else:
        temporary.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False)+'\n', encoding='utf-8')
    temporary.replace(path)


def read_record(path, manifest, spec):
    with gzip.open(path, 'rt', encoding='utf-8') as stream:
        record = json.load(stream)
    if record['manifest_sha256'] != fingerprint(manifest) or record['spec'] != spec:
        raise ValueError('different survey identity: '+str(path))
    if record['semantic_sha256'] != fingerprint(record['semantic']):
        raise ValueError('corrupt semantic record: '+str(path))
    if record['trace_sha256'] != fingerprint(record['trace']):
        raise ValueError('corrupt decision trace: '+str(path))
    if record['status'] == 'complete' and record['semantic']['decisions_sha256'] != fingerprint(record['operations']):
        raise ValueError('corrupt operation stream: '+str(path))
    return record


class TracedPolicy:
    """Passive recorder of detached observations already supplied to the policy."""
    def __init__(self, weights):
        self.policy, self.trace = CommonSmartCore(weights), []

    def decide(self, view, preview):
        decision = self.policy.decide(view, preview)
        self.trace.append(dict(view=view, decision=decision))
        return decision

    def choose_card(self, view, category):
        return self.policy.choose_card(view, category)


def run_one(spec, manifest, directory):
    memory_start = memory_sample()
    cpu_start = time.process_time()
    policy = TracedPolicy(Weights(**manifest['weights']))
    start = time.perf_counter()
    try:
        semantic, timing, operations = run_case(spec, policy)
        status, error = 'complete', None
    except Exception:
        semantic, timing, operations = {}, {}, []
        status, error = 'failed', traceback.format_exc()
    record = dict(manifest_sha256=fingerprint(manifest), spec=spec, status=status,
        semantic=semantic, semantic_sha256=fingerprint(semantic), timing=timing,
        operations=operations, trace=policy.trace, trace_sha256=fingerprint(policy.trace), error=error,
        wall_seconds=time.perf_counter()-start)
    path = Path(directory)/(spec['name']+'.json.gz')
    atomic_json(path, record, compressed=True)
    # The parent rereads/verifies records after all workers finish. Keep IPC small.
    result = dict(name=spec['name'], status=status, rounds=semantic.get('rounds'),
                  wall_seconds=record['wall_seconds'], error=error)
    memory_written = memory_sample()
    # PyPy does not reclaim large detached traces immediately like refcounted
    # CPython. End the game's lifetime explicitly before accepting another.
    del record, policy, semantic, timing, operations
    gc.collect()
    result['performance'] = dict(start=memory_start, after_write=memory_written,
        after_gc=memory_sample(), total_wall_seconds=time.perf_counter()-start,
        cpu_seconds=time.process_time()-cpu_start)
    performance_dir = Path(directory).parent/'performance'
    performance_dir.mkdir(exist_ok=True)
    atomic_json(performance_dir/(spec['name']+'.json'), result['performance'])
    return result


def manifest(root, namespace, weights):
    revision, engine = source_identity(root)
    return dict(schema=SCHEMA, source_revision=revision, engine_source_sha256=engine,
        harness_source_sha256=harness_hash(root), policy=VERSION, weights=asdict(weights),
        namespace=namespace, lords=LORDS, loadout=LOADOUT, round_cap=40,
        implementation=platform.python_implementation(), python=sys.version,
        runner_sha256=hashlib.sha256((Path(root)/'Scripts/Sim/run_u13_doctrine_survey.py').read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
        scope='Python self-play behavior survey; no weight tuning, policy comparison, balance claim or new native parity')


def aggregate(records):
    """Preserve unknown flags and raw denominators when combining seats/games."""
    games, groups, events, recipes, protection, maximum = [], {}, Counter(), Counter(), Counter(), Counter()
    phases, cards = {}, Counter()
    for record in records:
        spec, game = record['spec'], record['semantic']
        header = dict(name=spec['name'], lords=spec['setup']['lords'], repeat=spec['repeat'],
                      status=record['status'], wall_seconds=record['wall_seconds'], timing=record['timing'])
        if record['status'] != 'complete':
            header['error'] = record['error']; games.append(header); continue
        header.update({k: game[k] for k in ('rounds', 'operations', 'decisions_sha256', 'final_state_sha256', 'outcome')})
        header['rejected_previews'] = len(game['diagnostics']['rejected_previews'])
        games.append(header)
        d = game['diagnostics']
        events.update(d['event_counts']); recipes.update(d['recipe_decisions']); protection.update(d['protection_scenarios'])
        for k, v in d['maximum_work'].items(): maximum[k] = max(maximum[k], v)
        for row in d['groups']:
            key = row['lord'], row['category'], row['term'], row['support']
            if key not in groups:
                groups[key] = dict(lord=key[0], category=key[1], term=key[2], support=key[3],
                    decisions=0, flags={f: Counter() for f in row['flags']} if row['flags'] is not None else None,
                    candidates={f: Counter() for f in row['candidates']} if row['candidates'] is not None else None,
                    reasons=Counter(), outcomes=Counter(), metrics=Counter(), effect_records=0,
                    nonzero_effect_records=0, outcome_unobserved=0)
            merged = groups[key]
            merged['decisions'] += row['decisions']; merged['reasons'].update(row['reasons'])
            if row['support'] != 'supported':
                for field in ('outcomes', 'metrics', 'effect_records', 'nonzero_effect_records', 'outcome_unobserved'):
                    merged[field] = None
                continue
            for field in ('flags', 'candidates'):
                for f, counts in row[field].items(): merged[field][f].update(counts)
            for field in ('outcomes', 'metrics'): merged[field].update(row[field])
            for field in ('effect_records', 'nonzero_effect_records', 'outcome_unobserved'): merged[field] += row[field]
        for item in record['trace']:
            view, decision = item['view'], item['decision']
            phase = '1-5' if view['round'] <= 5 else '6-10' if view['round'] <= 10 else '11+'
            phases.setdefault(phase, Counter())[decision['plan']['order'].get('action', 'Pass')] += 1
            order = decision['plan']['order']
            cards['planning_decisions'] += 1; cards['hand_cards'] += len(view['hand'])
            cards['combat_cards'] += len(order.get('card_ids', []))
            cards['guard_cards'] += len(order.get('guard_moves', []))
            cards['resummon_cards'] += len(order.get('summon', {}).get('card_ids', []))
            cards['invocation_cards'] += len(order.get('rites', {}).get('invocation', {}).get('card_ids', []))
            cards['power_cards'] += sum(len(p['cost'].get('discard_ids', [])) for p in decision['plan']['powers'])
    complete = [g for g in games if g['status'] == 'complete']
    return dict(games=games, completed=len(complete), failed=len(games)-len(complete),
        rounds=sum(g['rounds'] for g in complete), operations=sum(g['operations'] for g in complete),
        rejected_previews=sum(g['rejected_previews'] for g in complete),
        groups=[groups[k] for k in sorted(groups)], event_counts=events, recipe_decisions=recipes,
        protection_scenarios=protection, maximum_work=maximum, combat_by_round_band=phases, card_use=cards)


def pooled_results(specs, identity, directory, workers, worker_batch_size=12, task=run_one):
    """Bound worker lifetime; a failed worker propagates instead of hanging.

    Rotate entire pools after a bounded batch, avoiding runtime-specific
    max_tasks_per_child behavior. A batch contains at most worker_batch_size
    games total. None is yielded for a heartbeat. Zero keeps one pool alive.
    """
    if workers < 1 or worker_batch_size < 0:
        raise ValueError('workers must be positive; worker_batch_size must be nonnegative')
    width = worker_batch_size or max(1, len(specs))
    for offset in range(0, len(specs), width):
        batch = specs[offset:offset+width]
        if offset: print('RECYCLE simulation workers; completed batch released.', flush=True)
        with ProcessPoolExecutor(max_workers=min(workers, len(batch)), mp_context=multiprocessing.get_context('spawn')) as pool:
            tasks = {pool.submit(task, spec, identity, directory) for spec in batch}
            while tasks:
                finished, tasks = wait(tasks, timeout=15, return_when=FIRST_COMPLETED)
                for future in finished:
                    yield future.result()
                if not finished: yield None


def run(root, directory, repeats=2, workers=8, namespace='u13-common-v3-survey-2026-09-17', weights=None,
        worker_batch_size=12):
    directory = Path(directory); directory.mkdir(parents=True, exist_ok=True)
    (directory/'games').mkdir(exist_ok=True)
    identity = manifest(root, namespace, weights or Weights())
    path = directory/'manifest.json'
    if path.exists() and json.loads(path.read_text()) != identity:
        raise ValueError('Existing directory contains a different survey; use a new directory.')
    atomic_json(path, identity)
    specs = list(cases(repeats, namespace)); pending = []
    for spec in specs:
        path = directory/'games'/(spec['name']+'.json.gz')
        if path.exists(): read_record(path, identity, spec)
        else: pending.append(spec)
    start, completed = time.perf_counter(), len(specs)-len(pending)
    print(f'SURVEY {len(specs)} games; {completed} verified cached; {workers} workers', flush=True)
    for result in pooled_results(pending, identity, str(directory/'games'), workers, worker_batch_size):
        if result is None:
            print(f'RUNNING {completed}/{len(specs)} elapsed={time.perf_counter()-start:.1f}s', flush=True)
            continue
        completed += 1
        mem = result['performance']['after_gc']
        print(f"{result['status'].upper()} {completed}/{len(specs)} {result['name']} rounds={result['rounds']} wall={result['wall_seconds']:.2f}s elapsed={time.perf_counter()-start:.1f}s worker={mem['pid']} rss={mem['rss_mb']}MB peak={mem['peak_mb']}MB", flush=True)
        if result['error']: print(result['error'], flush=True)
    records = (read_record(directory/'games'/(spec['name']+'.json.gz'), identity, spec) for spec in specs)
    result = dict(manifest=identity, repeats=repeats, workers=workers, worker_batch_size=worker_batch_size, requested=len(specs),
                  summary=aggregate(records), invocation_seconds=time.perf_counter()-start)
    result['summary_sha256'] = fingerprint(result['summary'])
    atomic_json(directory/'summary.json', result)
    print(f"SURVEY COMPLETE {result['summary']['completed']}/{len(specs)}; failures={result['summary']['failed']}; rejected_previews={result['summary']['rejected_previews']}", flush=True)
    return result
