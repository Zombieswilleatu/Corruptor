# Kroni — complete U13 implementation

Implements the accepted 2026-09-08 V2 handoff, section 5.5, and the random-legal addendum. This is the Hunger / Consume / Cannibal Hunger / Ravenous / Insatiable Hunger version, with the player-placement/random-launch correction of 2026-09-10. Legacy Gorge and Hungering Aura names are not additional V2 powers.

## Rules

- **Hunger:** starts at zero, never negative. Defense is 4 at zero, 6 at one or two, and 8 at three or more. These are the specified Defense bands, not a Threat-adjusted base. The first time each game Hunger reaches three, gain one personal Tear. Dropping below three, banishment and resummoning do not reset that milestone.
- **Ward / Pass:** an active Kroni loses one Hunger when combat resolves, before either player's attacks. This makes the resulting Defense apply consistently to both combat orders. Other actions do not incur this penalty.
- **Consume:** free prepared power, once per submission. Select one specific enemy Guard. At the start of the next round, before replenishment and deployment, Devour it and gain one Hunger if it is still an enemy Guard. A different lane does not invalidate that same Guard. A missing or friendly target fizzles; never retarget.
- **Cannibal Hunger:** after scheduled Consume checks, every active Kroni not fed by Consume this round Devours his own lowest-value Guard across both zones. Equal values use stable entity-ID ordering. If none exists, lose one Hunger. The accepted rule gives no Hunger increase for the friendly meal. This also applies when Consume was not declared, including the first round's automatic check.
- **Ravenous:** free immediate power. Step 10G arms one special actor; Marching executes it. The player selects only a horizontal starting position along their own field edge: bottom for player 0, top for player 1. When the power fires, it rolls a random launch angle toward the enemy boundary. Forward movement always remains enemy-facing; lateral movement starts in a random direction. Outer walls reverse lateral velocity. No steering, selected victim, pursuit or pathfinding. One touched friendly or enemy Marcher is Devoured per chomp. Nearby units on both sides begin fleeing on entry into twice his bite radius, moving directly away at 30% normal speed for 1.1 seconds. The 0.55-second double chomp does not start or renew their timers. No per-spot consumption cap. End at the far boundary. Six or more Devoured in one activation grants one Soul, one Hunger and one Neutral Tear, once only. Activation in round R blocks R+1 and R+2; ready in R+3.
- **Hunger footprint:** 100%, 110%, 120%, 135% at 0, 1, 2, 3+. The activation snapshots Hunger. Rendering and actual collision radius use that same snapshot; rewards do not resize an actor halfway through an activation.
- **Insatiable Hunger (Breach):** once per Marching phase while Kroni occupies the shared Breach. A keyed random point and random direction produce a brief special actor. It Devours either side with the same radial fleeing response, then disappears. No Hunger, Souls, Tears, milestone or Ravenous reward progress comes from it.

Devour retires the entity and retains its used identity. A Devoured Guard does not enter the discard pile. Devour is not combat damage or a combat kill: it ignores Armor and does not synthesize Guard-defeat/Marcher-kill reactions. Both types emit explicit public consumption events with the original victim for history and playback.

## Provisional spatial tuning

Shared field: forward 0–2400, lateral 0–1200 (Lord lane 0–600, Castle lane 600–1200). Ravenous starts at the chosen lateral position, with forward position locked to 0 for player 0 or 2400 for player 1. It advances 16 forward units per fixed Marching tick toward the enemy, with a keyed random lateral magnitude from 8–24 and a separately rolled sign. It reaches the enemy boundary within at most 150 of the phase's 200 ticks. Opponent forward motion is mirrored. The launch roll uses match seed, activation identity, round and separate angle/sign purposes; it happens only at firing. Planning exposes only position, never the trajectory, and editing placement does not reroll it. Base radius is 220; scaled radii are 220, 242, 264, 297. Swept segment/circle checks include the boundary. Reflection splits the segment at the wall so it cannot cut across the corner. Stable actor order and stable entity order settle simultaneous consumption ties.

The Breach uses eight fixed direction vectors, a baseline radius, and 33 ticks (0.99 seconds at the normal six-second Marching playback rate). Forward boundary contact reflects it; lateral walls use the same reflection as Ravenous. Its RNG keys include match seed, round-specific effect identity, and separate point/direction purposes. Presentation never supplies gameplay coordinates, collision decisions or random rolls.

## Runner and presentation

Kroni is selectable against the full current U13 roster. Random-legal candidates include both powers. Save/load covers delayed Consume, Hunger/milestone state, cooldowns, actor state and round ledgers. Existing Lords use their existing content adapters when Kroni is absent.

The powers panel offers Consume and Ravenous. Ravenous opens a transparent field placement control: click either lane to choose a position on the bottom edge, drag horizontally to adjust, then confirm. No aiming arrow or route is shown. Consume highlights actual enemy Guard cards; one click queues the target and dismisses targeting. Queued powers can be removed. The Lord card shows live Hunger and Defense. Debug controls include +1 Hunger through the normal milestone gate, alongside Guard/Card/Marcher additions and banishment into the Breach.

The exact uploaded four-direction, six-frame sprite sheet is stored separately from older Kroni art. Explicit atlas rectangles accommodate its uneven margins. Walking picks a cardinal row. On a recorded Devour, presentation freezes at that tick, faces the victim, plays the chomp cycle and shrinks the Marcher into the mouth. Northward bites turn side-on because the back row has no visible mouth. Sequential bites at one tick share that frozen instant. Skip clears all presentation state without changing the resolved result.

Main-screen animation gallery: **Kroni · Ravenous**. Standalone: `res://Prototype/U13/U13KroniPreview.tscn`. It uses the production actor simulation and renderer, with both lanes, both owners, all Marcher suits, the Lord artwork, Hunger presets, Breach mode, replay, pause, speed, frame rate, chomp duration and collision outlines. Preview controls do not alter match balance.

All Lord inspections now use the catalogued back artwork behind the passive/Breach rules. Existing hold-to-open, click-to-flip and hold-to-dismiss behavior remains. Inactive rules are dimmed; Breach is highlighted only while applicable. Card artwork fills its board container; inspected fronts preserve the source aspect ratio and stat overlays use the same displayed bounds. Hand-art padding is reduced to the selection border.

## Validation

`U13KroniTestRunner.gd` covers Hunger bands and milestone recurrence, Ward/Pass, Consume targeting/delay, Cannibal fallback, deterministic Devour and reflections, both owners, Breach reward exclusion, the real Match lifecycle, cooldowns, and JSON restoration at the meaningful hook boundaries.

`U13KroniBoardTestRunner.gd` covers the main runner, actual Guard selection, queue edits, debug Hunger, worker resolution, actor tape playback/skip, next round, live Breach execution, card back/fit and standalone chomp behavior. Existing Marching, Odradek, inspection, hand, loadout and debug regressions are run separately.

### Verified delivery

Godot 4.7.2: the focused foundation wrapper completed with **9/9 suites passed**, zero script errors or failed assertions. This includes Kroni core, Kroni board, Marching integration, spatial Marching, Lord inspection, direct board, loadout board, debug board and Odradek board. The full foundation suite was not rerun for this delivery.

Run from the U13 checkout:

```bash
bash Scripts/Sim/run_u13_foundation_tests.sh /path/to/Godot_console_executable --kroni
```

Kroni is available in the main runner's Lord picker and the animation gallery.

## Placement/random-launch revision

The preview accepts starting-point clicks and rolls a fresh launch each time. Two fast six-frame chomp cycles remain in each bite pause. Kroni content version is now U13_KRONI_PROXIMITY_FLEE_V5; older Kroni checkpoints are rejected rather than silently replayed with changed rules.

Revision validation: Godot 4.7.2 Kroni core and board suites passed with zero failures. Coverage includes required position-only declarations, fresh launch angles, forward-only motion for both owners, launch-hook JSON replay, board placement/cancel/confirmation, worker playback coordinates, and preview placement/new launches.

## Guard chomp and Hunger clarity

Both Consume and Cannibal Hunger play the exact Kroni sprite beside the eaten Guard, with a short pop-in, two six-frame chomp cycles in 0.55 seconds, the card shrinking into his mouth, and a short exit. The first-round Cannibal check is shown too. Events are captured at the scheduled round-start hook and passed through the worker; presentation never re-applies consumption. Decision input waits for the animation. Completion and skip restore affected controls.

Hunger has no cap of 1 and is not reset at round start. Ward/Pass loses 1 during combat; powers without a combat order count as Pass. No friendly Guard during the Cannibal check also loses 1. The powers panel now states when the current order will cost Hunger. Consecutive Consume meals with Hunt instead of Pass reach Hunger 3 and award the milestone once.

Validation for this revision: Godot 4.7.2 Kroni core and board suites passed, including Hunger 1→2→3 across offensive rounds, milestone payout, JSON state (the former three-per-spot rule is superseded below), first-round Cannibal animation, next-round Consume animation, and safe animation completion/skip.

## Minimum attack commitment

Hunt and Siege require at least one committed card for every U13 Lord. Empty attacks are rejected in order validation, strict preview, batch/bot legality and submission. Ward may commit zero cards, and Pass remains available. This closes the no-cost attack loophole for retaining Hunger. Hunger-growth fixtures now use a real card commitment.


## Fleeing replaces the consumption cap

Entering twice Kroni's consumption radius starts a 1.1-second panic timer, independent of his 0.55-second double chomp. Units flee directly away at 30% normal speed during normal field ticks and during his bite pause; both spend the same timer. Staying nearby does not refresh the timer. Leaving and re-entering can start another event. Fractional movement carry preserves the 30% rate across small ticks. Panic replaces normal forward movement while active.

The authoritative positions change for both sides, including waiting and duelling units. Units can cross the internal lane seam; outer edges clamp movement. Exact overlaps use a stable keyed radial direction. There is no guaranteed escape or fixed meal count.

The board and animation preview show Deimos's Rout ghost on active fleers before, during, and after bites. A proximity event triggers one audio voice for the group from res://Sounds/Wilhelm.wav when present. An ongoing scream finishes without being restarted by a neighboring group's entry. The actual user-supplied clip remains local to their checkout.

Validation includes proximity before contact, 1.1-second expiry, no refresh while nearby, movement without a bite and after Kroni disappears, fractional speed, deterministic replay, lane crossing, outer boundaries, and board/preview ghost and sound lifecycle.
