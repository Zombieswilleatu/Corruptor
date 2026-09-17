#!/usr/bin/env bash
# Focused free-opening gate; no full-game campaign or balance sweep.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! -x "${1:-}" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable [pypy_executable]\n' "$0" >&2
  exit 2
fi
u13_open_godot=$1
u13_open_pypy=${2:-}
u13_open_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_open_python=""
for u13_open_candidate in python3 python py; do
  if command -v "$u13_open_candidate" >/dev/null 2>&1 && "$u13_open_candidate" -c 'import sys,platform; sys.exit(sys.version_info < (3,10) or platform.python_implementation() != "CPython")' >/dev/null 2>&1; then
    u13_open_python=$u13_open_candidate
    break
  fi
done
if [[ -z "$u13_open_python" ]]; then
  printf 'CPython 3.10+ is required.\n' >&2
  exit 2
fi
u13_open_version=$("$u13_open_godot" --version)
if [[ "$u13_open_version" != 4.7.2.stable.* ]]; then
  printf 'Windows acceptance requires Godot 4.7.2 stable; found %s\n' "$u13_open_version" >&2
  exit 2
fi
if [[ -n "$u13_open_pypy" ]]; then
  "$u13_open_pypy" -c 'import sys,platform; sys.exit(sys.version_info < (3,10) or platform.python_implementation() != "PyPy")'
fi
cd -- "$u13_open_root"
export PYTHONPATH=Scripts/Sim
mkdir -p -- "$HOME/Downloads"
u13_open_reports=$(mktemp -d "$HOME/Downloads/u13-free-opening-XXXXXX")
cleanup() {
  local status=$?
  printf 'runner=u13-free-opening\nexit_status=%s\n' "$status" >"$u13_open_reports/run-status.txt"
  bash Scripts/Sim/package_u13_reports.sh "$u13_open_reports" || true
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git rev-parse HEAD >"$u13_open_reports/revision.txt"
git diff HEAD >"$u13_open_reports/worktree.diff"
printf '%s\n' "$u13_open_version" >"$u13_open_reports/godot-version.txt"
"$u13_open_python" --version >"$u13_open_reports/python-version.txt" 2>&1
"$u13_open_python" Scripts/Sim/run_u13_pysim.py source-identity >"$u13_open_reports/source-identity.txt"
mapfile -t u13_open_identity <"$u13_open_reports/source-identity.txt"
u13_open_revision=${u13_open_identity[0]%$'\r'}
u13_open_source=${u13_open_identity[1]%$'\r'}
run_logged() {
  local name=$1
  shift
  "$u13_open_python" - "$u13_open_reports/$name.log" "$@" <<'PY'
import pathlib,subprocess,sys,time
path=pathlib.Path(sys.argv[1]); process=None; start=time.monotonic()
try:
    with path.open('w',encoding='utf-8') as stream:
        process=subprocess.Popen(sys.argv[2:],stdout=stream,stderr=subprocess.STDOUT)
        heartbeat=15
        while process.poll() is None:
            elapsed=time.monotonic()-start
            if elapsed>=180: raise TimeoutError('three-minute stage watchdog: '+path.name)
            if elapsed>=heartbeat:
                print('Running',path.name,'('+str(int(elapsed))+' seconds)',flush=True)
                heartbeat+=15
            time.sleep(0.2)
    lines=path.read_text(encoding='utf-8',errors='replace').splitlines()
    errors=[line for line in lines if line.startswith(('FAIL','ERROR:','SCRIPT ERROR:','Traceback'))]
    print('\n'.join(lines[-5:]),flush=True)
    if process.returncode or errors:
        if errors: print('\n'.join(errors[:12]),file=sys.stderr)
        sys.exit(process.returncode or 1)
except (OSError,TimeoutError) as error:
    print('FAIL',error,file=sys.stderr);sys.exit(1)
finally:
    if process is not None and process.poll() is None:
        process.kill();process.wait()
PY
}
printf 'Focused opening reports: %s\n' "$u13_open_reports"
run_logged python-rules "$u13_open_python" Scripts/Sim/run_u13_pysim.py self-test-powers
run_logged python-opening "$u13_open_python" -m unittest u13_pysim.test_opening u13_doctrine.test_common
run_logged economy "$u13_open_godot" --headless --path "$u13_open_root" --script res://Scripts/Sim/U13GameEconomyTestRunner.gd
run_logged conductor "$u13_open_godot" --headless --path "$u13_open_root" --script res://Scripts/Sim/U13GameConductorTestRunner.gd
run_logged opening "$u13_open_godot" --headless --path "$u13_open_root" --script res://Scripts/Sim/U13OpeningEconomyTestRunner.gd -- \
  "$u13_open_reports/opening.exact.json" "$u13_open_revision" "$u13_open_source"
run_logged python-parity "$u13_open_python" -m u13_pysim.verify_free_opening \
  "$u13_open_reports/opening.exact.json" --report "$u13_open_reports/python-parity.json"
if [[ -n "$u13_open_pypy" ]]; then
  "$u13_open_pypy" --version >"$u13_open_reports/pypy-version.txt" 2>&1
  run_logged pypy-rules "$u13_open_pypy" Scripts/Sim/run_u13_pysim.py self-test-powers
  run_logged pypy-opening "$u13_open_pypy" -m unittest u13_pysim.test_opening u13_doctrine.test_common
  run_logged pypy-parity "$u13_open_pypy" -m u13_pysim.verify_free_opening \
    "$u13_open_reports/opening.exact.json" --report "$u13_open_reports/pypy-parity.json"
  "$u13_open_python" - "$u13_open_reports" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1])
if json.loads((p/'python-parity.json').read_text())!=json.loads((p/'pypy-parity.json').read_text()):
    raise SystemExit('FAIL CPython/PyPy opening reports differ')
print('CPython/PyPy exact opening reports match.')
PY
fi
printf 'Free opening passed the focused Windows gate. Start a new match for this rules version.\n'
