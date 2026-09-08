#!/usr/bin/env bash
# Usage: bash Scripts/Sim/run_u13_foundation_tests.sh /path/to/godot_console.exe
# Logs stay in the system temp directory, outside the project.
set -uo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: bash %s /path/to/Godot_console_executable\n' "$0" >&2
  exit 2
fi
godot_u13_exe=$1
if [[ ! -x "$godot_u13_exe" ]]; then
  printf 'Godot executable not found or not executable: %s\n' "$godot_u13_exe" >&2
  exit 2
fi
u13_project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
u13_test_logs=$(mktemp -d) || exit 2
u13_active_pid=""
u13_timeout_seconds=${U13_TEST_TIMEOUT_SECONDS:-30}
if [[ ! "$u13_timeout_seconds" =~ ^[1-9][0-9]{0,3}$ ]]; then
  printf 'U13_TEST_TIMEOUT_SECONDS must be a positive integer (maximum 9999).\n' >&2
  rm -rf -- "$u13_test_logs"
  exit 2
fi

u13_cleanup() {
  if [[ -n "$u13_active_pid" ]]; then
    kill -KILL "$u13_active_pid" 2>/dev/null || true
    wait "$u13_active_pid" 2>/dev/null || true
  fi
  rm -rf -- "$u13_test_logs"
}
trap u13_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Bash's PID/kill path works in Git Bash without relying on Windows timeout.exe
# (which is not GNU timeout). Kill only the Godot process this runner launched.
u13_run_godot() {
  local u13_log=$1
  shift
  local u13_deadline=$((SECONDS + u13_timeout_seconds))
  local u13_exit=0
  "$godot_u13_exe" --headless --path "$u13_project_dir" "$@" >"$u13_log" 2>&1 &
  u13_active_pid=$!
  while kill -0 "$u13_active_pid" 2>/dev/null; do
    if ((SECONDS >= u13_deadline)); then
      printf 'TIMEOUT: Godot exceeded %s seconds.\n' "$u13_timeout_seconds" >>"$u13_log"
      kill -KILL "$u13_active_pid" 2>/dev/null || true
      wait "$u13_active_pid" 2>/dev/null || true
      u13_active_pid=""
      return 124
    fi
    sleep 0.1
  done
  wait "$u13_active_pid" || u13_exit=$?
  u13_active_pid=""
  return "$u13_exit"
}

# Check the shared helper directly so Godot reports its actual parse location,
# instead of burying the root cause under dependent preload/compile failures.
printf 'Checking U13EffectData.gd with Godot before running suites...\n'
u13_preflight_log="$u13_test_logs/preflight.log"
u13_status=0
u13_run_godot "$u13_preflight_log" --check-only \
  --script res://Scripts/Sim/U13EffectData.gd || u13_status=$?
cat -- "$u13_preflight_log"
if [[ $u13_status -ne 0 ]] || grep -Eq -- 'SCRIPT ERROR:|ERROR:' "$u13_preflight_log"; then
  printf 'FAILED PREFLIGHT: U13EffectData (exit %s). Suites were not started.\n' "$u13_status" >&2
  exit 1
fi

u13_runners=(
  U13RoundTimeline
  U13RoundRuntime
  U13LordPowerDeclaration
  U13PendingEffects
  U13PersistentEffects
  U13EffectsIntegration
)
u13_markers=(
  'U13 round timeline failures: 0'
  'U13 round runtime failures: 0'
  'U13 Lord declaration failures: 0'
  'U13 pending effects failures: 0'
  'U13 persistent effects failures: 0'
  'U13 effects integration failures: 0'
)
u13_failed=0
for u13_index in "${!u13_runners[@]}"; do
  u13_runner=${u13_runners[$u13_index]}
  u13_log="$u13_test_logs/$u13_runner.log"
  u13_status=0
  printf 'Running %s (timeout %ss)...\n' "$u13_runner" "$u13_timeout_seconds"
  u13_run_godot "$u13_log" \
    --script "res://Scripts/Sim/${u13_runner}TestRunner.gd" || u13_status=$?
  cat -- "$u13_log"
  # Godot can log a script failure without a useful nonzero process exit.
  # Require the expected completion footer and reject engine/test errors.
  if [[ $u13_status -ne 0 ]] \
    || ! grep -Fq -- "${u13_markers[$u13_index]}" "$u13_log" \
    || grep -Eq -- 'SCRIPT ERROR:|ERROR:|^FAIL[[:space:]]' "$u13_log"; then
    printf 'FAILED RUNNER: %s (exit %s)\n' "$u13_runner" "$u13_status" >&2
    u13_failed=$((u13_failed + 1))
    printf 'Stopping after the first failed suite; dependent suites were not run.\n' >&2
    exit 1
  fi
done
printf 'U13 foundation runners passed: %s/%s\n' \
  "$((${#u13_runners[@]} - u13_failed))" "${#u13_runners[@]}"
[[ $u13_failed -eq 0 ]]
