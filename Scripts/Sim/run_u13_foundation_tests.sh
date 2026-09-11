#!/usr/bin/env bash
# Usage: bash Scripts/Sim/run_u13_foundation_tests.sh /path/to/godot_console.exe
# Successful logs are temporary; failure logs are preserved in Downloads.
set -uo pipefail

if [[ $# -lt 1 || $# -gt 2 || ( $# -eq 2 && "$2" != --board && "$2" != --construction && "$2" != --castle-rout && "$2" != --interaction && "$2" != --humbaba && "$2" != --kalligan && "$2" != --kalligan-board && "$2" != --marcher-feedback && "$2" != --alpha && "$2" != --planning && "$2" != --marching && "$2" != --breath && "$2" != --spatial && "$2" != --rout-visuals && "$2" != --orias-web && "$2" != --quickstart && "$2" != --gem-dagger && "$2" != --snare && "$2" != --orias && "$2" != --allegiance && "$2" != --odradek && "$2" != --kroni && "$2" != --valak && "$2" != --kanifous && "$2" != --game ) ]]; then
  printf 'Usage: bash %s /path/to/Godot_console_executable [--board|--construction|--castle-rout|--interaction|--humbaba|--kalligan|--kalligan-board|--marcher-feedback|--alpha|--planning|--marching|--breath|--spatial|--rout-visuals|--orias-web|--quickstart|--gem-dagger|--snare|--orias|--allegiance|--odradek|--kroni|--valak|--kanifous|--game]\n' "$0" >&2
  exit 2
fi
godot_u13_exe=$1
u13_board_only=false
u13_construction_only=false
u13_castle_rout_only=false
u13_interaction_only=false
u13_humbaba_only=false
u13_kalligan_only=false
u13_kalligan_board_only=false
u13_alpha_only=false
u13_planning_only=false
u13_marching_only=false
u13_odradek_only=false
if [[ ${2:-} == --odradek ]]; then
  u13_odradek_only=true
fi
u13_allegiance_only=false
if [[ ${2:-} == --allegiance ]]; then
  u13_allegiance_only=true
fi
u13_orias_only=false
if [[ ${2:-} == --orias ]]; then
  u13_orias_only=true
fi
u13_snare_only=false
if [[ ${2:-} == --snare ]]; then
  u13_snare_only=true
fi
u13_orias_web_only=false
u13_quickstart_only=false
u13_gem_dagger_only=false
if [[ ${2:-} == --orias-web ]]; then
  u13_orias_web_only=true
fi
if [[ ${2:-} == --quickstart ]]; then
  u13_quickstart_only=true
fi
if [[ ${2:-} == --gem-dagger ]]; then
  u13_gem_dagger_only=true
fi
u13_spatial_only=false
u13_rout_visuals_only=false
if [[ ${2:-} == --spatial ]]; then
  u13_spatial_only=true
fi
if [[ ${2:-} == --rout-visuals ]]; then
  u13_rout_visuals_only=true
fi
u13_breath_only=false
if [[ ${2:-} == --breath ]]; then
  u13_breath_only=true
fi
if [[ ${2:-} == --planning ]]; then
  u13_planning_only=true
fi
if [[ ${2:-} == --marching ]]; then
  u13_marching_only=true
fi
if [[ ${2:-} == --alpha ]]; then
  u13_alpha_only=true
fi
u13_feedback_only=false
if [[ ${2:-} == --marcher-feedback ]]; then
  u13_feedback_only=true
fi
if [[ ${2:-} == --kalligan-board ]]; then
  u13_kalligan_board_only=true
fi
if [[ ${2:-} == --kalligan ]]; then
  u13_kalligan_only=true
fi
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
for u13_dependency in U13EffectData U13SpatialSpace U13SpatialQueries U13SpatialFields U13Cooldowns U13KeyedRng U13EntityIds U13EventLog U13CardZones U13MarcherAllegiance U13BattleEvents U13CastleSlots U13Rout U13Structures U13Legality U13Match U13MarchingBuffer U13LaneAuras U13Marching U13Combat U13Construction U13ConstructionCandidates U13Gremory U13Deimos U13LordStats U13Humbaba U13HumbabaCandidates U13HumbabaScenario U13Hazards U13Kalligan U13KalliganCandidates U13KalliganScenario U13Resummoning U13GuardDeployment U13Orias U13OriasCandidates U13OriasScenario U13GuardTransfers U13DebugActions U13Odradek U13OdradekScenario U13SmokeSession U13DeimosCandidates U13CoreScenario U13GremoryCandidates U13RandomLegal U13FrequencyTelemetry U13RandomBatch U13AlphaScenario U13AlphaBatch U13BoardSession U13LoadoutBoardSession U13DenseBoardSession; do
  u13_check_script "res://Scripts/Sim/${u13_dependency}.gd"
done
for u13_dependency in U13SpatialInput U13WebVisuals U13WebPreview U13GemDaggerView U13RoutVisuals U13ScorchVisuals U13ScorchPreview U13MarcherFeedback U13SmokePlayback U13SmokeBoard U13Smoke U13BoardTextures U13ScorchPresentation U13BreathVisuals U13BreathPreview U13CastleArtwork U13ArtilleryView U13BoardHand U13BoardLanes U13LordRules U13LordCardPreview U13ParadoxVisual U13OdradekEffects U13DebugPanel U13LayoutCard U13PlayerBoard U13BoardHeader U13DomainRow U13ActionZone U13PhasePrompt U13BoardJob U13TutorialPreferences U13TutorialPopup U13LoadoutPicker U13Board U13OrderPreview U13DirectBoard U13WebPlacement U13OriasBoard U13OdradekBoard U13RedirectPlacement U13GemDaggerPreview; do
  u13_check_script "res://Prototype/U13/${u13_dependency}.gd"
done

u13_runners=(
  U13RoundTimeline
  U13RoundRuntime
  U13LordPowerDeclaration
  U13SpatialSpace
  U13SpatialQueries
  U13SpatialInput
  U13RoutVisuals
  U13PendingEffects
  U13PersistentEffects
  U13EffectsIntegration
  U13Cooldowns
  U13Determinism
  U13Match
  U13Gremory
  U13RandomLegal
  U13RandomLegalReplay
  U13Deimos
  U13Humbaba
  U13HumbabaIntegration
  U13HumbabaRandom
  U13LaneAuras
  U13Breath
  U13BreathLifetime1
  U13BreathLifetime2
  U13BreathLifetime3
  U13BreathLifetime4
  U13BreathLifetime5
  U13CastleLoadout
  U13Rout
  U13Construction
  U13ConstructionRandom
  U13ConstructionAuto
  U13PlanningLegality
  U13MarchingAudit
  U13Alpha
  U13AlphaReplay
  U13AlphaInteraction
  U13AlphaRout
  U13SpatialMarching
  U13SpatialReference6
  U13SpatialReference24
  U13SpatialReference48
  U13MarchingIntegration
  U13Smoke
  U13BoardModel
  U13Board
  U13DenseBoard
  U13LoadoutBoard
  U13Hunt
  U13DirectBoard
  U13ArtilleryTiming
  U13HumbabaBoardSession
  U13HumbabaBoard
  U13Hazards
  U13Kalligan
  U13KalliganIntegration
  U13KalliganRandom
  U13KalliganBoardSession
  U13KalliganBoard
  U13BreathVisuals
  U13MarcherFeedback
  U13MarcherFeedbackBoard
  U13ScorchVisuals
  U13OriasWeb
  U13OriasWebMotion
  U13OriasWebLifetime1
  U13OriasWebLifetime2
  U13OriasWebLifetime3
  U13OriasWebLifetime4
  U13WebVisuals
  U13Quickstart
  U13GemDagger
  U13GuardDeployment
  U13Snare
  U13SnareReplay1
  U13SnareReplay2
  U13SnareReplay3
  U13GuardRandom
  U13OriasPursuit
  U13OriasMark
  U13OriasResummon
  U13OriasBoard
  U13MarcherAllegiance
  U13Odradek
  U13OdradekBoard
  U13OdradekPowers
  U13OdradekCompleteBoard
  U13OdradekBot
  U13LordInspection
  U13DebugBoard
  U13OdradekVisual
  U13Kroni
  U13KroniBoard
  U13Valak
  U13ValakBoard
  U13Kanifous
  U13KanifousBoard
  U13GameEconomy
  U13OpeningEconomy
  U13Fracture
  U13GameConductor
  U13GameRandom
  U13GameDevelopment
  U13GamePlanCoverage
  U13CastleDefenses
  U13Stockpile
  U13GameMarket
  U13BloodConduit
  U13Sigils
  U13SigilBoard
)
u13_markers=(
  'U13 round timeline failures: 0'
  'U13 round runtime failures: 0'
  'U13 Lord declaration failures: 0'
  'U13 spatial space failures: 0'
  'U13 spatial queries failures: 0'
  'U13 spatial input failures: 0'
  'U13 Rout visuals failures: 0'
  'U13 pending effects failures: 0'
  'U13 persistent effects failures: 0'
  'U13 effects integration failures: 0'
  'U13 cooldowns failures: 0'
  'U13 determinism and identity failures: 0'
  'U13 match foundation failures: 0'
  'U13 Gremory failures: 0'
  'U13 random-legal failures: 0'
  'U13 random-legal replay failures: 0'
  'U13 Deimos failures: 0'
  'U13 Humbaba failures: 0'
  'U13 Humbaba integration failures: 0'
  'U13 Humbaba random failures: 0'
  'U13 lane auras failures: 0'
  'U13 Breath of Life failures: 0'
  'U13 Breath lifetime 1 failures: 0'
  'U13 Breath lifetime 2 failures: 0'
  'U13 Breath lifetime 3 failures: 0'
  'U13 Breath lifetime 4 failures: 0'
  'U13 Breath lifetime 5 failures: 0'
  'U13 Castle loadout failures: 0'
  'U13 Rout failures: 0'
  'U13 Construction failures: 0'
  'U13 Construction random failures: 0'
  'U13 automatic construction failures: 0'
  'U13 planning legality failures: 0'
  'U13 Marching audit failures: 0'
  'U13 alpha manifest failures: 0'
  'U13 alpha replay failures: 0'
  'U13 alpha Scorch Breath failures: 0'
  'U13 alpha Scorch Rout failures: 0'
  'U13 spatial Marching failures: 0'
  'U13 spatial reference 6 failures: 0'
  'U13 spatial reference 24 failures: 0'
  'U13 spatial reference 48 failures: 0'
  'U13 Marching integration failures: 0'
  'U13 smoke scene failures: 0'
  'U13 board model failures: 0'
  'U13 board failures: 0'
  'U13 dense board failures: 0'
  'U13 loadout board failures: 0'
  'U13 Hunt failures: 0'
  'U13 direct board failures: 0'
  'U13 artillery impact timing failures: 0'
  'U13 Humbaba board session failures: 0'
  'U13 Humbaba board failures: 0'
  'U13 hazards failures: 0'
  'U13 Kalligan failures: 0'
  'U13 Kalligan integration failures: 0'
  'U13 Kalligan random failures: 0'
  'U13 Kalligan board session failures: 0'
  'U13 Kalligan board failures: 0'
  'U13 Breath visuals failures: 0'
  'U13 Marcher feedback failures: 0'
  'U13 Marcher feedback board failures: 0'
  'U13 Scorch visuals failures: 0'
  'U13 Orias Web failures: 0'
  'U13 Orias Web motion failures: 0'
  'U13 Orias Web lifetime 1 failures: 0'
  'U13 Orias Web lifetime 2 failures: 0'
  'U13 Orias Web lifetime 3 failures: 0'
  'U13 Orias Web lifetime 4 failures: 0'
  'U13 Web visuals failures: 0'
  'U13 quickstart failures: 0'
  'U13 Gem Dagger visuals failures: 0'
  'U13 Guard deployment failures: 0'
  'U13 Snare failures: 0'
  'U13 Snare replay 1 failures: 0'
  'U13 Snare replay 2 failures: 0'
  'U13 Snare replay 3 failures: 0'
  'U13 Guard random failures: 0'
  'U13 Orias pursuit failures: 0'
  'U13 Orias Mark failures: 0'
  'U13 Orias resummon failures: 0'
  'U13 Orias board failures: 0'
  'U13 Marcher allegiance failures: 0'
  'U13 Odradek failures: 0'
  'U13 Odradek board failures: 0'
  'U13 Odradek powers failures: 0'
  'U13 Odradek complete board failures: 0'
  'U13 Odradek bot failures: 0'
  'U13 Lord inspection failures: 0'
  'U13 debug board failures: 0'
  'U13 Odradek visual failures: 0'
  'U13 Kroni failures: 0'
  'U13 Kroni board failures: 0'
  'U13 Valak failures: 0'
  'U13 Valak board failures: 0'
  'U13 Kanifous failures: 0'
  'U13 Kanifous board failures: 0'
  'U13 game economy failures: 0'
  'U13 opening economy failures: 0'
  'U13 Fracture failures: 0'
  'U13 game conductor failures: 0'
  'U13 game random failures: 0'
  'U13 game development failures: 0'
  'U13 game plan coverage failures: 0'
  'U13 castle defenses failures: 0'
  'U13 Stockpile failures: 0'
  'U13 game market failures: 0'
  'U13 Blood Conduit failures: 0'
  'U13 Sigils failures: 0'
  'U13 Sigil board failures: 0'
)
if [[ $u13_spatial_only == true ]]; then
  u13_runners=(U13LordPowerDeclaration U13SpatialSpace U13SpatialQueries U13SpatialInput U13Determinism)
  u13_markers=('U13 Lord declaration failures: 0' 'U13 spatial space failures: 0' 'U13 spatial queries failures: 0' 'U13 spatial input failures: 0' 'U13 determinism and identity failures: 0')
fi
if [[ $u13_rout_visuals_only == true ]]; then
  u13_runners=(U13RoutVisuals U13Rout)
  u13_markers=('U13 Rout visuals failures: 0' 'U13 Rout failures: 0')
fi
if [[ $u13_kalligan_only == true ]]; then
  u13_runners=(U13Hazards U13Kalligan U13KalliganIntegration U13KalliganRandom U13PendingEffects U13PersistentEffects U13Cooldowns U13Match U13LaneAuras U13Breath U13BreathLifetime1 U13BreathLifetime2 U13BreathLifetime3 U13BreathLifetime4 U13BreathLifetime5)
  u13_markers=('U13 hazards failures: 0' 'U13 Kalligan failures: 0' 'U13 Kalligan integration failures: 0' 'U13 Kalligan random failures: 0' 'U13 pending effects failures: 0' 'U13 persistent effects failures: 0' 'U13 cooldowns failures: 0' 'U13 match foundation failures: 0' 'U13 lane auras failures: 0' 'U13 Breath of Life failures: 0' 'U13 Breath lifetime 1 failures: 0' 'U13 Breath lifetime 2 failures: 0' 'U13 Breath lifetime 3 failures: 0' 'U13 Breath lifetime 4 failures: 0' 'U13 Breath lifetime 5 failures: 0')
fi
if [[ $u13_board_only == true ]]; then
  u13_runners=(U13MarcherFeedback U13MarcherFeedbackBoard U13ScorchVisuals U13KalliganBoardSession U13KalliganBoard U13BreathVisuals U13HumbabaBoardSession U13HumbabaBoard U13BoardModel U13Board U13DenseBoard U13LoadoutBoard U13Hunt U13DirectBoard)
  u13_markers=('U13 Marcher feedback failures: 0' 'U13 Marcher feedback board failures: 0' 'U13 Scorch visuals failures: 0' 'U13 Kalligan board session failures: 0' 'U13 Kalligan board failures: 0' 'U13 Breath visuals failures: 0' 'U13 Humbaba board session failures: 0' 'U13 Humbaba board failures: 0' 'U13 board model failures: 0' 'U13 board failures: 0' 'U13 dense board failures: 0' 'U13 loadout board failures: 0' 'U13 Hunt failures: 0' 'U13 direct board failures: 0')
fi
if [[ $u13_construction_only == true ]]; then
  u13_runners=(U13Construction U13ConstructionRandom U13ConstructionAuto)
  u13_markers=('U13 Construction failures: 0' 'U13 Construction random failures: 0' 'U13 automatic construction failures: 0')
fi
if [[ $u13_castle_rout_only == true ]]; then
  u13_runners=(U13Match U13CastleLoadout U13Rout U13Deimos U13Construction U13ConstructionRandom U13SpatialMarching U13SpatialReference6 U13SpatialReference24 U13SpatialReference48)
  u13_markers=('U13 match foundation failures: 0' 'U13 Castle loadout failures: 0' 'U13 Rout failures: 0' 'U13 Deimos failures: 0' 'U13 Construction failures: 0' 'U13 Construction random failures: 0' 'U13 spatial Marching failures: 0' 'U13 spatial reference 6 failures: 0' 'U13 spatial reference 24 failures: 0' 'U13 spatial reference 48 failures: 0')
fi
if [[ $u13_interaction_only == true ]]; then
  u13_runners=(U13Hunt U13DirectBoard U13ArtilleryTiming)
  u13_markers=('U13 Hunt failures: 0' 'U13 direct board failures: 0' 'U13 artillery impact timing failures: 0')
fi
if [[ $u13_humbaba_only == true ]]; then
  u13_runners=(U13LaneAuras U13Breath U13BreathLifetime1 U13BreathLifetime2 U13BreathLifetime3 U13BreathLifetime4 U13BreathLifetime5 U13Humbaba U13HumbabaIntegration U13HumbabaRandom U13Rout U13SpatialMarching U13SpatialReference6 U13SpatialReference24 U13SpatialReference48 U13Hunt U13Deimos U13CastleLoadout)
  u13_markers=('U13 lane auras failures: 0' 'U13 Breath of Life failures: 0' 'U13 Breath lifetime 1 failures: 0' 'U13 Breath lifetime 2 failures: 0' 'U13 Breath lifetime 3 failures: 0' 'U13 Breath lifetime 4 failures: 0' 'U13 Breath lifetime 5 failures: 0' 'U13 Humbaba failures: 0' 'U13 Humbaba integration failures: 0' 'U13 Humbaba random failures: 0' 'U13 Rout failures: 0' 'U13 spatial Marching failures: 0' 'U13 spatial reference 6 failures: 0' 'U13 spatial reference 24 failures: 0' 'U13 spatial reference 48 failures: 0' 'U13 Hunt failures: 0' 'U13 Deimos failures: 0' 'U13 Castle loadout failures: 0')
fi
if [[ $u13_kalligan_board_only == true ]]; then
  u13_runners=(U13KalliganBoardSession U13KalliganBoard U13BreathVisuals)
  u13_markers=('U13 Kalligan board session failures: 0' 'U13 Kalligan board failures: 0' 'U13 Breath visuals failures: 0')
fi
if [[ $u13_feedback_only == true ]]; then
  u13_runners=(U13MarcherFeedback U13MarcherFeedbackBoard U13ScorchVisuals U13Breath U13BreathLifetime1 U13BreathLifetime2 U13BreathLifetime3 U13BreathLifetime4 U13BreathLifetime5)
  u13_markers=('U13 Marcher feedback failures: 0' 'U13 Marcher feedback board failures: 0' 'U13 Scorch visuals failures: 0' 'U13 Breath of Life failures: 0' 'U13 Breath lifetime 1 failures: 0' 'U13 Breath lifetime 2 failures: 0' 'U13 Breath lifetime 3 failures: 0' 'U13 Breath lifetime 4 failures: 0' 'U13 Breath lifetime 5 failures: 0')
fi
if [[ $u13_alpha_only == true ]]; then
  u13_runners=(U13Alpha U13AlphaReplay U13AlphaInteraction U13AlphaRout U13LaneAuras U13ConstructionAuto U13Construction U13ConstructionRandom U13ScorchVisuals U13ArtilleryTiming U13DirectBoard)
  u13_markers=('U13 alpha manifest failures: 0' 'U13 alpha replay failures: 0' 'U13 alpha Scorch Breath failures: 0' 'U13 alpha Scorch Rout failures: 0' 'U13 lane auras failures: 0' 'U13 automatic construction failures: 0' 'U13 Construction failures: 0' 'U13 Construction random failures: 0' 'U13 Scorch visuals failures: 0' 'U13 artillery impact timing failures: 0' 'U13 direct board failures: 0')
fi
if [[ $u13_planning_only == true ]]; then
  u13_runners=(U13PlanningLegality U13Match U13RandomLegal U13RandomLegalReplay U13Construction U13ConstructionRandom U13AlphaReplay U13Hunt)
  u13_markers=('U13 planning legality failures: 0' 'U13 match foundation failures: 0' 'U13 random-legal failures: 0' 'U13 random-legal replay failures: 0' 'U13 Construction failures: 0' 'U13 Construction random failures: 0' 'U13 alpha replay failures: 0' 'U13 Hunt failures: 0')
fi
if [[ $u13_marching_only == true ]]; then
  u13_runners=(U13MarchingAudit U13SpatialMarching U13SpatialReference6 U13SpatialReference24 U13SpatialReference48 U13MarchingIntegration U13Rout U13LaneAuras U13Breath U13BreathLifetime1 U13BreathLifetime2 U13BreathLifetime3 U13BreathLifetime4 U13BreathLifetime5 U13Hazards U13Humbaba U13AlphaInteraction U13AlphaRout U13MarcherFeedback)
  u13_markers=('U13 Marching audit failures: 0' 'U13 spatial Marching failures: 0' 'U13 spatial reference 6 failures: 0' 'U13 spatial reference 24 failures: 0' 'U13 spatial reference 48 failures: 0' 'U13 Marching integration failures: 0' 'U13 Rout failures: 0' 'U13 lane auras failures: 0' 'U13 Breath of Life failures: 0' 'U13 Breath lifetime 1 failures: 0' 'U13 Breath lifetime 2 failures: 0' 'U13 Breath lifetime 3 failures: 0' 'U13 Breath lifetime 4 failures: 0' 'U13 Breath lifetime 5 failures: 0' 'U13 hazards failures: 0' 'U13 Humbaba failures: 0' 'U13 alpha Scorch Breath failures: 0' 'U13 alpha Scorch Rout failures: 0' 'U13 Marcher feedback failures: 0')
fi
if [[ $u13_breath_only == true ]]; then
  u13_runners=(U13Breath U13BreathLifetime1 U13BreathLifetime2 U13BreathLifetime3 U13BreathLifetime4 U13BreathLifetime5)
  u13_markers=('U13 Breath of Life failures: 0' 'U13 Breath lifetime 1 failures: 0' 'U13 Breath lifetime 2 failures: 0' 'U13 Breath lifetime 3 failures: 0' 'U13 Breath lifetime 4 failures: 0' 'U13 Breath lifetime 5 failures: 0')
fi
if [[ $u13_orias_web_only == true ]]; then
  u13_runners=(U13OriasWeb U13OriasWebMotion U13OriasWebLifetime1 U13OriasWebLifetime2 U13OriasWebLifetime3 U13OriasWebLifetime4 U13WebVisuals)
  u13_markers=('U13 Orias Web failures: 0' 'U13 Orias Web motion failures: 0' 'U13 Orias Web lifetime 1 failures: 0' 'U13 Orias Web lifetime 2 failures: 0' 'U13 Orias Web lifetime 3 failures: 0' 'U13 Orias Web lifetime 4 failures: 0' 'U13 Web visuals failures: 0')
fi
if [[ $u13_quickstart_only == true ]]; then
  u13_runners=(U13Quickstart)
  u13_markers=('U13 quickstart failures: 0')
fi
if [[ $u13_gem_dagger_only == true ]]; then
  u13_runners=(U13Gremory U13GemDagger)
  u13_markers=('U13 Gremory failures: 0' 'U13 Gem Dagger visuals failures: 0')
fi
if [[ $u13_snare_only == true ]]; then
  u13_runners=(U13GuardDeployment U13Snare U13SnareReplay1 U13SnareReplay2 U13SnareReplay3 U13GuardRandom)
  u13_markers=('U13 Guard deployment failures: 0' 'U13 Snare failures: 0' 'U13 Snare replay 1 failures: 0' 'U13 Snare replay 2 failures: 0' 'U13 Snare replay 3 failures: 0' 'U13 Guard random failures: 0')
fi
if [[ $u13_orias_only == true ]]; then
  u13_runners=(U13OriasPursuit U13OriasMark U13OriasResummon U13OriasBoard)
  u13_markers=('U13 Orias pursuit failures: 0' 'U13 Orias Mark failures: 0' 'U13 Orias resummon failures: 0' 'U13 Orias board failures: 0')
fi
if [[ $u13_odradek_only == true ]]; then
  u13_runners=(U13Odradek U13OdradekBoard U13OdradekPowers U13OdradekCompleteBoard U13OdradekBot U13LordInspection U13DebugBoard U13OdradekVisual U13MarcherAllegiance U13Match U13PlanningLegality)
  u13_markers=('U13 Odradek failures: 0' 'U13 Odradek board failures: 0' 'U13 Odradek powers failures: 0' 'U13 Odradek complete board failures: 0' 'U13 Odradek bot failures: 0' 'U13 Lord inspection failures: 0' 'U13 debug board failures: 0' 'U13 Odradek visual failures: 0' 'U13 Marcher allegiance failures: 0' 'U13 match foundation failures: 0' 'U13 planning legality failures: 0')
fi
if [[ $u13_allegiance_only == true ]]; then
  u13_runners=(U13MarcherAllegiance)
  u13_markers=('U13 Marcher allegiance failures: 0')
fi
if [[ ${2:-} == --kroni ]]; then
  u13_runners=(U13Kroni U13KroniBoard U13MarchingIntegration U13SpatialMarching U13LordInspection U13DirectBoard U13LoadoutBoard U13DebugBoard U13OdradekBoard)
  u13_markers=('U13 Kroni failures: 0' 'U13 Kroni board failures: 0' 'U13 Marching integration failures: 0' 'U13 spatial Marching failures: 0' 'U13 Lord inspection failures: 0' 'U13 direct board failures: 0' 'U13 loadout board failures: 0' 'U13 debug board failures: 0' 'U13 Odradek board failures: 0')
fi
if [[ ${2:-} == --valak ]]; then
  u13_runners=(U13Valak U13ValakBoard U13ValakVisual U13Kroni U13Odradek U13MarchingIntegration U13LaneAuras)
  u13_markers=('U13 Valak failures: 0' 'U13 Valak board failures: 0' 'U13 Valak visual checks: 23/23; failures: 0' 'U13 Kroni failures: 0' 'U13 Odradek failures: 0' 'U13 Marching integration failures: 0' 'U13 lane auras failures: 0')
fi
if [[ ${2:-} == --game ]]; then
  u13_runners=(U13GameEconomy U13OpeningEconomy U13Fracture U13GameConductor U13GameRandom U13GameDevelopment U13GamePlanCoverage U13CastleDefenses U13Stockpile U13GameMarket U13BloodConduit U13Sigils U13SigilBoard)
  u13_markers=('U13 game economy failures: 0' 'U13 opening economy failures: 0' 'U13 Fracture failures: 0' 'U13 game conductor failures: 0' 'U13 game random failures: 0' 'U13 game development failures: 0' 'U13 game plan coverage failures: 0' 'U13 castle defenses failures: 0' 'U13 Stockpile failures: 0' 'U13 game market failures: 0' 'U13 Blood Conduit failures: 0' 'U13 Sigils failures: 0' 'U13 Sigil board failures: 0')
fi
if [[ ${2:-} == --kanifous ]]; then
  u13_runners=(U13Kanifous U13KanifousBoard U13MarcherFeedback U13MarcherFeedbackBoard U13Valak U13Kroni U13MarchingIntegration)
  u13_markers=('U13 Kanifous failures: 0' 'U13 Kanifous board failures: 0' 'U13 Marcher feedback failures: 0' 'U13 Marcher feedback board failures: 0' 'U13 Valak failures: 0' 'U13 Kroni failures: 0' 'U13 Marching integration failures: 0')
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
if [[ $u13_odradek_only == true ]]; then
  u13_suite_label=odradek
elif [[ $u13_allegiance_only == true ]]; then
  u13_suite_label=allegiance
fi
if [[ $u13_orias_only == true ]]; then
  u13_suite_label=Orias
fi
if [[ $u13_snare_only == true ]]; then
  u13_suite_label=Snare
fi
if [[ $u13_orias_web_only == true ]]; then
  u13_suite_label=Orias-Web
fi
if [[ $u13_quickstart_only == true ]]; then
  u13_suite_label=quickstart
fi
if [[ $u13_gem_dagger_only == true ]]; then
  u13_suite_label=Gem-Dagger
fi
if [[ $u13_spatial_only == true ]]; then
  u13_suite_label=spatial
fi
if [[ $u13_rout_visuals_only == true ]]; then
  u13_suite_label=Rout-visuals
fi
if [[ $u13_breath_only == true ]]; then
  u13_suite_label=Breath
fi
if [[ $u13_planning_only == true ]]; then
  u13_suite_label=planning
fi
if [[ $u13_marching_only == true ]]; then
  u13_suite_label=Marching-audit
fi
if [[ $u13_alpha_only == true ]]; then
  u13_suite_label=alpha
fi
if [[ $u13_kalligan_board_only == true ]]; then
  u13_suite_label=Kalligan-board
fi
if [[ $u13_kalligan_only == true ]]; then
  u13_suite_label=Kalligan
fi
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
if [[ $u13_feedback_only == true ]]; then
  u13_suite_label=Marcher-feedback
fi
if [[ ${2:-} == --kroni ]]; then
  u13_suite_label=Kroni
fi
if [[ ${2:-} == --valak ]]; then
  u13_suite_label=Valak
fi
if [[ ${2:-} == --kanifous ]]; then
  u13_suite_label=Kanifous
fi
if [[ ${2:-} == --game ]]; then
  u13_suite_label="game foundation"
fi
printf 'U13 %s runners passed: %s/%s\n' "$u13_suite_label" \
  "$((${#u13_runners[@]} - u13_failed))" "${#u13_runners[@]}"
[[ $u13_failed -eq 0 ]]
