#!/usr/bin/env bash
# Reuse both accepted Godot streams; compare c228d85 and the candidate.
set -euo pipefail
if [[ $# -lt 3 || $# -gt 4 || ! -f "$1" || ! -f "$2" || ! -x "$3" ]]; then
  printf 'Usage: bash %s /path/to/full-match.exact.jsonl /path/to/marching.exact.json /path/to/pypy3.exe [cpython_executable]\n' "$0" >&2
  exit 2
fi
u13_march_full=$(cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
u13_march_phase=$(cd -- "$(dirname -- "$2")" && pwd)/$(basename -- "$2")
u13_march_pypy=$3
u13_march_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_march_cpython=()
if [[ $# -eq 4 ]]; then
  u13_march_cpython=("$4")
else
  for u13_march_candidate in python3 python py; do
    if command -v "$u13_march_candidate" >/dev/null 2>&1 &&
       "$u13_march_candidate" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))' >/dev/null 2>&1; then
      u13_march_cpython=("$u13_march_candidate")
      break
    fi
  done
fi
if [[ ${#u13_march_cpython[@]} -eq 0 ]] ||
   ! "${u13_march_cpython[@]}" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))'; then
  printf 'CPython 3.10+ is required.\n' >&2
  exit 2
fi
if ! "$u13_march_pypy" -c 'import sys; sys.exit(sys.implementation.name != "pypy" or sys.version_info < (3, 10))'; then
  printf 'The third argument must be PyPy 3.10+.\n' >&2
  exit 2
fi
mkdir -p -- "$HOME/Downloads"
u13_march_reports=$(mktemp -d "$HOME/Downloads/u13-pysim-marching-optimization-XXXXXX")
u13_march_pid=""
cleanup() {
  local result=$?
  if [[ -n "$u13_march_pid" ]]; then
    kill -KILL "$u13_march_pid" 2>/dev/null || true
    wait "$u13_march_pid" 2>/dev/null || true
  fi
  printf 'runner=u13-pysim-marching-optimization\nexit_status=%s\n' "$result" >"$u13_march_reports/run-status.txt"
  bash "$u13_march_root/Scripts/Sim/package_u13_reports.sh" "$u13_march_reports" || true
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git -C "$u13_march_root" diff HEAD >"$u13_march_reports/worktree.diff"
run_logged() {
  local log=$1 limit=$2
  shift 2
  "$@" >"$log" 2>&1 &
  u13_march_pid=$!
  local started=$SECONDS deadline=$((SECONDS + limit)) heartbeat=$((SECONDS + 15))
  while kill -0 "$u13_march_pid" 2>/dev/null; do
    if ((SECONDS >= deadline)); then
      printf 'FAIL stage watchdog (%s seconds): %s\n' "$limit" "$log" >&2
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
  wait "$u13_march_pid" || status=$?
  u13_march_pid=""
  if ((status != 0)) || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL([ :]|$)' "$log"; then
    tail -n 35 -- "$log"
    exit 1
  fi
  tail -n 4 -- "$log"
  printf '%s=%s seconds\n' "$(basename -- "$log")" "$((SECONDS-started))" >>"$u13_march_reports/stage-times.txt"
}
printf 'U13 Marching optimization reports: %s\n' "$u13_march_reports"
for u13_march_runtime in cpython pypy; do
  u13_march_command=("${u13_march_cpython[@]}")
  if [[ "$u13_march_runtime" == pypy ]]; then
    u13_march_command=("$u13_march_pypy")
  fi
  "${u13_march_command[@]}" --version >"$u13_march_reports/$u13_march_runtime-version.log" 2>&1
  run_logged "$u13_march_reports/$u13_march_runtime-tests.log" 180 \
    "${u13_march_command[@]}" "$u13_march_root/Scripts/Sim/run_u13_pysim.py" self-test-full-match
  grep -Eq '^Ran 67 tests in ' "$u13_march_reports/$u13_march_runtime-tests.log"
  grep -Eq '^OK[[:space:]]*$' "$u13_march_reports/$u13_march_runtime-tests.log"
  run_logged "$u13_march_reports/$u13_march_runtime-comparison-tests.log" 120 \
    "${u13_march_command[@]}" "$u13_march_root/Scripts/Sim/test_compare_u13_pysim_marching.py"
  grep -Eq '^Ran 3 tests in ' "$u13_march_reports/$u13_march_runtime-comparison-tests.log"
  grep -Eq '^OK[[:space:]]*$' "$u13_march_reports/$u13_march_runtime-comparison-tests.log"
  run_logged "$u13_march_reports/$u13_march_runtime-comparison.log" 4500 \
    "${u13_march_command[@]}" "$u13_march_root/Scripts/Sim/compare_u13_pysim_marching.py" \
    --full-trace "$u13_march_full" --marching-trace "$u13_march_phase" \
    --games 20 --report-dir "$u13_march_reports/$u13_march_runtime"
  grep -Eq '^U13 Marching optimization comparison failures: 0[[:space:]]*$' "$u13_march_reports/$u13_march_runtime-comparison.log"
done
printf 'Both runtime parity/comparison gates passed. Inspect both orderings before accepting the speedup.\n'
