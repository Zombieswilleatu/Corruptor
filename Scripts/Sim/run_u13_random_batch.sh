#!/usr/bin/env bash
# Frequency trials, not balance matches. Each seed is independently replayed.
set -uo pipefail
if [[ $# -lt 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot.exe [--trials=4] [--rounds=6] [--seed-prefix=name] [--roster=gremory|deimos|mixed|construction|loadout|humbaba]\n' "$0" >&2
  exit 2
fi
u13_batch_exe=$1
shift
u13_batch_roster=gremory
for u13_batch_arg in "$@"; do
  case "$u13_batch_arg" in
    --trials=*|--rounds=*|--seed-prefix=*) ;;
    --roster=gremory|--roster=deimos|--roster=mixed|--roster=construction|--roster=loadout|--roster=humbaba) u13_batch_roster=${u13_batch_arg#--roster=} ;;
    *) printf 'Unsupported batch argument: %s\n' "$u13_batch_arg" >&2; exit 2 ;;
  esac
done
u13_batch_project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
u13_batch_name=u13_random_legal
if [[ "$u13_batch_roster" != gremory ]]; then u13_batch_name="u13_random_${u13_batch_roster}"; fi
u13_batch_report=${U13_RANDOM_REPORT:-"$HOME/Downloads/${u13_batch_name}.json"}
u13_batch_log=${U13_RANDOM_LOG:-"$HOME/Downloads/${u13_batch_name}.log"}
u13_batch_timeout=${U13_BATCH_TIMEOUT_SECONDS:-300}
if [[ ! "$u13_batch_timeout" =~ ^[1-9][0-9]{0,3}$ ]]; then
  printf 'U13_BATCH_TIMEOUT_SECONDS must be 1..9999.\n' >&2
  exit 2
fi
mkdir -p -- "$(dirname -- "$u13_batch_report")" "$(dirname -- "$u13_batch_log")" || exit 2
u13_batch_partial="${u13_batch_report}.partial-$$"
u13_batch_pid=""
u13_batch_cleanup() {
  if [[ -n "$u13_batch_pid" ]]; then
    kill -KILL "$u13_batch_pid" 2>/dev/null || true
    wait "$u13_batch_pid" 2>/dev/null || true
  fi
  rm -f -- "$u13_batch_partial"
}
trap u13_batch_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'Running frequency trials and replay checks (limit %ss).\nProgress log: %s\n' "$u13_batch_timeout" "$u13_batch_log"
"$u13_batch_exe" --headless --path "$u13_batch_project" \
  --script res://Scripts/Sim/U13RandomBatchRunner.gd -- "$@" "--output=$u13_batch_partial" \
  >"$u13_batch_log" 2>&1 &
u13_batch_pid=$!
u13_batch_deadline=$((SECONDS + u13_batch_timeout))
u13_batch_status=0
while kill -0 "$u13_batch_pid" 2>/dev/null; do
  if ((SECONDS >= u13_batch_deadline)); then
    printf 'BATCH ERROR: exceeded %ss watchdog.\n' "$u13_batch_timeout" >>"$u13_batch_log"
    kill -KILL "$u13_batch_pid" 2>/dev/null || true
    break
  fi
  sleep 0.1
done
wait "$u13_batch_pid" || u13_batch_status=$?
u13_batch_pid=""
cat -- "$u13_batch_log"
if [[ $u13_batch_status -ne 0 || ! -s "$u13_batch_partial" ]] \
  || grep -Eq 'SCRIPT ERROR:|ERROR:|^FAIL[[:space:]]' "$u13_batch_log" \
  || ! grep -Fq 'U13 random-legal batch completed: OK' "$u13_batch_log"; then
  printf 'Batch failed; inspect %s. Previous report was preserved.\n' "$u13_batch_log" >&2
  exit 1
fi
mv -- "$u13_batch_partial" "$u13_batch_report" || exit 1
printf 'Frequency report: %s\nShare this JSON and the log.\n' "$u13_batch_report"
