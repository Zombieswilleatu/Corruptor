#!/usr/bin/env bash
set -euo pipefail
music_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
music_exe="${1:-${GODOT_BIN:-}}"
if [[ -z "$music_exe" ]]; then
  music_folder="$HOME/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe"
  if [[ -f "$music_folder" ]]; then
    music_exe="$music_folder"
  elif [[ -d "$music_folder" ]]; then
    music_exe=$(find "$music_folder" -maxdepth 2 -type f -iname '*godot*.exe' ! -iname '*console*' -print -quit)
  fi
fi
if [[ -z "$music_exe" ]]; then
  for music_command in godot godot4; do
    if command -v "$music_command" >/dev/null 2>&1; then
      music_exe=$(command -v "$music_command")
      break
    fi
  done
fi
if [[ -z "$music_exe" ]]; then
  echo 'Pass your Godot executable: bash Scripts/Sim/run_u13_music_lab.sh "$godot_exe"' >&2
  exit 1
fi
echo 'Opening native Godot Music Lab.'
exec "$music_exe" --path "$music_root" --windowed --resolution 1440x960 \
  --rendering-method gl_compatibility res://Prototype/U13/U13MusicLab.tscn
