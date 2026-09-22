#!/usr/bin/env bash
# Headless random-wave balance study using the production lane sandbox.
set -euo pipefail
if [[ $# -lt 1 || ! -f "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_executable [--seeds 32 --rounds 40 --workers 2]\n' "$0" >&2
  exit 2
fi
u13_batch_godot=$1
shift
u13_batch_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_batch_python=()
for u13_batch_candidate in python3 python pypy3; do
  if command -v "$u13_batch_candidate" >/dev/null 2>&1 && "$u13_batch_candidate" -c 'import sys; sys.exit(sys.version_info < (3, 9))' 2>/dev/null; then
    u13_batch_python=("$u13_batch_candidate"); break
  fi
done
if [[ ${#u13_batch_python[@]} -eq 0 ]] && command -v py >/dev/null 2>&1 && py -3 -c 'import sys; sys.exit(sys.version_info < (3, 9))' 2>/dev/null; then
  u13_batch_python=(py -3)
fi
if [[ ${#u13_batch_python[@]} -eq 0 ]]; then
  printf 'Python 3.9+ is required for reports. No extra Python packages are needed.\n' >&2
  exit 2
fi
exec "${u13_batch_python[@]}" "$u13_batch_root/Scripts/Sim/run_u13_lane_balance_batch.py" --godot "$u13_batch_godot" "$@"
