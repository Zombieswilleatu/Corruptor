#!/usr/bin/env bash
# Opens the protected-staging/responsive-monster balance sandbox directly.
set -euo pipefail
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable\n' "$0" >&2
  exit 2
fi
u13_preview_exe=$1
u13_preview_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_preview_version=$("$u13_preview_exe" --version)
if [[ ! "$u13_preview_version" =~ ^4\.7\.2\.stable([.[:space:]]|$) ]]; then
  printf 'The Vulture preview requires Godot 4.7.2 stable. Found: %s\n' "$u13_preview_version" >&2
  exit 1
fi
mkdir -p -- "$HOME/Downloads/Corruptor/Logs"
u13_preview_log=$(mktemp "$HOME/Downloads/Corruptor/Logs/u13-vulture-preview-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.log")
printf 'MARCHER BALANCE · Dotra timed hide V16 (2026-09-19).\nSinodek targets the nearest visible enemy within 600; one 25%% attempt per active round.\nFyra: 30%% charm per hit; pink hearts show temporary control.\nTumler: 3 damage against marked prey, 2 against others (before Armor).\nKopita: pulses at the start and ~10 seconds; heals wounds, otherwise harms enemies.\nDotra: one guaranteed hide after his first 15 seconds on the field; full-speed hidden approach; 5-damage ambush exposes nearby enemies to +1 damage for one round.\n15 protected slots per side; newborns wait one round; pressure-aware bot releases.\nVulture range 400; tower 600; Vulture +1 damage vs Butchers.\nSame-seed seat swap; 0.5x / 1x / 2x / 3x / 5x playback.\nContinuous mode prepares the next interval during playback (default ON).\nGoal-distance advance/fire starts ON. Staging offers 15 / 12 / Off comparisons.\nRun log: %s\n' "$u13_preview_log"
"$u13_preview_exe" --path "$u13_preview_root" --windowed --resolution 1440x900 \
  --rendering-method gl_compatibility res://Prototype/U13/U13VulturePreview.tscn 2>&1 | tee "$u13_preview_log"
