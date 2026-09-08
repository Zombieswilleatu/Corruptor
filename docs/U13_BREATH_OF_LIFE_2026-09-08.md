# U13 Breath of Life and shared lane auras

Runtime: Godot 4.7.2 stable. Branch: `u13-lord-overhaul`.
The first Humbaba slice is locally accepted after the fixture identity correction
at `fc65cb4`. This slice completes Breath's headless rules path; the playable
Humbaba picker/controls follow its local gate.

## Timing and behavior

Breath of Life declares one lane, costs nothing, and fires at Step 10D. Friendly
Marchers occupying that lane gain +1 Health regeneration and +25% movement speed.
The aura lasts for the firing round R and the next round R+1. It expires at Step 2
of R+2; the two-round cooldown blocks R+2 and R+3, and permits reuse in R+4.

| Round | Step 3 regeneration | Marching | Readiness |
| --- | --- | --- | --- |
| R | Normal; Breath has not fired yet | +25% in the selected lane after Step 10D | Armed/active |
| R+1 | Normal regeneration +1, capped at maximum HP | +25% in the selected lane | Active |
| R+2 | Normal; aura expired at Step 2 | Normal | Cooling, first blocked round |
| R+3 | Normal | Normal | Cooling, second blocked round |
| R+4 | Normal unless another aura applies | A new declaration may apply | Ready |

This preserves the canonical regeneration hook. There is no retroactive heal on
casting or second regeneration pulse at Step 10D. The timing consequence is two
Marching phases but one intervening bonus regeneration pulse. Waiters retain the
existing rule that they do not regenerate. A Penitent healed above 1 HP does not
meet Endurance's final-HP condition. Changing regeneration timing would be an
explicit shared-rule change, not a hidden exception in Breath.

Membership is queried from each body's current owner and lane, never captured at
activation: entering gains the benefit, leaving loses it, late spawns qualify,
and enemies do not. An armed power and its subsequent aura survive Banishment.
Muster and Breath may share one submission; Step 10A spawns precede Step 10D.

## Implementation

`U13LaneAuras` uses `U13PersistentEffects` as the sole lifetime/identity owner.
The match owner supplies a detached active-registry view to ordinary hook
consumers. Four small lane/owner modifier records are compiled once per phase;
movement ticks query those records. No entity scan of active effects occurs per
body/tick, and no per-body aura tags or second world-state lifetime are stored.

The movement bonus composes with Rout before integer rounding. A base-3 Penitent
moves 750 fixed-point units over an unobstructed 200-tick phase under Breath;
Rout recovery plus Breath produces 375, preserving the exact 1.875 average step.
Retreat direction, steering, contacts, collision spacing, waiting, readiness and
authoritative playback events remain owned by Marching. Base stats are unchanged.
No visual-only movement offset or sequential RNG is used.

Restore binds aura payload, stage sequence, lane and declaration parameters to
trusted rules, and binds active lifetime to its waiting cooldown. Forged bonuses,
extended stages, changed targets and detached clocks are rejected atomically.
Explicit firing rounds and the shared immediate-fire sentinel both restore.

The Humbaba content profile advances to `U13_HUMBABA_BREATH_V2`, with
`U13_LANE_AURAS_V1` pinned in its policy/world. Old Humbaba snapshots are rejected
rather than silently reinterpreted. Existing Gremory/Deimos policies are retained.
Both Humbaba powers now appear in the central random-legal candidate vocabulary.
The existing `--roster=humbaba` batch can exercise either and reports their normal
declaration/resolution/fizzle counters. These are frequency measurements, not
balance evidence.

## Local gate

Two new bounded runners cover actual movement/regeneration and the full match
lifetime path. Coverage includes late spawns, lane transitions, enemy exclusion,
HP caps, canonical once-per-round healing, expiry, Rout composition, declaration
rejection, keyed choice, per-hook replay, JSON restoration, corrupted snapshots,
and armed Breath after Banishment.

`--humbaba` now runs ten processes: LaneAuras, Breath, the three prior Humbaba
runners, Rout, SpatialMarching, Hunt, Deimos and CastleLoadout. The full foundation
is 30/30; the board gate remains 6/6. All retain the default 30-second deadline,
completion marker, engine-error scan and fail-fast behavior. The five-round
lifetime fixture uses an empty field; physical movement is tested separately.

```bash
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  --humbaba
```

Expected footer: `U13 Humbaba runners passed: 10/10`.

Workspace checks cover GDScript grammar, static dependency/call review and stub
engine wrapper behavior. They do not execute the Godot compiler or gameplay.
The user's Godot 4.7.2 gate remains authoritative; board integration waits for it.
The accepted Castle damage/construction artwork backlog remains queued for UI work.
