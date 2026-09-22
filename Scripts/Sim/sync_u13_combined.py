#!/usr/bin/env python3
"""Safely fast-forward the known V26 combined ZIP installation to this branch."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

BASE = '9f790a98f5d124b3522b8406bf40b74164e20a0c'
RECEIPT = 'docs/evidence/U13_COMBINED_SOURCE_BASELINES.json'


def digest(data):
    return None if data is None else hashlib.sha256(data.replace(b'\r\n', b'\n')).hexdigest()


def git(root, *args, check=True):
    return subprocess.run(['git', '-C', str(root), *args], capture_output=True, check=check)


def blob(root, commit, path):
    result = git(root, 'show', commit+':'+path, check=False)
    return result.stdout if result.returncode == 0 else None


def synchronize(root, ref, check_only=False):
    target = git(root, 'rev-parse', '--verify', ref+'^{commit}').stdout.decode().strip()
    branch = git(root, 'branch', '--show-current').stdout.decode().strip()
    if branch != 'u13-basic-doctrine':
        raise ValueError('Use the Corruptor-U13-Doctrine checkout on u13-basic-doctrine; current branch: '+branch)
    if git(root, 'merge-base', '--is-ancestor', 'HEAD', target, check=False).returncode:
        raise ValueError('Local commits diverge from the target. No files changed; preserve them for review.')
    if git(root, 'diff', '--cached', '--quiet', check=False).returncode:
        raise ValueError('There are staged changes. No files changed; preserve them for review.')
    receipt_bytes = blob(root, target, RECEIPT)
    if receipt_bytes is None: raise ValueError('Target has no combined-source receipt; no files changed.')
    allowed = json.loads(receipt_bytes)
    changed = git(root, 'diff', '--name-only', BASE, target, '--').stdout.decode().splitlines()
    paths = sorted(set(allowed) | set(changed))
    conflicts = []
    final = {}
    for name in paths:
        path = root/name
        if path.is_symlink() or (path.exists() and not path.is_file()):
            conflicts.append(name); continue
        current = path.read_bytes() if path.is_file() else None
        final[name] = digest(blob(root, target, name))
        accepted = allowed.get(name, [digest(blob(root, BASE, name))]) + [final[name]]
        if digest(current) not in accepted: conflicts.append(name)
    if conflicts:
        raise ValueError('Unknown local edits; no files changed. Review these files:\n'+'\n'.join(conflicts))
    print(f'Verified {len(paths)} source files against the base, combined ZIP, or target commit.', flush=True)
    if check_only: return
    head = git(root, 'rev-parse', 'HEAD').stdout.decode().strip()
    if head != target:
        # Only known changed paths are shelved. Other local files and previous
        # patch backups remain in place; every previous stash is retained.
        shelve = [name for name in changed if (root/name).exists() or blob(root, head, name) is not None]
        if shelve:
            saved = git(root, 'stash', 'push', '--include-untracked', '-m',
                        'Known combined patches before V27 balance checkpoint', '--', *shelve)
            print(saved.stdout.decode(errors='replace'), end='', flush=True)
        merged = git(root, 'merge', '--ff-only', target)
        print(merged.stdout.decode(errors='replace'), end='', flush=True)
    mismatches = [name for name, expected in final.items()
                  if digest((root/name).read_bytes() if (root/name).is_file() else None) != expected]
    if mismatches:
        raise ValueError('Files changed during synchronization; saved patches remain in Git stash:\n'+'\n'.join(mismatches))
    print('VERIFIED: combined build + V27 reserve-aware recipes + Lord balance runner. Existing stashes are retained; do not pop them over this build.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path.cwd())
    parser.add_argument('--target', default='origin/u13-basic-doctrine')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try: synchronize(args.project.resolve(), args.target, args.check)
    except (ValueError, subprocess.CalledProcessError) as error:
        if isinstance(error, subprocess.CalledProcessError):
            print(error.stderr.decode(errors='replace'))
        else: print(error)
        return 1
    return 0


if __name__ == '__main__': raise SystemExit(main())
