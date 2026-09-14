#!/usr/bin/env bash
# Focused acceptance for the public Guards and Action Forecast.
set -euo pipefail
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable\n' "$0" >&2
  exit 2
fi
u13_forecast_exe=$1
u13_forecast_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_forecast_revision=$(git -C "$u13_forecast_root" rev-parse HEAD)
mkdir -p -- "$HOME/Downloads"
u13_forecast_reports=$(mktemp -d "$HOME/Downloads/u13-action-forecast-${u13_forecast_revision:0:8}-XXXXXX")
u13_forecast_pid=""
cleanup() {
  local result=$?
  if [[ -n "$u13_forecast_pid" ]]; then
    kill -KILL "$u13_forecast_pid" 2>/dev/null || true
    wait "$u13_forecast_pid" 2>/dev/null || true
  fi
  printf 'revision=%s\nexit_status=%s\n' "$u13_forecast_revision" "$result" >"$u13_forecast_reports/run-status.txt"
  bash "$u13_forecast_root/Scripts/Sim/package_u13_reports.sh" "$u13_forecast_reports" || true
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
"$u13_forecast_exe" --version >"$u13_forecast_reports/version.log" 2>&1
if ! grep -Eq '^4\.7\.2\.stable([.[:space:]]|$)' "$u13_forecast_reports/version.log"; then
  printf 'Requires Godot 4.7.2 stable.\n' >&2
  exit 1
fi
git -C "$u13_forecast_root" diff HEAD >"$u13_forecast_reports/worktree.diff"
printf 'Action Forecast reports: %s\n' "$u13_forecast_reports"
for u13_forecast_suite in U13ActionForecast U13GuardWork U13ActionFlowBoard U13PlayableBoard; do
  printf 'Checking %s...\n' "$u13_forecast_suite"
  "$u13_forecast_exe" --headless --path "$u13_forecast_root" --script "Scripts/Sim/${u13_forecast_suite}TestRunner.gd" >"$u13_forecast_reports/$u13_forecast_suite.log" 2>&1 &
  u13_forecast_pid=$!
  u13_forecast_deadline=$((SECONDS + 300))
  u13_forecast_heartbeat=$((SECONDS + 15))
  while kill -0 "$u13_forecast_pid" 2>/dev/null; do
    if ((SECONDS >= u13_forecast_deadline)); then
      printf 'FAIL suite watchdog (300 seconds)\n' >&2
      exit 1
    fi
    if ((SECONDS >= u13_forecast_heartbeat)); then
      tail -n 1 -- "$u13_forecast_reports/$u13_forecast_suite.log"
      u13_forecast_heartbeat=$((SECONDS + 15))
    fi
    sleep 0.2
  done
  u13_forecast_status=0
  wait "$u13_forecast_pid" || u13_forecast_status=$?
  u13_forecast_pid=""
  if ((u13_forecast_status != 0)) || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_forecast_reports/$u13_forecast_suite.log" || ! grep -Eq 'failures: 0$' "$u13_forecast_reports/$u13_forecast_suite.log"; then
    tail -n 40 -- "$u13_forecast_reports/$u13_forecast_suite.log"
    exit 1
  fi
  tail -n 1 -- "$u13_forecast_reports/$u13_forecast_suite.log"
done
printf 'Action Forecast checks passed. Upload the report ZIP.\n'
