#!/usr/bin/env bash
# Compare lazy Random-Legal power selection with the frozen a0b774c policy.
set -euo pipefail
if [[ $# -lt 2 || $# -gt 3 || ! -x "$1" || ! -f "$2" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable checkpoint_json [report_directory]\n' "$0" >&2
  exit 2
fi
u13_perf_exe=$1
u13_perf_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_perf_commit=$(git -C "$u13_perf_root" rev-parse HEAD)
mkdir -p -- "$HOME/Downloads"
u13_perf_reports=${3:-$(mktemp -d "$HOME/Downloads/u13-random-planning-${u13_perf_commit:0:8}-XXXXXX")}
mkdir -p -- "$u13_perf_reports"
u13_perf_reports=$(cd -- "$u13_perf_reports" && pwd)
u13_perf_pid=""
cleanup() {
  local run_status=$?
  if [[ -n "$u13_perf_pid" ]]; then
    kill -KILL "$u13_perf_pid" 2>/dev/null || true
    wait "$u13_perf_pid" 2>/dev/null || true
  fi
  printf 'runner=random-planning\nrevision=%s\nexit_status=%s\n' "$u13_perf_commit" "$run_status" >"$u13_perf_reports/run-status.txt" || true
  if ! bash "$u13_perf_root/Scripts/Sim/package_u13_reports.sh" "$u13_perf_reports"; then
    printf 'Upload ZIP unavailable. Reports remain at: %s\n' "$u13_perf_reports" >&2
  fi
  exit "$run_status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
"$u13_perf_exe" --version >"$u13_perf_reports/version.log" 2>&1
if ! grep -Eq '^4\.7\.2\.stable([.[:space:]]|$)' "$u13_perf_reports/version.log"; then
  cat -- "$u13_perf_reports/version.log"
  printf 'This acceptance runner requires Godot 4.7.2 stable.\n' >&2
  exit 1
fi
printf '%s\n' "$u13_perf_commit" >"$u13_perf_reports/revision.txt"
git -C "$u13_perf_root" diff HEAD >"$u13_perf_reports/worktree.diff"
printf 'Random planning reports: %s\nChecking exact choices, Random-Legal plans, full rounds and saves...\n' "$u13_perf_reports"
for u13_perf_suite in U13RandomPlanningPerformance; do
"$u13_perf_exe" --headless --path "$u13_perf_root" --script "Scripts/Sim/${u13_perf_suite}TestRunner.gd" -- "--checkpoint=$2" "--output=$u13_perf_reports/comparison.json" >"$u13_perf_reports/${u13_perf_suite}.log" 2>&1 &
u13_perf_pid=$!
u13_perf_deadline=$((SECONDS + 1200))
u13_perf_heartbeat=$((SECONDS + 15))
while kill -0 "$u13_perf_pid" 2>/dev/null; do
  if ((SECONDS >= u13_perf_deadline)); then
    printf 'FAIL random planning watchdog (1200 seconds). Reports: %s\n' "$u13_perf_reports" >&2
    exit 1
  fi
  if ((SECONDS >= u13_perf_heartbeat)); then
    printf 'Elapsed %sm %ss\n' "$((SECONDS / 60))" "$((SECONDS % 60))"
    tail -n 1 -- "$u13_perf_reports/${u13_perf_suite}.log"
    u13_perf_heartbeat=$((SECONDS + 15))
  fi
  sleep 0.2
done
u13_perf_status=0
wait "$u13_perf_pid" || u13_perf_status=$?
u13_perf_pid=""
if ((u13_perf_status != 0)) || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_perf_reports/${u13_perf_suite}.log" || ! grep -Eq '^U13 random planning performance failures: 0$' "$u13_perf_reports/${u13_perf_suite}.log"; then
  tail -n 40 -- "$u13_perf_reports/${u13_perf_suite}.log"
  printf 'FAIL shared performance verification. Reports: %s\n' "$u13_perf_reports" >&2
  exit 1
fi
grep -E '^PROFILE |^U13 random planning performance failures:' "$u13_perf_reports/${u13_perf_suite}.log"
done
printf 'Random planning comparison passed. Reports: %s\n' "$u13_perf_reports"
