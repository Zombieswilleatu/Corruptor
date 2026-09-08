# U13 Castle loadouts and Deimos Rout

Runtime: **Godot 4.7.2 stable**. Branch: `u13-lord-overhaul`.

## Accepted design amendment

Each player chooses five Castle slots. A type may appear at most twice.
The catalog is Keep, Bastion, Summoning Circle, Stockpile, and Siege Engine.
A duplicate is a physical instance with its own immutable identity, Integrity,
construction state, Repair lock and (for an Engine) artillery target history.
Ruination and reconstruction retain that identity and occupy the same slot;
losing a Castle does not authorize a third copy of its type.

**All Castles controlled by a player share one Castle Guard zone.** The user's
explicit correction supersedes the per-instance Guard-zone proposal. Siege,
Fear Aura and Guard-slot uniqueness retain the existing shared-zone behavior.
There is no type-to-type or slot-to-slot mapping for Castle Guard effects.

The build lifecycle remains the locally verified Construction rules:

- Construct supplies +3 passive Integrity whether free or card-funded;
  acceleration uses the existing payment rules.
- Unbuilt/under-construction Castles are protected and supply no printed effects.
- At 7+ Integrity, the player may **Commission** that instance. This is the
  existing one-way `Activate` command and consumes the single Castle action.
- Commissioning supplies no extra Integrity. The Castle becomes exposed;
  its printed effects require at least 7 Integrity. Subsequent growth uses Repair.
- Even a full protected build awaits the player's Commission choice.
- An exposed Castle that falls below 7 remains exposed. Repair and War Foundry
  retain their already verified restrictions.

Instance effects generally stack. Every operational Engine takes its own normal
2-damage shot at Step 7, using its own locked target/acquisition key. War Machine
chooses **one operational Engine you control**, which fires exactly one extra
shot. Two Engines do not provide two War Machine activations. Extra shot timing
retains the existing same-hook contract: pending powers, then normal artillery.
Every shot rechecks its source and target; destruction can prevent later shots.

## Setup boundary and implementation scope

`U13CastleSlots.selection_valid` owns the five-slot/two-copy catalog constraint.
`U13CoreScenario.loadout_world(lords, selections)` accepts explicit choices;
`start_loadout(seed, lords, selections)` creates a correctly configured match.
The returned setup draft and stored choices do not alias one another. The
match seals the chosen composition; ordinary transforms cannot replace it.
Snapshots validate each instance against the chosen slot and type, and reject
mismatched current/presented loadouts.

Stable IDs derive from player setup origin plus physical slot ordinal, never
Castle type, Integrity or construction state. The slot is presentation order,
not a new Guard zone. Player projections include the loadout and typed instances.

This prepares the **eventual pregame Lord/Castle picker**. No picker screen or
production opening economy is introduced here. Only implemented Lords (Gremory
and Deimos) may start this rules slice. The setup shell allocates unbuilt Castles
and retains the exercise fixture's cards/resources. The separate loadout batch
explicitly commissions two Engines per side to exercise duplicate artillery.
Neither fixture decides how many completed Castles production starts with.

Siege Engine is the currently migrated printed Castle effect. Keep, Bastion,
Stockpile and Summoning Circle now have selectable stable identities and the
Construction lifecycle, but their printed powers still need their U13 migration.
They are not evidence that those powers work or stack. Their eventual instance
semantics must be implemented and tested individually; there is no global
nonstacking rule. Existing Gremory board, U12 and project launch settings are
unchanged.

## Rout

Rout declares one lane through shared legality and fires at **Step 10D**.
Membership is captured at firing: enemy Marchers then in that lane, including
Step 10A spawns and any already revealed commitment bodies. Later spawns never
inherit either stage. An empty lane is a legal declaration with an empty cohort;
the activation and cooldown are still spent.

| Round relative to firing | Affected surviving bodies | Power clock |
| --- | --- | --- |
| R | Retreat at full base movement speed | Active |
| R+1 | Resume forward movement at half speed | Active |
| R+2 | Normal movement | Cooldown 1 |
| R+3 | Normal movement | Cooldown 2 |
| R+4 | Normal movement | Ready |

The existing persistent registry owns the two-stage lifetime and the central
cooldown starts on expiration. Its payload retains the captured entity IDs;
unit status references that lifetime. Snapshot checks reject missing/forged
lifetime references, unlisted members, fractional dates and future phase dates.
Retired cohort members remain historical IDs rather than becoming fresh targets.
Recovery never re-queries the lane or rescans for new enemies.

Movement decisions made explicit for the current spatial model:

- Rout releases a waiter from its banked state. It does not erase the body.
- A retreating body moves toward its owner's home edge and does not steer back
  toward an enemy. Existing friendly center spacing and lateral detours apply.
- Bodies retain their existing spawn-readiness delay; Rout does not advance an
  otherwise unready commitment body early.
- Retreat may leave an ongoing duel. Contact combat still applies while bodies
  intersect, but exchanges stop immediately after physical separation. It does
  not grant damage immunity or permit ranged contact damage.
- Reaching home clamps position without creating an arrival or a waiter.
- Recovery uses ordinary forward steering/contact behavior at half base speed.
  Odd fixed-point speeds alternate halves across ticks: a speed-3 Penitent
  travels 300 rather than 200 units over an unobstructed 200-tick recovery phase.
- Base speed, owner and forward direction are not overwritten by the status.
  The existing non-Rout trajectory/tape contract remains the spatial V2 model;
  Deimos snapshots separately pin the new Rout policy/version.

Both lane declarations are offered by `U13DeimosCandidates`; U13Legality filters
and U13RandomLegal chooses with the existing keyed purposes. Real doctrine
priority is unchanged. Historical mixed/Construction batch numbers are not
expected to reproduce under the expanded power-choice domain.

## Verification and local handoff

Added `U13CastleLoadoutTestRunner` covers catalog constraints, setup/identity,
shared Guards and Fear Aura, independent Engine shots, selected War Machine,
protected copies, reconstruction eligibility and atomic snapshot rejection.

Added `U13RoutTestRunner` covers membership, waiter release, late spawns,
readiness, both movement directions, odd-speed recovery, home-boundary behavior,
ongoing contact escape, effect-ID binding, per-hook JSON replay and readiness
through R+4. The ordinary Deimos random check now accepts either implemented
power instead of assuming every random choice must be War Machine; dedicated
artillery and duplicate-Engine tests still assert War Machine's exact behavior.

The focused wrapper runs seven processes with the unchanged **30-second**
per-process limit. Full foundation now contains 21 runners. Script grammar and
shell launcher behavior can be checked in the implementation workspace; only
local Godot 4.7.2 execution is authoritative engine verification. The user has now reported the focused **7/7 green** on Godot 4.7.2.
The subsequent loadout batch also completed OK (see acceptance below).

```bash
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  --castle-rout
```

Expected: `U13 castle-rout runners passed: 7/7`.

After that gate, the bounded duplicate-Engine frequency/replay batch is:

```bash
bash Scripts/Sim/run_u13_random_batch.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  --roster=loadout
```

Reports go to Downloads as `u13_random_loadout.json` and `.log`. Four seeds,
six rounds and independent replay are the defaults. The report distinguishes
shots by Engine identity, Rout activations/affected bodies/empty cohorts and
recovery events. Counts are frequency/coverage observations, never win-rate or
balance evidence. Existing batch and wrapper error/timeout/report-preservation
behavior remains in force.

## Prior Construction gate accepted

Before this amendment, the user reported Construction **2/2** green at the
30-second default. Random-path total: 13,838 ms; trial 4,597 ms and replay
4,611 ms. The subsequent four-seed, six-round Construction batch completed OK
with replay checks: 24 measured rounds, four reconstructions, seven activations
(Integrity 7–12, including three at 7), nineteen repairs and no reported fizzles.
This is acceptance of the prior Construction slice, not a 21/21 claim for the
new loadout/Rout changes. The pasted summary is the evidence; the full JSON was
not supplied for this final prior batch.


## Castle/Rout local acceptance

The user reported the focused seven-runner gate green, then supplied console
output from `--roster=loadout`: four seeds, six rounds per trial, each followed
by independent replay, ending `U13 random-legal batch completed: OK`.

Across 24 measured rounds: 72 normal artillery shots and 16 War Machine shots,
with nonzero shot counts from both Engine instances on both sides. Six Rout
activations resolved without reported fizzles, affecting 19 bodies; none had an
empty cohort. Five Commissions occurred at Integrity 7–8, alongside 11 repairs,
one reconstruction and five Castle destructions. These are coverage/frequency
observations, not balance conclusions. The console summary is the evidence;
the full JSON was not attached for this run. This does not claim full-foundation
22/22 or local acceptance of the later board integration.
