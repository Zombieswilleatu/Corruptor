# U13 direct board interactions — 2026-09-08

## Current flow

`run_u13_board.sh` opens the existing U13 layout through `U13DirectBoard`, a
thin interaction controller over the established board/session/worker path.
The old fixture and dense regressions retain their original interaction mode.
The default playable entry uses direct targeting:

- Click Siege, Hunt or Ward; click a target; click hand cards.
- Or drag a hand card onto an enemy Castle (Siege), enemy Lord (Hunt), your
  Lord (Lord Ward), or your Castle/shared Castle Guard zone (Castle Ward).
- Staged cards leave the hand and form an overlapping, clickable stack at the
  destination. Clicking a staged card returns it during the ordinary-order phase. Combat and
  Castle-payment stacks lock during Lord powers and pass target clicks through;
  return to combat to edit those commitments. The original suit outlines remain. Both input methods update
  the same draft and stable physical card IDs.
- After at least one card is staged to the selected destination, double-click
  anywhere in the hand to add all remaining available cards. This excludes
  cards reserved for another action. Fixed two-card Ruin payment is not an
  all-in action.
- Construct and Repair use action -> own Castle -> optional/required payment
  cards. Selecting a Construct target stages free progress; extra cards add
  payment. Repair requires payment, with an optional Repair-token checkbox.
- Eligible protected Castle cards have a Commission button. Clicking it stages
  that copy's `Activate` order; clicking Undo Commission cancels it. Replacing
  a paid Castle order returns its cards. This is still one Castle action per
  round and is applied when the round resolves, with no intermediate advance.

The action and power target dropdowns are hidden in this interaction mode.
The backing controls remain for the established fixture tests. Valid target
surfaces pulse once and the prompt collapses to its existing Return tab while
selecting on the board. No continuous highlighting/redraw loop is introduced.

## Lord power gestures

The separate Lord-power prompt still follows combat with no simulation advance.

- Predator of Ruin: click power, then click a lane in the right battlefield.
- Inevitable Ruin: click power, click exactly two available hand cards, then
  click a damaged, exposed enemy Castle instance. The cost stack is labeled
  beside your Lord while being selected and after queuing. Returning a queued
  Ruin payment cancels Ruin and preserves any other queued power.
- War Machine: click power, then one operational own Siege Engine. The prompt
  explains and displays its retained artillery target, or automatic acquisition
  at firing (including the only currently eligible target when there is one).
  War Machine does not select a separate enemy target.
- Rout: click power, then the enemy lane in the right battlefield.

Names remain above target instructions and cooldowns remain visible. Pending
power selection disables Resolve until completed or cleared. No Powers releases
power payments while preserving staged combat and Castle orders. Click-to-return
and Clear work with the same reservation state as drag/drop.

## Reuse audit

Audited the U12 implementations at branch parent `15358d1`:

- `Prototype/UI2/HandView.gd` / existing U13 hand copy: drag payload and preview,
  physical ID selection, and the original same-button double-click gesture.
- `Prototype/UI2/PlayerBoard.gd`: `_configure_attack_drop_target`,
  `_can_drop_attack_data`, `_drop_attack_data`, attack/Ward preview stacks,
  click-to-return and target flashes.
- `Prototype/UI2/PlayableUI2.gd`: attack/ward drop handlers selecting the action
  and target before adding the card to the shared selection.

The U13 hand retains its drag payload (`commitment_hand_card`, source Hand,
physical card ID) and art preview. All-in now listens over the hand surface
because immediately moving the first card removes the original same-button
click target. `U13OrderPreview` adapts the old overlapping stack presentation
without feeding U12 controller objects into the U13 owner. Target drops validate
membership in the available hand, and final candidates always pass the owner.

No U12 file, original asset, project main scene or Marching simulation was
changed. The full rendered board remains available while BoardJob calculates
round results. Staging refreshes are deferred until a click/drop callback has
finished, so the emitting hand button is not synchronously destroyed.

## Hunt scope and provenance

The previous board rejected Hunt. The direct board explicitly opts into
`U13_CORE_HUNT_V1`; its content policy and checkpoint setup pin that choice.
Other loadout/Construction/frequency profiles do not gain Hunt implicitly.
Their accepted replay fixtures therefore keep their prior action domain.
Core candidate enumeration offers Hunt only when the player projection carries
that profile, and uses the existing keyed random chooser and owner legality.

This implements basic ordinary Hunt using the measured U13 combat rules:
printed commitment strength with the existing Butcher exemption/bonus, +1 per
matching Lord-lane waiter consumed, Ward first (off-lane half), descending
Lord Guards with strict-greater defeat, flat Fresh/Flipped Sigils (2/1), then
Lord defense. Gremory/Deimos printed defense is 4, reduced by the existing
Threat bands (1 at Threat 2, 2 at 3, 3 at 4+). Strictly greater banishes;
equality survives. Successful ordinary banishment grants attacker two Souls,
removes up to one defender Soul, creates one Neutral Tear, marks the Lord
banished, resets its existing Threat and updates the Breach through the shared
battle/reaction path. A target already banished at firing fizzles without
consuming its waiters. Commitment cards still create Lord-lane Marchers at
reveal and are spent through normal cleanup.

These numbers/order come from `Scripts/Sim/GameSetup.gd`'s Gremory/Deimos
`base_defense` and `HuntResolutionEngine.gd`'s `_resolve_combat`,
`_calculate_lord_defense`, and ordinary `_banish_lord`, adapted to the existing
U13 event boundary. This is not the full U12 Hunt dependency graph: Keep/Bastion
printed effects, Fracture, Consume/overkill return, resummoning and victory are
not migrated by this interaction change. The board is still an exercise;
a banished Lord cannot declare combat/powers, and Restart/New loadout remains
available. The picker/header identify outstanding systems.

## Verification

New runners:

- `U13HuntTestRunner`: same/off-lane Ward, strict defense threshold, Guard/Sigil
  order, rewards/Breach, invalid/self targets, rejected caller damage, opt-in
  policy, full owner hook replay, per-hook JSON restore and Marcher creation.
- `U13DirectBoardTestRunner`: real scene controls, on-card Commission/undo,
  click and drag paths, stack movement/return, all-in reservation exclusion,
  forged/repeated/protected-target drop rejection, both Lords' direct power
  paths, and a staged free Construct + Predator through the background worker.

Focused interaction gate: **2/2**, unchanged 30 seconds per runner.
The broader board gate is now **5/5**; full foundation contains **24 runners**.
Grammar and shell orchestration are checkable here; this workspace has no
Godot binary. Engine and visual acceptance must come from local Godot 4.7.2.
The user's "seems to be working" accepts the preceding picker/board usability
checkpoint, not these new runners.

```bash
godot_u13="/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh "$godot_u13" --interaction &&
bash Scripts/Sim/run_u13_board.sh "$godot_u13"
```

Manual check: drag one card onto an exposed enemy Castle, then double-click
the remaining hand. Click a card in the destination stack to return it. Try
an own Castle and each Lord. Restart, click Commission on slot 2, then continue
to the power prompt and select War Machine -> slot 1 or Rout -> a lane. For
Gremory, select Predator -> lane and Ruin -> two cards -> enemy Castle.


## Board polish after direct-target acceptance

The default new direct board picker now offers one of each Castle type, Keep
first. Existing match loadouts and regression fixtures retain their selected
physical slot order; this does not silently reorder a running match.

Replacing a Keep opens beginner advice: Keep is strongly suggested for all
builds, and one of each Castle type is suggested for beginners. The choice is
held until Continue; Cancel or × retains Keep. It remains possible to use any
legal specialized loadout. The advice acknowledges Keep's printed effect is
still unimplemented in this slice.

`U13TutorialPreferences` gates prompts by stable tutorial ID and an `enabled`
flag. Dismissals persist in `user://u13_tutorial_popups.cfg`; the picker’s
**Show tutorial popups** button clears *all* dismissed IDs and enables the gate.
Live consumers reload at the popup boundary, so reset also affects already
created modal instances. Future tutorial modals should use this gate and
`U13TutorialPopup` rather than introducing separate don't-show preferences.

The existing direct interaction runner additionally covers locked commitment
and Castle payments, mouse pass-through, preserved suit outlines, automatic/
retained War Machine target copy, beginner defaults, tutorial cancel/accept,
persisted dismissal, global reset (including another tutorial ID), and the gate.
Its preference checks use an isolated temporary user path and leave the player's
real tutorial choices alone. Runner counts remain interaction 2/2, board 5/5,
foundation 24/24. Local Godot 4.7.2 acceptance is still required for this update.
