#!/usr/bin/env bash
# Profile the accepted optimized engine under both installed runtimes.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/pypy3.exe [cpython_executable]\n' "$0" >&2
  exit 2
fi
u13_profile_pypy=$1
u13_profile_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_profile_cpython=()
if [[ $# -eq 2 ]]; then
  u13_profile_cpython=("$2")
else
  for u13_profile_candidate in python3 python py; do
    if command -v "$u13_profile_candidate" >/dev/null 2>&1 &&
       "$u13_profile_candidate" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))' >/dev/null 2>&1; then
      u13_profile_cpython=("$u13_profile_candidate")
      break
    fi
  done
fi
if [[ ${#u13_profile_cpython[@]} -eq 0 ]] ||
   ! "${u13_profile_cpython[@]}" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))'; then
  printf 'CPython 3.10+ is required as the comparison runtime.\n' >&2
  exit 2
fi
if ! "$u13_profile_pypy" -c 'import sys; sys.exit(sys.implementation.name != "pypy" or sys.version_info < (3, 10))'; then
  printf 'The first argument must be the PyPy 3.10+ executable.\n' >&2
  exit 2
fi
mkdir -p -- "$HOME/Downloads"
u13_profile_reports=$(mktemp -d "$HOME/Downloads/u13-pysim-optimized-profile-XXXXXX")
u13_profile_pid=""
cleanup() {
  local result=$?
  if [[ -n "$u13_profile_pid" ]]; then
    kill -KILL "$u13_profile_pid" 2>/dev/null || true
    wait "$u13_profile_pid" 2>/dev/null || true
  fi
  printf 'runner=u13-pysim-optimized-profile\nexit_status=%s\n' "$result" >"$u13_profile_reports/run-status.txt"
  bash "$u13_profile_root/Scripts/Sim/package_u13_reports.sh" "$u13_profile_reports" || true
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git -C "$u13_profile_root" diff HEAD >"$u13_profile_reports/worktree.diff"
printf 'U13 optimized full-match profile reports: %s\n' "$u13_profile_reports"
for u13_profile_runtime in cpython pypy; do
  u13_profile_command=("${u13_profile_cpython[@]}")
  if [[ "$u13_profile_runtime" == pypy ]]; then
    u13_profile_command=("$u13_profile_pypy")
  fi
  "${u13_profile_command[@]}" --version >"$u13_profile_reports/$u13_profile_runtime-version.log" 2>&1
  if ! "${u13_profile_command[@]}" "$u13_profile_root/Scripts/Sim/test_profile_u13_pysim_full_match.py" \
      >"$u13_profile_reports/$u13_profile_runtime-observer-tests.log" 2>&1; then
    tail -n 35 -- "$u13_profile_reports/$u13_profile_runtime-observer-tests.log"
    exit 1
  fi
  u13_profile_log="$u13_profile_reports/$u13_profile_runtime-profile.log"
  "${u13_profile_command[@]}" "$u13_profile_root/Scripts/Sim/profile_u13_pysim_full_match.py" \
    --games 20 --warmups 10 --report-dir "$u13_profile_reports/$u13_profile_runtime" >"$u13_profile_log" 2>&1 &
  u13_profile_pid=$!
  u13_profile_started=$SECONDS
  u13_profile_deadline=$((SECONDS + 2100))
  u13_profile_heartbeat=$((SECONDS + 15))
  while kill -0 "$u13_profile_pid" 2>/dev/null; do
    if ((SECONDS >= u13_profile_deadline)); then
      printf 'FAIL profile watchdog: %s\n' "$u13_profile_runtime" >&2
      exit 1
    fi
    if ((SECONDS >= u13_profile_heartbeat)); then
      printf 'Running %s (%s seconds)\n' "$u13_profile_runtime" "$((SECONDS-u13_profile_started))"
      tail -n 1 -- "$u13_profile_log"
      u13_profile_heartbeat=$((SECONDS + 15))
    fi
    sleep 0.2
  done
  u13_profile_status=0
  wait "$u13_profile_pid" || u13_profile_status=$?
  u13_profile_pid=""
  if ((u13_profile_status != 0)) || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL([ :]|$)' "$u13_profile_log"; then
    tail -n 35 -- "$u13_profile_log"
    exit 1
  fi
  grep -Eq '^U13 optimized full-match profile failures: 0[[:space:]]*$' "$u13_profile_log"
  tail -n 4 -- "$u13_profile_log"
  printf '%s=%s seconds\n' "$u13_profile_runtime" "$((SECONDS-u13_profile_started))" >>"$u13_profile_reports/stage-times.txt"
done
printf 'Optimized profiles complete under CPython and PyPy; all match digests checked.\n'
