# U13 Deimos: artillery and siege slice

## Gates and scope

Gremory's random-legal gate was locally accepted on Godot 4.7.2: four seeds,
24 measured rounds plus identical independent replays. Both sides spawned 48
Marchers; all 24 Predator and 10 Inevitable Ruin activations resolved. The user
confirmed moving forward after the foundation gate. The responsive-board
performance pass remains accepted.

This implementation starts Milestone 3's Deimos work. It is a headless rules
slice, not a complete Deimos playable build. The existing Gremory board keeps its
opening, layout and policy. U12, the main scene and project settings are untouched.

Implemented here:

- Shared Siege Engine fire, operational floor, persistent targeting and ruin state.
- War Machine: one extra normal 2-damage shot at Step 7; operational engine checked
  both at declaration and firing. No extra cost or blocked future round is specified
  in the final Lord design, so the shared zero-round clock prevents duplicate use
  this round and permits declaration next round.
- Fear Aura: before Deimos's Siege resolves, return the lowest-value enemy Castle
  Guards, count `1 + Threat`, ties by stable entity ID. Returns preserve card
  identity, use Hand (not discard), and do not emit Guard defeat rewards. Return is
  not a draw, so the draw hand-limit gate is not applied. The once-per-Siege ledger
  survives saves and repeated delivery of the same round's fact.
- Spoils of War: attributed enemy Castle Ruination gives the living Deimos owner
  an extra personal Tear on his first Ruination, then an extra Neutral Tear on each
  later Ruination. The lifetime count survives rounds, Banishment and saves. It
  does not reset when another Castle falls or when the Breach changes. Ordinary
  Castle-destruction consequences are retained.
- Cracked Foundations: while Deimos occupies the Breach, effective maximum
  Integrity is base maximum minus five. Existing Integrity is clamped to that
  ceiling; already-damaged Castles below it do not take another five damage. On
  exit the ceiling rises, but current Integrity is not healed.
- War Foundry eligibility: only a living Deimos's own ruined Siege Engine can
  qualify for ordinary reconstruction. A profaned Engine, enemy structure, plain
  Castle or unavailable Deimos cannot qualify. Eligibility grants no free build.
- Random-legal War Machine candidates and Deimos/mixed headless frequency batches.

Still open: the actual normal Construction/Reconstruction action, Rout, full
Development/Repair/Profane/Hunt migration, Veil/victory, and Deimos board controls.
Rout is explicitly permitted to follow in the movement-state work by the plan.
This does not check off the entire Deimos definition of done or Milestone 3.

## Structure contract and identity

`U13Structures` owns `U13_CORE_ARTILLERY_COMBAT_V1`, an explicit second profile.
The existing Gremory-only plain-Integrity profile remains available. New structures
carry base/effective maximum Integrity, current Integrity, status, saved artillery
target ID and an acquisition counter. Status distinguishes standing, defunct,
ruined and profaned. Ruined/profaned structures have zero Integrity.

Operational Siege Engines need at least seven Integrity. Normal fire runs at
`POST_REPAIR_ARTILLERY`, after the Development slot, once per engine per round in
player resolution order and then stable engine-ID order. War Machine follows the
match owner's existing pending-before-ordinary-hook contract: queued extra shots
resolve in the established player/queue order, followed by the normal sweep. An
extra shot can disable a later engine; that engine's queued extra shot fizzles and
its normal shot is skipped. No new prompt appears between them.

Acquisition chooses uniformly from sorted enemy standing/defunct structure IDs,
using the match seed, immutable engine ID, `ARTILLERY_TARGET` purpose and persisted
acquisition count. Full repair does not change the target: this follows the
addendum's explicit “same structure until Ruined” rule. Ruined/profaned targets
are unavailable and a new target is acquired when the engine next fires. With no
eligible target, a finite no-target event is emitted. No target is a fabricated
player choice. Retarget timing after Profane can be reviewed when that action is
migrated; it is not currently an available submission.

The new `ruin_castle` authoritative transition preserves the entity and immutable
ID, instead of retiring and later resurrecting it. It emits the existing
`CASTLE_DESTROYED` fact with attacker ownership and cause retained. This lets
Gremory Sifting and Deimos Spoils share the transition. A defunct Castle hit by
positive Siege/artillery damage becomes Ruined. Ruination clears a destroyed
engine's own target. Reconstruction must eventually update this same structure;
it must not allocate or reuse another entity ID.

Artillery deals damage directly to the structure. It does not count as a Siege
commitment, consume waiters, eject Guards, or award Siege Souls. It retains the
existing once-per-round normal Castle Neutral Tear and content reactions; Spoils
bonuses are additional and do not inherit that cap. Full universal personal Tear
and Veil accounting remains outside this profile; its new personal counters record
Spoils only. Do not interpret them as the complete future economy.

Gremory's public discard reclamation is retained when War Machine Ruins a Castle.
Extra-shot events are flattened to the public power path only when both event
views exactly equal the authoritative event. A future private reaction is rejected
instead of leaking it. The match resolver context now supplies player order for
cross-Lord reactions; the timeline and pending-effect ordering are unchanged.

## Construction clarification

The user clarified the earlier shorthand explicitly:

> i did mean any construction btw. you can spend whatever and still get the passive bonus.

Any Construction receives its passive bonus regardless of the spending choice.
A Construction token is not a prerequisite for that bonus. Do not implement a
special token-only passive path or make the bonus disappear for another permitted
Construction payment. This supersedes the prior interpretation of “with a const
token.” It specifies Construction behavior; do not extrapolate it into progress
on a round with no Construction action. The tick rate and completion threshold
must still be pinned when implementing the ordinary action.

Actual Construction/Reconstruction remains outside this artillery slice; the
War Foundry eligibility check itself grants no free progress.

## Local parser correction

The first local run caught a test-helper collision: `_set` overrides Godot's
`Object._set(StringName, Variant) -> bool`, so a three-argument helper with that
name cannot compile. Rename the helper and every call to
`_patch_entity_attributes`. This changes test plumbing only. Grammar parsing is
available here; the corrected runner still needs authoritative Godot verification.

## Tests and local command

The full wrapper now has **17** suites. `U13DeimosTestRunner` covers operational
floor boundaries, persistent/reacquired targets, JSON targeting replay, no-target
termination, extra-shot counts, firing-time disable/fizzle, guard return ordering,
repeat-event handling, first/later Spoils, retained ruined identities, reconstruction
eligibility, Breach ceiling entry/exit, invalid restoration, joint submissions,
per-hook JSON restore/replay and a deterministic mixed-roster batch. The preceding
16 suites remain required with their normal 30-second watchdog.

```bash
u13_godot="/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh "$u13_godot" &&
bash Scripts/Sim/run_u13_random_batch.sh "$u13_godot" --roster=mixed
```

Expected: `U13 foundation runners passed: 17/17` and
`U13 random-legal batch completed: OK`. Share Downloads `u13_random_mixed.json`
and `u13_random_mixed.log`. `--roster=deimos` runs mirrors and writes
`u13_random_deimos.*`; the default `--roster=gremory` retains `u13_random_legal.*`.
Default four seeds, six rounds and independent replays are unchanged.

The new opening is deliberately labeled: four cards and two Wright Guards per
side, one plain Castle at 8/21 and one prebuilt Siege Engine at 12/21, empty Breach.
It exercises artillery without inventing Construction. Its density distribution
must not be compared directly with the different old Gremory opening as a balance
comparison. Reports pin roster and profile and add normal/War Machine shot counts,
Fear Aura events and personal Tears by source. No win rates are produced.

Implementation-environment checks cover grammar, Bash syntax and simulated
launcher sequencing/error handling. No Godot executable is available here;
Godot 4.7.2 compiler and runtime verification remains local and pending.


## Local mixed-batch acceptance

The user supplied `u13_random_mixed.json` after the parser-helper fix. The Godot
4.7.2 report contains four seeds, six rounds each, all marked replay-verified, no
pending effects at the limits, and 200 Marching ticks in each of 24 measured rounds.
The summary density histograms agree with the per-round records.

Observed coverage:

- Eight Castle destructions and eight Gremory Sifting events.
- Five Fear Aura events; Spoils produced three personal Tears and one extra
  Neutral Tear across the batch.
- War Machine: 13 declarations/resolutions and 12 actual extra shots. The one
  no-shot activation is seed `u13-frequency-v1:1`, round six. This is consistent
  with the explicit successful no-target path; the frequency report does not
  retain that event separately, so do not call resolutions and shots synonymous.
- Deimos spawned 16 Marchers; Gremory spawned 50. Both spawned in ten rounds.
  Start density mean 8.5, range 3–14; end density mean 7.25, range 3–13.
- Gremory reached five Lord-lane waiters in seed `u13-frequency-v1:2`, rounds
  four through six: one sustained occurrence across three rounds, not three
  independent threshold discoveries. The count persisted for 402 fixed ticks.

These results accept the mixed-batch measurement/replay path. They do not complete
Construction, Rout, full-game economy, or balance validation. The opening has
prebuilt structures and lacks normal round draws, so its frequencies retain that
scope. This documentation update changes no runtime behavior and needs no test
rerun by itself.
