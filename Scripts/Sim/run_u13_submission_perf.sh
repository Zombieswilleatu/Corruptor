#!/usr/bin/env bash
# Compare joint plan submission with the frozen e680d28 full-save transaction.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable [report_directory]\n' "$0" >&2
  exit 2
fi
u13_perf_exe=$1
u13_perf_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_perf_commit=$(git -C "$u13_perf_root" rev-parse HEAD)
mkdir -p -- "$HOME/Downloads"
u13_perf_reports=${2:-$(mktemp -d "$HOME/Downloads/u13-submission-${u13_perf_commit:0:8}-XXXXXX")}
mkdir -p -- "$u13_perf_reports"
u13_perf_reports=$(cd -- "$u13_perf_reports" && pwd)
u13_perf_pid=""
cleanup() {
  local run_status=$?
  if [[ -n "$u13_perf_pid" ]]; then
    kill -KILL "$u13_perf_pid" 2>/dev/null || true
    wait "$u13_perf_pid" 2>/dev/null || true
  fi
  printf 'runner=submission\nrevision=%s\nexit_status=%s\n' "$u13_perf_commit" "$run_status" >"$u13_perf_reports/run-status.txt" || true
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
printf 'Submission reports: %s\nChecking atomic submission, history isolation and nine Lord pairs...\n' "$u13_perf_reports"
"$u13_perf_exe" --headless --path "$u13_perf_root" --script Scripts/Sim/U13SubmissionPerformanceTestRunner.gd -- "--output=$u13_perf_reports/submission.json" >"$u13_perf_reports/submission.log" 2>&1 &
u13_perf_pid=$!
u13_perf_deadline=$((SECONDS + 600))
u13_perf_heartbeat=$((SECONDS + 15))
while kill -0 "$u13_perf_pid" 2>/dev/null; do
  if ((SECONDS >= u13_perf_deadline)); then
    printf 'FAIL submission performance watchdog (600 seconds). Reports: %s\n' "$u13_perf_reports" >&2
    exit 1
  fi
  if ((SECONDS >= u13_perf_heartbeat)); then
    printf 'Elapsed %sm %ss\n' "$((SECONDS / 60))" "$((SECONDS % 60))"
    tail -n 1 -- "$u13_perf_reports/submission.log"
    u13_perf_heartbeat=$((SECONDS + 15))
  fi
  sleep 0.2
done
u13_perf_status=0
wait "$u13_perf_pid" || u13_perf_status=$?
u13_perf_pid=""
if ((u13_perf_status != 0)) || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_perf_reports/submission.log" || ! grep -Eq '^U13 submission performance failures: 0$' "$u13_perf_reports/submission.log"; then
  tail -n 40 -- "$u13_perf_reports/submission.log"
  printf 'FAIL submission verification. Reports: %s\n' "$u13_perf_reports" >&2
  exit 1
fi
grep -E '^PROFILE |^Submission totals|^U13 submission performance failures:' "$u13_perf_reports/submission.log"
printf 'Submission checks passed. Reports: %s\n' "$u13_perf_reports"
