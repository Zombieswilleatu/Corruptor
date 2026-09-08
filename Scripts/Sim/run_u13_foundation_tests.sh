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
trap 'rm -rf -- "$u13_test_logs"' EXIT

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
  "$godot_u13_exe" --headless --path "$u13_project_dir" \
    --script "res://Scripts/Sim/${u13_runner}TestRunner.gd" >"$u13_log" 2>&1 || u13_status=$?
  cat -- "$u13_log"
  # Godot can log a script failure without a useful nonzero process exit.
  # Require the expected completion footer and reject engine/test errors.
  if [[ $u13_status -ne 0 ]] \
    || ! grep -Fq -- "${u13_markers[$u13_index]}" "$u13_log" \
    || grep -Eq -- 'SCRIPT ERROR:|ERROR:|^FAIL[[:space:]]' "$u13_log"; then
    printf 'FAILED RUNNER: %s (exit %s)\n' "$u13_runner" "$u13_status" >&2
    u13_failed=$((u13_failed + 1))
  fi
done
printf 'U13 foundation runners passed: %s/%s\n' \
  "$((${#u13_runners[@]} - u13_failed))" "${#u13_runners[@]}"
[[ $u13_failed -eq 0 ]]
