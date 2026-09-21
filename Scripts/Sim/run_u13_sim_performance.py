#!/usr/bin/env python3
"""Short, sequential saved-game benchmark against a frozen balance report.

Replays recorded decisions and checks the exact final state, including events.
Measures engine execution and hashing, not bot planning or trace recording.
Each build runs in a fresh process using the same Python interpreter.
"""
import argparse
import gc
import gzip
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time


DEFAULT_GAMES = ['gremory_humbaba_00', 'kroni_odradek_00', 'valak_kalligan_00']


def replay(source, report, games):
    # Load only the standalone measurement helper from this benchmark's build.
    from u13_doctrine.process_memory import sample
    sys.path.insert(0, str(source/'Scripts/Sim'))
    from u13_pysim.power_match import PowerMatch
    from u13_pysim.benchmark_full_match import digest
    results = []
    for name in games:
        with gzip.open(report/'games'/(name+'.json.gz'), 'rt', encoding='utf-8') as stream:
            record = json.load(stream)
        if record['status'] != 'complete': raise ValueError('Cannot replay failed game: '+name)
        setup, operations = record['spec']['setup'], record['operations']
        expected = record['semantic']['final_state_sha256']
        del record
        gc.collect()
        start = time.perf_counter()
        match = PowerMatch(setup)
        for operation in operations:
            response = match.apply(operation)
            if response['action'] == 'invalid': raise ValueError((name, operation, response))
        played = time.perf_counter()-start
        actual = digest(match)
        elapsed = time.perf_counter()-start
        if actual != expected: raise ValueError('Final-state mismatch: '+name)
        before_gc = sample()
        del match, operations, response
        gc.collect()
        result = dict(game=name, replay_seconds=played, total_seconds=elapsed,
                      final_state_sha256=actual, after_digest=before_gc, after_gc=sample())
        results.append(result)
        print(f'{source.name}: {name} {elapsed:.2f}s peak={before_gc["peak_mb"]}MB exact state matched', flush=True)
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, help='Completed report folder; defaults to newest completed balance report')
    parser.add_argument('--games', nargs='+', default=DEFAULT_GAMES)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--source', type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if any(Path(name).name != name or '/' in name or '\\' in name for name in args.games):
        parser.error('games must be simple case names')
    if args.report is None:
        folder = Path.home()/'Downloads/Corruptor/Balance'
        available = [p.parent for p in folder.glob('*/lord-balance.json')]
        if not available: parser.error('No completed report found; supply --report with its folder path')
        args.report = max(available, key=lambda p: p.stat().st_mtime)
    args.report = args.report.resolve()
    if args.source:
        args.output.write_text(json.dumps(replay(args.source.resolve(), args.report, args.games), indent=2)+'\n', encoding='utf-8')
        return 0
    from run_u13_lord_balance import verify_frozen, hashes
    verify_frozen(args.report)
    for game in args.games:
        if not (args.report/'games'/(game+'.json.gz')).is_file(): parser.error('Missing saved game: '+game)
    root = Path(__file__).resolve().parents[2]
    output = (args.output or Path.home()/'Downloads/Corruptor/Performance'/
              time.strftime('sim-performance-%Y%m%d-%H%M%S.json')).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    result = dict(report=str(args.report), implementation=platform.python_implementation(), python=sys.version,
                  scope='Sequential operation replay; excludes doctrine planning and trace writing', builds={},
                  frozen_identity=json.loads((args.report/'frozen-source.json').read_text(encoding='utf-8')),
                  candidate_files=hashes(root))
    print(f'Comparing {len(args.games)} saved games per build; one worker. Report: {output}', flush=True)
    env = dict(os.environ); env.pop('PYTHONPATH', None)
    for label, source in [('before', args.report/'source'), ('after', root)]:
        part = output.with_name(output.stem+'-'+label+'.json')
        subprocess.run([sys.executable, '-u', str(Path(__file__).resolve()), '--source', str(source),
                        '--report', str(args.report), '--output', str(part), '--games', *args.games], check=True, env=env)
        result['builds'][label] = json.loads(part.read_text(encoding='utf-8'))
        part.unlink()
        output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    if result['candidate_files'] != hashes(root):
        raise RuntimeError('Candidate source changed during benchmark; rerun from a stable checkout.')
    before = sum(r['total_seconds'] for r in result['builds']['before'])
    after = sum(r['total_seconds'] for r in result['builds']['after'])
    print(f'Exact states matched. Total: {before:.2f}s -> {after:.2f}s ({100*(1-after/before):.1f}% less time).', flush=True)
    print('PERFORMANCE REPORT: '+str(output), flush=True)
    return 0


if __name__ == '__main__': raise SystemExit(main())
