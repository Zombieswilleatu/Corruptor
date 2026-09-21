#!/usr/bin/env bash
# Human-versus-doctrine game. Leaves the U12 main scene unchanged.
set -euo pipefail
if (( $# > 2 )); then
  printf 'Usage: bash %s [Godot_4.7.2_executable] [python_executable]\n' "$0" >&2
  exit 2
fi
u13_play_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_play_exe=
u13_play_candidates=("${1:-${GODOT_BIN:-}}")
if [[ -z "${1:-${GODOT_BIN:-}}" ]]; then
  u13_play_candidates=(godot godot4 "$HOME"/Downloads/Godot_v4.7.2*.exe "$HOME"/Downloads/Godot_v4.7.2*/*.exe)
fi
for u13_play_candidate in "${u13_play_candidates[@]}"; do
  [[ -n "$u13_play_candidate" ]] || continue
  if u13_play_resolved=$(command -v -- "$u13_play_candidate") && [[ -x "$u13_play_resolved" ]]; then
    u13_play_version=$("$u13_play_resolved" --version) || continue
    if [[ "$u13_play_version" =~ ^4\.7\.2\.stable([.[:space:]]|$) ]]; then
      u13_play_exe=$u13_play_resolved
      break
    fi
  fi
done
if [[ -z "$u13_play_exe" ]]; then
  printf 'Godot 4.7.2 stable was not found. Pass its executable as the first argument.\n' >&2
  exit 1
fi
u13_play_python=
u13_play_python_candidates=("${2:-${CORRUPTOR_BOT_PYTHON:-}}")
if [[ -z "${2:-${CORRUPTOR_BOT_PYTHON:-}}" ]]; then
  u13_play_python_candidates=(python python3 py)
fi
for u13_play_candidate in "${u13_play_python_candidates[@]}"; do
  if u13_play_python=$("$u13_play_candidate" -c 'import sys; sys.exit(1) if sys.version_info < (3,10) else print(sys.executable)' 2>/dev/null); then
    break
  fi
  u13_play_python=
done
if [[ -z "$u13_play_python" ]]; then
  printf 'The V26 opponent needs Python 3.10 or newer. Pass its executable as the second argument.\n' >&2
  exit 1
fi
export CORRUPTOR_BOT_PYTHON="$u13_play_python"
u13_play_policy=$("$CORRUPTOR_BOT_PYTHON" "$u13_play_root/Scripts/Sim/u13_common_bot_worker.py" --check)
printf 'Opponent: %s\nPython: %s\n' "$u13_play_policy" "$CORRUPTOR_BOT_PYTHON"
mkdir -p -- "$HOME/Downloads/Corruptor/Logs"
u13_play_log=$(mktemp "$HOME/Downloads/Corruptor/Logs/u13-playable-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.log")
printf 'Launching the playable game against the doctrine bot.\nRun log: %s\nSaved games: Downloads/Corruptor/Saves. Use OLDER SAVES IN DOWNLOADS to load earlier matches.\n' "$u13_play_log"
"$u13_play_exe" --path "$u13_play_root" --windowed --resolution 1440x810 \
  --rendering-method gl_compatibility res://Prototype/U13/U13PlayableBoard.tscn 2>&1 | tee "$u13_play_log"
