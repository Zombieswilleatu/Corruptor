#!/usr/bin/env bash
# Phase timings for the complete Kroni correctness suite; preserves its assertions.
set -euo pipefail
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s GODOT\n' "$0" >&2
  exit 2
fi
u13_profile_project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_profile_root=${U13_PROFILE_LOG_DIR:-$HOME/Downloads}
mkdir -p -- "$u13_profile_root"
u13_profile_log=$(mktemp "$u13_profile_root/u13-kroni-profile-XXXXXX.log")
printf 'Kroni phase profile. Log: %s\nNo suite deadline during measurement; Ctrl+C cancels.\n' "$u13_profile_log"
"$1" --headless --path "$u13_profile_project" --script res://Scripts/Sim/U13KroniTestRunner.gd -- --profile 2>&1 | tee "$u13_profile_log"
if ! grep -Fxq 'U13 Kroni failures: 0' "$u13_profile_log" || grep -Eq 'SCRIPT ERROR:|ERROR:|^FAIL' "$u13_profile_log"; then
  printf 'FAILED profile; inspect %s\n' "$u13_profile_log" >&2
  exit 1
fi
printf 'Profile passed. Share this log: %s\n' "$u13_profile_log"
