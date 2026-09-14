# Penitent preview checkpoint

The approved replacement walk is integrated into `U13PenitentLanePreview`.
Branch: `u13-basic-doctrine`.

- Replacement asset: `Assets/PenitentWalkV2.png`, the six-frame image attached
  to the September 13, 2026 "Patch animation preview" chat. Original bytes
  preserved; 1536 x 1024, three columns and two rows, all facing right.
- Playback order: top row left to right, then bottom row left to right, 8 FPS.
- New walk is the default. The existing art selector restores Original walk.
- Left walk mirrors the replacement. Ground anchors and one shared body scale
  are configured in the Penitent script, independent of the Butcher defaults.
- `U13PenitentKey.gdshader` hides the opaque pale checkerboard at runtime.
  This brightness key may also soften very bright neutral artwork highlights.
- Original celebrate, attack and death crops are retained. The third source
  row is celebrate; the fourth is attack.
- Preview only: no authoritative marching or combat changes.

Run `Scripts/Sim/run_u13_penitent_preview.sh` with the Godot executable as
argument 1 and the existing original `PenitentSprite.png` as argument 2.
The original sheet is local to the user's Windows worktree and is not bundled
by this patch. The replacement asset is bundled in this repository.

Validation: isolated Godot 4.6 import and headless preview launch passed;
`git diff --check` passed. Interactive visual review on the user's Godot 4.7.2
remains to be done. The existing runtime image loading emits an export warning;
this check exercises the standalone source-project preview.
