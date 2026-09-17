#!/usr/bin/env bash
# Bounded doctrine alpha: five Python games; optional focused native rules gate.
set -euo pipefail
if [[ $# -lt 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/pypy3.exe [cpython_executable] [--godot /path/to/godot]\n' "$0" >&2
  exit 2
fi
u13_common_pypy=$1
u13_common_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_common_cpython=""
u13_common_godot=""
shift
while [[ $# -gt 0 ]]; do
  if [[ "$1" == --godot && $# -ge 2 && -z "$u13_common_godot" ]]; then
    u13_common_godot=$2
    shift 2
  elif [[ "$1" != --* && -z "$u13_common_cpython" ]]; then
    u13_common_cpython=$1
    shift
  else
    printf 'Unexpected or incomplete argument: %s\n' "$1" >&2
    exit 2
  fi
done
if [[ -z "$u13_common_cpython" ]]; then
  for u13_common_candidate in python3 python py; do
    if command -v "$u13_common_candidate" >/dev/null 2>&1 &&
       "$u13_common_candidate" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))' >/dev/null 2>&1; then
      u13_common_cpython=$u13_common_candidate
      break
    fi
  done
fi
if [[ -n "$u13_common_godot" ]]; then
  u13_common_godot_version=$("$u13_common_godot" --version)
  if [[ "$u13_common_godot_version" != 4.7.2.stable.* ]]; then
    printf 'Windows acceptance requires Godot 4.7.2 stable; found %s\n' "$u13_common_godot_version" >&2
    exit 2
  fi
fi
cd -- "$u13_common_root"
export PYTHONPATH=Scripts/Sim
if [[ -z "$u13_common_cpython" ]] ||
   ! "$u13_common_cpython" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))'; then
  printf 'CPython 3.10+ is required.\n' >&2
  exit 2
fi
if ! "$u13_common_pypy" -c 'import sys; sys.exit(sys.implementation.name != "pypy" or sys.version_info < (3, 10))'; then
  printf 'The first argument must be PyPy 3.10+.\n' >&2
  exit 2
fi
mkdir -p -- "$HOME/Downloads"
u13_common_reports=$(mktemp -d "$HOME/Downloads/u13-common-doctrine-XXXXXX")
u13_common_pid=""
cleanup() {
  local status=$?
  if [[ -n "$u13_common_pid" ]]; then
    kill -KILL "$u13_common_pid" 2>/dev/null || true
    wait "$u13_common_pid" 2>/dev/null || true
  fi
  printf 'runner=u13-common-doctrine\nexit_status=%s\n' "$status" >"$u13_common_reports/run-status.txt"
  bash "$u13_common_root/Scripts/Sim/package_u13_reports.sh" "$u13_common_reports" || true
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git -C "$u13_common_root" diff HEAD >"$u13_common_reports/worktree.diff"
git rev-parse HEAD >"$u13_common_reports/revision.txt"
run_logged() {
  local log=$1
  shift
  "$@" >"$log" 2>&1 &
  u13_common_pid=$!
  local started=$SECONDS heartbeat=$((SECONDS + 15))
  while kill -0 "$u13_common_pid" 2>/dev/null; do
    if ((SECONDS-started >= 600)); then
      printf 'FAIL doctrine watchdog: %s\n' "$log" >&2
      exit 1
    fi
    if ((SECONDS >= heartbeat)); then
      printf 'Running %s (%s seconds)\n' "$(basename -- "$log")" "$((SECONDS-started))"
      tail -n 1 -- "$log"
      heartbeat=$((SECONDS + 15))
    fi
    sleep 0.2
  done
  local status=0
  wait "$u13_common_pid" || status=$?
  u13_common_pid=""
  if ((status != 0)); then
    tail -n 35 -- "$log"
    exit "$status"
  fi
  "$u13_common_cpython" - "$log" <<'PY'
from pathlib import Path
import sys
errors = [line for line in Path(sys.argv[1]).read_text(encoding='utf-8', errors='replace').splitlines()
          if line.startswith(('FAIL ', 'SCRIPT ERROR:', 'ERROR:', 'Traceback'))]
if errors:
    print('\n'.join(errors[:12]), file=sys.stderr)
    sys.exit(1)
PY
  tail -n 5 -- "$log"
}
printf 'U13 common doctrine reports: %s\n' "$u13_common_reports"
if [[ -n "$u13_common_godot" ]]; then
  printf '%s\n' "$u13_common_godot_version" >"$u13_common_reports/godot-version.txt"
  for u13_common_suite in U13GuardWork U13ActionForecast; do
    run_logged "$u13_common_reports/$u13_common_suite.log" "$u13_common_godot" --headless --path "$u13_common_root" \
      --script "res://Scripts/Sim/${u13_common_suite}TestRunner.gd"
  done
  for u13_common_suite in U13VeilBreaches U13Monster U13MonsterResurrection U13MonsterGravity; do
    run_logged "$u13_common_reports/$u13_common_suite.log" "$u13_common_godot" --headless --path "$u13_common_root" \
      --script "res://Scripts/Sim/${u13_common_suite}TestRunner.gd" -- "$u13_common_reports/$u13_common_suite.exact"
  done
  for u13_common_runtime in "$u13_common_cpython" "$u13_common_pypy"; do
    u13_common_runtime_name=$("$u13_common_runtime" -c 'import platform; print(platform.python_implementation().lower())')
    run_logged "$u13_common_reports/$u13_common_runtime_name-native-comparison.log" "$u13_common_runtime" \
      "$u13_common_root/Scripts/Sim/run_u13_common_doctrine.py" verify-rules "$u13_common_reports"
  done
fi
run_logged "$u13_common_reports/cpython.log" "$u13_common_cpython" \
  "$u13_common_root/Scripts/Sim/run_u13_common_doctrine.py" check --report "$u13_common_reports/cpython.json"
run_logged "$u13_common_reports/pypy.log" "$u13_common_pypy" \
  "$u13_common_root/Scripts/Sim/run_u13_common_doctrine.py" check --report "$u13_common_reports/pypy.json"
run_logged "$u13_common_reports/comparison.log" "$u13_common_cpython" \
  "$u13_common_root/Scripts/Sim/run_u13_common_doctrine.py" compare \
  "$u13_common_reports/cpython.json" "$u13_common_reports/pypy.json"
printf 'Common doctrine alpha passed under both runtimes. Focused native checks run when --godot is supplied; expanded game parity and tuning remain ahead.\n'
