# Retained animation previews

Open the U13 Lord/Castle picker and choose **ANIMATION PREVIEWS**. During an
existing match, **New loadout** opens that same picker when the board is idle.

The gallery offers the existing scenes:

- **Castle damage & repair:** Castle type, automatic degradation/repair, manual
  Integrity slider and fixed damage-band references.
- **Breath of Life:** flower growth, hold, healing sweep, expiration and staggered
  dying, with manual restart and expiration controls.
- **Scorch & combat numbers:** arrangements, intensity 1/2, Pyroclasm flash,
  expiration, and cosmetic HP/Armor numbers.

These use the board renderers. The gallery does not create a match or advance
the current one. Returning preserves the picker's Lord/Castle choices. Only the
selected preview is instantiated; leaving or switching stops its processing and
queues it for deletion. Scenes fit the available panel without resizing the game
window. Castle background drawing is local to the preview, not a global renderer
change.

**Back to previews** (or Escape) closes the active preview. **Back to Lords &
Castles** closes the gallery. Escape on the gallery menu also returns to the
picker. Standalone scenes still use Exit/Escape to close their application.

The original scenes and launchers remain supported:

```bash
bash Scripts/Sim/run_u13_castle_preview.sh "$GODOT_U13"
bash Scripts/Sim/run_u13_breath_preview.sh "$GODOT_U13"
bash Scripts/Sim/run_u13_scorch_preview.sh "$GODOT_U13"
```

The older Marching smoke harness remains in `run_u13_smoke.sh`; it exercises a
simulation and is separate from this visual-only gallery.

Verification in the implementation workspace is limited to grammar, block
structure, source review and resource-path checks. Godot 4.7.2 compilation and
visual navigation require the local runtime. For a quick check, alter a loadout,
open each preview, use its controls and return; confirm the selections remain
and returning does not exit the game. Check the standalone Exit behavior too.
