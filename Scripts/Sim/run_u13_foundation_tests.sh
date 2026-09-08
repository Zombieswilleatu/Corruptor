#!/usr/bin/env bash
# Usage: bash Scripts/Sim/run_u13_foundation_tests.sh /path/to/godot_console.exe
# Successful logs are temporary; failure logs are preserved in Downloads.
set -uo pipefail

if [[ $# -lt 1 || $# -gt 2 || ( $# -eq 2 && "$2" != --board && "$2" != --construction && "$2" != --castle-rout && "$2" != --interaction && "$2" != --humbaba ) ]]; then
  printf 'Usage: bash %s /path/to/Godot_console_executable [--board|--construction|--castle-rout|--interaction|--humbaba]\n' "$0" >&2
  exit 2
fi
godot_u13_exe=$1
u13_board_only=false
u13_construction_only=false
u13_castle_rout_only=false
u13_interaction_only=false
u13_humbaba_only=false
if [[ ${2:-} == --humbaba ]]; then
  u13_humbaba_only=true
fi
if [[ ${2:-} == --interaction ]]; then
  u13_interaction_only=true
fi
if [[ ${2:-} == --castle-rout ]]; then
  u13_castle_rout_only=true
fi
if [[ ${2:-} == --construction ]]; then
  u13_construction_only=true
fi
if [[ ${2:-} == --board ]]; then
  u13_board_only=true
fi
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
  local u13_cleanup_status=$?
  if [[ -n "$u13_active_pid" ]]; then
    kill -KILL "$u13_active_pid" 2>/dev/null || true
    wait "$u13_active_pid" 2>/dev/null || true
  fi
  if [[ $u13_cleanup_status -ne 0 ]]; then
    local u13_failure_dir=${U13_TEST_LOG_DIR:-$HOME/Downloads}
    local u13_failure_log
    if mkdir -p -- "$u13_failure_dir" && u13_failure_log=$(mktemp "$u13_failure_dir/u13-foundation-failure-XXXXXX.log"); then
      printf 'U13 wrapper exit: %s; board_only: %s; construction_only: %s; castle_rout_only: %s; timeout: %ss\n' \
        "$u13_cleanup_status" "$u13_board_only" "$u13_construction_only" "$u13_castle_rout_only" "$u13_timeout_seconds" >"$u13_failure_log"
      for u13_saved_log in "$u13_test_logs"/*.log; do
        [[ -f "$u13_saved_log" ]] || continue
        printf '\nLOG: %s\n' "${u13_saved_log##*/}" >>"$u13_failure_log"
        cat -- "$u13_saved_log" >>"$u13_failure_log"
      done
      printf 'Failure log saved: %s\n' "$u13_failure_log" >&2
    else
      printf 'Could not save failure log; preserving logs at %s\n' "$u13_test_logs" >&2
      return
    fi
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

# Reject accidental runs with the old 4.2 executable. Accept mono/non-mono
# builds of the pinned stable runtime, while retaining its full version output.
u13_version_log="$u13_test_logs/version.log"
u13_status=0
u13_run_godot "$u13_version_log" --version || u13_status=$?
cat -- "$u13_version_log"
if [[ $u13_status -ne 0 ]] || ! grep -Eq -- '^4\.7\.2\.stable([.[:space:]]|$)' "$u13_version_log"; then
  printf 'U13 requires Godot 4.7.2 stable. Pass the 4.7.2 executable to this wrapper.\n' >&2
  exit 1
fi

# Check dependencies directly so the compiler can report the actual source file.
# Godot 4.7.2 is the authoritative U13 runtime; this wrapper is not a migration test.
u13_check_script() {
  local u13_script=$1
  printf 'Checking %s with Godot before running suites...\n' "$u13_script"
  u13_preflight_log="$u13_test_logs/preflight.log"
  u13_status=0
  u13_run_godot "$u13_preflight_log" --check-only --script "$u13_script" || u13_status=$?
  cat -- "$u13_preflight_log"
  if [[ $u13_status -ne 0 ]] || grep -Eq -- 'SCRIPT ERROR:|ERROR:' "$u13_preflight_log"; then
    printf 'FAILED PREFLIGHT: %s (exit %s). Suites were not started.\n' "$u13_script" "$u13_status" >&2
    exit 1
  fi
}
for u13_dependency in U13EffectData U13Cooldowns U13KeyedRng U13EntityIds U13EventLog U13CardZones U13BattleEvents U13CastleSlots U13Rout U13Structures U13Legality U13Match U13MarchingBuffer U13LaneAuras U13Marching U13Combat U13Construction U13ConstructionCandidates U13Gremory U13Deimos U13LordStats U13Humbaba U13HumbabaCandidates U13HumbabaScenario U13SmokeSession U13DeimosCandidates U13CoreScenario U13GremoryCandidates U13RandomLegal U13FrequencyTelemetry U13RandomBatch U13BoardSession U13LoadoutBoardSession U13DenseBoardSession; do
  u13_check_script "res://Scripts/Sim/${u13_dependency}.gd"
done
for u13_dependency in U13SmokePlayback U13SmokeBoard U13Smoke U13BoardTextures U13ArtilleryView U13BoardHand U13BoardLanes U13LayoutCard U13PlayerBoard U13BoardHeader U13DomainRow U13ActionZone U13PhasePrompt U13BoardJob U13TutorialPreferences U13TutorialPopup U13LoadoutPicker U13Board U13OrderPreview U13DirectBoard; do
  u13_check_script "res://Prototype/U13/${u13_dependency}.gd"
done

u13_runners=(
  U13RoundTimeline
  U13RoundRuntime
  U13LordPowerDeclaration
  U13PendingEffects
  U13PersistentEffects
  U13EffectsIntegration
  U13Cooldowns
  U13Determinism
  U13Match
  U13Gremory
  U13RandomLegal
  U13Deimos
  U13Humbaba
  U13HumbabaIntegration
  U13HumbabaRandom
  U13LaneAuras
  U13Breath
  U13CastleLoadout
  U13Rout
  U13Construction
  U13ConstructionRandom
  U13SpatialMarching
  U13MarchingIntegration
  U13Smoke
  U13BoardModel
  U13Board
  U13DenseBoard
  U13LoadoutBoard
  U13Hunt
  U13DirectBoard
)
u13_markers=(
  'U13 round timeline failures: 0'
  'U13 round runtime failures: 0'
  'U13 Lord declaration failures: 0'
  'U13 pending effects failures: 0'
  'U13 persistent effects failures: 0'
  'U13 effects integration failures: 0'
  'U13 cooldowns failures: 0'
  'U13 determinism and identity failures: 0'
  'U13 match foundation failures: 0'
  'U13 Gremory failures: 0'
  'U13 random-legal failures: 0'
  'U13 Deimos failures: 0'
  'U13 Humbaba failures: 0'
  'U13 Humbaba integration failures: 0'
  'U13 Humbaba random failures: 0'
  'U13 lane auras failures: 0'
  'U13 Breath of Life failures: 0'
  'U13 Castle loadout failures: 0'
  'U13 Rout failures: 0'
  'U13 Construction failures: 0'
  'U13 Construction random failures: 0'
  'U13 spatial Marching failures: 0'
  'U13 Marching integration failures: 0'
  'U13 smoke scene failures: 0'
  'U13 board model failures: 0'
  'U13 board failures: 0'
  'U13 dense board failures: 0'
  'U13 loadout board failures: 0'
  'U13 Hunt failures: 0'
  'U13 direct board failures: 0'
)
if [[ $u13_board_only == true ]]; then
  u13_runners=(U13BoardModel U13Board U13DenseBoard U13LoadoutBoard U13Hunt U13DirectBoard)
  u13_markers=('U13 board model failures: 0' 'U13 board failures: 0' 'U13 dense board failures: 0' 'U13 loadout board failures: 0' 'U13 Hunt failures: 0' 'U13 direct board failures: 0')
fi
if [[ $u13_construction_only == true ]]; then
  u13_runners=(U13Construction U13ConstructionRandom)
  u13_markers=('U13 Construction failures: 0' 'U13 Construction random failures: 0')
fi
if [[ $u13_castle_rout_only == true ]]; then
  u13_runners=(U13Match U13CastleLoadout U13Rout U13Deimos U13Construction U13ConstructionRandom U13SpatialMarching)
  u13_markers=('U13 match foundation failures: 0' 'U13 Castle loadout failures: 0' 'U13 Rout failures: 0' 'U13 Deimos failures: 0' 'U13 Construction failures: 0' 'U13 Construction random failures: 0' 'U13 spatial Marching failures: 0')
fi
if [[ $u13_interaction_only == true ]]; then
  u13_runners=(U13Hunt U13DirectBoard)
  u13_markers=('U13 Hunt failures: 0' 'U13 direct board failures: 0')
fi
if [[ $u13_humbaba_only == true ]]; then
  u13_runners=(U13LaneAuras U13Breath U13Humbaba U13HumbabaIntegration U13HumbabaRandom U13Rout U13SpatialMarching U13Hunt U13Deimos U13CastleLoadout)
  u13_markers=('U13 lane auras failures: 0' 'U13 Breath of Life failures: 0' 'U13 Humbaba failures: 0' 'U13 Humbaba integration failures: 0' 'U13 Humbaba random failures: 0' 'U13 Rout failures: 0' 'U13 spatial Marching failures: 0' 'U13 Hunt failures: 0' 'U13 Deimos failures: 0' 'U13 Castle loadout failures: 0')
fi
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
u13_suite_label=foundation
if [[ $u13_humbaba_only == true ]]; then
  u13_suite_label=Humbaba
fi
if [[ $u13_interaction_only == true ]]; then
  u13_suite_label=interaction
fi
if [[ $u13_board_only == true ]]; then
  u13_suite_label=board
fi
if [[ $u13_construction_only == true ]]; then
  u13_suite_label=construction
fi
if [[ $u13_castle_rout_only == true ]]; then
  u13_suite_label=castle-rout
fi
printf 'U13 %s runners passed: %s/%s\n' "$u13_suite_label" \
  "$((${#u13_runners[@]} - u13_failed))" "${#u13_runners[@]}"
[[ $u13_failed -eq 0 ]]
