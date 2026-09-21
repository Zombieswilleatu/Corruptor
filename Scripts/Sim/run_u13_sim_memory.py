#!/usr/bin/env python3
"""Six fresh self-play games, two workers, one pool restart after four games."""
import argparse
import gc
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import traceback

from run_u13_lord_balance import freeze, verify_frozen, package, Tee

NAMES = [
    'gremory_humbaba_00', 'kroni_odradek_00', 'valak_kalligan_00',
    'humbaba_gremory_00', 'odradek_kroni_00', 'kalligan_valak_00',
]


def signatures(record):
    return dict(semantic=record['semantic_sha256'], trace=record['trace_sha256'],
                decisions=record['semantic']['decisions_sha256'],
                final_state=record['semantic']['final_state_sha256'])


def execute(output):
    from u13_doctrine.common import Weights
    from u13_doctrine.survey import manifest, pooled_results, read_record, atomic_json
    verify_frozen(output)
    config = json.loads((output/'memory-check-config.json').read_text(encoding='utf-8'))
    root = Path(__file__).resolve().parents[2]
    identity = manifest(root, config['namespace'], Weights(**config['weights']))
    atomic_json(output/'manifest.json', identity)
    games = output/'games'
    games.mkdir()
    specs = config['cases']
    lookup = {spec['name']: spec for spec in specs}
    batches = {spec['name']: 1+i//4 for i, spec in enumerate(specs)}
    report = dict(scope='Six-game self-play memory check; no balance or long-run leak verdict',
                  workers=2, worker_batch_size=4, requested=len(specs),
                  baseline_report=config['baseline_report'], manifest=identity,
                  status='running', games=[])
    start = time.perf_counter()
    atomic_json(output/'memory-check.json', report)
    print('MEMORY CHECK: 6 fresh games; 2 workers; restart after 4.', flush=True)
    for result in pooled_results(specs, identity, str(games), 2, 4):
        if result is None:
            print(f"RUNNING {len(report['games'])}/6 elapsed={time.perf_counter()-start:.1f}s", flush=True)
            continue
        result['batch'] = batches[result['name']]
        report['games'].append(result)
        report['elapsed_seconds'] = time.perf_counter()-start
        atomic_json(output/'memory-check.json', report)
        perf = result['performance']
        before, after = perf['start'], perf['after_gc']
        print(f"{result['status'].upper()} {len(report['games'])}/6 {result['name']} "
              f"batch={result['batch']} worker={after['pid']} "
              f"start={before['rss_mb']}MB after_gc={after['rss_mb']}MB "
              f"peak={after['peak_mb']}MB total={perf['total_wall_seconds']:.2f}s", flush=True)
        if result['error']: print(result['error'], flush=True)
    # Verify only after both pools exit, keeping record parsing out of worker timings.
    report['simulation_elapsed_seconds'] = time.perf_counter()-start
    for result in report['games']:
        record = read_record(games/(result['name']+'.json.gz'), identity, lookup[result['name']])
        result['exact_match'] = record['status'] == 'complete'
        if result['exact_match']:
            result['actual_signatures'] = signatures(record)
            result['expected_signatures'] = config['expected'][result['name']]
            result['exact_match'] = result['actual_signatures'] == result['expected_signatures']
        del record
        gc.collect()
    report['passed'] = sum(r['exact_match'] for r in report['games'])
    report['failed'] = len(specs)-report['passed']
    report['status'] = 'complete' if report['failed'] == 0 else 'failed'
    report['worker_pids_by_batch'] = {
        str(batch): sorted({r['performance']['start']['pid'] for r in report['games'] if r['batch'] == batch})
        for batch in (1, 2)}
    report['elapsed_seconds'] = time.perf_counter()-start
    atomic_json(output/'memory-check.json', report)
    print(f"MEMORY CHECK COMPLETE: {report['passed']}/6 exact self-play matches.", flush=True)
    print('MEMORY REPORT: '+str(output/'memory-check.json'), flush=True)
    return int(report['failed'] != 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, help='Original balance report; defaults to latest completed report')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--frozen', action='store_true', help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.frozen:
        if args.output is None: parser.error('frozen mode requires output')
        with (args.output/'run.log').open('a', encoding='utf-8') as log:
            old_out, old_err = sys.stdout, sys.stderr
            sys.stdout, sys.stderr = Tee(old_out, log), Tee(old_err, log)
            try:
                return execute(args.output)
            except Exception:
                traceback.print_exc()
                return 1
            finally:
                sys.stdout, sys.stderr = old_out, old_err
    if args.report is None:
        folder = Path.home()/'Downloads/Corruptor/Balance'
        reports = [p.parent for p in folder.glob('*/lord-balance.json')]
        if not reports: parser.error('No completed balance report found; supply --report with its folder')
        args.report = max(reports, key=lambda p: p.stat().st_mtime)
    baseline = args.report.resolve()
    verify_frozen(baseline)
    from u13_doctrine.survey import read_record, atomic_json
    old_identity = json.loads((baseline/'manifest.json').read_text(encoding='utf-8'))
    old_config = json.loads((baseline/'balance-config.json').read_text(encoding='utf-8'))
    available = {spec['name']: spec for spec in old_config['cases']}
    selected, expected = [], {}
    for name in NAMES:
        spec = available[name]
        record = read_record(baseline/'games'/(name+'.json.gz'), old_identity, spec)
        if record['status'] != 'complete': raise ValueError('Baseline game did not complete: '+name)
        selected.append(spec)
        expected[name] = signatures(record)
        del record
        gc.collect()
    output = (args.output or Path.home()/'Downloads/Corruptor/Performance'/
              time.strftime('sim-memory-check-%Y%m%d-%H%M%S')).resolve()
    output.mkdir(parents=True, exist_ok=False)
    root = Path(__file__).resolve().parents[2]
    frozen = freeze(root, output)
    atomic_json(output/'memory-check-config.json', dict(
        baseline_report=str(baseline), namespace=old_identity['namespace'],
        weights=old_identity['weights'], cases=selected, expected=expected))
    print('FROZEN MEMORY CHECK: '+str(output), flush=True)
    env = dict(os.environ)
    env.pop('PYTHONPATH', None)
    code = 130
    try:
        code = subprocess.call([sys.executable, '-u', str(frozen/'Scripts/Sim/run_u13_sim_memory.py'),
                                '--frozen', '--output', str(output)], cwd=frozen, env=env)
        return code
    finally:
        atomic_json(output/'run-status.json', dict(
            status='complete' if code == 0 else 'failed_or_interrupted', exit_code=code))
        package(output)


if __name__ == '__main__': raise SystemExit(main())
