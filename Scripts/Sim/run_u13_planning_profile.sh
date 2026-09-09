#!/usr/bin/env bash
# Compare unchanged bot decisions/domains and timings, one Lord per process.
set -uo pipefail
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s GODOT\n' "$0" >&2
  exit 2
fi
u13_exe=$1
u13_project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
u13_output_root=${U13_PLANNING_LOG_DIR:-$HOME/Downloads}
mkdir -p -- "$u13_output_root" || exit 2
u13_output=$(mktemp -d "$u13_output_root/u13-planning-XXXXXX") || exit 2
u13_pid=""
u13_cleanup() {
  if [[ -n "$u13_pid" ]]; then
    kill -KILL "$u13_pid" 2>/dev/null || true
    wait "$u13_pid" 2>/dev/null || true
  fi
}
trap u13_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
u13_run() {
  local label=$1
  shift
  local log=$u13_output/$label.log
  local partial=$u13_output/$label.json.partial
  local deadline=$((SECONDS + 300))
  local status=0
  local next_update=$((SECONDS + 15))
  "$u13_exe" --headless --path "$u13_project" --script res://Scripts/Sim/U13PlanningProfileRunner.gd -- "$@" "--output=$partial" >"$log" 2>&1 &
  u13_pid=$!
  while kill -0 "$u13_pid" 2>/dev/null; do
    if ((SECONDS >= deadline)); then
      printf 'TIMEOUT: planning profile shard exceeded 300 seconds.\n' >>"$log"
      kill -KILL "$u13_pid" 2>/dev/null || true
      wait "$u13_pid" 2>/dev/null || true
      u13_pid=""
      status=124
      break
    fi
    if ((SECONDS >= next_update)); then
      printf 'Still running %s; progress: %s\n' "$label" "$log"
      next_update=$((SECONDS + 15))
    fi
    sleep 0.1
  done
  if [[ -n "$u13_pid" ]]; then
    wait "$u13_pid" || status=$?
    u13_pid=""
  fi
  cat -- "$log"
  if ((status != 0)) || [[ ! -s "$partial" ]] || ! grep -Fxq 'U13 planning profile completed: OK' "$log" || grep -Eq 'SCRIPT ERROR:|ERROR:|^FAIL' "$log"; then
    printf 'FAILED PLANNING %s (exit %s). Reports/logs preserved: %s\n' "$label" "$status" "$u13_output" >&2
    return 1
  fi
  mv -- "$partial" "$u13_output/$label.json" || return 1
}
printf 'Planning profile: four Lords, rounds 1 and 2, optimized/reference ABBA comparison. Limit 300s per shard.\nReports: %s\n' "$u13_output"
for u13_lord in Gremory Deimos Humbaba Kalligan; do
  u13_run "$u13_lord" "--lord=$u13_lord" || exit 1
done
printf 'U13 planning profiles passed: 4/4. Share the four JSON files from: %s\n' "$u13_output"
