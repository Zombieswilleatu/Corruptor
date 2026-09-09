# Scorch sprite presentation

Uses the three original PNG blobs from main commit
`2088da7708ae490cdabf346feafb8d8afb4c377c`. No image pixels were modified and no
other main-branch changes were brought into U13.

## Direction implemented

- GroundFire: six atlas variants stamped closely across the active target with
  soft radial alpha. Each small stamp fades from its center to a transparent rim.
  One cached mesh holds the entire brush layer, with a maximum of 160 stamps.
- Twelve small flames per active instance, distributed with stratified jitter.
  Stable cosmetic offsets vary position, height and starting animation phase.
- Fire1 and Fire2 each use their five horizontal frames at 6 FPS. Every repeating
  block contains four full Fire1 loops and one full Fire2 loop; phase offsets keep
  all flames from switching to alien fire together.
- Intensity 2 increases every flame's size by 12%, brightness by 15%, and opacity
  from 0.62 to 0.72. The ground layer brightens too. Intensity 1 restores baseline.
- A resolved Pyroclasm pulse creates a one-second envelope: 0.10-second ramp,
  bright hold to 0.65 seconds, then fade back by one second. At its peak, flame size
  gains another 30%, brightness another 70%, and opacity reaches 1.0. It preserves
  the normal/alien animation clock and returns to the current stage's appearance.
- Pyroclasm flashes even when the affected area is empty. The trigger comes from
  the resolved Step 10F hazard pulse, not a click or draft declaration.

Lane fire draws below the chits, health rings, and floating numbers. Guard fire
uses the same renderer behind the appropriate Guard cards. Pending Inferno keeps
its existing future-round telegraph and does not burn early. Expiry removes the
fire; relocation follows the current target while preserving animation phase.

## Cost boundaries

No particle nodes, physics, lights, offscreen viewports, per-pixel GDScript scans,
or simulation RNG. Three cached textures are shared through the board art cache
(about 18 MiB uncompressed RGBA in total, before driver overhead). Lane warm-up
loads at most one Breath/Scorch asset per frame. Ground geometry is rebuilt only
when the target dimensions change or a new effect instance is created. Flame
quads use atlas sampling, clipped to the target. Numeric feedback remains bounded
and separate from fire animation. Hardware FPS is not established by static checks.

The mesh uses Godot's [ArrayMesh arrays](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html)
and [CanvasItem drawing API](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html).

## Fast visual runner

```bash
bash Scripts/Sim/run_u13_scorch_preview.sh "$GODOT_U13"
```

This visual-only scene uses the real board lane renderer and stationary reference
chits. Controls change the arrangement, toggle intensity 1/2, trigger the one-second
Pyroclasm flash, expire fire, and demonstrate HP/healing/Armor numbers. The number
buttons do not simulate damage. No matches or full foundation tests run here.

Authoritative damage timing/amount checks and the renderer gate:

```bash
bash Scripts/Sim/run_u13_foundation_tests.sh "$GODOT_U13" --marcher-feedback
```

Expected `U13 Marcher-feedback runners passed: 4/4`. The normal board runner is
unchanged. Workspace validation is grammar/static/shell only; Godot 4.7.2 local
verification and visual acceptance are still required.
