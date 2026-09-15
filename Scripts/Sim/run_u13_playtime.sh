#!/usr/bin/env bash
# Focused acceptance for non-authoritative playtime and playable flow.
set -euo pipefail
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable\n' "$0" >&2
  exit 2
fi
u13_playtime_exe=$1
u13_playtime_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_playtime_revision=$(git -C "$u13_playtime_root" rev-parse HEAD)
mkdir -p -- "$HOME/Downloads"
u13_playtime_reports=$(mktemp -d "$HOME/Downloads/u13-playtime-${u13_playtime_revision:0:8}-XXXXXX")
u13_playtime_pid=""
cleanup() {
  local result=$?
  if [[ -n "$u13_playtime_pid" ]]; then
    kill -KILL "$u13_playtime_pid" 2>/dev/null || true
    wait "$u13_playtime_pid" 2>/dev/null || true
  fi
  printf 'revision=%s\nexit_status=%s\n' "$u13_playtime_revision" "$result" >"$u13_playtime_reports/run-status.txt"
  bash "$u13_playtime_root/Scripts/Sim/package_u13_reports.sh" "$u13_playtime_reports" || true
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
"$u13_playtime_exe" --version >"$u13_playtime_reports/version.log" 2>&1
if ! grep -Eq '^4\.7\.2\.stable([.[:space:]]|$)' "$u13_playtime_reports/version.log"; then
  printf 'Requires Godot 4.7.2 stable.\n' >&2
  exit 1
fi
git -C "$u13_playtime_root" diff HEAD >"$u13_playtime_reports/worktree.diff"
printf 'Playtime reports: %s\n' "$u13_playtime_reports"
for u13_playtime_suite in U13Playtime U13ActionFlowBoard U13PlayableBoard; do
  printf 'Checking %s...\n' "$u13_playtime_suite"
  "$u13_playtime_exe" --headless --path "$u13_playtime_root" --script "Scripts/Sim/${u13_playtime_suite}TestRunner.gd" >"$u13_playtime_reports/$u13_playtime_suite.log" 2>&1 &
  u13_playtime_pid=$!
  u13_playtime_deadline=$((SECONDS + 300))
  u13_playtime_heartbeat=$((SECONDS + 15))
  while kill -0 "$u13_playtime_pid" 2>/dev/null; do
    if ((SECONDS >= u13_playtime_deadline)); then
      printf 'FAIL suite watchdog (300 seconds)\n' >&2
      exit 1
    fi
    if ((SECONDS >= u13_playtime_heartbeat)); then
      tail -n 1 -- "$u13_playtime_reports/$u13_playtime_suite.log"
      u13_playtime_heartbeat=$((SECONDS + 15))
    fi
    sleep 0.2
  done
  u13_playtime_status=0
  wait "$u13_playtime_pid" || u13_playtime_status=$?
  u13_playtime_pid=""
  if ((u13_playtime_status != 0)) || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_playtime_reports/$u13_playtime_suite.log" || ! grep -Eq 'failures: 0$' "$u13_playtime_reports/$u13_playtime_suite.log"; then
    tail -n 40 -- "$u13_playtime_reports/$u13_playtime_suite.log"
    exit 1
  fi
  tail -n 1 -- "$u13_playtime_reports/$u13_playtime_suite.log"
done
printf 'Playtime checks passed. Upload the report ZIP.\n'
