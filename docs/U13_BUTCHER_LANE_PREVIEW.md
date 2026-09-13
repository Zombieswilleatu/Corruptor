# Butcher lane sprite trial

Presentation-only standalone preview; does not change the playable board or simulation.
Launch from the Doctrine worktree:

```bash
bash Scripts/Sim/run_u13_butcher_preview.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  "/c/Users/jerem/OneDrive/Documents/Corruptor/ConceptImages/Sprites/ButcherSprite.png"
```

Loads the external PNG directly, without copying or importing it into the worktree.
The sheet is six columns by five rows: right walk, left walk, two attack rows,
and death. Idle holds the first movement frame. Attack rows are unused.

Default sprite height is 56 pixels, with 24 units across two vertical lanes.
Select 1, 24, or 48 units; adjust size from 32–512 pixels with a pixel readout; pause, compare chits, or trigger
one death per side per lane (or the single sprite in solo mode). Solo mode centers a single Butcher for frame inspection. The bottom army faces right; top faces left.
Death uses the last row, mirrored for the top army, then fades. Units reappear
after the death preview; movement repeats after ten seconds. Ownership rings
and illustrative full-health bars remain separate from the sprite.

This is an art/readability trial with scripted movement and contact pauses,
not a combat test. It deliberately does not play attacks in the lane. Existing
action-window combat is unchanged. Escape or Close exits.
