# Marcher spacing, seat swap and targeted Vulture damage

The long-range Vulture experiment is withdrawn. Vultures again shoot at range
**400**, and towers at **600**, including in the dedicated balance sandbox.
Vulture hits gain **+1 damage against Butchers only**: ordinarily 2 before Armor,
in both ranged and melee attacks. The bonus is target-specific, applies after
the existing attack modifier and before armor absorption, and does not alter the
saved attack stat. Other targets and tower damage receive no such bonus.

## Small collision footprints

Modern marchers reserve a **42 fixed-point minimum center separation**, half the
former 84-unit footprint. This permits visual overlap around the edges while
preventing moving units from occupying the same center. Existing exact stacks
can separate, including stationary ranged fighters. Anchored builders, turret
Sooge and waiting/deployment-held units stay anchored while other units yield.
Enemy walls remain solid; enemy stealth and ghost bypass retain their exceptions.

Collision avoidance uses stable entity order and steers perpendicular to the
attempted movement. A fighter holds newly established melee contact instead of
stepping away after another unit reaches it during the same tick. A captured
sideways-chase deadlock is included in the replay checks. Friendly guards remain
passable by moving around their small footprint.

Spacing and the Butcher damage bonus apply to the ordinary modern combat engine
and its Python mirror. The optional goal-advance behavior remains in the balance
sandbox: it now starts only in the **last 400 distance to the goal**. Melee,
blocking walls, taunts and retreat still apply.

## Same-seed seat swap

**SWAP SEATS · SAME SEED** restarts the current seed at interval one with the two
armies exchanged. It preserves both original draw streams, keyed spawn positions
and immutable unit IDs, reflected into the opposite seats. Combat actually runs
in those seats. Initial manual spawns are recreated on the opposite side, and
the random-spawn checkboxes follow the corresponding armies. Mid-run manual
additions and queued requests are cleared by the restart.

The button becomes **RESTORE SEATS · SAME SEED**; clicking again restores the
original opening. A running playback resumes from the new opening; a paused
arena stays paused. The button is disabled while a worker prepares an interval.
Reset, new-seed and goal-advance controls preserve the selected seat assignment.

## Runner

```bash
git pull --ff-only origin u13-basic-doctrine
bash Scripts/Sim/run_u13_vulture_balance.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The heading reads **MARCHER BALANCE · range 400 · tower 600**. The Vulture tooltip
states the Butcher-only bonus. The goal-advance checkbox starts on.

## Verification and balance sample

Native/Python verification covers full phases and every tick for damage targets,
armor, both range edges, the restored goal-distance boundary, exact stacks,
half-footprint spacing, friendly guards, crowded convergence and the captured
sideways-chase deadlock. The native UI/round checks cover real seat exchange
across six successive paired waves, exact manual-opening restoration, controls,
thread interlocks and viewport bounds.

Final checks passed: **82 complete native/Python phases (16,400 ticks)**,
**59 native preview/seat checks**, **245 existing sandbox checks**, and
**19 existing Python marching tests**, with no native script/runtime errors.
The existing Vulture ranged runner also passed, including cadence, armor,
retreat, ranged-to-melee transition and projectile playback. Shell syntax and
`git diff --check` passed.

The counter probe used **16 independent seeds reflected to both seats** per
matchup (32 played trials per row), 12-round maximum, ordinary goal behavior,
and no Lords or reinforcement waves. All 192 battles resolved before the cap.

| Matchup | Wins for first side | Losses | Draws |
| --- | ---: | ---: | ---: |
| Vulture vs Butcher, 1v1 | 32 | 0 | 0 |
| Penitent vs Vulture, 1v1 | 20 | 12 | 0 |
| Butcher vs Penitent, 1v1 | 32 | 0 | 0 |
| Vulture vs Butcher, 4v4 | 32 | 0 | 0 |
| Penitent vs Vulture, 4v4 | 30 | 2 | 0 |
| Butcher vs Penitent, 4v4 | 32 | 0 | 0 |

The requested counter relationships now hold in this sample, with Penitent's
1v1 advantage over Vulture less decisive than its squad advantage. These are
isolated counter results, not full-game win rates or measured comeback rates.
Raw outcomes and source hashes are in
`evidence/U13_MARCHER_COUNTER_BATTLES_2026-09-19.json.gz`; full-phase parity evidence
is in `evidence/U13_MARCHER_COUNTER_SPACING_2026-09-19.json`.

Automated native checks used Godot **4.5.1 stable Linux**; the launcher requires
the user's **4.7.2 stable Windows** runtime for the visual playtest.

```bash
python3 Scripts/Sim/verify_u13_vulture_preview.py --godot /path/to/godot \
  --output /tmp/u13-marcher-counter-spacing.json
/path/to/godot --headless --path . --script res://Scripts/Sim/U13VulturePreviewTestRunner.gd
```
