#!/usr/bin/env bash
# Short dual-runtime observer check; reuses the two existing ordinary games.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/pypy3.exe [cpython_executable]\n' "$0" >&2
  exit 2
fi
u13_diag_pypy=$1
u13_diag_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_diag_cpython=""
if [[ $# -eq 2 ]]; then
  u13_diag_cpython=$2
else
  for u13_diag_candidate in python3 python py; do
    if command -v "$u13_diag_candidate" >/dev/null 2>&1 &&
       "$u13_diag_candidate" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))' >/dev/null 2>&1; then
      u13_diag_cpython=$u13_diag_candidate
      break
    fi
  done
fi
if [[ -z "$u13_diag_cpython" ]] ||
   ! "$u13_diag_cpython" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))'; then
  printf 'CPython 3.10+ is required.\n' >&2
  exit 2
fi
if ! "$u13_diag_pypy" -c 'import sys; sys.exit(sys.implementation.name != "pypy" or sys.version_info < (3, 10))'; then
  printf 'The first argument must be PyPy 3.10+.\n' >&2
  exit 2
fi
mkdir -p -- "$HOME/Downloads"
u13_diag_reports=$(mktemp -d "$HOME/Downloads/u13-doctrine-diagnostics-XXXXXX")
u13_diag_pid=""
cleanup() {
  local status=$?
  if [[ -n "$u13_diag_pid" ]]; then
    kill -KILL "$u13_diag_pid" 2>/dev/null || true
    wait "$u13_diag_pid" 2>/dev/null || true
  fi
  printf 'runner=u13-doctrine-diagnostics\nexit_status=%s\n' "$status" >"$u13_diag_reports/run-status.txt"
  bash "$u13_diag_root/Scripts/Sim/package_u13_reports.sh" "$u13_diag_reports" || true
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git -C "$u13_diag_root" diff HEAD >"$u13_diag_reports/worktree.diff"
run_logged() {
  local log=$1
  shift
  "$@" >"$log" 2>&1 &
  u13_diag_pid=$!
  local started=$SECONDS heartbeat=$((SECONDS + 15))
  while kill -0 "$u13_diag_pid" 2>/dev/null; do
    if ((SECONDS-started >= 180)); then
      printf 'FAIL diagnostic watchdog: %s\n' "$log" >&2
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
  wait "$u13_diag_pid" || status=$?
  u13_diag_pid=""
  if ((status != 0)); then
    tail -n 35 -- "$log"
    exit "$status"
  fi
  tail -n 5 -- "$log"
}
printf 'U13 doctrine diagnostic reports: %s\n' "$u13_diag_reports"
run_logged "$u13_diag_reports/cpython.log" "$u13_diag_cpython" \
  "$u13_diag_root/Scripts/Sim/run_u13_doctrine_diagnostics.py" check --report "$u13_diag_reports/cpython.json"
run_logged "$u13_diag_reports/pypy.log" "$u13_diag_pypy" \
  "$u13_diag_root/Scripts/Sim/run_u13_doctrine_diagnostics.py" check --report "$u13_diag_reports/pypy.json"
run_logged "$u13_diag_reports/comparison.log" "$u13_diag_cpython" \
  "$u13_diag_root/Scripts/Sim/run_u13_doctrine_diagnostics.py" compare \
  "$u13_diag_reports/cpython.json" "$u13_diag_reports/pypy.json"
printf 'Diagnostics passed under both runtimes. Full-roster doctrine tuning remains gated by rules parity.\n'
