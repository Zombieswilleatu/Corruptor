#!/usr/bin/env bash
# Focused Snare/Conduit legality gate, optionally replaying one saved slow round.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! -x "$1" || ( $# -eq 2 && ! -f "$2" ) ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable [checkpoint.json]\n' "$0" >&2
  exit 2
fi
u13_exe=$1
u13_checkpoint=${2:-}
u13_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_timeout=${U13_TEST_TIMEOUT_SECONDS:-180}
if [[ ! "$u13_timeout" =~ ^[1-9][0-9]{0,3}$ ]]; then
  printf 'U13_TEST_TIMEOUT_SECONDS must be a positive integer, maximum 9999.\n' >&2
  exit 2
fi
mkdir -p -- "$HOME/Downloads"
u13_reports=$(mktemp -d "$HOME/Downloads/u13-snare-planning-XXXXXX")
u13_pid=""
cleanup() {
  if [[ -n "$u13_pid" ]]; then
    kill -KILL "$u13_pid" 2>/dev/null || true
    wait "$u13_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
run_godot() {
  local log=$1
  shift
  local deadline=$((SECONDS + u13_timeout))
  local heartbeat=$((SECONDS + 15))
  local status=0
  "$u13_exe" --headless --path "$u13_root" "$@" >"$log" 2>&1 &
  u13_pid=$!
  while kill -0 "$u13_pid" 2>/dev/null; do
    if ((SECONDS >= deadline)); then
      printf 'TIMEOUT: exceeded %ss.\n' "$u13_timeout" >>"$log"
      kill -KILL "$u13_pid" 2>/dev/null || true
      wait "$u13_pid" 2>/dev/null || true
      u13_pid=""
      return 124
    fi
    if ((SECONDS >= heartbeat)); then
      tail -n 1 -- "$log"
      heartbeat=$((SECONDS + 15))
    fi
    sleep 0.2
  done
  wait "$u13_pid" || status=$?
  u13_pid=""
  return "$status"
}
printf 'Logs and profile: %s\n' "$u13_reports"
run_godot "$u13_reports/version.log" --version
if ! grep -Eq '^4\.7\.2\.stable([.[:space:]]|$)' "$u13_reports/version.log"; then
  cat -- "$u13_reports/version.log"
  printf 'This gate requires Godot 4.7.2 stable.\n' >&2
  exit 1
fi
u13_status=0
run_godot "$u13_reports/regression.log" --script Scripts/Sim/U13SnarePlanningTestRunner.gd || u13_status=$?
cat -- "$u13_reports/regression.log"
if [[ $u13_status -ne 0 ]] || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_reports/regression.log" || ! grep -q '^U13 Snare planning failures: 0$' "$u13_reports/regression.log"; then
  exit 1
fi
if [[ -n "$u13_checkpoint" ]]; then
  u13_status=0
  run_godot "$u13_reports/checkpoint.log" --script Scripts/Sim/U13CheckpointProfileRunner.gd -- \
    "--checkpoint=$u13_checkpoint" "--output=$u13_reports/profile.json" --compare-reference || u13_status=$?
  cat -- "$u13_reports/checkpoint.log"
  if [[ $u13_status -ne 0 ]] || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_reports/checkpoint.log" || ! grep -q '^U13 checkpoint profile failures: 0$' "$u13_reports/checkpoint.log"; then
    exit 1
  fi
fi
printf 'U13 Snare planning gate passed.\n'
