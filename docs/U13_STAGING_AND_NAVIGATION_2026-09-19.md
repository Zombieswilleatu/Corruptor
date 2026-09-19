# Protected staging and movement recovery — 2026-09-19

This is a **lane sandbox experiment**, enabled by default in the Marcher & Monster
Balance arena and the standalone Vulture balance runner. Full-game recruitment
and round submission still use their existing deployment rules. The movement
fix applies to the shared native/Python Marching engines.

## Playtest rules

- Production in round N goes into protected, visible off-field staging. Even an
  explicit March command cannot release it before N+1. Manual additions follow
  the same rule. No targeting, damage, banishment, regeneration, construction,
  rooting attempts, pulses or charging occurs while staged.
- Start with **15 bodies per side**; 12 and Off are available for same-seed
  comparisons. Changing capacity resets the arena. Staged Sooge/Sinodek reserve
  their one-living-copy slots.
- Each side chooses Auto, Hold, or March ready group once. Choices made during
  playback apply at the next interval boundary. March releases the entire
  eligible group, then the control returns to Hold. Fresh production stays put.
- Auto assesses visible armies within 1,800 distance of its home gate, including
  friendly field units and its own eligible reserves. Its initial strength
  estimate is `(HP + Armor) × (Attack + 1)`, with the Vulture/Butcher matchup bonus
  when Butchers make up at least half the opposing force. It holds below 80% of
  the opposing score and may release a small viable force early. A full eligible
  reserve can release even against stronger pressure. This is a heuristic, not
  an exact combat forecast; hidden units and enemy reserves are not consulted.
- If staging exceeds capacity, complete oldest birth-round groups automatically
  march until the excess is covered. **Newborns never skip the wait**: an oversized
  fresh cohort remains protected until eligible, so the displayed count can
  temporarily exceed capacity. If the 64-body field limit prevents a complete
  release, the group remains protected. No body is discarded or split to fit.
- Released formations put Penitents/Lemek/Kurchin ahead of support, spread across
  the gate. Their IDs, original ownership and birth records remain intact.
- Playback now offers **0.5×, 1×, 2×, 3× and 5×**. Both reserve trays show real
  pieces, empty slots and ready/new counts. Hover distinguishes protected pieces
  from battlefield units. Monster height is reserved above the far gate so
  approaching sprites cannot overlap the enemy tray.

Vulture range stays **400**, tower range **600**, and Vultures keep **+1 damage
against Butchers only**. The goal-distance advancing-fire toggle remains on by
default. Small 42-unit collision footprints and same-seed seat swaps remain.

The sandbox has no unused Battle Window panel to remove. The agreed full-board
layout direction is to replace that placeholder with staging areas; important
battle presentation belongs in the later Resolution Theater integration. This
patch does not implement or advance that theater milestone.

## Why units were stuck

The swapped-seat screenshot seed `lane-30d27b94-0258ddb4` reproduced a stationary
Vulture screen with melee units repeatedly sidestepping back into the same
positions. The captured round-25 world is stored in the evidence fixture.

After **24 ticks without meaningful movement progress** (1.8 seconds at 1×), a
unit searches a bounded local grid for a legal route. It follows persistent
waypoints instead of immediately reversing its sidestep. If no local route is
found, it skips that target for 80 ticks and tries another. A moving target alone
does not count as movement progress. Tumler's hunting choice also respects the
temporary skip. Melee contact and forced taunts retain priority.

Routes check bodies, lane boundaries and walls, including intermediate points;
they do not teleport units, ghost through walls or remove hitboxes. Deliberate
shooting, construction, guard duty, birth holds and turrets are not treated as
movement stalls. Local search is bounded and dynamic crowds may take more than
one interval to clear.

## Results

All four comparisons below used the same seed, both automatic card producers,
the new movement fix, no manual opening, normal seats, and **109 rounds**.
“March” means release every eligible wave immediately after its mandatory wait.

| `lane-f881e7ec-e3aebe70` | Your goals | Enemy goals | Your bodies produced | Enemy bodies produced |
| --- | ---: | ---: | ---: | ---: |
| Staging off | 0 | 124 | 370 | 402 |
| 12 slots, Auto | 37 | 119 | 409 | 446 |
| 15 slots, Auto | 99 | 48 | 418 | 446 |
| 15 slots, March | 30 | 149 | 409 | 446 |

With 15-slot Auto, home scored its first goal in round 42 and first took the
cumulative lead in round 44. There were 33 pressure-hold decisions across both
sides. This demonstrates recovery on the reported seed and supports 15 as the
initial playtest capacity. It does **not** establish overall balance or guarantee
a comeback: the other screenshot seed, swapped, ended **49–2 after 30 rounds**
with 15-slot Auto. The sandbox has no castle/Lord defeat condition, so surviving
long enough to recover in a real match remains untested.

The card algorithm and seed are shared, but field-capacity waits and living
monster restrictions can change later production. These are whole-system
comparisons, not identical pre-recorded armies. The original screenshot's
0–211 result predates these patches; the current Off control is 0–124.

## Verification

Local runtime: **Godot 4.5.1 Linux headless**, plus the Python engine. The supplied
Windows runner remains pinned to the user's Godot **4.7.2 stable**; native Windows
visual acceptance has not been performed here.

- 60 staging checks: timing, protected HP/abilities, enemy/portal immunity,
  limited copies, capacity/overflow, complete releases, pressure decisions,
  six actual mirrored combat rounds, reserve UI, and 5× interval completion.
- 245 existing sandbox checks and 59 Vulture-preview checks pass. The existing
  direct-field UI regression explicitly selects Staging Off; the new suite
  exercises the default protected mode.
- **88 complete native/Python phases, 17,600 ticks**, match in full: range edges,
  damage bonuses, goal advance, spacing, the captured crowd in both orientations,
  and unreachable-target reselection. Five of the seven captured stalled movers
  moved or fought in the first phase; all seven did within two phases. The
  reflection includes hazards, builder ownership and navigation state.
- 19 Python Marching regression tests pass.
- 192 isolated counter battles (16 seeds in both orientations) all finish
  within the 12-round limit. Vultures beat Butchers in all 32 sampled 1v1 and
  32 sampled 4v4 fights. Penitents beat Vultures in 20/32 singles and 32/32
  squads; Butchers beat Penitents in 32/32 of each. These are sampled outcomes,
  not universal matchup guarantees.
- Five seeded trials cover **466 rounds**, checking global body conservation at
  every boundary. Results, histories, final worlds and source hashes are saved
  in the evidence files.

Evidence:

- `evidence/U13_STAGING_NAVIGATION_PARITY_2026-09-19.json`
- `evidence/U13_STAGING_TRIALS_2026-09-19.json` and `.json.gz`
- `evidence/U13_NAVIGATION_CROWD_FIXTURE_2026-09-19.json.gz`
- `evidence/U13_STAGING_COUNTER_BATTLES_2026-09-19.json.gz`

## Runner

From Git Bash inside the Corruptor checkout:

```bash
git pull --ff-only origin u13-basic-doctrine
bash Scripts/Sim/run_u13_vulture_balance.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The title must include **staging v1** and the launcher prints
**protected staging + movement recovery (2026-09-19)**. Enable both random-spawn checkboxes, choose
Continuous and 3× or 5×, then Start. Use the unchanged seed and Swap seats for
the opposite orientation. Logs go to `~/Downloads/Corruptor/Logs/`.

Reproduce a comparison with the headless runtime of your choice:

```bash
godot --headless --path . --script res://Scripts/Sim/U13LaneStagingTrial.gd -- \
  lane-f881e7ec-e3aebe70 109 15 Auto normal /tmp/staging-15-auto.json
```
