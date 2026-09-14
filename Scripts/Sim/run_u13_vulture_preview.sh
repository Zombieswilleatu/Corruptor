#!/usr/bin/env bash
set -euo pipefail
u13_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_godot=${1:?Pass the Godot executable as the first argument.}
u13_sheet=${2:-"$u13_root/ConceptImages/Sprites/VultureSprite.png"}
if [[ ! -f "$u13_sheet" ]]; then
  echo "Sprite not found: $u13_sheet" >&2
  echo 'Pass the VultureSprite.png path as the second argument.' >&2
  exit 1
fi
# Explicit conversion also handles an asset in a different Windows worktree.
if command -v cygpath >/dev/null 2>&1; then
  u13_sheet=$(cygpath -am "$u13_sheet")
fi
exec "$u13_godot" --path "$u13_root" --resolution 1100x800 \
  res://Prototype/U13/U13VultureLanePreview.tscn -- "--vulture-sheet=$u13_sheet"
