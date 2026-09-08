#!/usr/bin/env bash
# Explicit scene launch: does not change project.godot or the U12 main scene.
set -uo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! -x "$1" || ( $# -eq 2 && "$2" != --dense ) ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable [--dense]\n' "$0" >&2
  exit 2
fi
u13_board_exe=$1
shift
u13_board_args=()
if [[ $# -eq 1 ]]; then
  u13_board_args=(-- --dense)
fi
u13_board_project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
exec "$u13_board_exe" --path "$u13_board_project" --windowed --resolution 1440x810 \
  --rendering-method gl_compatibility res://Prototype/U13/U13Board.tscn "${u13_board_args[@]}"
