#!/usr/bin/env python3
"""Frozen V10 versus V11, on the same accepted immediate-Breath engine.

Three repeats of every ordered matchup involving Deimos or Humbaba, each with
both policy assignments. Eight unchanged-Lord control games are separate from
the primary result. Reuse the established comparison recorder and policy loader.
"""
import argparse
from concurrent.futures import FIRST_COMPLETED, ProcessPoolExecutor, wait
from dataclasses import asdict
import hashlib
import json
import multiprocessing
from pathlib import Path
import platform
import sys
import time

from u13_doctrine.common import VERSION, Weights
from u13_doctrine.comparison import aggregate, freeze_baseline, load_baseline, paired_cases, run_one
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.reference_probe import harness_hash
from u13_doctrine.survey import LOADOUT, atomic_json, read_record
from u13_pysim import opening
from u13_pysim.verify import source_identity

BASELINE = 'c0b2a76fdc1ae33239194a18f9477bbc58fc3d80'
NAMESPACE = 'u13-v10-v11-same-breath-2026-09-19'
FOCUS = frozenset(('Deimos', 'Humbaba'))
CONTROLS = {frozenset(('Gremory', 'Kroni')), frozenset(('Kalligan', 'Odradek'))}


def campaign_cases(repeats, namespace):
    result = []
    for spec in paired_cases(repeats, namespace):
        lords = set(spec['setup']['lords'])
        purpose = 'primary' if lords & FOCUS else 'control'
        if purpose == 'control' and (spec['repeat'] != 0 or frozenset(lords) not in CONTROLS):
            continue
        result.append(dict(spec, purpose=purpose))
    assert len(result) == 64*repeats+8
    assert len({s['name'] for s in result}) == len(result)
    for first, second in zip(result[::2], result[1::2]):
        assert first['setup'] == second['setup']
        assert first['pair_id'] == second['pair_id']
        assert (first['candidate_seat'], second['candidate_seat']) == (0, 1)
    return result


def run(directory, repeats=3, workers=8, namespace=NAMESPACE):
    root = Path(__file__).resolve().parents[2]
    directory = Path(directory).resolve()
    specs = campaign_cases(repeats, namespace)
    (directory/'games').mkdir(parents=True, exist_ok=True)
    frozen = freeze_baseline(root, BASELINE, directory/'baseline')
    baseline = load_baseline(directory/'baseline')
    assert VERSION == 'U13_COMMON_SMART_CORE_ALPHA_V11_ROUT_HUMBABA'
    assert baseline.VERSION == 'U13_COMMON_SMART_CORE_ALPHA_V10_DEIMOS_ARTILLERY'
    assert asdict(Weights()) == asdict(baseline.Weights())
    revision, engine = source_identity(root)
    runner_hash = hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n', b'\n')).hexdigest()
    manifest = dict(schema='U13_SUPPORT_MATCHED_COMPARISON_V1', source_revision=revision,
        engine_source_sha256=engine, harness_source_sha256=harness_hash(root),
        runner_sha256=runner_hash, baseline=frozen, candidate_policy=VERSION,
        baseline_policy=baseline.VERSION, weights=asdict(Weights()),
        namespace=namespace, repeats=repeats, focused_lords=sorted(FOCUS),
        controls=sorted(sorted(pair) for pair in CONTROLS), loadout=LOADOUT,
        opening_policy=opening.ECONOMY, round_cap=40, cases_sha256=fingerprint(specs),
        primary_games=64*repeats, control_games=8,
        implementation=platform.python_implementation(), python=sys.version,
        scope='Same current engine and seed within each pair; swap policy assignments and Lord seats. '
              'Controls excluded from primary outcomes. Descriptive fixed-loadout Python comparison; '
              'no weight tuning, Lord balance, native parity or independent-games significance claim.')
    path = directory/'manifest.json'
    if path.exists() and json.loads(path.read_text()) != manifest:
        raise ValueError('Different comparison identity')
    atomic_json(path, manifest)
    atomic_json(directory/'specs.json', specs)
    pending = []
    for spec in specs:
        path = directory/'games'/(spec['name']+'.json.gz')
        if path.exists(): read_record(path, manifest, spec)
        else: pending.append(spec)
    start, done = time.perf_counter(), len(specs)-len(pending)
    print(f'SUPPORT COMPARISON {len(specs)} games; {done} verified cached; {workers} workers', flush=True)
    with ProcessPoolExecutor(max_workers=workers, mp_context=multiprocessing.get_context('spawn')) as pool:
        tasks = {pool.submit(run_one, spec, manifest, str(directory)) for spec in pending}
        while tasks:
            finished, tasks = wait(tasks, timeout=15, return_when=FIRST_COMPLETED)
            for task in finished:
                result = task.result(); done += 1
                print(f"{result['status'].upper()} {done}/{len(specs)} {result['name']} "
                      f"rounds={result['rounds']} elapsed={time.perf_counter()-start:.1f}s", flush=True)
                if result['error']: print(result['error'], flush=True)
            if not finished:
                print(f'RUNNING {done}/{len(specs)} elapsed={time.perf_counter()-start:.1f}s', flush=True)
    if source_identity(root)[1] != engine or harness_hash(root) != manifest['harness_source_sha256']:
        raise ValueError('Source changed during comparison')
    if hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n', b'\n')).hexdigest() != runner_hash:
        raise ValueError('Runner changed during comparison')
    summaries = {}
    for purpose in ('primary', 'control'):
        summaries[purpose] = aggregate((read_record(directory/'games'/(s['name']+'.json.gz'), manifest, s)
                                       for s in specs if s['purpose'] == purpose), VERSION)
    report = dict(manifest=manifest, summaries=summaries, summaries_sha256=fingerprint(summaries),
                  elapsed_seconds=time.perf_counter()-start)
    atomic_json(directory/'summary.json', report)
    for purpose, summary in summaries.items():
        print(f"{purpose.upper()} {summary['completed']}/{summary['requested']}; failures={summary['failed']}; "
              f"wins={dict(summary['wins'])}; rejected_previews={summary['rejected_previews']}", flush=True)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--repeats', type=int, default=3)
    parser.add_argument('--workers', type=int, default=8)
    parser.add_argument('--namespace', default=NAMESPACE)
    args = parser.parse_args()
    if args.repeats < 1 or args.workers < 1: parser.error('Repeats and workers must be positive')
    report = run(args.output, args.repeats, args.workers, args.namespace)
    raise SystemExit(int(any(s['failed'] for s in report['summaries'].values())))
