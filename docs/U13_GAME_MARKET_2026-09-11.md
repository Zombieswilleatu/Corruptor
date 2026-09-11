> Audit correction: `U13_U12_PARITY_AUDIT_2026-09-11.md` replaces fixed visitor
> priority below with a seeded first visitor and identifies remaining migration gaps.

# U13 public market checkpoint

The game foundation runner now expects **8/8**. The market is part of the
full-game conductor and its private-choice path. Exercise boards and U12 remain
separate; human market UI follows completion of the authoritative match loop.

## Source and rules

Recovered from `GameSetup._deal_market`, `RoundEngine.resolve_market_player`,
`RoundEngine.refresh_market_offers` and the current UI2 lab ruleset's
`RuleConfig.market_refresh = true`. The older static-market profile is not used.

- Deal three public offers from the shared sixty-card deck before the opening
  five-card hands. Forty-seven cards remain in the deck after setup.
- Ordinary draws and all Stockpile selections finish before market decisions.
- Seat 0 acts, then seat 1, matching the conductor's current first-seat convention.
  Market priority does not use the later combat Reflex result.
- Each player may pass or exchange one card from their own hand for one current
  offer. No value/suit matching or resource cost applies. Hand size is unchanged.
- The given card joins the end of the public row. The second player chooses from
  the updated row and can take that card. Already-taken offers are unavailable.
- Round one retains the opening row. Starting in round two, refresh after draws:
  draw three new offers, then return the old offers below the deck in the legacy
  push-front order. Recycle the discard deterministically when needed. Only when
  no other cards remain may refresh reuse the old row.
- Market cards are a distinct neutral card zone, unavailable to ordinary draws,
  Sifting, guard deployment or hand payments until exchanged into a hand.

The first-seat convention remains the existing conductor's fixed seat 0. This
checkpoint does not introduce alternating initiative or import old Lord rules.

## Choice API and authority

`to_planning()` returns `game_market_choice` and `player_id` when a seat needs to
act. `market_choices(player_id)` lists Pass and each current hand/offer pair.
`choose_market(player_id, choice)` accepts exactly one of:

- `{"market": "Pass"}`
- `{"market": "Swap", "take_id": "...", "give_id": "..."}`

`to_planning(true)` resolves Stockpile and market choices with keyed Random-Legal
sampling through the same authoritative APIs. Market candidates read only the
chooser's hand and public row. Swaps are optional, and passing always remains legal.

The public-state hook stays blocked until both seats finish. Powers, payments,
Castle choices and combat orders therefore see the final post-market hand.
Invalid, stale, foreign-card and out-of-turn choices leave the match unchanged.
Saves retain the market row, round and next seat. Card-zone validation enforces
unique stable identities and neutral market ownership; snapshot validation rejects
market clocks inconsistent with the draw stage and hook.

Offers and exchanges are public. Other hidden cards retain existing projections.
Shared discard recycling was factored into a helper also used by neutral market
draws; its keyed shuffle and error propagation are unchanged.

This checkpoint introduced `U13_GAME_ECONOMY_V3`. The later paid production
opening advances that policy to `U13_GAME_ECONOMY_V4`; both changes require new
games, and neither promises old seed-to-state parity.

## Verification

Market tests cover opening order, public faces, full-hand swaps, explicit passes,
one action per seat, updated-row selection, stale offers, wrong zones, atomic
rejection, duplicate IDs, saves between seats, full-round completion, rollover
order, keyed Random-Legal replay and exhausted-deck reuse.

Existing directed suites explicitly pass market decisions to retain their combat
fixtures. The Random-Legal suite makes real market choices. Stockpile tests still
cover seat-ordered draw choices and scarcity before the market opens.

Local runtime: Godot 4.5.1 compatibility. User gate: Windows Godot 4.7.2.
Next full-game work: waiter-to-Tear spending, Veil progression and legitimate
victory, followed by sustained full matches and the playable UI.
