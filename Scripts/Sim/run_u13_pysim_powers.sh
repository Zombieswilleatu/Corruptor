#!/usr/bin/env bash
# Exact native export plus dual-runtime replay; five games plus directed power and actor cases; no timing campaign.
set -euo pipefail
if [[ $# -lt 2 || $# -gt 3 || ! -x "$1" || ! -x "$2" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2 /path/to/pypy3.exe [cpython_executable]\n' "$0" >&2
  exit 2
fi
u13_powers_godot=$1
u13_powers_pypy=$2
u13_powers_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_powers_cpython=""
if [[ $# -eq 3 ]]; then
  u13_powers_cpython=$3
else
  for u13_powers_candidate in python3 python py; do
    if command -v "$u13_powers_candidate" >/dev/null 2>&1 &&
       "$u13_powers_candidate" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))' >/dev/null 2>&1; then
      u13_powers_cpython=$u13_powers_candidate
      break
    fi
  done
fi
if [[ -z "$u13_powers_cpython" ]] ||
   ! "$u13_powers_cpython" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))'; then
  printf 'CPython 3.10+ is required.\n' >&2
  exit 2
fi
if ! "$u13_powers_pypy" -c 'import sys; sys.exit(sys.implementation.name != "pypy" or sys.version_info < (3, 10))'; then
  printf 'The second argument must be PyPy 3.10+.\n' >&2
  exit 2
fi
mkdir -p -- "$HOME/Downloads"
u13_powers_reports=$(mktemp -d "$HOME/Downloads/u13-pysim-powers-XXXXXX")
u13_powers_pid=""
cleanup() {
  local status=$?
  if [[ -n "$u13_powers_pid" ]]; then
    kill -KILL "$u13_powers_pid" 2>/dev/null || true
    wait "$u13_powers_pid" 2>/dev/null || true
  fi
  printf 'runner=u13-pysim-powers\nexit_status=%s\n' "$status" >"$u13_powers_reports/run-status.txt"
  bash "$u13_powers_root/Scripts/Sim/package_u13_reports.sh" "$u13_powers_reports" || true
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git -C "$u13_powers_root" diff HEAD >"$u13_powers_reports/worktree.diff"
run_logged() {
  local log=$1
  shift
  "$@" >"$log" 2>&1 &
  u13_powers_pid=$!
  local started=$SECONDS heartbeat=$((SECONDS + 15))
  local limit=900
  if [[ "$log" == */godot.log ]]; then limit=3600; fi
  while kill -0 "$u13_powers_pid" 2>/dev/null; do
    if ((SECONDS-started >= limit)); then
      printf 'FAIL parity watchdog: %s\n' "$log" >&2
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
  wait "$u13_powers_pid" || status=$?
  u13_powers_pid=""
  if ((status != 0)) || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL([ :]|$)' "$log"; then
    tail -n 35 -- "$log"
    exit 1
  fi
  tail -n 5 -- "$log"
}
printf 'U13 powers reports: %s\n' "$u13_powers_reports"
"$u13_powers_godot" --version >"$u13_powers_reports/version.log" 2>&1
if ! grep -Eq '^4\.7\.2\.stable([.[:space:]]|$)' "$u13_powers_reports/version.log"; then
  printf 'This acceptance runner requires Godot 4.7.2 stable.\n' >&2
  exit 1
fi
"$u13_powers_cpython" "$u13_powers_root/Scripts/Sim/run_u13_pysim.py" source-identity >"$u13_powers_reports/source-identity.txt"
mapfile -t u13_powers_identity <"$u13_powers_reports/source-identity.txt"
u13_powers_revision=${u13_powers_identity[0]%$'\r'}
u13_powers_source=${u13_powers_identity[1]%$'\r'}
run_logged "$u13_powers_reports/cpython-tests.log" "$u13_powers_cpython" "$u13_powers_root/Scripts/Sim/run_u13_pysim.py" self-test-powers
run_logged "$u13_powers_reports/pypy-tests.log" "$u13_powers_pypy" "$u13_powers_root/Scripts/Sim/run_u13_pysim.py" self-test-powers
printf 'Native gate: five complete games, eight settlement cases and 34 power components, then an independent replay.\n'
run_logged "$u13_powers_reports/godot.log" "$u13_powers_godot" --headless --path "$u13_powers_root" \
  --script Scripts/Sim/U13PySimPowersTestRunner.gd -- \
  "$u13_powers_reports/powers.exact.jsonl" "$u13_powers_revision" "$u13_powers_source"
grep -Eq '^U13 PySim powers Godot failures: 0[[:space:]]*$' "$u13_powers_reports/godot.log"
for u13_powers_runtime in cpython pypy; do
  if [[ "$u13_powers_runtime" == cpython ]]; then u13_powers_python=$u13_powers_cpython; else u13_powers_python=$u13_powers_pypy; fi
  "$u13_powers_python" -c 'import json,platform,sys; print(json.dumps(dict(implementation=platform.python_implementation(),python=sys.version,platform=platform.platform()),indent=2))' >"$u13_powers_reports/$u13_powers_runtime-runtime.json"
  run_logged "$u13_powers_reports/$u13_powers_runtime-parity.log" "$u13_powers_python" "$u13_powers_root/Scripts/Sim/run_u13_pysim.py" \
    verify-powers "$u13_powers_reports/powers.exact.jsonl" --report "$u13_powers_reports/$u13_powers_runtime.json"
  grep -Eq '^U13 PySim powers Python failures: 0[[:space:]]*$' "$u13_powers_reports/$u13_powers_runtime-parity.log"
done
"$u13_powers_cpython" - "$u13_powers_reports/cpython.json" "$u13_powers_reports/pypy.json" >"$u13_powers_reports/comparison.log" <<'PYCOMPARE'
import json,sys
first,second=(json.load(open(p,encoding="utf-8")) for p in sys.argv[1:])
if first!=second or first.get("failures")!=0 or first.get("diagnostic_only") is not False:
    raise SystemExit("FAIL dual-runtime powers comparison")
print("CPython and PyPy exact parity summaries match. Comparison failures: 0")
PYCOMPARE
cat "$u13_powers_reports/comparison.log"
printf 'Nine-Lord powers gate passed. This is rules parity, not doctrine strength or balance evidence.\n'
