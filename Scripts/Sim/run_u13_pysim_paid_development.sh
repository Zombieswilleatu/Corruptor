#!/usr/bin/env bash
# Exact native export plus dual-runtime replay; four games, no timing campaign.
set -euo pipefail
if [[ $# -lt 2 || $# -gt 3 || ! -x "$1" || ! -x "$2" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2 /path/to/pypy3.exe [cpython_executable]\n' "$0" >&2
  exit 2
fi
u13_paid_godot=$1
u13_paid_pypy=$2
u13_paid_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_paid_cpython=""
if [[ $# -eq 3 ]]; then
  u13_paid_cpython=$3
else
  for u13_paid_candidate in python3 python py; do
    if command -v "$u13_paid_candidate" >/dev/null 2>&1 &&
       "$u13_paid_candidate" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))' >/dev/null 2>&1; then
      u13_paid_cpython=$u13_paid_candidate
      break
    fi
  done
fi
if [[ -z "$u13_paid_cpython" ]] ||
   ! "$u13_paid_cpython" -c 'import sys; sys.exit(sys.implementation.name != "cpython" or sys.version_info < (3, 10))'; then
  printf 'CPython 3.10+ is required.\n' >&2
  exit 2
fi
if ! "$u13_paid_pypy" -c 'import sys; sys.exit(sys.implementation.name != "pypy" or sys.version_info < (3, 10))'; then
  printf 'The second argument must be PyPy 3.10+.\n' >&2
  exit 2
fi
mkdir -p -- "$HOME/Downloads"
u13_paid_reports=$(mktemp -d "$HOME/Downloads/u13-pysim-paid-development-XXXXXX")
u13_paid_pid=""
cleanup() {
  local status=$?
  if [[ -n "$u13_paid_pid" ]]; then
    kill -KILL "$u13_paid_pid" 2>/dev/null || true
    wait "$u13_paid_pid" 2>/dev/null || true
  fi
  printf 'runner=u13-pysim-paid-development\nexit_status=%s\n' "$status" >"$u13_paid_reports/run-status.txt"
  bash "$u13_paid_root/Scripts/Sim/package_u13_reports.sh" "$u13_paid_reports" || true
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git -C "$u13_paid_root" diff HEAD >"$u13_paid_reports/worktree.diff"
run_logged() {
  local log=$1
  shift
  "$@" >"$log" 2>&1 &
  u13_paid_pid=$!
  local started=$SECONDS heartbeat=$((SECONDS + 15))
  local limit=900
  if [[ "$log" == */godot.log ]]; then limit=3600; fi
  while kill -0 "$u13_paid_pid" 2>/dev/null; do
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
  wait "$u13_paid_pid" || status=$?
  u13_paid_pid=""
  if ((status != 0)) || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL([ :]|$)' "$log"; then
    tail -n 35 -- "$log"
    exit 1
  fi
  tail -n 5 -- "$log"
}
printf 'U13 paid-development reports: %s\n' "$u13_paid_reports"
"$u13_paid_godot" --version >"$u13_paid_reports/version.log" 2>&1
if ! grep -Eq '^4\.7\.2\.stable([.[:space:]]|$)' "$u13_paid_reports/version.log"; then
  printf 'This acceptance runner requires Godot 4.7.2 stable.\n' >&2
  exit 1
fi
"$u13_paid_cpython" "$u13_paid_root/Scripts/Sim/run_u13_pysim.py" source-identity >"$u13_paid_reports/source-identity.txt"
mapfile -t u13_paid_identity <"$u13_paid_reports/source-identity.txt"
u13_paid_revision=${u13_paid_identity[0]%$'\r'}
u13_paid_source=${u13_paid_identity[1]%$'\r'}
run_logged "$u13_paid_reports/cpython-tests.log" "$u13_paid_cpython" "$u13_paid_root/Scripts/Sim/run_u13_pysim.py" self-test-paid-development
run_logged "$u13_paid_reports/pypy-tests.log" "$u13_paid_pypy" "$u13_paid_root/Scripts/Sim/run_u13_pysim.py" self-test-paid-development
run_logged "$u13_paid_reports/godot.log" "$u13_paid_godot" --headless --path "$u13_paid_root" \
  --script Scripts/Sim/U13PySimPaidDevelopmentTestRunner.gd -- \
  "$u13_paid_reports/paid.exact.jsonl" "$u13_paid_revision" "$u13_paid_source"
grep -Eq '^U13 PySim paid-development Godot failures: 0[[:space:]]*$' "$u13_paid_reports/godot.log"
for u13_paid_runtime in cpython pypy; do
  if [[ "$u13_paid_runtime" == cpython ]]; then u13_paid_python=$u13_paid_cpython; else u13_paid_python=$u13_paid_pypy; fi
  "$u13_paid_python" -c 'import json,platform,sys; print(json.dumps(dict(implementation=platform.python_implementation(),python=sys.version,platform=platform.platform()),indent=2))' >"$u13_paid_reports/$u13_paid_runtime-runtime.json"
  run_logged "$u13_paid_reports/$u13_paid_runtime-parity.log" "$u13_paid_python" "$u13_paid_root/Scripts/Sim/run_u13_pysim.py" \
    verify-paid-development "$u13_paid_reports/paid.exact.jsonl" --report "$u13_paid_reports/$u13_paid_runtime.json"
  grep -Eq '^U13 PySim paid-development Python failures: 0[[:space:]]*$' "$u13_paid_reports/$u13_paid_runtime-parity.log"
done
"$u13_paid_cpython" - "$u13_paid_reports/cpython.json" "$u13_paid_reports/pypy.json" >"$u13_paid_reports/comparison.log" <<'PYCOMPARE'
import json,sys
first,second=(json.load(open(p,encoding="utf-8")) for p in sys.argv[1:])
if first!=second or first.get("failures")!=0 or first.get("diagnostic_only") is not False:
    raise SystemExit("FAIL dual-runtime paid-development comparison")
print("CPython and PyPy exact parity summaries match. Comparison failures: 0")
PYCOMPARE
cat "$u13_paid_reports/comparison.log"
printf 'Paid-development gate passed. Declared powers and five Lord integrations still await parity.\n'
