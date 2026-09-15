#!/usr/bin/env bash
# Reuse the pinned Windows 4.7.2 stream; compare old/new code under both runtimes.
set -euo pipefail
if [[ $# -lt 2 || $# -gt 3 || ! -f "$1" || ! -x "$2" ]]; then
  printf 'Usage: bash %s /path/to/full-match.exact.jsonl /path/to/pypy3.exe [cpython_executable]\n' "$0" >&2
  exit 2
fi
u13_copy_reference=$(cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
u13_copy_pypy=$2
u13_copy_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_copy_cpython=()
if [[ $# -eq 3 ]]; then
  u13_copy_cpython=("$3")
else
  for u13_copy_candidate in python3 python py; do
    if command -v "$u13_copy_candidate" >/dev/null 2>&1 &&
       "$u13_copy_candidate" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))' >/dev/null 2>&1; then
      u13_copy_cpython=("$u13_copy_candidate")
      break
    fi
  done
fi
if [[ ${#u13_copy_cpython[@]} -eq 0 ]] ||
   ! "${u13_copy_cpython[@]}" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))'; then
  printf 'CPython 3.10+ is required as the comparison runtime.\n' >&2
  exit 2
fi
if ! "$u13_copy_pypy" -c 'import sys; sys.exit(sys.implementation.name != "pypy" or sys.version_info < (3, 10))'; then
  printf 'The second argument must be the PyPy 3.10+ executable.\n' >&2
  exit 2
fi
mkdir -p -- "$HOME/Downloads"
u13_copy_reports=$(mktemp -d "$HOME/Downloads/u13-pysim-full-copying-XXXXXX")
u13_copy_pid=""
cleanup() {
  local result=$?
  if [[ -n "$u13_copy_pid" ]]; then
    kill -KILL "$u13_copy_pid" 2>/dev/null || true
    wait "$u13_copy_pid" 2>/dev/null || true
  fi
  printf 'runner=u13-pysim-full-match-copying\nexit_status=%s\n' "$result" >"$u13_copy_reports/run-status.txt"
  bash "$u13_copy_root/Scripts/Sim/package_u13_reports.sh" "$u13_copy_reports" || true
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git -C "$u13_copy_root" diff HEAD >"$u13_copy_reports/worktree.diff"
run_logged() {
  local log=$1 limit=$2
  shift 2
  "$@" >"$log" 2>&1 &
  u13_copy_pid=$!
  local started=$SECONDS deadline=$((SECONDS + limit)) heartbeat=$((SECONDS + 15))
  while kill -0 "$u13_copy_pid" 2>/dev/null; do
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
  wait "$u13_copy_pid" || status=$?
  u13_copy_pid=""
  if ((status != 0)) || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL([ :]|$)' "$log"; then
    tail -n 35 -- "$log"
    exit 1
  fi
  tail -n 3 -- "$log"
  printf '%s=%s seconds\n' "$log" "$((SECONDS-started))" >>"$u13_copy_reports/stage-times.txt"
}
printf 'U13 full-match copying reports: %s\n' "$u13_copy_reports"
for u13_copy_runtime in cpython pypy; do
  u13_copy_command=("${u13_copy_cpython[@]}")
  u13_copy_order=()
  if [[ "$u13_copy_runtime" == pypy ]]; then
    u13_copy_command=("$u13_copy_pypy")
    u13_copy_order=(--reverse)
  fi
  u13_copy_dir="$u13_copy_reports/$u13_copy_runtime"
  mkdir -p -- "$u13_copy_dir"
  "${u13_copy_command[@]}" --version >"$u13_copy_dir/python-version.log" 2>&1
  "${u13_copy_command[@]}" "$u13_copy_root/Scripts/Sim/run_u13_pysim.py" source-identity >"$u13_copy_dir/source-identity.txt"
  run_logged "$u13_copy_dir/python-tests.log" 180 "${u13_copy_command[@]}" \
    "$u13_copy_root/Scripts/Sim/run_u13_pysim.py" self-test-full-match
  run_logged "$u13_copy_dir/python-parity.log" 900 "${u13_copy_command[@]}" \
    "$u13_copy_root/Scripts/Sim/run_u13_pysim.py" verify-full-match-copying \
    "$u13_copy_reference" --report "$u13_copy_dir/python-summary.json"
  grep -Eq '^U13 PySim full-match copying parity failures: 0[[:space:]]*$' "$u13_copy_dir/python-parity.log"
  # Each worker has its own 15-minute limit; the outer deadline allows both.
  run_logged "$u13_copy_dir/copying-comparison.log" 2400 "${u13_copy_command[@]}" \
    "$u13_copy_root/Scripts/Sim/run_u13_pysim.py" benchmark-full-match-copying \
    --games 20 --verified-report "$u13_copy_dir/python-summary.json" \
    --report "$u13_copy_dir/copying-comparison.json" "${u13_copy_order[@]}"
  grep -Eq '^U13 PySim full-match copying timing failures: 0[[:space:]]*$' "$u13_copy_dir/copying-comparison.log"
done
printf 'U13 full-match copying gate passed under CPython and PyPy. Twenty consecutive measured games per implementation/runtime; original Godot stream reused.\n'
