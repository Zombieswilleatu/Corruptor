# Butcher lane sprite trial

Presentation-only standalone preview; does not change the playable board or simulation.
Launch from the Doctrine worktree:

```bash
bash Scripts/Sim/run_u13_butcher_preview.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  "/c/Users/jerem/OneDrive/Documents/Corruptor/ConceptImages/Sprites/ButcherSprite.png"
```

Loads the external PNG directly, without copying or importing it into the worktree.
The sheet contains six poses per row: right walk, left walk, two attack rows,
and death. Cuts use measured per-pose rectangles, not a uniform grid; ground
anchors and a shared scale keep the sprite aligned without enlarging death poses. Idle holds the first movement frame. Attack rows are unused.

Default sprite height is 75 pixels, with 24 units across two vertical lanes.
Select 1, 24, or 48 units; adjust size from 32–512 pixels with a pixel readout; pause, compare chits, or trigger
one death per side per lane (or the single sprite in solo mode). Solo mode centers a single Butcher for frame inspection. Every marcher independently chooses left or right with 50% probability at spawn. Horizontal travel overrides facing to match its direction; vertical travel, idle and death preserve the last facing; Restart rerolls the choices.
Death uses the last row, mirrored for left-facing units, then fades. Units reappear
after the death preview; movement repeats after ten seconds. Ownership rings
and illustrative full-health bars remain separate from the sprite.

This is an art/readability trial with scripted movement and contact pauses,
not a combat test. It deliberately does not play attacks in the lane. Existing
action-window combat is unchanged. Escape or Close exits.

Use the inspection selector for right walk, left walk or death, then scrub frames
1–6. Inspection holds movement and disables death fading so every cut can be
examined. The final death poses touch in the source art; rectangular separation
cannot reconstruct pixels already overlapping or clipped at the sheet edge.

## New walk draft

The preview defaults to the approved six-pose redraw in `Prototype/U13/Assets/ButcherWalkV2.png`. Select Original walk to compare. The new sheet has three columns and two rows; left-facing playback mirrors the same cycle. Idle holds frame one, and death continues to use the original external sheet. Ground anchors correct the different row baselines without independently scaling frames. The generated RGB asset uses a green background, removed by a shader on a separate sprite layer; the board and ownership markers are not keyed. This remains a preview, not a change to simulation or the playable board.

## Penitent

The same controls are available in `run_u13_penitent_preview.sh`, taking the Godot path and external `PenitentSprite.png` path. It uses measured cuts from the existing sheet: source row one faces left, row two faces right, and row five is death. No redraw or attack animation is used. Both previews now default to 75 pixels. The preview size is not yet applied to the playable board.

The Penitent inspection selector also offers **Inspect attack 1** and **Inspect attack 2** (source rows three and four). Select an animation, then **Play / hold** to loop its six poses at 8 FPS; scrubbing holds the selected frame. Global pause also pauses inspection playback. Use solo mode and the size slider for close inspection. Attack cuts are provisional full cells (six columns in the existing 1374×1145 reference space), pending visual verification against the external PNG. Walk and death cuts are unchanged. These attacks are inspection-only.
