# U13 game foundation — Development planning checkpoint

The full-game runner now uses `U13GameRandomLegal`, with composable Development
candidates in `U13GameDevelopment`. Existing rules and the old board/fixture bots
are unchanged. The new planner is for reachability, not intelligent strategy.

## What the audit found

The mechanics for guard deployment, returning a banished Lord, construction,
automatic project progress, early activation/Commission, repairs, and Deimos's
War Foundry reconstruction already existed. The missing piece at this checkpoint
was consistently composing them into one complete submission from real hands.

In the old scenario chooser, resummon candidates were appended after guard
candidate expansion. Thus a return could be combined with a Castle action but
not with guard deployment. Guard samples were also prepared independently of
later Castle/power payments, leaving many combinations to fail the final filter.

`BotDeployDoctrine.reserved_cards` supplied the reusable idea: explicitly account
for competing card uses before proposing deployments. No old gameplay authority
or Smart Core monolith was imported.

## New path

1. Read the player's public view and the existing finite Lord/combat vocabulary.
2. Choose a legal Lord power or pass.
3. Consider returning the Lord, using the unreserved hand.
4. Consider a Castle action alongside that return/power.
5. Consider combat using the remaining budget (no combat with resummoning).
6. Add legal guards to the remaining cells, using only unreserved cards.
7. Validate the final complete submission through `U13Match.preview_submission`.

Every candidate extension passes `legal_order_candidates`, so costs, Orias's
placement cap, occupied cells, resummon requirements and Castle restrictions stay
owned by existing U13 validators. `U13GameDevelopment` only proposes payloads.
It reads public entities and the player's hand; it does not inspect hidden cards.

Each random choice has a stage-specific keyed identity. Pass is an explicit
choice at power, return, Castle and combat stages. Guard count can be zero.
Rejected candidates do not mutate the owner. A final invalid plan is reported as
an error, rather than being disguised as an all-pass success.

The bot policy version is `U13_GAME_RANDOM_LEGAL_V1`. Seeds now produce different
bot choices than the former scenario bot, but replay of the same new policy is
exact. Recorded submissions still resolve under unchanged mechanics.

## Verification

`run_u13_game.sh` now expects **5/5**:

- Economy and seeded opening.
- Conductor / each-hook save and restore.
- Three Random-Legal rounds with identical regenerated plans and resolved replay.
- Directed Development lifecycle and interactions.
- All nine Lords generating and locking complete plans, resolving Development,
  and restoring the resulting state.

Directed cases include:

- A real opening constructs a Keep while deploying guards and committing a Ward.
- Automatic construction advances once on subsequent pass rounds.
- Early activation stops free protected progress; repair can coexist with a guard.
- A banished Lord returns while constructing and deploying a guard in the same
  Development; the Lord identity, summon count and single Neutral Tear are checked.
- Deimos reconstructs a ruined Siege Engine through normal protected construction.
- Combat/guard and summon/guard card reuse are rejected.
- Sealed choices resume from JSON with identical state and private/public events.

The banishment and ruined-Engine cases use explicit pre-match fixtures. They are
not represented as autonomously reached full games. The ordinary build lifecycle
and random rounds start from the new seeded opening without fixture intervention.

Local tests use Godot 4.5.1 for compatibility. The user-facing runner remains
pinned to Windows Godot 4.7.2 stable, with the existing 90-second per-suite limit.

## Still pending

This checkpoint completes the combination path for the existing Development
systems; it does not claim that every game rule is implemented. Castle printed
powers (Keep interception, Bastion layers, Stockpile selection), remaining
Development/market decisions, waiter-to-Tear spending, Veil, and legitimate victory
remain on the roadmap. Human UI wiring follows the complete authoritative loop.

Candidate sampling is deliberately bounded: one Lord power, existing combat
payments, single/pair Castle payments, and ascending/descending payment prefixes
for resummoning. This proves useful combinations are reachable, not that every
possible legal strategy has been enumerated or that the bot plays well.
