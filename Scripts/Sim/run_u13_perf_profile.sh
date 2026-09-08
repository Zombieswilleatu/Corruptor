#!/usr/bin/env bash
# Standalone diagnostic: deliberately outside the foundation runner watchdog.
set -uo pipefail
if [[ $# -lt 1 ]]; then
  printf 'Usage: bash %s /path/to/Godot.exe [--counts=6,24,48] [--samples=3] [--rounds=3]\n' "$0" >&2
  exit 2
fi
u13_perf_exe=$1
shift
if [[ ! -x "$u13_perf_exe" ]]; then
  printf 'Godot executable not found: %s\n' "$u13_perf_exe" >&2
  exit 2
fi
u13_perf_project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
u13_perf_log=${U13_PERF_LOG:-"$HOME/Downloads/u13_perf_profile.log"}
mkdir -p -- "$(dirname -- "$u13_perf_log")" || exit 2
printf 'Profiling U13; log: %s\nNo 30-second cutoff. Progress is printed before each measurement.\n' "$u13_perf_log"
"$u13_perf_exe" --headless --path "$u13_perf_project" \
  --script res://Scripts/Sim/U13PerfProfileRunner.gd -- "$@" 2>&1 | tee "$u13_perf_log"
u13_perf_codes=("${PIPESTATUS[@]}")
if [[ ${u13_perf_codes[0]} -ne 0 || ${u13_perf_codes[1]} -ne 0 ]] \
  || grep -Eq 'SCRIPT ERROR:|ERROR:|PROFILE ERROR:|completed: FAILED' "$u13_perf_log" \
  || ! grep -Fq 'U13 performance profile completed: OK' "$u13_perf_log"; then
  printf 'Profile did not complete successfully; inspect %s\n' "$u13_perf_log" >&2
  exit 1
fi
printf 'Profile complete. Share %s\n' "$u13_perf_log"
