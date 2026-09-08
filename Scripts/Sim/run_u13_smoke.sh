#!/usr/bin/env bash
# Explicit scene launch: does not change project.godot or the U12 main scene.
set -uo pipefail
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable\n' "$0" >&2
  exit 2
fi
u13_smoke_exe=$1
u13_smoke_project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
exec "$u13_smoke_exe" --path "$u13_smoke_project" --windowed --resolution 1440x960 \
  --rendering-method gl_compatibility res://Prototype/U13/U13Smoke.tscn
