#!/usr/bin/env bash
# Directed playable acceptance, without a long campaign.
set -euo pipefail
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable\n' "$0" >&2
  exit 2
fi
u13_play_exe=$1
u13_play_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
mkdir -p -- "$HOME/Downloads"
u13_play_reports=$(mktemp -d "$HOME/Downloads/u13-playable-checks-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX")
u13_play_child=
u13_play_cleanup() {
  local result=$?
  if [[ -n "$u13_play_child" ]]; then
    kill -KILL "$u13_play_child" 2>/dev/null || true
    wait "$u13_play_child" 2>/dev/null || true
  fi
  printf 'runner=playable_checks\nexit_status=%s\n' "$result" >"$u13_play_reports/run-status.txt"
  bash "$u13_play_root/Scripts/Sim/package_u13_reports.sh" "$u13_play_reports" || true
  exit "$result"
}
trap u13_play_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
"$u13_play_exe" --version >"$u13_play_reports/version.log" 2>&1
if ! grep -Eq '^4\.7\.2\.stable([.[:space:]]|$)' "$u13_play_reports/version.log"; then
  printf 'Playable acceptance requires Godot 4.7.2 stable.\n' >&2
  exit 1
fi
git -C "$u13_play_root" rev-parse HEAD >"$u13_play_reports/revision.txt"
printf 'Playable check reports: %s\n' "$u13_play_reports"
for u13_play_suite in U13CommittedHunt U13WishDoctrine U13PlayableInteraction U13PlayableSession U13PlayableBoard; do
  u13_play_extra=()
  if [[ "$u13_play_suite" == U13PlayableSession ]]; then
    u13_play_extra=(-- --fixtures-only)
  fi
  printf 'Checking %s...\n' "$u13_play_suite"
  "$u13_play_exe" --headless --path "$u13_play_root" --script "Scripts/Sim/${u13_play_suite}TestRunner.gd" "${u13_play_extra[@]}" >"$u13_play_reports/$u13_play_suite.log" 2>&1 &
  u13_play_child=$!
  u13_play_deadline=$((SECONDS + 600))
  u13_play_heartbeat=$((SECONDS + 15))
  while kill -0 "$u13_play_child" 2>/dev/null; do
    if ((SECONDS >= u13_play_deadline)); then
      printf 'Timed out: %s (600 seconds).\n' "$u13_play_suite" >&2
      exit 124
    fi
    if ((SECONDS >= u13_play_heartbeat)); then
      tail -n 2 "$u13_play_reports/$u13_play_suite.log"
      u13_play_heartbeat=$((SECONDS + 15))
    fi
    sleep 1
  done
  u13_play_result=0
  wait "$u13_play_child" || u13_play_result=$?
  u13_play_child=
  if ((u13_play_result != 0)) || grep -Eq '(^FAIL|SCRIPT ERROR|^ERROR:)' "$u13_play_reports/$u13_play_suite.log"; then
    cat "$u13_play_reports/$u13_play_suite.log"
    exit 1
  fi
  tail -n 1 "$u13_play_reports/$u13_play_suite.log"
done
printf 'Playable checks passed.\n'
