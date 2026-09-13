#!/usr/bin/env bash
# Human-versus-doctrine game. Leaves the U12 main scene unchanged.
set -euo pipefail
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable\n' "$0" >&2
  exit 2
fi
u13_play_exe=$1
u13_play_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_play_version=$("$u13_play_exe" --version)
if [[ ! "$u13_play_version" =~ ^4\.7\.2\.stable([.[:space:]]|$) ]]; then
  printf 'The playable U13 runner requires Godot 4.7.2 stable. Found: %s\n' "$u13_play_version" >&2
  exit 1
fi
mkdir -p -- "$HOME/Downloads"
u13_play_log=$(mktemp "$HOME/Downloads/u13-playable-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.log")
printf 'Launching the playable game against the doctrine bot.\nRun log: %s\nSaved games also go directly to Downloads.\n' "$u13_play_log"
"$u13_play_exe" --path "$u13_play_root" --windowed --resolution 1440x810 \
  --rendering-method gl_compatibility res://Prototype/U13/U13PlayableBoard.tscn 2>&1 | tee "$u13_play_log"
