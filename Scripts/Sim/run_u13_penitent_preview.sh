#!/usr/bin/env bash
set -euo pipefail
u13_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_godot=${1:?Pass the Godot executable as the first argument.}
u13_sheet=${2:-"$u13_root/ConceptImages/Sprites/PenitentSprite.png"}
# The preview bundles both the still and the comparison sheet.
if [[ ! -f "$u13_sheet" ]]; then
  u13_sheet="$u13_root/Prototype/U13/Assets/PenitentSpriteV3.png"
fi
# Explicit conversion also handles an asset in a different Windows worktree.
if command -v cygpath >/dev/null 2>&1; then
  u13_sheet=$(cygpath -am "$u13_sheet")
fi
exec "$u13_godot" --path "$u13_root" --resolution 1100x800 \
  res://Prototype/U13/U13PenitentLanePreview.tscn -- "--penitent-sheet=$u13_sheet"
