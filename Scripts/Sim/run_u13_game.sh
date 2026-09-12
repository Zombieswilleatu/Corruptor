#!/usr/bin/env bash
# Game-conductor gates: paid production opening, draws, Development/rites, and replay.
# Fast foundation gate including victory; run_u13_full_matches.sh is the long batch.
set -euo pipefail
export U13_TEST_TIMEOUT_SECONDS=${U13_TEST_TIMEOUT_SECONDS:-90}
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable\n' "$0" >&2
  exit 2
fi
u13_game_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec bash "$u13_game_script_dir/run_u13_foundation_tests.sh" "$1" --game
