#!/usr/bin/env bash
# One bounded Godot process per ordered pair/seed; no Python dependency.
set -uo pipefail
if [[ $# -lt 1 ]]; then
  printf 'Usage: bash %s GODOT [--pair=Kalligan,Humbaba] [--trials=1] [--rounds=6] [--seed-prefix=u13-alpha-v1]\n' "$0" >&2
  exit 2
fi
u13_exe=$1
shift
u13_trials=1
u13_rounds=6
u13_seed=u13-alpha-v1
u13_pair=""
for u13_arg in "$@"; do
  case "$u13_arg" in
    --pair=*) u13_pair=${u13_arg#*=} ;;
    --trials=*) u13_trials=${u13_arg#*=} ;;
    --rounds=*) u13_rounds=${u13_arg#*=} ;;
    --seed-prefix=*) u13_seed=${u13_arg#*=} ;;
    *) printf 'Unknown option: %s\n' "$u13_arg" >&2; exit 2 ;;
  esac
done
if [[ ! -x "$u13_exe" || ! $u13_trials =~ ^[1-9][0-9]?$ || ! $u13_rounds =~ ^[1-9][0-9]?$ || ! $u13_seed =~ ^[A-Za-z0-9_:.-]+$ ]]; then
  printf 'Use an executable, 1..99 trials/rounds, and a simple nonempty seed prefix.\n' >&2
  exit 2
fi
u13_lords=(Gremory Deimos Humbaba Kalligan)
if [[ -n "$u13_pair" && ! $u13_pair =~ ^(Gremory|Deimos|Humbaba|Kalligan),(Gremory|Deimos|Humbaba|Kalligan)$ ]]; then
  printf 'Invalid pair: %s\n' "$u13_pair" >&2; exit 2
fi
u13_project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
u13_output_root=${U13_ALPHA_LOG_DIR:-$HOME/Downloads}
mkdir -p -- "$u13_output_root" || exit 2
u13_output=$(mktemp -d "$u13_output_root/u13-alpha-XXXXXX") || exit 2
u13_manifest=$u13_output/manifest.tsv
u13_index=0
for u13_left in "${u13_lords[@]}"; do
  for u13_right in "${u13_lords[@]}"; do
    [[ -z "$u13_pair" || "$u13_pair" == "$u13_left,$u13_right" ]] || continue
    for ((u13_trial=0; u13_trial<u13_trials; u13_trial++)); do
      printf '%s\t%s\t%s\t%s:%s\t%s\n' "$u13_index" "$u13_left" "$u13_right" "$u13_seed" "$u13_trial" "$u13_rounds" >>"$u13_manifest"
      u13_index=$((u13_index + 1))
    done
  done
done
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
  "$u13_exe" --headless --path "$u13_project" --script res://Scripts/Sim/U13AlphaBatchRunner.gd -- "$@" "--output=$partial" >"$log" 2>&1 &
  u13_pid=$!
  while kill -0 "$u13_pid" 2>/dev/null; do
    if ((SECONDS >= deadline)); then
      printf 'TIMEOUT: alpha shard exceeded 300 seconds.\n' >>"$log"
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
  if ((status != 0)) || [[ ! -s "$partial" ]] || ! grep -Fxq 'U13 alpha batch completed: OK' "$log" || grep -Eq 'SCRIPT ERROR:|ERROR:|^FAIL' "$log"; then
    printf 'FAILED ALPHA %s (exit %s). Reports/logs preserved: %s\n' "$label" "$status" "$u13_output" >&2
    return 1
  fi
  mv -- "$partial" "$u13_output/$label.json" || return 1
}
printf 'Four-Lord alpha: %s pair/seed shards; %s rounds plus restored replay each. Limit 300s per shard.\nLogs: %s\n' "$u13_index" "$u13_rounds" "$u13_output"
while IFS=$'\t' read -r u13_id u13_left u13_right u13_trial_seed u13_trial_rounds; do
  printf 'ALPHA SHARD %s/%s %s / %s\n' "$((u13_id + 1))" "$u13_index" "$u13_left" "$u13_right"
  u13_run "$u13_id" "--pair=$u13_left,$u13_right" "--seed=$u13_trial_seed" "--rounds=$u13_trial_rounds" || exit 1
done <"$u13_manifest"
u13_run report "--manifest=$u13_manifest" || exit 1
printf 'U13 alpha matrix completed: %s/%s shards.\nShare report and logs: %s\n' "$u13_index" "$u13_index" "$u13_output/report.json"
