#!/usr/bin/env bash
# Short purposeful matches. Random-Legal's full stress gate remains separate.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable [report_directory]\n' "$0" >&2
  exit 2
fi
u13_exe=$1
u13_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_games=${U13_DOCTRINE_GAMES:-9}
u13_workers=${U13_DOCTRINE_WORKERS:-2}
u13_rounds=${U13_DOCTRINE_ROUND_LIMIT:-40}
u13_timeout=${U13_DOCTRINE_TIMEOUT_SECONDS:-1200}
u13_verify=${U13_DOCTRINE_VERIFY_EVERY:-5}
for u13_number in "$u13_games" "$u13_workers" "$u13_rounds" "$u13_timeout" "$u13_verify"; do
  if [[ ! "$u13_number" =~ ^[1-9][0-9]{0,4}$ ]]; then
    printf 'Doctrine limits must be positive integers.\n' >&2
    exit 2
  fi
done
if ((u13_games > 1000 || u13_workers > 16 || u13_rounds > 200 || u13_timeout > 86400 || u13_verify > 1000)); then
  printf 'Doctrine limits exceed maximums.\n' >&2
  exit 2
fi
u13_commit=$(git -C "$u13_root" rev-parse HEAD)
u13_diff=$(git -C "$u13_root" diff HEAD | git -C "$u13_root" hash-object --stdin)
u13_revision="$u13_commit-$u13_diff"
mkdir -p -- "$HOME/Downloads"
u13_reports=${2:-$(mktemp -d "$HOME/Downloads/u13-doctrine-${u13_commit:0:8}-XXXXXX")}
mkdir -p -- "$u13_reports"
u13_reports=$(cd -- "$u13_reports" && pwd)
u13_pids=()
u13_indices=()
u13_deadlines=()
cleanup() {
  local pid
  for pid in "${u13_pids[@]}"; do
    [[ -n "$pid" ]] || continue
    kill -KILL "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
"$u13_exe" --version >"$u13_reports/version.log" 2>&1
if ! grep -Eq '^4\.7\.2\.stable([.[:space:]]|$)' "$u13_reports/version.log"; then
  cat -- "$u13_reports/version.log"
  printf 'This acceptance runner requires Godot 4.7.2 stable.\n' >&2
  exit 1
fi
printf 'Doctrine reports: %s\nChecking doctrine legality and replay fixtures...\n' "$u13_reports"
for u13_suite in U13CommittedHunt U13BasicDoctrine; do
"$u13_exe" --headless --path "$u13_root" --script "Scripts/Sim/${u13_suite}TestRunner.gd" >"$u13_reports/${u13_suite}.log" 2>&1 &
u13_pids[0]=$!
u13_deadline=$((SECONDS + u13_timeout))
u13_heartbeat=$((SECONDS + 15))
while kill -0 "${u13_pids[0]}" 2>/dev/null; do
  if ((SECONDS >= u13_deadline)); then
    printf 'FAIL doctrine preflight timeout; log preserved.\n' >&2
    exit 1
  fi
  if ((SECONDS >= u13_heartbeat)); then
    tail -n 1 -- "$u13_reports/${u13_suite}.log"
    u13_heartbeat=$((SECONDS + 15))
  fi
  sleep 0.2
done
u13_status=0
wait "${u13_pids[0]}" || u13_status=$?
u13_pids=()
if ((u13_status != 0)) || grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_reports/${u13_suite}.log" || ! grep -Eq '^U13 (basic doctrine|committed Hunt) failures: 0$' "$u13_reports/${u13_suite}.log"; then
  cat -- "$u13_reports/${u13_suite}.log"
  exit 1
fi
done
printf 'Running %s matches, %s workers, cap %s rounds; independent replay on every %sth game starting with game 1.\n' "$u13_games" "$u13_workers" "$u13_rounds" "$u13_verify"
printf 'index\tstatus\tverification\n' >"$u13_reports/results.tsv"
u13_next=0
u13_done=0
u13_won=0
u13_capped=0
u13_heartbeat=$((SECONDS + 15))
while ((u13_done < u13_games)); do
  for ((u13_slot=0; u13_slot<u13_workers; u13_slot++)); do
    if [[ -z ${u13_pids[u13_slot]:-} ]] && ((u13_next < u13_games)); then
      # First nine form a ring: all Lords in both seats, distinct opponents.
      u13_index=$((u13_next % 9 + 9 * ((u13_next / 9 + u13_next + 1) % 9)))
      # Cover all 81 ordered pairs before repeating; label by campaign slot.
      u13_dir="$u13_reports/match-$(printf '%03d' "$u13_next")"
      mkdir -p -- "$u13_dir"
      u13_extra=()
      if ((u13_next % u13_verify == 0)); then u13_extra=(--verify); fi
      "$u13_exe" --headless --path "$u13_root" --script Scripts/Sim/U13DoctrineMatchRunner.gd -- --index="$u13_index" --round-limit="$u13_rounds" --output="$u13_dir" --revision="$u13_revision" "${u13_extra[@]}" >"$u13_dir/game.log" 2>&1 &
      u13_pids[u13_slot]=$!
      u13_indices[u13_slot]=$u13_next
      u13_deadlines[u13_slot]=$((SECONDS + u13_timeout))
      printf 'Worker %s: match %s/%s (seed index %s)\n' "$((u13_slot + 1))" "$((u13_next + 1))" "$u13_games" "$u13_index"
      u13_next=$((u13_next + 1))
    fi
    [[ -n ${u13_pids[u13_slot]:-} ]] || continue
    u13_pid=${u13_pids[u13_slot]}
    u13_dir="$u13_reports/match-$(printf '%03d' "${u13_indices[u13_slot]}")"
    if kill -0 "$u13_pid" 2>/dev/null; then
      if ((SECONDS >= u13_deadlines[u13_slot])); then
        printf 'FAIL match timeout; workers stopped. Reports: %s\n' "$u13_reports" >&2
        exit 1
      fi
      continue
    fi
    u13_status=0
    wait "$u13_pid" || u13_status=$?
    u13_pids[u13_slot]=""
    if grep -Eq 'SCRIPT ERROR|ERROR:|^FAIL ' "$u13_dir/game.log" || [[ $u13_status != 0 && $u13_status != 2 ]] || ! grep -Eq '^U13 doctrine match (won|censored):' "$u13_dir/game.log"; then
      tail -n 25 -- "$u13_dir/game.log"
      printf 'FAIL match; workers stopped. Reports: %s\n' "$u13_reports" >&2
      exit 1
    fi
    u13_label=won
    if ((u13_status == 2)); then u13_label=censored; u13_capped=$((u13_capped + 1)); else u13_won=$((u13_won + 1)); fi
    u13_mode=single
    if ((u13_indices[u13_slot] % u13_verify == 0)); then u13_mode=replay; fi
    printf '%s\t%s\t%s\n' "${u13_indices[u13_slot]}" "$u13_label" "$u13_mode" >>"$u13_reports/results.tsv"
    tail -n 1 -- "$u13_dir/game.log"
    u13_done=$((u13_done + 1))
    printf 'Completed %s/%s; %s wins, %s capped\n' "$u13_done" "$u13_games" "$u13_won" "$u13_capped"
  done
  if ((SECONDS >= u13_heartbeat)); then
    printf 'Elapsed %sm %ss\n' "$((SECONDS / 60))" "$((SECONDS % 60))"
    for u13_slot in "${!u13_pids[@]}"; do
      [[ -n ${u13_pids[u13_slot]} ]] || continue
      tail -n 1 -- "$u13_reports/match-$(printf '%03d' "${u13_indices[u13_slot]}")/game.log"
    done
    u13_heartbeat=$((SECONDS + 15))
  fi
  sleep 0.2
done
printf 'Doctrine campaign: %s won, %s capped, 0 failures. Reports: %s\n' "$u13_won" "$u13_capped" "$u13_reports"
if ((u13_capped > 0)); then exit 2; fi
