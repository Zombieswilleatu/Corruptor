#!/usr/bin/env bash
# Standalone visual preview; no match or foundation suites.
set -uo pipefail
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable\n' "$0" >&2
  exit 2
fi
u13_scorch_preview_exe=$1
u13_scorch_preview_project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
exec "$u13_scorch_preview_exe" --path "$u13_scorch_preview_project" \
  --windowed --resolution 960x900 --rendering-method gl_compatibility \
  res://Prototype/U13/U13ScorchPreview.tscn
