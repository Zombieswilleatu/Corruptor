#!/usr/bin/env bash
set -euo pipefail
intro_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
intro_exe="${1:-${GODOT_BIN:-}}"
if [[ -z "$intro_exe" ]]; then
  intro_folder="$HOME/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe"
  if [[ -d "$intro_folder" ]]; then
    intro_exe=$(find "$intro_folder" -maxdepth 2 -type f -iname '*godot*.exe' ! -iname '*console*' -print -quit)
  fi
fi
if [[ -z "$intro_exe" ]]; then
  echo 'Pass the Godot executable: bash Scripts/Sim/run_u13_intro.sh "$godot_exe"' >&2
  exit 1
fi
# CORRUPTOR_TITLE_TO_U13_BOT_SETUP_V1
if (( $# > 2 )); then
  echo 'Usage: bash Scripts/Sim/run_u13_intro.sh [Godot executable] [Python executable]' >&2
  exit 2
fi
intro_python=
intro_python_candidates=("${2:-${CORRUPTOR_BOT_PYTHON:-}}")
if [[ -z "${2:-${CORRUPTOR_BOT_PYTHON:-}}" ]]; then
  intro_python_candidates=(python python3 py)
fi
for intro_candidate in "${intro_python_candidates[@]}"; do
  if intro_python=$("$intro_candidate" -c 'import sys; sys.exit(1) if sys.version_info < (3,10) else print(sys.executable)' 2>/dev/null); then
    break
  fi
  intro_python=
done
if [[ -z "$intro_python" ]]; then
  echo 'The U13 opponent needs Python 3.10 or newer. Pass Python as the second argument.' >&2
  exit 1
fi
export CORRUPTOR_BOT_PYTHON="$intro_python"
intro_policy=$("$CORRUPTOR_BOT_PYTHON" "$intro_root/Scripts/Sim/u13_common_bot_worker.py" --check)
printf 'Opponent: %s\nPython: %s\n' "$intro_policy" "$CORRUPTOR_BOT_PYTHON"

intro_log_dir="$HOME/Downloads/Corruptor/Logs"
mkdir -p "$intro_log_dir"
intro_log="$intro_log_dir/intro-import-$(date +%Y%m%d-%H%M%S).log"
echo 'Preparing intro artwork and audio. The first import may take a little while.'
echo "Import log: $intro_log"
if ! "$intro_exe" --headless --path "$intro_root" --editor --import --rendering-method mobile > "$intro_log" 2>&1; then
  cat "$intro_log"
  exit 1
fi
# Godot can exit successfully after import while reporting individual failures.
# Explicitly verify every asset needed by the sequence before opening its window.
"$intro_exe" --headless --path "$intro_root" --script res://Scripts/Sim/IntroAssetCheck.gd \
  --rendering-method mobile 2>&1 | tee -a "$intro_log"
echo 'Starting: Corruptor main menu'
"$intro_exe" --path "$intro_root" --windowed --resolution 1440x810 \
  --rendering-method mobile res://Prototype/U13/U13MainMenu.tscn 2>&1 | tee -a "$intro_log"
