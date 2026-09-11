> Follow-up: Blood Conduit is implemented in `U13_BLOOD_CONDUIT_2026-09-11.md`.
> That note also distinguishes printed Fracture from summon-payment Threat.
> Sigil lifecycle and printed Fracture are implemented; see
> `U13_SIGILS_2026-09-11.md` and `U13_FRACTURE_2026-09-11.md`.

# Final playable U12 versus migrated U13 — audit

## Baseline and scope

Verified remote `main` at `94c68ae49f287458de0b214651ac2a8521ac2689`
(September 8 asset checkpoint). The checked-out copies of `Prototype/UI2`,
`Prototype/PlayableRoundController.gd`, `RuleConfig`, `BotRoundEngine`,
`RoundEngine`, `CastleIntegrityRules`, `GameSetup` and `SeededGameSetup` match
those paths on that baseline. No newer main revision was available at audit time.
The older `lab-6.5-migration` ref is a July checkpoint, not the final UI2 authority.

Actual launch path: `PlayableUI2._ready` -> `PlayableRoundController.start_match`
-> `RuleConfig.lab_v6_5` -> `SeededGameSetup.setup_locked_game`. The version-like
factory name is misleading: its contents include later v7.4/v7.5/v7.6 rules.
Standalone `RoundEngine` routines are not sufficient evidence for live behavior.

This audit follows setup, Slaver, draws, Castle powers, Development and lifecycle
entry points. It is not exhaustive simulation parity, a balance certification,
or a reason to restore the old Lord kits over the explicit U13 overhaul.

The later production-opening decision is recorded in
`U13_PRODUCTION_OPENING_2026-09-11.md`. It resolves the two opening/Repair items
that were still queued when this audit was first written.

## Findings

| System | Playable U12 evidence | U13 finding / disposition |
|---|---|---|
| Slaver name and offers | UI2 `PhasePrompt` / `ActionZone`: THE SLAVER, VISIT THE SLAVER, EXCHANGE SUBJECT, PASS, visible single-select offers and live trade summary. Internal stage remains MARKET. | Exchange semantics match. Corrected public event wording to Slaver; preserve these UI requirements for the later board integration. |
| Slaver rules | Controller directly calls `RoundEngine.resolve_market_player`; one optional hand/offer swap, then the other visitor sees the changed row. Refresh enabled in actual config, starting round two. | Matches migrated swaps/refresh, including old offers returning below the deck and exhausted-row reuse. |
| First visitor | `SeededGameSetup` rolls first_player once; controller visits in that order. | Confirmed migration mismatch: fixed seat 0. Fixed with a keyed seeded first visitor, persistent across rounds. Both orders tested. Combat Reflex is separate and unchanged. |
| Stockpile | Live controller calls `BotRoundEngine._resolve_normal_draws`: flat +1 for merely owning Stockpile. This ignores the operational gate and `stockpile_filter`. The config, printed text and standalone `RoundEngine._run_draw_step` specify Selective Stores. | Real pre-existing U12 inconsistency. Keep U13's operational draw-two/keep-one rule and private choice. Do not import the stale live shortcut. Earlier source notes were too broad about matching live U12. |
| Keep / Bastion | Latest `CastlePowerText`, `CastleIntegrityRules`, Hunt/Siege engines: Keep interception, operational -3, physical Bastion screen while Defunct, overflow and direct-Bastion exception. | Core defensive behavior matches. Current U13 callbacks and ruination semantics intentionally supersede older Lord callbacks. Zero/one Keep and duplicate Bastions follow current user decisions. |
| Summoning Circle | Actual config enables Blood Offering and Blood Conduit. `CastleIntegrityRules.gain_threat` exerts 3 Integrity to prevent 1 Threat at a DEF breakpoint. | Offering is present in `U13Resummoning`; Conduit is absent. Earlier claim that all Castle powers were covered was wrong. Add Conduit against current U13 Threat rules, not old Lord passives. |
| Repairs | Controller explicitly loops further Repairs and permits the remaining Construct action. | Resolved as an intentional U13 difference: one Construct, Repair, or Activate per player per round. Do not restore the sequential U12 maintenance loop. |
| Construction / activation | U12 granular rules differ from the later U13 automatic-project amendment. | Deliberate newer U13 behavior: automatic selected-project progress, full-integrity commissioning, optional early commissioning at 7+. Preserve the September 9 amendment. |
| Integrity / repair lock | U12 ceiling 21, operational floor 7, vulnerability-round lock after crossing below 7. | Present in U13 Structures/Construction. |
| Resummon Tears | Latest U12 config sets resummon_tear_mode to none. | U13 adds one Neutral Tear by an explicitly accepted addendum, documented in `U13_ORIAS_MARK_BOARD_2026-09-09.md`. Intentional difference; preserved. |
| Opening | U12 deals public row then five-card hands, starts selected Castles at full Integrity and pays an opening summon. | Resolved for U13: the first three ordered physical slots start active, the final two remain constructible, and the five-card Hand pays the current U13 Lord cost. A starting Circle applies one automatic Blood Offering. |
| Sigils | Live BotRoundEngine ages Fresh -> Flipped -> gone; `RevealEngine` handles creation. | U13 now creates Sigils at Ward reveal, ages Fresh -> Decaying -> gone, and renders the supplied zone overlays; lifecycle and replay gates are included. |
| Vacant Throne | Controller calls `VacantThroneEngine.resolve_end_round`. | Not connected to U13 full-game conductor. Add alongside banishment/Veil lifecycle. |
| Dominion rites, waiter spending, Veil, victory | Explicit U12 controller/engine phases. | Still pending; existing Souls/Tears counters and bounded test rounds are not a complete game. |

## Corrections shipped with this audit

- Seeded Slaver visitor priority, stored in game_market.first_player. The existing
  seat field names the current chooser; it becomes 2 when both choices finish.
- Slaver wording in public exchange/refresh/pass events, retaining internal keys.
- `U13_GAME_MARKET_V2` in the policy identity. Older game snapshots require a new
  match; no old seed-to-result parity is claimed across the policy change.
- Tests for both visitor orders, plus existing sequential exchange, save/replay,
  rollover and exhaustion checks. Conductor, Random-Legal and Stockpile regressions.
- Corrected completeness claims and updated the next-work queue below.

The audit checkpoint's user runner was **8/8**. The user later accepted the Sigil
checkpoint at **11/11**; the production-opening change expands the next gate to
**12/12**. Windows Godot 4.7.2 remains authoritative.

## Revised queue

1. Waiter spending, Dominion rites, Vacant Throne, Veil and actual victory.
2. Full-match Random-Legal acceptance, then playable UI with the Slaver's actual
   offer presentation and established warning/selection behavior.

Later reviews must follow the playable controller and active config, compare the
called helper with printed rules, and label old bugs, deliberate U13 changes and
missing migrations separately. A green suite verifies its tested behavior; it
cannot establish that an omitted mechanic was migrated.
