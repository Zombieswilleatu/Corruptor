# Rout status sprite

The supplied, unmodified PNG is committed at
`ConceptImages/Sprites/Rout/Rout.png`. It appears above each affected Marcher
in the full U13 board and the original smoke view, following the same playback
position as its chit. It is also shown with the actor in the clash display.
Health rings and allegiance outlines remain drawn above the overlay.

The sprite fades in on application, then smoothly fades out and back in over a
2.4-second cycle. Each actor has a stable cosmetic phase so a group does not
blink in lockstep. There is no translation, rotation or scale animation.
Recovery is still a Rout-affected round, so the mark persists through recovery
and disappears when Rout ends, the actor is removed or the board resets.

The renderer uses the simulation's `retreating` and `recovering` predicates,
never infers Rout from movement direction. It keeps no gameplay state and
consumes no simulation RNG. One texture is cached, with no per-actor scene
nodes, physics bodies or tweens. Redraw processing remains active while a Rout
mark is visible, including when playback is stationary.

Focused verification:

```bash
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  --rout-visuals
```

Expected: `U13 Rout-visuals runners passed: 2/2`. The small presentation runner
checks the real PNG loads, pulse progression, repeated playback refreshes,
recovery, removal and reset, followed by the existing Rout rules runner.
Local Godot and visual confirmation are still required; implementation-side
checks are source/static checks only.

To inspect in game, use the regular board runner, select Deimos and apply Rout
to a lane containing enemy Marchers. The ghost should follow each affected
chit and fade without moving independently.
