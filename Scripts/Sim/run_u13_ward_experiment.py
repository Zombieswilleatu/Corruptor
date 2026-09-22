#!/usr/bin/env python3
"""Focused Ward checks and 18 paired self-play cases, using two workers."""
import argparse
import gc
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import time
import traceback

from run_u13_lord_balance import freeze, verify_frozen, package, Tee

BASELINE = '0d964b322fb4e0aa3fb2020cc67bfe10cdf302b8'
# The original campaign predates the parity-checked memory optimization.
# Accept complete source snapshots, never individual missing-file exceptions.
ARCHIVED_BASELINE = 'f89384d1adbb1004b695fce2abd72363cadd56e5'
BASELINE_REVISIONS = (BASELINE, ARCHIVED_BASELINE)
BASELINE_FOLDERS = ('Scripts/Sim/u13_pysim', 'Scripts/Sim/u13_doctrine')
# A fixed ring covers every Lord in two matchups and both seats.
LORDS = ['Gremory', 'Humbaba', 'Kroni', 'Odradek', 'Valak',
         'Kalligan', 'Deimos', 'Orias', 'Kanifous']


def selected_cases(config):
    available = {s['name']: s for s in config['cases']}
    result = []
    for i, left in enumerate(LORDS):
        right = LORDS[(i+1) % len(LORDS)]
        for a, b in ((left, right), (right, left)):
            result.append(available[f'{a.lower()}_{b.lower()}_00'])
    if len({s['name'] for s in result}) != 18:
        raise ValueError('Expected 18 distinct cases')
    return result


def baseline_source(root, report):
    """Match every engine/policy Python file to one known pre-change build."""
    source = report/'source'
    actual = {p.relative_to(source).as_posix(): p.read_bytes().replace(b'\r\n', b'\n')
              for folder in BASELINE_FOLDERS for p in (source/folder).rglob('*.py')
              if '__pycache__' not in p.parts}
    problems = []
    for revision in BASELINE_REVISIONS:
        archive = subprocess.check_output(['git', '-C', str(root), 'archive', revision, '--', *BASELINE_FOLDERS])
        with tarfile.open(fileobj=io.BytesIO(archive)) as files:
            expected = {p.name: files.extractfile(p).read().replace(b'\r\n', b'\n')
                        for p in files if p.isfile() and p.name.endswith('.py')}
        if actual == expected:
            print('Verified archived baseline source: '+revision[:7], flush=True)
            return revision
        different = sorted(name for name in actual.keys() | expected.keys()
                           if actual.get(name) != expected.get(name))
        problems.append(revision[:7]+': '+', '.join(different[:6]))
    raise ValueError('Archive matches no supported pre-change build; missing, extra or changed files: '
                     +'; '.join(problems))


def metrics(record):
    if record['status'] != 'complete':
        return dict(status=record['status'], error=record.get('error'))
    game = record['semantic']
    actions = {name: 0 for name in ('Pass', 'Ward', 'Hunt', 'Siege', 'Profane')}
    recipe_actions = {}
    for row in record['trace']:
        order = row['decision']['plan']['order']
        action = order.get('action', 'Pass')
        actions[action] = actions.get(action, 0)+1
        if 'monster_choice' in order:
            recipe_actions[action] = recipe_actions.get(action, 0)+1
    return dict(status='complete', rounds=game['rounds'], outcome=game['outcome'],
                decisions=len(record['trace']), actions=actions, recipe_actions=recipe_actions,
                event_counts=game['diagnostics']['event_counts'],
                rejected_previews=len(game['diagnostics']['rejected_previews']),
                semantic_sha256=record['semantic_sha256'], trace_sha256=record['trace_sha256'])


def execute(output):
    from u13_doctrine.common import Weights
    from u13_doctrine.survey import manifest, pooled_results, read_record, atomic_json
    verify_frozen(output)
    config = json.loads((output/'ward-config.json').read_text(encoding='utf-8'))
    identity = manifest(Path(__file__).resolve().parents[2], config['namespace'], Weights(**config['weights']))
    atomic_json(output/'manifest.json', identity)
    games = output/'games'
    games.mkdir()
    report = dict(status='running', workers=2, worker_batch_size=4, fresh_games=18,
        baseline_revision=config['baseline_revision'], baseline_manifest=config['baseline_manifest'], candidate_manifest=identity,
        scope='Paired before/after self-play behavior screen of combined rules and doctrine; not a head-to-head strength or balance verdict.',
        completed=[], pairs=[])
    atomic_json(output/'ward-comparison.json', report)
    start = time.perf_counter()
    for result in pooled_results(config['cases'], identity, str(games), 2, 4):
        if result is None:
            print(f"RUNNING {len(report['completed'])}/18 elapsed={time.perf_counter()-start:.1f}s", flush=True)
            continue
        report['completed'].append(result)
        atomic_json(output/'ward-comparison.json', report)
        print(f"{result['status'].upper()} {len(report['completed'])}/18 {result['name']}", flush=True)
        if result['error']: print(result['error'], flush=True)
    for spec in config['cases']:
        record = read_record(games/(spec['name']+'.json.gz'), identity, spec)
        after = metrics(record)
        before = config['baseline'][spec['name']]
        pair = dict(name=spec['name'], setup=spec['setup'], before=before, after=after)
        if after['status'] == 'complete':
            pair['round_delta'] = after['rounds']-before['rounds']
            pair['ward_share_delta'] = (after['actions']['Ward']/max(1, after['decisions'])
                                       -before['actions']['Ward']/max(1, before['decisions']))
        report['pairs'].append(pair)
        del record
        gc.collect()
    bad = [p['name'] for p in report['pairs'] if p['after']['status'] != 'complete'
           or p['after'].get('recipe_actions', {}).get('Ward', 0)]
    report.update(status='failed' if bad else 'complete', failed_cases=bad,
                  elapsed_seconds=time.perf_counter()-start)
    atomic_json(output/'ward-comparison.json', report)
    print('COMPARISON: '+str(output/'ward-comparison.json'), flush=True)
    return int(bool(bad))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, help='Completed pre-change Lord balance report folder')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--godot', type=Path, help='Godot 4.7.2 executable; required to run native checks')
    parser.add_argument('--prepare-only', action='store_true', help='Freeze and validate 18 cases without starting workers')
    parser.add_argument('--frozen', action='store_true', help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.frozen:
        if args.output is None: parser.error('frozen mode requires output')
        with (args.output/'run.log').open('a', encoding='utf-8') as log:
            old_out, old_err = sys.stdout, sys.stderr
            sys.stdout, sys.stderr = Tee(old_out, log), Tee(old_err, log)
            try: return execute(args.output)
            except Exception:
                traceback.print_exc()
                return 1
            finally: sys.stdout, sys.stderr = old_out, old_err
    if not args.prepare_only and args.godot is None:
        parser.error('--godot is required so native checks run before the comparison')
    root = Path(__file__).resolve().parents[2]
    if args.report is None:
        reports = list((Path.home()/'Downloads/Corruptor/Balance').glob('*/lord-balance.json'))
        if not reports: parser.error('No baseline report found; supply --report')
        args.report = max(reports, key=lambda p: p.stat().st_mtime).parent
    baseline = args.report.resolve()
    verify_frozen(baseline)
    baseline_revision = baseline_source(root, baseline)
    from u13_doctrine.survey import read_record, atomic_json
    old_identity = json.loads((baseline/'manifest.json').read_text(encoding='utf-8'))
    config = json.loads((baseline/'balance-config.json').read_text(encoding='utf-8'))
    specs = selected_cases(config)
    old = {}
    for spec in specs:
        record = read_record(baseline/'games'/(spec['name']+'.json.gz'), old_identity, spec)
        old[spec['name']] = metrics(record)
        if record['status'] != 'complete': raise ValueError('Incomplete baseline: '+spec['name'])
        del record
        gc.collect()
    output = (args.output or Path.home()/'Downloads/Corruptor/Balance'/
              time.strftime('ward-experiment-%Y%m%d-%H%M%S')).resolve()
    output.mkdir(parents=True, exist_ok=False)
    code = 130
    try:
        # Run focused admission/recipe tests; stdout and stderr remain in evidence.
        env = dict(os.environ)
        env.pop('PYTHONPATH', None)
        with (output/'focused-python.log').open('w', encoding='utf-8') as log:
            subprocess.run([sys.executable, '-m', 'unittest',
                'u13_doctrine.test_ward_recipes', 'u13_doctrine.test_recipes_veil',
                'u13_doctrine.test_reserved_recipes'], cwd=root/'Scripts/Sim', env=env,
                stdout=log, stderr=subprocess.STDOUT, check=True)
        if args.godot:
            godot = args.godot.resolve()
            version = subprocess.check_output([str(godot), '--version'], text=True).strip()
            if not version.startswith('4.7.2.stable'): raise ValueError('Expected Godot 4.7.2 stable: '+version)
            with (output/'focused-godot.log').open('w', encoding='utf-8') as log:
                subprocess.run([str(godot), '--headless', '--path', str(root),
                    '--script', 'res://Scripts/Sim/U13WardRecipeTestRunner.gd'],
                    cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
        frozen = freeze(root, output)
        atomic_json(output/'ward-config.json', dict(baseline_report=str(baseline),
            baseline_revision=baseline_revision, baseline_manifest=old_identity,
            namespace=old_identity['namespace'], weights=old_identity['weights'],
            cases=specs, baseline=old, workers=2, worker_batch_size=4, fresh_games=18,
            focused_python='passed', focused_godot='passed' if args.godot else 'not_run'))
        print('PREPARED: 18 paired games; 2 workers; recycle after 4. '+str(output), flush=True)
        if args.prepare_only:
            code = 0
            return 0
        code = subprocess.call([sys.executable, '-u', str(frozen/'Scripts/Sim/run_u13_ward_experiment.py'),
                                '--frozen', '--output', str(output)], cwd=frozen, env=env)
        return code
    finally:
        atomic_json(output/'run-status.json', dict(
            status='prepared' if code == 0 and args.prepare_only else 'complete' if code == 0 else 'failed_or_interrupted',
            exit_code=code))
        package(output)


if __name__ == '__main__':
    raise SystemExit(main())
