#!/usr/bin/env bash
set -euo pipefail
encounter_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
encounter_exe="${1:-${GODOT_BIN:-}}"
if [[ -z "$encounter_exe" ]]; then
  encounter_folder="$HOME/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe"
  if [[ -d "$encounter_folder" ]]; then
    encounter_exe=$(find "$encounter_folder" -maxdepth 2 -type f -iname '*godot*.exe' ! -iname '*console*' -print -quit)
  fi
fi
if [[ -z "$encounter_exe" ]]; then
  for encounter_candidate in godot godot4; do
    if command -v "$encounter_candidate" >/dev/null 2>&1; then encounter_exe="$encounter_candidate"; break; fi
  done
fi
if [[ -z "$encounter_exe" ]]; then
  echo 'Pass Godot: bash Scripts/Sim/run_u13_encounter.sh "$godot_exe"' >&2
  exit 1
fi
if [[ "${2:-}" == "--test" ]]; then
  exec "$encounter_exe" --headless --path "$encounter_root" --script res://Scripts/Sim/U13EncounterTestRunner.gd
fi
echo 'Opening The Crossing: isolated Ascent encounter playtest.'
exec "$encounter_exe" --path "$encounter_root" --windowed --resolution 1440x810 --rendering-method gl_compatibility res://Prototype/U13/Encounters/U13EncounterLab.tscn
