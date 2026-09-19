#!/usr/bin/env bash
# Bounded doctrine alpha: five Python games; optional focused native rules gate.
set -euo pipefail
# Each Python check includes the unit suite and five full games. The old
# ten-minute command budget expired after passing tests on slower machines.
u13_common_doctrine_timeout=${U13_DOCTRINE_TIMEOUT_SECONDS:-1800}
if [[ ! "$u13_common_doctrine_timeout" =~ ^[1-9][0-9]{0,4}$ ]] ||
   ((u13_common_doctrine_timeout > 86400)); then
  printf 'U13_DOCTRINE_TIMEOUT_SECONDS must be an integer from 1 to 86400.\n' >&2
  exit 2
fi
if [[ $# -lt 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/pypy3.exe [cpython_executable] [--godot /path/to/godot] [--kalligan-godot /path/to/godot] [--humbaba-godot /path/to/godot]\n' "$0" >&2
  exit 2
fi
u13_common_pypy=$1
u13_common_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_common_cpython=""
u13_common_godot=""
u13_common_kalligan_godot=""
u13_common_humbaba_godot=""
shift
while [[ $# -gt 0 ]]; do
  if [[ "$1" == --godot && $# -ge 2 && -z "$u13_common_godot" ]]; then
    u13_common_godot=$2
    shift 2
  elif [[ "$1" == --kalligan-godot && $# -ge 2 && -z "$u13_common_kalligan_godot" ]]; then
    u13_common_kalligan_godot=$2
    shift 2
  elif [[ "$1" == --humbaba-godot && $# -ge 2 && -z "$u13_common_humbaba_godot" ]]; then
    u13_common_humbaba_godot=$2
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
if [[ -n "$u13_common_kalligan_godot" ]]; then
  u13_common_kalligan_version=$("$u13_common_kalligan_godot" --version)
  if [[ "$u13_common_kalligan_version" != 4.7.2.stable.* ]]; then
    printf 'Windows acceptance requires Godot 4.7.2 stable; found %s\n' "$u13_common_kalligan_version" >&2
    exit 2
  fi
fi
cd -- "$u13_common_root"
if [[ -n "$u13_common_humbaba_godot" ]]; then
  u13_common_humbaba_version=$("$u13_common_humbaba_godot" --version)
  if [[ "$u13_common_humbaba_version" != 4.7.2.stable.* ]]; then
    printf 'Windows acceptance requires Godot 4.7.2 stable; found %s\n' "$u13_common_humbaba_version" >&2
    exit 2
  fi
fi
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
u13_common_downloads=${U13_REPORT_DOWNLOADS:-"$HOME/Downloads"}
mkdir -p -- "$u13_common_downloads"
u13_common_reports=$(mktemp -d "$u13_common_downloads/u13-common-doctrine-XXXXXX")
u13_common_pid=""
u13_common_reason=runner_error
u13_common_phase=setup
u13_common_started=$SECONDS
u13_common_phase_started=$SECONDS
u13_common_phase_timeout=0
stop_child() {
  if [[ -n "$u13_common_pid" ]]; then
    kill -KILL "$u13_common_pid" 2>/dev/null || true
    wait "$u13_common_pid" 2>/dev/null || true
    u13_common_pid=""
  fi
}
cleanup() {
  local status=$?
  stop_child
  if ((status == 0)); then u13_common_reason=passed; fi
  {
    printf 'runner=u13-common-doctrine\nexit_status=%s\n' "$status"
    printf 'reason=%s\nphase=%s\n' "$u13_common_reason" "$u13_common_phase"
    printf 'elapsed_seconds=%s\nphase_elapsed_seconds=%s\n' \
      "$((SECONDS-u13_common_started))" "$((SECONDS-u13_common_phase_started))"
    printf 'phase_timeout_seconds=%s\ndoctrine_timeout_seconds=%s\n' \
      "$u13_common_phase_timeout" "$u13_common_doctrine_timeout"
  } >"$u13_common_reports/run-status.txt"
  bash "$u13_common_root/Scripts/Sim/package_u13_reports.sh" "$u13_common_reports" || true
  exit "$status"
}
trap cleanup EXIT
trap 'u13_common_reason=interrupted; exit 130' INT
trap 'u13_common_reason=terminated; exit 143' TERM
git -C "$u13_common_root" diff HEAD >"$u13_common_reports/worktree.diff"
git rev-parse HEAD >"$u13_common_reports/revision.txt"
for u13_common_runtime in "$u13_common_cpython" "$u13_common_pypy"; do
  "$u13_common_runtime" -c 'import platform, sys; print(platform.python_implementation()); print(sys.version); print(sys.executable)'
done >"$u13_common_reports/runtimes.txt"
run_logged() {
  local log=$1
  shift
  u13_common_phase=$(basename -- "$log")
  u13_common_phase_timeout=600
  if [[ "$1" == --timeout-seconds ]]; then
    u13_common_phase_timeout=$2
    shift 2
  fi
  u13_common_phase_started=$SECONDS
  u13_common_reason=runner_error
  printf 'START %s (timeout %s seconds)\n' "$u13_common_phase" "$u13_common_phase_timeout" \
    | tee -a "$u13_common_reports/runner.log"
  "$@" >"$log" 2>&1 &
  u13_common_pid=$!
  local heartbeat=$((SECONDS + 15))
  while kill -0 "$u13_common_pid" 2>/dev/null; do
    if ((SECONDS-u13_common_phase_started >= u13_common_phase_timeout)); then
      u13_common_reason=watchdog_timeout
      stop_child
      printf 'FAIL doctrine watchdog: %s exceeded %s seconds (elapsed %s seconds)\n' \
        "$u13_common_phase" "$u13_common_phase_timeout" "$((SECONDS-u13_common_phase_started))" \
        | tee -a "$log" "$u13_common_reports/runner.log" >&2
      exit 124
    fi
    if ((SECONDS >= heartbeat)); then
      printf 'Running %s (%s seconds; timeout %s seconds)\n' \
        "$u13_common_phase" "$((SECONDS-u13_common_phase_started))" "$u13_common_phase_timeout"
      tail -n 1 -- "$log"
      heartbeat=$((SECONDS + 15))
    fi
    sleep 0.2
  done
  local status=0
  wait "$u13_common_pid" || status=$?
  u13_common_pid=""
  if ((status != 0)); then
    u13_common_reason=command_failed
    printf 'FAIL doctrine command: %s exited %s after %s seconds\n' \
      "$u13_common_phase" "$status" "$((SECONDS-u13_common_phase_started))" \
      | tee -a "$log" "$u13_common_reports/runner.log" >&2
    tail -n 35 -- "$log"
    exit "$status"
  fi
  if ! "$u13_common_cpython" - "$log" <<'PY'
from pathlib import Path
import sys
errors = [line for line in Path(sys.argv[1]).read_text(encoding='utf-8', errors='replace').splitlines()
          if line.startswith(('FAIL ', 'SCRIPT ERROR:', 'ERROR:', 'Traceback'))]
if errors:
    print('\n'.join(errors[:12]), file=sys.stderr)
    sys.exit(1)
PY
  then
    u13_common_reason=log_error
    printf 'FAIL doctrine log: %s contains an error despite exit status 0\n' "$u13_common_phase" \
      | tee -a "$log" "$u13_common_reports/runner.log" >&2
    exit 1
  fi
  printf 'PASS %s (%s seconds)\n' "$u13_common_phase" "$((SECONDS-u13_common_phase_started))" \
    | tee -a "$u13_common_reports/runner.log"
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
if [[ -n "$u13_common_kalligan_godot" ]]; then
  printf '%s\n' "$u13_common_kalligan_version" >"$u13_common_reports/kalligan-godot-version.txt"
  for u13_common_suite in U13Hazards U13KalliganIntegration U13KalliganBoard U13ScorchVisuals; do
    run_logged "$u13_common_reports/$u13_common_suite.log" "$u13_common_kalligan_godot" --headless --path "$u13_common_root" \
      --script "res://Scripts/Sim/${u13_common_suite}TestRunner.gd"
  done
  run_logged "$u13_common_reports/scorch-inputs.log" "$u13_common_cpython" Scripts/Sim/run_u13_common_doctrine.py scorch-inputs "$u13_common_reports/scorch-inputs.json"
  u13_common_identity=$("$u13_common_cpython" -c 'from pathlib import Path; from u13_pysim.verify import source_identity; print(" ".join(source_identity(Path.cwd())))')
  read -r u13_common_revision u13_common_source_hash <<<"$u13_common_identity"
  run_logged "$u13_common_reports/scorch-native.log" "$u13_common_kalligan_godot" --headless --path "$u13_common_root" \
    --script res://Scripts/Sim/U13ScorchCastleTestRunner.gd -- "$u13_common_reports/scorch.exact" "$u13_common_reports/scorch-inputs.json" "$u13_common_revision" "$u13_common_source_hash"
  for u13_common_runtime in "$u13_common_cpython" "$u13_common_pypy"; do
    u13_common_runtime_name=$("$u13_common_runtime" -c 'import platform; print(platform.python_implementation().lower())')
    run_logged "$u13_common_reports/$u13_common_runtime_name-scorch-comparison.log" "$u13_common_runtime" \
      Scripts/Sim/run_u13_common_doctrine.py verify-scorch "$u13_common_reports/scorch.exact" "$u13_common_reports/scorch-inputs.json"
  done
fi
if [[ -n "$u13_common_humbaba_godot" ]]; then
  printf '%s\n' "$u13_common_humbaba_version" >"$u13_common_reports/humbaba-godot-version.txt"
  run_logged "$u13_common_reports/U13Breath.log" "$u13_common_humbaba_godot" --headless --path "$u13_common_root" \
    --script res://Scripts/Sim/U13BreathTestRunner.gd
  run_logged "$u13_common_reports/breath-inputs.log" "$u13_common_cpython" Scripts/Sim/run_u13_common_doctrine.py breath-inputs "$u13_common_reports/breath-inputs.json"
  u13_common_identity=$("$u13_common_cpython" -c 'from pathlib import Path; from u13_pysim.verify import source_identity; print(" ".join(source_identity(Path.cwd())))')
  read -r u13_common_revision u13_common_source_hash <<<"$u13_common_identity"
  run_logged "$u13_common_reports/breath-native.log" "$u13_common_humbaba_godot" --headless --path "$u13_common_root" \
    --script res://Scripts/Sim/U13BreathPulseTestRunner.gd -- "$u13_common_reports/breath.exact" "$u13_common_reports/breath-inputs.json" "$u13_common_revision" "$u13_common_source_hash"
  for u13_common_runtime in "$u13_common_cpython" "$u13_common_pypy"; do
    u13_common_runtime_name=$("$u13_common_runtime" -c 'import platform; print(platform.python_implementation().lower())')
    run_logged "$u13_common_reports/$u13_common_runtime_name-breath-comparison.log" "$u13_common_runtime" \
      Scripts/Sim/run_u13_common_doctrine.py verify-breath "$u13_common_reports/breath.exact" "$u13_common_reports/breath-inputs.json"
  done
fi
run_logged "$u13_common_reports/cpython.log" --timeout-seconds "$u13_common_doctrine_timeout" "$u13_common_cpython" \
  "$u13_common_root/Scripts/Sim/run_u13_common_doctrine.py" check --report "$u13_common_reports/cpython.json"
run_logged "$u13_common_reports/pypy.log" --timeout-seconds "$u13_common_doctrine_timeout" "$u13_common_pypy" \
  "$u13_common_root/Scripts/Sim/run_u13_common_doctrine.py" check --report "$u13_common_reports/pypy.json"
run_logged "$u13_common_reports/comparison.log" "$u13_common_cpython" \
  "$u13_common_root/Scripts/Sim/run_u13_common_doctrine.py" compare \
  "$u13_common_reports/cpython.json" "$u13_common_reports/pypy.json"
printf 'Common doctrine alpha passed under both runtimes. Native checks run with --godot, --kalligan-godot or --humbaba-godot; expanded game parity and tuning remain ahead.\n'
