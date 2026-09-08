# U13 Lord/Castle picker and development board — 2026-09-08

## Subsequent interaction update

The picker and instance model remain. The default board now uses direct card
and lane targets, on-card Commission and all-in; see
[U13_DIRECT_BOARD_2026-09-08.md](U13_DIRECT_BOARD_2026-09-08.md).
The detailed staging-button flow below describes the preceding fixture.

## What changed

The explicit U13 board launcher now opens a pregame picker. Choose Deimos or
Gremory for each side and fill five Castle slots, with at most two of any type.
The opponent remains the existing random-legal exercise bot. The picker calls
the shared Core loadout boundary; committed types stay fixed for the match.
New loadout starts a new match, Cancel returns to the existing board, and
Restart repeats the current selected opening and seed.

Every Castle card shows its slot, selected type, Integrity and lifecycle.
Duplicate types have distinct IDs and independent state. Target menus use slot
and type; protected construction is omitted from Siege and Ruin attack targets.
The existing U12-derived board arrangement, art catalogs, hand inspection,
right-side Marching lanes and health-ring playback remain in use.
**All Castles still share one Castle Guard zone per player.**

## Explicit exercise openings

- **Quick start** (default): each player's slot 1 is commissioned at 12/21;
  slot 2 is protected construction at 7/21; slots 3–5 are unbuilt. Default
  selections put Siege Engines in slots 1 and 2, making Commission and
  War Machine immediately exercisable.
- **Construction start**: all five copies are unbuilt and protected.

Both use existing fixture hand/deck/Guard resources and two Repair tokens per
side. This does not decide the production starting economy. Siege Engine
artillery is implemented; the other four Castle types have identity,
construction, Commission and Repair but their printed effects are not yet
connected. Hunt, ordinary draws and victory are still outside this board slice.
The picker and header say so. No U12 scene or `project.godot` changes.

## Orders and payments

The combat prompt also offers one optional Castle action:

1. Choose Construct, Commission or Repair, then the specific Castle copy.
2. Select payment cards in the hand, where applicable, and Stage the action.
   Construct may be free and retains +3 passive progress with any payment.
   Commission uses no cards or token and maps to the existing `Activate` order.
   Repair uses cards and optionally one Repair token (+3).
3. Staged Castle payment cards leave the available hand. Choose Siege/Ward
   using remaining cards, or Skip Combat. Clear Castle action returns its cards.
4. Next opens the separate Lord powers prompt with **no simulation advance**.
   Combat and Castle orders remain staged. Ruin may reserve two remaining cards.
5. Resolve submits everything together. No Powers clears only powers; it keeps
   combat and Castle orders. Back to combat clears powers and preserves the
   Castle reservation. Empty hands still have Resolve/No Powers/Skip Combat.

Staging and final submission ask the same U13 owner validator. UI labels do not
implement another rules engine. The full submission still detects shared
payment identities and invalid targets. Construction does not advance merely
because its unfinished target is remembered: submit Construct for that round's
progress. Commission is explicit at 7+, preserves current Integrity and removes
protection permanently; subsequent improvements are repairs. The UI displays
repair locks and construction state, and the owner enforces eligibility.

## Lord powers

Gremory retains Predator of Ruin and Inevitable Ruin, including enemy-only
instance targets and delayed-firing notice. Deimos gets War Machine and Rout:

- War Machine chooses one currently operational own Siege Engine for one extra
  shot. That Engine retains/acquires its target through the existing artillery
  rules. It does not multiply all Engines' fire.
- Rout chooses an enemy lane. UI status distinguishes its active/recovering
  lifetime from the two cooldown rounds that begin after expiration.

Power names remain the section headlines above targets. Repeated queue clicks
are no-ops, with Queued status; Clear powers allows a different choice. Human
submissions can combine the two legal powers. The random bot still follows its
existing one-power chooser policy through Core enumeration and U13Legality.

## Responsiveness and verification

The existing BoardJob remains the only round-resolution path. Its independent
session fork now carries setup choices and seed/opening behavior; the worker
plans the opponent and resolves hooks, while the rendered board remains intact.
Only a successful complete result is published. Marching playback and normal
window-close handling are unchanged. The new session restores checkpoints with
the matching Deimos/Construction/loadout owner and rejects mismatched setup.

The new `U13LoadoutBoardTestRunner` exercises the actual picker and scene:
invalid third copies, cancellation, instance cards and shared Guards, protected
target filtering, disjoint payment reservations, both Lord panels, duplicate
queue clicks, Commission and Repair through the background worker, setup
preservation/restart/checkpoint restore, and empty-hand progression with Ruin.
The old board regression explicitly selects its established Gremory fixture;
the dense board still uses its original 48-body performance fixture.

The focused `--board` gate now runs **3/3**, each with the unchanged 30-second
limit. Full foundation now contains 22 runners. In this workspace, validation
is GDScript grammar and shell orchestration only: there is no Godot binary here.
Godot 4.7.2 compiler, scene/layout and gameplay verification remains local.
Do not report the new board gate as green until that run succeeds.

```bash
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  --board
```

Then launch directly (no repeated tests required):

```bash
bash Scripts/Sim/run_u13_board.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

For a short manual check, keep the default quick start. Stage Commission on
slot 2, Skip Combat, queue War Machine on slot 1 and Rout in Castle lane, then
Resolve. Inspect slot 2's exposed state and the event history. Restart to try
paid Construct on slot 3 or Repair on slot 1 with a token. Change the human Lord
to Gremory to check its original powers against a specific damaged enemy copy.
