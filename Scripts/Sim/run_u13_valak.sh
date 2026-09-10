#!/usr/bin/env bash
# Run Valak's focused integration checks, then open the main U13 board.
set -euo pipefail
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable\n' "$0" >&2
  exit 2
fi
u13_valak_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bash "$u13_valak_script_dir/run_u13_foundation_tests.sh" "$1" --valak
exec bash "$u13_valak_script_dir/run_u13_board.sh" "$1"
