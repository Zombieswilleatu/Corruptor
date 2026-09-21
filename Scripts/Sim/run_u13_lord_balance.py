#!/usr/bin/env python3
"""Freeze the installed build, run/resume 81 Lord matchups and package evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import traceback
import zipfile


def source_paths(root):
    return sorted(p for folder in ('Scripts/Sim', 'docs/evidence')
                  for p in (root/folder).rglob('*') if p.is_file()
                  and p.suffix in ('.py', '.gd', '.json', '.sh') and '__pycache__' not in p.parts)


def hashes(root):
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in source_paths(root)}


def freeze(root, output):
    frozen = output/'source'
    before = hashes(root)
    # A local metadata-only clone pins HEAD without copying any game art.
    subprocess.run(['git', 'clone', '--shared', '--no-checkout', str(root), str(frozen)], check=True)
    for name in before:
        destination = frozen/name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root/name, destination)
    if before != hashes(root) or before != hashes(frozen):
        raise RuntimeError('Source changed while freezing; start a fresh output directory.')
    identity = dict(files=before, revision=subprocess.check_output(['git', '-C', str(frozen), 'rev-parse', 'HEAD'], text=True).strip())
    (output/'frozen-source.json').write_text(json.dumps(identity, indent=2)+'\n', encoding='utf-8')
    return frozen


def verify_frozen(output):
    identity = json.loads((output/'frozen-source.json').read_text(encoding='utf-8'))
    if identity['files'] != hashes(output/'source'):
        raise RuntimeError('Frozen simulation source changed; refusing to mix results.')


class Tee:
    def __init__(self, terminal, log): self.terminal, self.log = terminal, log
    def write(self, text):
        self.terminal.write(text); self.log.write(text); self.log.flush()
        return len(text)
    def flush(self): self.terminal.flush(); self.log.flush()


def execute(args):
    from u13_doctrine.lord_balance import NAMESPACE, summarize, markdown
    from u13_doctrine.survey import run, cases, read_record, atomic_json
    verify_frozen(args.output)
    result = run(Path(__file__).resolve().parents[2], args.output, repeats=args.repeats,
                 workers=args.workers, namespace=NAMESPACE)
    records = (read_record(args.output/'games'/(spec['name']+'.json.gz'), result['manifest'], spec)
               for spec in cases(args.repeats, NAMESPACE))
    report = summarize(records)
    atomic_json(args.output/'lord-balance.json', report)
    (args.output/'lord-balance.md').write_text(markdown(report), encoding='utf-8')
    return int(bool(result['summary']['failed']))


def package(output):
    archive = output.with_suffix('.zip')
    temporary = archive.with_suffix('.zip.partial')
    with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED) as z:
        for path in sorted(output.rglob('*')):
            if not path.is_file() or any(p in ('.git', '__pycache__') for p in path.relative_to(output).parts): continue
            if path.suffix in ('.tmp', '.partial', '.pyc'): continue
            z.write(path, path.relative_to(output.parent))
    temporary.replace(archive)
    print('REPORT ZIP: '+str(archive), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--resume', type=Path, help='Resume the existing frozen build, never the current checkout')
    parser.add_argument('--workers', type=int, default=2)
    parser.add_argument('--repeats', type=int, default=1, help='81 games per repeat; default is one screening pass')
    parser.add_argument('--prepare-only', action='store_true', help='Freeze and validate the case list without playing games')
    parser.add_argument('--frozen', action='store_true', help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.workers < 1 or args.repeats < 1: parser.error('workers and repeats must be positive')
    if args.output and args.resume: parser.error('choose output or resume')
    if args.frozen:
        with (args.output/'run.log').open('a', encoding='utf-8') as log:
            sys.stdout = Tee(sys.stdout, log); sys.stderr = Tee(sys.stderr, log)
            try: return execute(args)
            except Exception:
                traceback.print_exc()
                return 1
            finally:
                sys.stdout, sys.stderr = sys.__stdout__, sys.__stderr__
    root = Path(__file__).resolve().parents[2]
    args.output = (args.resume or args.output or Path.home()/'Downloads/Corruptor/Balance'/
                   time.strftime('u13-lord-balance-%Y%m%d-%H%M%S')).resolve()
    if args.resume:
        verify_frozen(args.output)
        config = json.loads((args.output/'balance-config.json').read_text())
        args.repeats = config['repeats']
        frozen = args.output/'source'
    else:
        args.output.mkdir(parents=True, exist_ok=False)
        frozen = freeze(root, args.output)
        from u13_doctrine.lord_balance import NAMESPACE
        from u13_doctrine.survey import cases
        case_list = list(cases(args.repeats, NAMESPACE))
        (args.output/'balance-config.json').write_text(json.dumps(dict(repeats=args.repeats, namespace=NAMESPACE,
            cases=case_list, games=len(case_list), round_cap=40), indent=2)+'\n', encoding='utf-8')
    print(f'Frozen build ready: {81*args.repeats} games, {args.workers} workers. Reports: {args.output}', flush=True)
    if args.prepare_only: return 0
    status = 'interrupted'; code = 130
    try:
        # Inherit no PYTHONPATH that could import the live checkout over the snapshot.
        env = dict(os.environ); env.pop('PYTHONPATH', None)
        code = subprocess.call([sys.executable, '-u', str(frozen/'Scripts/Sim/run_u13_lord_balance.py'),
            '--frozen', '--output', str(args.output), '--workers', str(args.workers), '--repeats', str(args.repeats)],
            cwd=frozen, env=env)
        status = 'complete' if code == 0 else 'failed_or_interrupted'
        return code
    finally:
        (args.output/'run-status.json').write_text(json.dumps(dict(status=status, exit_code=code))+'\n')
        package(args.output)


if __name__ == '__main__': raise SystemExit(main())
