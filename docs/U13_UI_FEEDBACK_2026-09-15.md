# Playtest UI corrections — 15 September 2026

## Changes

- The Slaver uses the modal artwork’s two lower action slots for **Swap Cards** and **Pass Trade**. The selectors remain in the modal.
- A compact visible-offense/visible-defense forecast appears immediately below committed cards. The full current-board calculation remains at the bottom of the Combat modal. The defense total includes Guards, pair protection, Sigils, screening Castles and the target’s defense or Integrity; it is a visible baseline, not a prediction of hidden orders or future reactions.
- Clicking a hand card after choosing Hunt or Siege stages it immediately. Without a manually chosen target, the first legal public target is selected; another target can still be clicked. Siege with no exposed Castle uses Pillage.
- The persistent or newly staged Work target has a badge on its Castle card.
- Commission can be staged or undone from every planning step, including Lord Powers and Dominion Rites. It requires an owned protected building/ready Castle with at least 7 Integrity. It resolves during Development, before Work, at current Integrity. Existing persistent Work remains selected; Commission uses the existing single castle-action slot, replacing a newly staged Work choice. Resolution/Aftermath buttons remain disabled while orders are locked.
- Aftermath reports Kanifous wish counts, including zero-effect wishes and Deathwish kills, as well as summon, Rout, Redirect, Reconfiguration, Allegiance Shift, lane-aura and Ravenous outcomes from public facts.

## Rules corrections and PySim handoff

Inevitable Ruin now sets Integrity to zero and status to `defunct`, emitting `CASTLE_DEFUNCT`. It no longer sets `ruined` in the Guard Work profile. The existing following-round repair lock and artillery-target clearing remain. The Castle stays eligible for ordinary Work repair.

The Guard Work profile again admits the existing four-field `Activate` castle choice. It validates ownership, protected construction state and the seven-Integrity floor, revalidates during Development and emits `CASTLE_ACTIVATED` or `COMMISSION_FIZZLED`. Commission does not provide free Integrity or passive construction after activation.

These two rule changes must be mirrored in PySim before claiming parity with this revision. No Python simulation or bot policy is changed here. Old checkpoints remain loadable; already resolved outcomes are not rewritten. Replaying old commands under corrected rules can produce different outcomes.

## Playtest evidence

The supplied round-15 save records Inevitable Ruin causing ruin in rounds 5, 7 and 13, and Deathwish killing four Marchers in round 15. Its playtime metadata records 20m 07s total (16m 25s decisions/review and 3m 42s resolution). The save restores successfully with this patch, and the round-15 Aftermath renders its four recorded kills.

## Validation

Focused runner: `Scripts/Sim/U13UIFeedbackTestRunner.gd`. Covers modal actions, Work badge, direct Hunt/Siege card staging, adjacent forecast, commission validation and complete-round resolution, defunct/repairable Ruin and its repair lock, and Deathwish counts. Existing Action Flow, Guard Work, Action Forecast and Aftermath Ledger regressions also pass locally.

Local headless Godot 4.5.1 is diagnostic evidence only. Visual acceptance remains on the player’s Windows Godot 4.7.2: check Slaver slot alignment, forecast placement with larger hands, Work badge visibility and commission at each planning step.

Launch with the existing `Scripts/Sim/run_u13_playable.sh` runner. No sprite files are changed.
