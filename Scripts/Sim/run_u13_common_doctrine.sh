#!/usr/bin/env bash
# Bounded doctrine alpha: directed tests and five Python games; no native export.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/pypy3.exe [cpython_executable]\n' "$0" >&2
  exit 2
fi
u13_common_pypy=$1
u13_common_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_common_cpython=""
if [[ $# -eq 2 ]]; then
  u13_common_cpython=$2
else
  for u13_common_candidate in python3 python py; do
    if command -v "$u13_common_candidate" >/dev/null 2>&1 &&
       "$u13_common_candidate" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))' >/dev/null 2>&1; then
      u13_common_cpython=$u13_common_candidate
      break
    fi
  done
fi
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
  tail -n 5 -- "$log"
}
printf 'U13 common doctrine reports: %s\n' "$u13_common_reports"
run_logged "$u13_common_reports/cpython.log" "$u13_common_cpython" \
  "$u13_common_root/Scripts/Sim/run_u13_common_doctrine.py" check --report "$u13_common_reports/cpython.json"
run_logged "$u13_common_reports/pypy.log" "$u13_common_pypy" \
  "$u13_common_root/Scripts/Sim/run_u13_common_doctrine.py" check --report "$u13_common_reports/pypy.json"
run_logged "$u13_common_reports/comparison.log" "$u13_common_cpython" \
  "$u13_common_root/Scripts/Sim/run_u13_common_doctrine.py" compare \
  "$u13_common_reports/cpython.json" "$u13_common_reports/pypy.json"
printf 'Common doctrine alpha passed under both runtimes. This is behavior verification; expanded native parity and tuning remain ahead.\n'
