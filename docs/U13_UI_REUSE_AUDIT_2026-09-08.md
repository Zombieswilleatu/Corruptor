# U12 UI reuse audit for U13

Audited 2026-09-08 against `u13-lord-overhaul` at
`73ad19808bd4272ec4921f5446a1d618bc6145f9`, with the user's original-board
screenshot as the visual reference. Main remains the frozen U12 baseline
`7eaf5d4d5f0674ee1f37f115b82d121b5a2ee216`. PhasePrompt contents and the
PlayableUI2/HandView blob IDs match between these refs. This is a source audit,
not a Godot runtime or visual verification report.

## Finding

The U12 board is an established component system, not merely an asset source.
U13 should adapt that system's presentation and interactions. The first U13
board reused too little: horizontal lanes, a toolbar, bare portrait textures
and text Castle summaries replaced working components and obscured the flow.

The Slaver modal consists of **PhasePrompt hosting ActionZone**, with hand and
board signals routed by PlayableUI2. Replacing it with a newly drawn modal
would still discard existing interaction and layout work. The provisional
replacement modal was stopped before publication; this audit changes no UI or
simulation code.

## Component decisions

Paths below are relative to `Prototype/UI2/`.

| Component | Preserve | Replace or adapt for U13 |
| --- | --- | --- |
| `PlayableUI2._build_shell()` | Top summaries/Veil/Breach, two stacked domains, bottom hand, right battlefield, overlay prompt and History. Human Castle guards above Castle cards; enemy orientation retained. | Extract the shell and signal wiring from the U12 match startup/phase driver. Do not instantiate the U12 controller as U13's owner. |
| `PhasePrompt.gd` | DecisionPanel art, fixed expanded footprint, header/button slots, intro/detail flow, bottom actions, persistent View Board/Return tab, selection retention, direct-manipulation synchronization. | `bind_state`, stage copy, intro/confirmation rules and maintenance branching receive a U13 decision description. Keep its established layout machinery. |
| `ActionZone.gd` | Visible action buttons, target controls, payment selection, scroll behavior, staged moves, confirm/pass signals, disabled-action feedback. | `_action_is_legal`, `_build_forecast_cache`, `_compute_confirm_state_v17`, phase configuration and payment helpers currently invoke U12 rules. Feed these controls U13 choices and preview results. |
| `HandView.gd` | Physical card selection, fan layout, hold inspection, drag payloads, staged-card removal, double-click all-in, selection signals. | U13 stable physical IDs and reservation roles. The current U13 copy already only adapts class/texture loading, but most drag modes are not wired to the new board. Preserve and connect them. |
| `PlayerBoard.gd` | Lord/Castle placement, Guard slots, domain crop, attack/Ward/payment overlays, target flashes, drag targets, click-to-return staged cards. | `bind_player`, fixed named Castle list, Guard-slot policy and previews based on `attack_value`/`ward_reinforcement_value` must use U13 presentation data and authoritative previews. |
| `LordCard.gd` | Full-size portrait, stat-slot placement, front/back and rules toggle, hold preview, gesture cancellation, modal input protection. | `bind_player` reads GameSetup Lord numbers and U12 LordPowerText. Use U13 content/stats; unavailable stats must not acquire invented zero values. |
| `CastleSpine.gd` | Physical Castle cards, Integrity placement, state tint, inspection, construction visual/shader. | U12 hard-codes 21 max Integrity, 7 operational floor, named powers and permanent ruin copy. Current U13 plain-Integrity targets cannot be labeled Keep/Bastion or given those semantics. |
| `GuardPip.gd` | Empty/occupied slots, hidden backs, suit art, inspection and styling. | Supply permitted card-face data and explicit visibility. Its basic `bind_guard(card, revealed)` interface is already close to reusable. |
| `PlayerPuck.gd`, `VeilTrack.gd`, `BreachSlot.gd` | Framed scoreboard, pip track, dedicated Breach card/inspection. | Replace U12 GameSetup/game/rules reads. U13 currently projects a Breach Lord name but no owner; do not infer ownership or display YOUR/ENEMY LORD without authoritative data. Do not invent personal-Tear/victory thresholds. |
| `MarchingLaneView.gd` | Right sidebar, two vertical lanes, framed action window, card chits, spatial packing, collision/death/arrival presentation. | `bind_players` consumes U12 marcher objects; `begin_battlefield_playback` consumes half-round tape with owner-relative progress and lowercase event types. Adapt U13's full-phase public tape and stable IDs; preserve actual positions, waiting, birth holds and simultaneous kills. |
| `ResolutionTheater.gd` | Order reveal, attack/defense card staging, impacts, completed-round Aftermath with explicit next-round button. | U12 player/result inputs and rule-specific narration. Example: existing both-Ward copy says Sigils rise; that must not be asserted unless U13 emitted it. Feed presentation facts, never replay gameplay to animate. |
| `ActivityRail.gd` | Collapsible History overlay, formatting and scroll behavior. | Replace `bind_controller`/state-diff ingestion with redacted U13 player events. Do not hand the UI an authoritative snapshot to satisfy its old controller interface. |

## Existing interaction flow to retain

1. A phase presents its explanation and current choices through PhasePrompt.
   Intro confirmation opens ActionZone rather than bypassing the detailed choice.
2. Hand selection updates payment/commitment controls and physical previews.
   Dropping a card on an enemy target selects the action/target and stages it.
   Dropping on the player's zone selects Ward. Clicking a staged card returns it.
3. `sync_direct_manipulation` advances the prompt to the relevant detail view,
   while respecting an explicit View Board collapse. It does not reset the hand.
4. Confirm and Pass emit separate signals to the controller. A collapsed prompt
   remains reachable through its persistent Return to Decision tab.
5. Reveal/impact/Marching presentation consumes resolved facts. Aftermath is
   shown once for the completed round, with the next-round action there.

The U13 toolbar did not preserve steps 1–4. Reintroducing only a visible Pass
button would fix one symptom, not restore this flow.

## Adapter boundary

Build small read-only presentation bindings rather than a fake U12 GameState:

- **Decision:** phase/title/copy, action IDs, legal targets, selected physical IDs,
  reserved payments, preview feedback, confirm/pass availability and labels.
- **Board:** public Lord/Castle/Guard records, explicit stats/status/capabilities,
  stable IDs and allowed visibility. Unsupported slots/actions must be labeled
  unavailable, not represented as ordinary buildable U12 content.
- **Events:** already redacted reveal/impact/reward/Marching facts, with stable
  event identities for once-only playback and cancellation on reset/restore.

UI widgets emit intent. The U13 owner validates complete power-plus-combat
submissions and owns costs, cooldowns, ordering and outcomes. Do not copy U12
legality/forecasts into those presentation bindings. A legality-only preview
must not be advertised as a damage forecast.

Pass semantics must be explicit in the decision descriptor. Distinguish
skipping combat while retaining queued powers from cancelling the entire plan;
never silently cancel powers because an old U12 Pass callback was reused.

## Migration order

1. Preserve the actual PlayableUI2 shell and its PhasePrompt/ActionZone layout.
   Add the U13 decision binding and existing modal/hand signal flow first.
2. Bind the actual PlayerBoard, LordCard, CastleSpine and GuardPip presentation.
   Keep U13 content gaps explicit rather than substituting U12 rule values.
3. Reconnect attack/Ward drag targeting and click-to-return previews using
   stable card IDs and the same selection state as the modal.
4. Adapt the existing battlefield sidebar and ResolutionTheater event inputs;
   retain existing animation/layout work and test no-contact Butcher movement.
5. Bind scoreboard/Breach/History only to supported public fields. Add missing
   authoritative projection fields when their semantics are settled.

Use isolated U13 copies or narrowly extracted presentation components; do not
change the frozen U12 startup, behavior or main scene. Record provenance and
small binding diffs so later UI improvements remain transferable. Prefer this
to accumulating independently rebuilt widgets. Asset loading must retain the
source-checkout path established by the direct-launch repair; avoid bringing
back unconditional PNG preloads that require missing imported `.ctex` files.

## Required regression checks for implementation

- Screenshot layout: top summary/Veil/Breach; two domains; large Lords;
  physical Castle/Guard slots; right battlefield; bottom hand; overlay prompt.
- Prompt stays reachable and preserves action/target/payment across View Board.
- Modal and drag/drop share selections; click-to-return and all-in use physical
  identities correctly when cards have identical suit/value faces.
- No legal Siege target yields plain-language feedback and a visible way to
  continue. No-hand states and pending powers cannot strand the decision.
- Pass labels and resulting retained/cancelled powers agree.
- Preview, opening/closing modals and animation do not mutate the owner.
- Opponent commitments remain hidden until reveal. History and inspection do
  not expose authoritative snapshots or unrevealed data.
- Playback includes no-contact movement, new-unit holds, collisions, arrivals,
  and once-only Aftermath. Restart/restore cancel stale playback callbacks.
- Existing U12 behavior and direct U13 launch without an import cache remain
  intact. Runtime/visual verification uses the user's Godot 4.7.2 build.

## Evidence anchors

All source links are pinned to the audited revision:

- [PlayableUI2 shell and event wiring](https://github.com/Zombieswilleatu/Corruptor/blob/73ad19808bd4272ec4921f5446a1d618bc6145f9/Prototype/UI2/PlayableUI2.gd)
- [PhasePrompt](https://github.com/Zombieswilleatu/Corruptor/blob/73ad19808bd4272ec4921f5446a1d618bc6145f9/Prototype/UI2/PhasePrompt.gd)
- [ActionZone](https://github.com/Zombieswilleatu/Corruptor/blob/73ad19808bd4272ec4921f5446a1d618bc6145f9/Prototype/UI2/ActionZone.gd)
- [PlayerBoard](https://github.com/Zombieswilleatu/Corruptor/blob/73ad19808bd4272ec4921f5446a1d618bc6145f9/Prototype/UI2/PlayerBoard.gd)
- [MarchingLaneView](https://github.com/Zombieswilleatu/Corruptor/blob/73ad19808bd4272ec4921f5446a1d618bc6145f9/Prototype/UI2/MarchingLaneView.gd)
- [ResolutionTheater](https://github.com/Zombieswilleatu/Corruptor/blob/73ad19808bd4272ec4921f5446a1d618bc6145f9/Prototype/UI2/ResolutionTheater.gd)
