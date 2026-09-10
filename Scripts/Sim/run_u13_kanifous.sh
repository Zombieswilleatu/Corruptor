#!/usr/bin/env bash
# Run Kanifous's focused integration checks, then open the main U13 board.
set -euo pipefail
export U13_TEST_TIMEOUT_SECONDS=${U13_TEST_TIMEOUT_SECONDS:-90}
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable\n' "$0" >&2
  exit 2
fi
u13_kanifous_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bash "$u13_kanifous_script_dir/run_u13_foundation_tests.sh" "$1" --kanifous
exec bash "$u13_kanifous_script_dir/run_u13_board.sh" "$1"
