#!/usr/bin/env bash
# Opens the explicit range/goal-advance experiment directly.
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
printf 'VULTURE PREVIEW: Vulture range 900; tower range 1125.\nGoal-distance advance/fire starts ON; toggle it to reset the same seed.\nRun log: %s\n' "$u13_preview_log"
"$u13_preview_exe" --path "$u13_preview_root" --windowed --resolution 1440x900 \
  --rendering-method gl_compatibility res://Prototype/U13/U13VulturePreview.tscn 2>&1 | tee "$u13_preview_log"
