#!/usr/bin/env bash
set -euo pipefail
u13_sound_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_sound_exe=${1:-${GODOT_BIN:-}}
if [[ -z "$u13_sound_exe" ]]; then
  printf 'Usage: bash %s /path/to/Godot_v4.7.2-stable_executable\n' "$0" >&2
  exit 2
fi
u13_sound_python=${CORRUPTOR_SOUND_PYTHON:-}
if [[ -z "$u13_sound_python" ]]; then
  for u13_sound_candidate in python python3 py; do
    if u13_sound_python=$("$u13_sound_candidate" -c 'import sys; sys.exit(1) if sys.version_info < (3, 10) else print(sys.executable)' 2>/dev/null); then
      break
    fi
  done
fi
if [[ -z "$u13_sound_python" ]]; then
  printf 'Python 3.10 or newer is required to preview and save edited WAVs.\n' >&2
  exit 1
fi
export CORRUPTOR_SOUND_PYTHON="$u13_sound_python"
"$u13_sound_exe" --path "$u13_sound_root" --windowed --resolution 1440x810 \
  --rendering-method gl_compatibility res://Prototype/U13/U13SoundLab.tscn
