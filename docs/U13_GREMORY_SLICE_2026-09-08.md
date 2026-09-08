# Gremory: first U13 headless Lord slice

## Gate and scope

The user confirmed `U13 foundation runners passed: 9/9` on Godot 4.7.2 at
`215f5673f2045f536a5341202d207372f84cfa6c`. That cleared the shared-foundation gate.
This batch implements the five finalized Gremory mechanics through the U13 match
owner, and adds a tenth acceptance suite. Godot 4.7.2 remains the target runtime.

**Historical gate cleared:** the user confirmed **10/10 on Godot 4.7.2** for
`827e7cc0c2baba64a3fdcf3446cbc4273dc86ef2`. The subsequent actual Marching/combat
integration and its pending **11/11** gate are documented in
[U13_MARCHING_COMBAT_AUDIT_2026-09-08.md](U13_MARCHING_COMBAT_AUDIT_2026-09-08.md).
The scope below describes the original isolated ten-suite checkpoint.

This is a headless content slice. It does not add a playable scene, a UI/bot adapter,
a complete combat controller, or new Marching movement/contact rules. The included
phase adapter fixture supplies deterministic authoritative battle transitions; the
production controller must later feed that same transition path from actual combat.
In particular, the tests verify kill attribution and rewards, not contact finding,
whole-lane combat, movement of newborn Lord-spawned Marchers, or game balance.
U12 and its frozen playable reference are untouched.

## Implemented mechanics

| Mechanic | Declaration or trigger | Result |
|---|---|---|
| Predator of Ruin | Select `Lord` or `Castle` lane; fires Step 10A | Three Vulture Marchers; activation R1 blocks R2, ready R3. |
| Picking the Bones | First attributed enemy Marcher combat kill by an active Gremory player's Vulture during the Marching hook | Draw one card and create one Neutral Tear, once per player/round. Hazard kills and other suits do not qualify. |
| Sifting the Ruins | First Castle destruction while Gremory is active that round | Take actual discard top into Hand; one attempt per player/round. Defunct is not destruction. |
| Inevitable Ruin | Damaged standing Castle plus exactly two distinct owned Hand card IDs; fires next round at the first hook | Set that instance Defunct, with zero Integrity. Repair does not cancel doom. Missing/non-standing target fizzles; payment remains spent and no retarget occurs. |
| Gem Dagger | First Guard defeat each round while the Breach contains Gremory | Both players draw one card, once globally per round. Does not require an active Gremory on the battlefield. |

Inevitable Ruin's target relation is `any`: the finalized specification does not
limit it to enemy structures. Standing Defunct structures remain structurally
present; Ruined/Profaned targets are illegal. No additional cooldown was specified
for Ruin: zero full blocked rounds, with the existing one-activation-per-round lock.
The original declaration survives Banishment, as required by the shared armed-effect
rule. Stable IDs prevent a replacement Castle inheriting an old target reference.

The Vulture profile matches the inspected baseline `MarchingEngine.STANDARD_STATS`:
HP 5, attack 2, armor 1, regen 1, fixed movement step 6, armor bypass. Spawn origins
are the pending effect ID plus ordinals 0–2. Birth round, lane, direction and initial
fixed-point position are data. This is not an adaptation of the U12 contact engine;
movement eligibility for these Lord spawns must be covered when wiring the U13
Marching controller, without silently inheriting U12 commitment-spawn exceptions.

## Shared foundation extensions

### Card zones and declaration payment

`U13CardZones` gives physical card entities one authoritative location: deck,
discard, either Hand, or an active Guard role. Duplicate IDs across piles, incorrect
ownership, Guard/Hand overlap and untracked ordinary cards reject the world.
The bottom-to-top pile convention matches the existing `DrawEngine.pop_back()`.

World data contains:

```text
card_zones: {hands: [p0_ids, p1_ids], deck: ids, discard: ids, hand_limit: 10}
neutral_tears: integer
breach_lord: string
```

Rules may now specify `discard_count`. The selected identities live in the frozen
**declaration cost** as `cost.discard_ids`, not in a later prompt. Common legality
checks exact count/type/uniqueness and configured resource costs. The match owner
checks current ownership/Hand location, reserves payments across the full queue,
and commits discard in submitted order at joint lock. Failed preview/submission
never changes live piles. The original cost remains in pending/spent records.

Drawing respects the hand limit. An empty deck recycles discard using keyed
Fisher–Yates draws before checking that limit, matching the baseline ordering.
Sifting only takes discard top; it neither draws from deck nor recycles it. A full
Hand or empty pile consumes that trigger's first-event opportunity for the round.
Picking the Bones still creates its Tear when drawing is blocked. If both players
have active Gremory, shared-pile rewards use the explicit Reflex player order.

### Context and content lifetime

`U13Match` retains its previous callback API. Optional new constructor arguments
provide a contextual hook, a strong RefCounted content owner, and a pure world
validator. Contextual hooks receive copied `{hook, round, seed, player_order, world}`.
The strong owner keeps content Callables alive after a factory returns. None of
these runtime objects enter serialized game data. Their behavior is covered by the
required policy/adapter implementation identity; snapshots still reject mismatches.
The world validator runs on start, restore and transformed state installation.

`U13Gremory.create_match(adapter_version)` wires both powers, their common validator,
resolvers, event reactions and player projection. The adapter version must identify
the actual deterministic driver implementation. The optional driver receives hook
context and returns an array of authoritative transition commands. Without a driver,
the match can resolve declared powers but has no base combat/development simulation.

### Attributed events, immediate reactions

`U13BattleEvents` handles damage application/removal, Guard defeat, Castle
destruction/repair, Banishment and Breach changes. Commands have stable semantic IDs;
a repeated command ID in the same round is rejected. Combat damage requires an
existing living enemy Marcher in the same lane and the Marching hook. Damage is the
**already resolved amount** from the combat adapter; this module is not a second
armor/damage calculator. Hazard damage is distinctly attributed.

Facts retain attacker and victim state before removal. Gremory reactions run after
each transition, before the next command. This ensures Sifting sees the discard top
at the first destruction, not at the end of a batch. Per-round trigger ledgers and
command identities persist through snapshots; replaying an already consumed trigger
does not award it twice. Destroyed entities are retired through the shared registry;
setting Defunct preserves the Castle instance and emits a distinct event.

Card draw events retain authoritative identities but expose a drawn card only to its
recipient. Sifting identities are already public discard information. The player
world projection exposes its own Hand, public discard/Guard/board entities, counts
for the opponent Hand and deck, Neutral Tears and Breach. It omits deck order, seed,
internal command schedules and trigger bookkeeping.

## Acceptance runner

`U13GremoryTestRunner` covers:

- Legal/illegal lane and damaged-target declarations; exact distinct Hand payment.
- Step 10A timing, three standard Vultures, stable spawn IDs, cooldown boundaries.
- Joint-lock payment, next-round firing before Repair, repaired targets, Banishment,
  missing-target fizzle without a new payment refund or retarget.
- Combat versus hazard attribution; wrong suit; once-per-round draw/Tear rewards;
  hand-limit behavior and next-round trigger resets.
- Actual discard top, mirror-Gremory ordering, empty discard, repeat-event handling.
- Gem Dagger on/off Breach, both-player draws, hand limit, global once-per-round cap.
- Keyed discard recycling and private draw views.
- Combined Predator/Ruin declarations with exact JSON save/restore between every
  hook over three rounds, including before joint lock and delayed firing.

The wrapper preflights the new shared dependencies and Gremory, retains all nine
previous suites, and appends this suite. It still rejects logged engine errors even
when Godot exits zero. Runtime success is only the exact final **10/10** footer.

```bash
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```


## Accepted plan amendment: random-legal declarations

The user's [Random-Legal Doctrine Tier addendum](U13_RANDOM_LEGAL_ADDENDUM_2026-09-08.md)
adds a legal random-declaration path to each power's definition of done.
Gremory's verified correctness checkpoint does not complete that new requirement.
The chooser and frequency/reachability instrumentation remain pending, scheduled
after the smoke-scene gate and before adding another Lord. Milestone 3 proves
correctness, not balance; Level 5.5 batches report distributions and trigger counts,
never random-bot win rates. Real doctrine retains priority and Milestone 9 stays put.
