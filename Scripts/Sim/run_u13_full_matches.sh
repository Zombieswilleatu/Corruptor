#!/usr/bin/env bash
# A separate long gate. Defaults to 100 complete games, not 100 fixed-length trials.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable [report_directory]\n' "$0" >&2
  exit 2
fi
u13_exe=$1
u13_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_games=${U13_BATCH_GAMES:-100}
u13_workers=${U13_BATCH_WORKERS:-4}
u13_round_limit=${U13_BATCH_ROUND_LIMIT:-80}
u13_timeout=${U13_BATCH_TIMEOUT_SECONDS:-1200}
for u13_number in "$u13_games" "$u13_round_limit" "$u13_timeout" "$u13_workers"; do
  if [[ ! "$u13_number" =~ ^[1-9][0-9]{0,4}$ ]]; then
    printf 'Batch limits must be positive integers.\n' >&2
    exit 2
  fi
done
if ((u13_games > 1000 || u13_round_limit > 200 || u13_timeout > 86400 || u13_workers > 16)); then
  printf 'Maximums: 1000 games, 200 rounds, 86400 seconds per game, 16 workers.\n' >&2
  exit 2
fi
# Scheduler/docs-only updates can reuse verified games from identical content.
# Other tracked changes get a new identity, including dirty gameplay changes.
u13_commit=$(git -C "$u13_root" log -1 --format=%H -- . ':(exclude)docs' ':(exclude)Scripts/Sim/run_u13_full_matches.sh')
u13_diff=$(git -C "$u13_root" diff HEAD -- . ':(exclude)docs' ':(exclude)Scripts/Sim/run_u13_full_matches.sh' | git -C "$u13_root" hash-object --stdin)
u13_revision="$u13_commit-$u13_diff"
u13_reports=${2:-"$HOME/Downloads/u13-full-matches-${u13_commit:0:8}-${u13_diff:0:8}-r$u13_round_limit"}
mkdir -p -- "$u13_reports"
u13_reports=$(cd -- "$u13_reports" && pwd)
u13_pid=""
u13_pool_pids=()
u13_pool_indices=()
u13_pool_logs=()
u13_pool_deadlines=()
cleanup() {
  local pid
  # The parent owns every Godot PID, so Ctrl-C/failure cannot leave workers behind.
  for pid in "$u13_pid" "${u13_pool_pids[@]}"; do
    [[ -n "$pid" ]] || continue
    kill -KILL "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
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
      printf 'TIMEOUT: exceeded %s seconds; game is unfinished.\n' "$u13_timeout" >>"$log"
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
run_godot "$u13_reports/version.log" --version
if ! grep -Eq '^4\.7\.2\.stable([.[:space:]]|$)' "$u13_reports/version.log"; then
  cat -- "$u13_reports/version.log"
  printf 'This gate requires Godot 4.7.2 stable.\n' >&2
  exit 1
fi
u13_status=0
printf 'Checking planning parity before starting workers...\n'
run_godot "$u13_reports/planning-parity.log" --script Scripts/Sim/U13PlanningPerformanceTestRunner.gd || u13_status=$?
if [[ $u13_status -ne 0 ]] || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_reports/planning-parity.log" || ! grep -q '^U13 planning performance failures: 0$' "$u13_reports/planning-parity.log"; then
  cat -- "$u13_reports/planning-parity.log"
  exit 1
fi
printf 'Checking batch saves and gameplay parity...\n'
run_godot "$u13_reports/snare-planning.log" --script Scripts/Sim/U13SnarePlanningTestRunner.gd || u13_status=$?
if [[ $u13_status -ne 0 ]] || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_reports/snare-planning.log" || ! grep -q '^U13 Snare planning failures: 0$' "$u13_reports/snare-planning.log"; then
  cat -- "$u13_reports/snare-planning.log"
  exit 1
fi
run_godot "$u13_reports/harness.log" --script Scripts/Sim/U13FullMatchBatchTestRunner.gd || u13_status=$?
if [[ $u13_status -ne 0 ]] || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_reports/harness.log" || ! grep -q '^U13 full match harness failures: 0$' "$u13_reports/harness.log"; then
  cat -- "$u13_reports/harness.log"
  exit 1
fi
printf 'Running %s games with %s Godot workers; round limit %s; watchdog %ss per game.\nBatch event profile: state changes; position samples omitted.\nReports/checkpoints: %s\n' "$u13_games" "$u13_workers" "$u13_round_limit" "$u13_timeout" "$u13_reports"
u13_next=0
u13_completed=0
u13_heartbeat=$((SECONDS + 15))
while ((u13_completed < u13_games)); do
  for ((u13_slot=0; u13_slot<u13_workers; u13_slot++)); do
    u13_worker_pid=${u13_pool_pids[u13_slot]:-}
    if [[ -n "$u13_worker_pid" ]]; then
      u13_status=0
      if kill -0 "$u13_worker_pid" 2>/dev/null; then
        if ((SECONDS < u13_pool_deadlines[u13_slot])); then
          continue
        fi
        printf 'TIMEOUT: exceeded %s seconds; game is unfinished.\n' "$u13_timeout" >>"${u13_pool_logs[u13_slot]}"
        kill -KILL "$u13_worker_pid" 2>/dev/null || true
        wait "$u13_worker_pid" 2>/dev/null || true
        u13_status=124
      else
        wait "$u13_worker_pid" || u13_status=$?
      fi
      u13_pool_pids[u13_slot]=""
      u13_index=${u13_pool_indices[u13_slot]}
      u13_log=${u13_pool_logs[u13_slot]}
      tail -n 2 -- "$u13_log"
      if grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_log" || \
        { [[ $u13_status -eq 0 ]] && ! grep -q '^U13 full match won:' "$u13_log"; } || \
        { [[ $u13_status -eq 2 ]] && ! grep -q '^U13 full match censored:' "$u13_log"; } || \
        [[ $u13_status -ne 0 && $u13_status -ne 2 ]]; then
        printf 'FAILED game %s (exit %s). Other workers stopped; logs/checkpoints preserved: %s\n' "$u13_index" "$u13_status" "$u13_reports" >&2
        exit 1
      fi
      u13_completed=$((u13_completed + 1))
      printf 'Completed %s/%s\n' "$u13_completed" "$u13_games"
    fi
    if ((u13_next < u13_games)); then
      u13_index=$u13_next
      u13_next=$((u13_next + 1))
      printf -v u13_log '%s/game-%03d.log' "$u13_reports" "$u13_index"
      printf 'Worker %s: game %s/%s\n' "$((u13_slot + 1))" "$((u13_index + 1))" "$u13_games"
      "$u13_exe" --headless --path "$u13_root" --script Scripts/Sim/U13FullMatchBatchRunner.gd -- \
        "--index=$u13_index" "--round-limit=$u13_round_limit" "--output=$u13_reports" "--revision=$u13_revision" >"$u13_log" 2>&1 &
      u13_pool_pids[u13_slot]=$!
      u13_pool_indices[u13_slot]=$u13_index
      u13_pool_logs[u13_slot]=$u13_log
      u13_pool_deadlines[u13_slot]=$((SECONDS + u13_timeout))
    fi
  done
  if ((SECONDS >= u13_heartbeat)); then
    printf 'Elapsed %sm %ss\n' "$((SECONDS / 60))" "$((SECONDS % 60))"
    for ((u13_slot=0; u13_slot<u13_workers; u13_slot++)); do
      if [[ -n "${u13_pool_pids[u13_slot]:-}" ]]; then
        tail -n 1 -- "${u13_pool_logs[u13_slot]}"
      fi
    done
    u13_heartbeat=$((SECONDS + 15))
  fi
  if ((u13_completed < u13_games)); then sleep 0.2; fi
done
u13_status=0
run_godot "$u13_reports/summary.log" --script Scripts/Sim/U13FullMatchBatchRunner.gd -- \
  --summarize "--games=$u13_games" "--round-limit=$u13_round_limit" "--output=$u13_reports" "--revision=$u13_revision" || u13_status=$?
cat -- "$u13_reports/summary.log"
if grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_reports/summary.log" || ! grep -q '^U13 full match batch:' "$u13_reports/summary.log"; then
  exit 1
fi
printf 'Summary: %s/summary.json\n' "$u13_reports"
exit "$u13_status"
