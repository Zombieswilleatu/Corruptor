# U13 Marcher damage and healing feedback

Runtime: Godot 4.7.2 stable. Local Godot verification is required before acceptance.

## When Scorch damages Marchers

A lane Scorch pulses at Step 11 (`marching_start`), immediately before movement.
Pyroclasm adds a separate pulse at Step 10F (`post_resolution_direct`). Inferno is
prepared for the following round; declaring it does not immediately burn a lane.
Both owners' Marchers in that lane are affected, including waiters. A Scorch
placed on a Guard zone affects eligible Guards, not Marchers in the lane.
Intensity follows the existing 1 / 2 / 1 stages. Armor absorbs each pulse first.
An intensity-1 hit against 1 Armor therefore removes Armor without lowering HP.
These rules are unchanged by this presentation pass.

## Visible results

- Red negative numbers: actual HP lost, capped at remaining HP on a lethal hit.
- Green positive numbers: actual HP restored, capped at maximum HP.
- Blue signed `ARM` numbers: actual Armor changes, including absorbed Scorch hits.
- Scorch labels identify its hits; regeneration labels identify round-start healing.
- Labels rise and fade above the recorded chit position. Live anchors follow the
  moving chit; lethal hits retain the last known position after removal.
- Rapid exchanges on the same chit combine while visible, preserving their total.
  Damage and healing do not cancel each other into one misleading net number.

The board presents artillery first, then a short lane-damage feedback sequence,
then Marching. Distinct hazard pulses are scheduled 0.75 seconds apart; the final
pulse gets 1.1 seconds of reading time. Pyroclasm markers also flash an empty target area for
one second; these markers are never converted into fake damage numbers. This affects presentation only. Round-start
regeneration appears while planning remains available. Normal completion preserves
final-hit labels; Skip clears queued/visible numbers and immediately uses the exact
final picture. Restart clears both numbers and existing flower tails.

## Implementation and performance

`U13BattleEvents` adds integer `hp_before` and `hp_after` to Marcher damage events.
The command still applies the same clamped damage exactly once. Existing public
victim/attacker/cause fields remain intact. New events replay deterministically;
old saved events without these optional fields remain readable.

The event log filters the player's explicit projection before copying selected
non-Marching events. It does not expose authoritative payloads or copy 200 dense
movement frames for feedback extraction. `U13BoardJob` prepares those cosmetic
rows on its existing isolated worker and publishes them only on success.

`U13SmokePlayback` builds health/Armor transitions alongside its immutable recorded
frames. Terminal exchange Armor preserves bypass semantics, and disappearance
without a recorded defeat does not become invented damage. Newly spawned units do
not generate fake healing. A monotonic cursor collects every crossed feedback
entry even when a rendered frame skips several simulation ticks. Sampling remains
stateless and never applies damage or emits events.

`U13MarcherFeedback` owns a bounded list (96 visible labels maximum), drawn by the
existing lane Control. There are no per-hit scene nodes, timers, physics bodies,
new textures, simulation RNG calls or full-world per-frame copies. Over-budget
labels evict the oldest visual entry only. Actual damage/replay data is unaffected.
The Breath animation process remains active when either flowers or numbers need
animation. The existing Marching playback duration is unchanged.

## Focused verification

```bash
bash Scripts/Sim/run_u13_foundation_tests.sh "$GODOT_U13" --marcher-feedback
```

Expected footer: `U13 Marcher-feedback runners passed: 4/4`.

The focused group runs:

1. `U13MarcherFeedback`: actual hazard extra/normal pulses, Armor-only damage,
   lethal/overkill amounts and anchors, other-lane exclusion, actual capped
   regeneration, waiter/full-HP exclusion, skipped-frame combat hits, bypass,
   consumption, duplicate prevention, label cleanup/budget and event-view privacy.
2. `U13MarcherFeedbackBoard`: real direct-board surface/controller, pre-Marching
   feedback pause, distinct pulses, coexistence with Breath, Skip, final hits,
   planning-time healing, and save independence. Only subsequent worker dispatch
   is replaced in this fixture; it does not resolve redundant full matches.
3. `U13ScorchVisuals`: sprite phases, independent 25% alien-loop choices, intensity,
   Pyroclasm flash/return, bounded radial mesh, assets and real preview draw path.
4. `U13Breath`: existing authoritative Breath/regen integration regression gate.

The three new runners also belong to `--board` (now 14 runners) and the full foundation
suite (now 42 runners). Existing groups and the 30-second per-runner limit remain.

Then launch the normal board:

```bash
bash Scripts/Sim/run_u13_board.sh "$GODOT_U13"
```

Choose Kalligan; place Inferno on a lane occupied by Marchers. On the next round,
look for blue Armor loss/red HP loss just before movement, labeled SCORCH. Pyroclasm
provides the extra preceding pulse. Ordinary clashes should show HP/Armor changes;
a surviving damaged, non-waiting Marcher should show green regeneration at the
next round start. Breath adds its existing regeneration bonus to the actual heal.

## Validation boundary

Workspace checks cover GDScript grammar, static preload call arity/constant
references, shell syntax, wrapper sequencing and injected wrapper failures.
No Godot executable is available in this workspace: these checks do not establish
engine compilation, passing gameplay assertions, visual quality or measured FPS.
The user's local focused gate and visual check remain authoritative.
