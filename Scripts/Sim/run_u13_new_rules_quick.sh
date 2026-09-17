#!/usr/bin/env bash
# Focused Veil/monster correctness; no complete-game campaign or balance sweep.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! -x "${1:-}" ]]; then
  printf 'Usage: bash %s /path/to/godot [python_executable]\n' "$0" >&2
  exit 2
fi
u13_quick_godot=$1
u13_quick_python=${2:-python}
u13_quick_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_quick_version=$("$u13_quick_godot" --version)
if [[ "$u13_quick_version" != 4.7.2.stable.* ]]; then
  printf 'Windows acceptance requires Godot 4.7.2 stable; found %s\n' "$u13_quick_version" >&2
  exit 2
fi
"$u13_quick_python" -c 'import sys; sys.exit(sys.version_info < (3, 10))'
cd -- "$u13_quick_root"
export PYTHONPATH=Scripts/Sim
mkdir -p -- "$HOME/Downloads"
u13_quick_reports=$(mktemp -d "$HOME/Downloads/u13-new-rules-quick-XXXXXX")
cleanup() {
  local status=$?
  printf 'runner=u13-new-rules-quick\nexit_status=%s\n' "$status" >"$u13_quick_reports/run-status.txt"
  bash Scripts/Sim/package_u13_reports.sh "$u13_quick_reports" || true
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git rev-parse HEAD >"$u13_quick_reports/revision.txt"
git diff HEAD >"$u13_quick_reports/worktree.diff"
printf '%s\n' "$u13_quick_version" >"$u13_quick_reports/godot-version.txt"
"$u13_quick_python" --version >"$u13_quick_reports/python-version.txt" 2>&1
"$u13_quick_python" -c 'import json; from pathlib import Path; from u13_pysim.verify import source_identity; from u13_doctrine.reference_probe import harness_hash; from u13_doctrine.common import VERSION; revision, source = source_identity(Path.cwd()); print(json.dumps(dict(revision=revision, engine_source_sha256=source, doctrine_source_sha256=harness_hash(Path.cwd()), policy=VERSION)))' >"$u13_quick_reports/identity.json"
run_logged() {
  local name=$1
  shift
  "$u13_quick_python" - "$u13_quick_reports/$name.log" "$@" <<'PY'
import pathlib, subprocess, sys, time
path = pathlib.Path(sys.argv[1])
start = time.monotonic()
process = None
try:
    with path.open('w', encoding='utf-8') as stream:
        process = subprocess.Popen(sys.argv[2:], stdout=stream, stderr=subprocess.STDOUT)
        heartbeat = 15
        while process.poll() is None:
            elapsed = time.monotonic() - start
            if elapsed >= 180:
                raise TimeoutError('three-minute stage watchdog: ' + path.name)
            if elapsed >= heartbeat:
                print('Running', path.name, '(' + str(int(elapsed)) + ' seconds)', flush=True)
                heartbeat += 15
            time.sleep(0.2)
    lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
    errors = [line for line in lines if line.startswith(('FAIL', 'ERROR:', 'SCRIPT ERROR:', 'Traceback'))]
    print('\n'.join(lines[-6:]), flush=True)
    if process.returncode or errors:
        if errors: print('\n'.join(errors[:12]), file=sys.stderr)
        sys.exit(process.returncode or 1)
except (OSError, TimeoutError) as error:
    print('FAIL', error, file=sys.stderr)
    sys.exit(1)
finally:
    if process is not None and process.poll() is None:
        process.kill()
        process.wait()
PY
}
printf 'Focused reports: %s\n' "$u13_quick_reports"
run_logged python "$u13_quick_python" -m unittest \
  u13_pysim.test_powers u13_pysim.test_marching \
  u13_doctrine.test_common u13_doctrine.test_diagnostics
run_logged veil "$u13_quick_godot" --headless --path "$u13_quick_root" \
  --script res://Scripts/Sim/U13VeilBreachesTestRunner.gd -- "$u13_quick_reports/veil.json"
run_logged veil-python "$u13_quick_python" -m u13_pysim.verify_veil "$u13_quick_reports/veil.json"
run_logged monsters "$u13_quick_godot" --headless --path "$u13_quick_root" \
  --script res://Scripts/Sim/U13MonsterTestRunner.gd -- "$u13_quick_reports/monsters.jsonl"
run_logged monsters-python "$u13_quick_python" -m u13_pysim.verify_monsters "$u13_quick_reports/monsters.jsonl"
run_logged resurrection "$u13_quick_godot" --headless --path "$u13_quick_root" \
  --script res://Scripts/Sim/U13MonsterResurrectionTestRunner.gd -- "$u13_quick_reports/resurrections.jsonl"
run_logged resurrection-python "$u13_quick_python" -m u13_pysim.verify_monsters \
  --resurrections "$u13_quick_reports/resurrections.jsonl"
printf 'Focused Veil, monster and doctrine checks passed. Full-game acceptance and balance remain separate.\n'
