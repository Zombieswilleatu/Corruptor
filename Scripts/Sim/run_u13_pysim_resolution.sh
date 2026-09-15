#!/usr/bin/env bash
# Focused Windows 4.7.2 gate: artillery, recruitment and ordinary combat parity.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable [python_executable]\n' "$0" >&2
  exit 2
fi
u13_py_exe=$1
u13_py_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_py_command=()
if [[ $# -eq 2 ]]; then
  u13_py_command=("$2")
else
  for u13_py_candidate in python3 python py; do
    if command -v "$u13_py_candidate" >/dev/null 2>&1 && "$u13_py_candidate" -c 'import sys; sys.exit(sys.version_info < (3, 10))' >/dev/null 2>&1; then
      u13_py_command=("$u13_py_candidate")
      break
    fi
  done
fi
if [[ ${#u13_py_command[@]} -eq 0 ]] || ! "${u13_py_command[@]}" -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then
  printf 'Python 3.10+ is required. Pass its executable as the optional second argument. No pip packages are needed.\n' >&2
  exit 2
fi
mkdir -p -- "$HOME/Downloads"
u13_py_reports=$(mktemp -d "$HOME/Downloads/u13-pysim-resolution-XXXXXX")
u13_py_pid=""
cleanup() {
  local result=$?
  if [[ -n "$u13_py_pid" ]]; then
    kill -KILL "$u13_py_pid" 2>/dev/null || true
    wait "$u13_py_pid" 2>/dev/null || true
  fi
  printf 'runner=u13-pysim-resolution\nexit_status=%s\n' "$result" >"$u13_py_reports/run-status.txt"
  bash "$u13_py_root/Scripts/Sim/package_u13_reports.sh" "$u13_py_reports" || true
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
"$u13_py_exe" --version >"$u13_py_reports/version.log" 2>&1
if ! grep -Eq '^4\.7\.2\.stable([.[:space:]]|$)' "$u13_py_reports/version.log"; then
  printf 'This acceptance runner requires Godot 4.7.2 stable.\n' >&2
  exit 1
fi
"${u13_py_command[@]}" --version >"$u13_py_reports/python-version.log" 2>&1
"${u13_py_command[@]}" "$u13_py_root/Scripts/Sim/run_u13_pysim.py" source-identity >"$u13_py_reports/source-identity.txt"
mapfile -t u13_py_identity <"$u13_py_reports/source-identity.txt"
u13_py_revision=${u13_py_identity[0]%$'\r'}
u13_py_source=${u13_py_identity[1]%$'\r'}
git -C "$u13_py_root" diff HEAD >"$u13_py_reports/worktree.diff"
run_logged() {
  local log=$1
  shift
  "$@" >"$log" 2>&1 &
  u13_py_pid=$!
  # This corpus also replays every Godot trace after exact export/decode.
  # The first diagnostic exceeded 180s during that replay, with zero failures.
  local stage_limit=180
  if [[ "$log" == */godot.log ]]; then stage_limit=420; fi
  local deadline=$((SECONDS + stage_limit))
  local heartbeat=$((SECONDS + 15))
  while kill -0 "$u13_py_pid" 2>/dev/null; do
    if ((SECONDS >= deadline)); then
      printf 'FAIL stage watchdog (%s seconds): %s\n' "$stage_limit" "$log" >&2
      exit 1
    fi
    if ((SECONDS >= heartbeat)); then
      tail -n 1 -- "$log"
      heartbeat=$((SECONDS + 15))
    fi
    sleep 0.2
  done
  local status=0
  wait "$u13_py_pid" || status=$?
  u13_py_pid=""
  if ((status != 0)) || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL([ :]|$)' "$log"; then
    tail -n 35 -- "$log"
    exit 1
  fi
  tail -n 3 -- "$log"
}
printf 'U13 PySim resolution reports: %s\n' "$u13_py_reports"
run_logged "$u13_py_reports/python-tests.log" "${u13_py_command[@]}" "$u13_py_root/Scripts/Sim/run_u13_pysim.py" self-test-resolution
run_logged "$u13_py_reports/godot.log" "$u13_py_exe" --headless --path "$u13_py_root" \
  --script Scripts/Sim/U13PySimResolutionTestRunner.gd -- \
  "$u13_py_reports/resolution.exact.json" "$u13_py_revision" "$u13_py_source"
grep -Eq '^U13 PySim resolution Godot failures: 0[[:space:]]*$' "$u13_py_reports/godot.log"
run_logged "$u13_py_reports/python-parity.log" "${u13_py_command[@]}" "$u13_py_root/Scripts/Sim/run_u13_pysim.py" \
  verify-resolution "$u13_py_reports/resolution.exact.json" --report "$u13_py_reports/python-summary.json"
grep -Eq '^U13 PySim resolution Python failures: 0[[:space:]]*$' "$u13_py_reports/python-parity.log"
printf 'U13 PySim resolution passed: nine fresh-game hooks plus isolated ordinary-resolution cases. Full-match speed remains unknown.\n'
