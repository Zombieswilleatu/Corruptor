# Valak animation preview — September 10, 2026

Gameplay integration now follows this preview; see
`U13_VALAK_IMPLEMENTATION_2026-09-10.md` for current rules and the board runner.

Adds **Valak · Orbs & Absorption** to the U13 animation gallery and a standalone
`Prototype/U13/U13ValakPreview.tscn` scene. The gallery sidebar now scrolls and
keeps its Back button visible as the roster grows.

## Controls

- Click either lane to choose the destination, then **Cast orb**.
- **Absorb +1** brings a green mote into the hovering orb and adds one layer
  on arrival. **Auto absorb** demonstrates the five supplied layers in sequence.
- **Project charges** sends the accumulated green layers to the selected point
  and clears the hovering charge display. Empty projection does nothing.
- **Pause**, playback speed, flight duration, formation duration and orb size
  support inspection. **Move staff origin** lets a click on the card adjust
  the launch anchor. **Reset** clears charges and all in-flight effects.

The purple orb launches from the staff, animates through flight, plays the six
singularity frames at the destination, then enters the rotating sheet. Its first
two expanding frames play once; the remaining five loop without shrinking.
Explicit uneven atlas cuts and nucleus anchors preserve the supplied artwork.

The green assets are separate cumulative layers, not five replacement frames.
The core is small; each arriving charge adds a larger, slowly rotating ring.
The fifth asset retains its original lowercase filename `energy5.png`.

## Integration boundary

This change implements the **animation preview and reusable visual component**.
It does not enable Valak as a completed U13 gameplay Lord, port legacy Valak
rules, decide damage/charge costs, or change U12. The U13 branch at `86d1c38`
contains no authoritative Valak power adapter to connect yet.

`U13ValakVisual.gd` accepts local-space staff/hover anchors, targets and explicit
charge totals. It advances only when its owner calls `advance(delta)` so future
board playback can share the same pause/speed clock. The preview's five-charge
showcase limit is not a gameplay cap; the visual component accepts higher totals
and reuses the outer ring for additional layers.

## Run

Open the U13 loadout animation gallery, or run:

```bash
bash Scripts/Sim/run_u13_valak_preview.sh /path/to/Godot_4.7.2_executable
```

Headless validation:

```bash
/path/to/Godot_4.7.2_executable --headless --path . \
  --script res://Scripts/Sim/U13ValakVisualTestRunner.gd
```

The runner checks original asset loading, staff anchoring, phase order, time
overflow, the rotating hold loop, multiple absorption arrivals, Projection,
empty charge handling, clearing, preview reset/pause and gallery open/close.

The recovered preview also fixes Projection's impact anchor: changing the aim
while a shot is in flight does not move that shot's arrival flash. Large frames
preserve the arrival flash instead of consuming it immediately.

Validation in this environment: **23/23**, zero failures, using Godot 4.5.1
headless. The user's Godot 4.7.2 runtime and visual review remain local checks.
The standalone Bash runner passes syntax validation and the diff has no
whitespace errors.
