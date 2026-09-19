# Vulture range and goal-advance preview

**Superseded:** the range increase was withdrawn after playtesting. The same
runner now uses 400/600 ranges, +1 Vulture damage against Butchers, small marcher
footprints and a same-seed seat swap. See
[the current marcher balance notes](U13_MARCHER_COUNTER_SPACING_2026-09-19.md).
The remainder of this document records the earlier 900/1,125 experiment.

The earlier range-review push added comparison tools and evidence, while the
ordinary game and sandbox still used Vulture range 400 and tower range 600.
This runner opens a separate, visibly labeled playable experiment directly.

```bash
git pull --ff-only origin u13-basic-doctrine
bash Scripts/Sim/run_u13_vulture_balance.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The heading must read **VULTURE PREVIEW · range 900 · tower 1125**. The runner
requires Godot 4.7.2 stable and writes a dated log under
`Downloads/Corruptor/Logs`. Exit Preview or Escape closes this standalone window.
`run_u13_vulture_preview.sh` remains the older sprite preview; it is a different tool.

## Rules in this experiment

| Setting | Value |
| --- | --- |
| Vulture shooting range | 900 |
| Tower shooting range | 1,125 |
| Vulture ranged damage / cadence | Existing 1 damage / 50 ticks |
| Goal-advance toggle | On initially |

Tower range 1,125 is 25% beyond the proposed Vulture range of 900. It is an
87.5% increase from the current tower range of 600. This is the tower setting
recommended for a playable trial in the preceding range review.

The **goal itself** must be within the Vulture's shooting range: the last 900
of a 2,400-long lane. This is x >= 1,500 for side 0 and x <= 900 for side 1.
Before entering that stretch, Vultures stop to shoot and use existing support
pacing. Inside it, they move straight toward the goal at their normal modified
speed while the normal volley logic selects targets and fires on its existing
cooldown. They can shoot at an enemy behind them without turning back to chase it.
Allied support pacing and lamp attraction do not pull them away from this advance.
Melee contact, hostile walls, deployment readiness, taunts and retreat still apply.
Arrivals count once and leave at the end of the sandbox interval as before.

Unchecking **Advance when GOAL is within range** keeps the 900/1,125 ranges and
restores stopping behavior. Changing the toggle clears the arena and playback
using the entered seed, including the same two opening card decks. Repeating
manual comparisons requires spawning the same units again. New Random Arena
keeps the selected toggle setting. Enable both random spawn checkboxes and choose
Continuous to examine repeated waves.

The preview stores its version and toggle in `world.data.lane_balance_preview`,
so worker copies and successive rounds use the selected rules. Native Godot and
Python read the same explicit setting. Ordinary matches and the main-menu
sandbox retain their existing defaults. This is a trial of the proposed fix;
the broader question of recovery after an early lead still needs playtesting.

## Verification

- 40 complete native/Python phases matched across all 8,000 ticks and full
  results. Cases cover both owners, the exact goal-distance edge and one unit
  outside it, nearby enemies far from the goal, moving fire, support pacing,
  contact, walls, taunts, retreat, deployment hold, gate arrival, toggle-off
  behavior, current defaults, and both sides of the shooting-range boundaries
  for Vultures and towers. Evidence: `evidence/U13_VULTURE_PREVIEW_2026-09-19.json`.
- 32 native preview checks passed, including two successive intervals with
  camping enabled/disabled on both sides, retirement after arrival, scene flags,
  visible ranges, deterministic reset, worker interlock, cleared playback and
  layout bounds at the runner's 1,440 × 900 viewport. No script/runtime errors.
- Existing Python marching suite: 19 tests passed. Runner shell syntax and
  `git diff --check` passed.

These automated runs used local Godot **4.5.1 stable Linux**. They do not replace
the user's Godot **4.7.2 stable Windows** visual and gameplay acceptance run.

```bash
python3 Scripts/Sim/verify_u13_vulture_preview.py --godot /path/to/godot \
  --output /tmp/u13-vulture-preview.json
/path/to/godot --headless --path . --script res://Scripts/Sim/U13VulturePreviewTestRunner.gd
```
