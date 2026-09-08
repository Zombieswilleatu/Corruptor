# U13 spatial Marching — 2026-09-08

## Purpose and scope

Marchers now spawn and move in two authoritative fixed-point coordinates. They steer toward enemy Marchers in their own lane. Physical contact selects opponents; the board does not invent offsets or move chits toward opponents chosen by a one-dimensional simulation.

This is shared movement work following the Gremory board checkpoint. It does not add another Lord, Development, Hunt, normal draws, victory, or balance doctrine. U12 and the main scene are unchanged.

## Rules in this implementation

- `x_fp` is distance along the lane (0–2400); `y_fp` is lateral position (0–600). Both serialize with the Marcher. Owner 0 advances toward 2400 and owner 1 toward 0.
- Spawn candidates use keyed RNG purposes `SPAWN_FORWARD` and `SPAWN_LATERAL`, keyed by immutable entity identity and candidate ordinal. Forward spread is 0–120 from the owner's gate; lateral centers are 90–510. Up to 64 candidates seek allied center clearance of 84. If all are crowded, choose the candidate with greatest clearance; this does not introduce a spawn rejection/capacity rule.
- Friendly center avoidance prevents movement from worsening a separation below 84. It is a small center collider, not a requirement that the artwork never overlaps. Blocked units try a stable lateral detour.
- A free Marcher seeks the nearest enemy in its lane. Equal target distances use immutable ID order. Movement uses integer coordinates, integer square-root distance, and explicitly rounded fixed-point steps. All targets are read from one tick snapshot; allied clearance is applied in immutable ID order.
- Opposing centers within 180 are in contact. The collision distance and spread values are initial spatial tuning, not balance conclusions. Existing suit attack, armor, regeneration, speed, and the commitment birth-round movement hold remain in use. Predator's Lord spawns can move in their birth round.
- Each lane runs **one active duel at a time**. Other Marchers continue moving until they touch an enemy, then wait. Oldest contact tickets take priority; equal contact choices use keyed `CONTACT_TIE` selection over stable candidates. Separate lanes may fight concurrently.
- Both attacks in a duel exchange land simultaneously. Exchanges occur eight simulation ticks apart. Once the duel ends, the next touching pair may begin on the following tick. No participant is teleported to a midpoint.
- A phase remains 200 ticks. An unfinished duel persists across the round boundary, including original participants, exchange history, and next exchange time. Existing round-start regeneration still applies. Removal, ownership/lane changes, or relocation that separates participants interrupts the duel before further attacks.
- Actual defeats still use the existing Gremory reaction path. Waiting/arrival is considered after contact, so a gate defender cannot be bypassed by the arrival flag.

## Replay and presentation

`MARCHING_STARTED` identifies `U13_MARCHING_SPATIAL_V2`. `MARCHER_CONTACT` records the actual contact pair, `MARCHING_TICK` records positions/HP/armor and active fighters every tick, and `MARCHING_FINISHED` records the final population. `MARCHER_CLASH` remains the completed duel summary for existing consumers.

The full board and smoke viewer use recorded positions. Playback interpolates both display coordinates between ticks; these display floats never enter match state. Health rings use recorded damage. The full board retains the original chit atlas and continuous lane surface, with only the Lord/Castle boundary.

The combat match policy includes the Marching version. Old V1 combat checkpoints cannot silently resume under V2. Restart the board after updating. The legacy tape reader remains available for earlier event tapes.

Full tick tapes deliberately favor inspectability. They increase event-log/save size; compacting tapes is a separate optimization and must preserve exact playback and replay checks.

## Verification

Added `U13SpatialMarchingTestRunner.gd` and registered it in the wrapper, bringing the gate to **14/14**. Coverage includes actual two-axis spawn spread, birth hold, physical contact versus forward-coordinate coincidence, steering, lane isolation, insertion-order replay, sequential joins, round-boundary duel JSON replay, malformed state rejection, and recorded-position playback.

Existing integration tests retain suit-stat, death/reward, commitment, replay, and UI coverage. They now compare movement against actual spawn positions and recorded endpoints rather than assuming all six Predators die at the final tick of their first phase.

Workspace verification: gdtoolkit grammar/format checks and Bash wrapper orchestration checks with a stub executable. **Godot 4.7.2 compilation, the 14 real suites, and visual verification remain local gates; no engine pass is claimed here.**

Run:

```bash
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

After 14/14, launch `run_u13_board.sh` with the same executable. Queue Predator on a lane and watch the real spread, convergence, shrinking health rings, and waiting joiners. A late-starting fight may finish next round. Do not treat random-legal match win rates as balance evidence.


## Smoke timeout follow-up

The first local verification reached U13Smoke and hit its 30-second watchdog. Full unit records on all 200 ticks amplified the cost of subsequent match snapshot validation. Tick rows now use `attribute_delta_v1`: immutable metadata and unchanged attributes are inherited from the phase-start unit; coordinates, HP and armor remain explicit. Each tick is independently reconstructed against that baseline, so scrubbing cannot accumulate deltas. Full tick tapes remain readable. A regression compares full and compact tape samples, including fractional times.

Smoke tests print section timings and scenario starts to distinguish a slow section from an apparent hang. The default watchdog remains 30 seconds. This addresses a concrete source of avoidable work; runtime improvement and completion still require local Godot verification.
