# Bot Doctrine — Veil Clock Sanity

**Reconciled for U13 on 2026-09-16.** This is a doctrine contract, not a rules
change or an already installed safety heuristic.

## Narrow exclusion

Exclude a voluntary complete plan only when it provably causes an avoidable
opponent victory at the next actual victory check. Evaluate the full plan's
known consequences and scheduled effects; a dangerous intermediate state is
not necessarily the state at which the game awards victory.

Current U13 settles all sealed actions, Marching, Vacant Throne rewards and
scheduled round pressure before the final victory check. That check gives
Ritual precedence over Final Collapse, then Dominion. Use authority's actual
winner and tie handling rather than comparing independent win flags.

The shared Veil includes both players' personal Tears and neutral Tears.
Advancing it is an ordinary strategic tradeoff. **Remove the old prohibition
on merely "materially advancing" a clock where the opponent currently leads.**
Hunt remains available when its pressure, rewards or denial justify the risk.
A possible future enemy Resummon is not an observed immediate loss.

## Certainty and alternatives

- A hard exclusion requires a known losing result and an available alternative
  that avoids that proven loss. Keep legal last-chance plans when passing or
  every known continuation already loses.
- Unrevealed orders, unknown future choices and unresolved random effects are
  uncertainty. One speculative opponent scenario cannot certify a hard veto.
- Account for the whole plan: spending Souls may remove a Ritual win; other
  same-round gains may create one; Lord presence matters for Ritual; scheduled
  pressure can make Pass lose too.
- Once a loss is proved avoidable, exclusion takes precedence over heuristic
  score. A mere possible loss is scored as risk.
- Reuse bounded public projections and the rules evaluator. The earlier
  instruction to deep-copy a whole world for every candidate is retired.

## Historical regression

The following legacy report preserves the intent, not current U13 terminology
or payment rules. Reproduce the situation using current authority before using
it as a live policy fixture.

Observed playable match, seed 20260724:

- Veil: 11 / 12
- Orias personal Tears: 6
- Valak personal Tears: 2
- Valak had already used no Invocation and could legally invoke.
- Valak voluntarily paid 13 for Cataclysmic Invocation.
- Invocation added 1 Tear / advanced Veil 11 -> 12.
- Final Collapse awarded Dominion to Orias.

Rules resolution was legal.
Bot doctrine was wrong.

Expected doctrine:

Valak must reject Cataclysmic Invocation in that state because invoking
immediately awards the opponent the game.

## Directed contract cases

1. A Tear contribution causes an otherwise avoidable enemy Dominion: exclude
   only when that remains the provable result at the actual settlement point.
2. Clock advancement produces our own victory: allow it.
3. Productive Hunt advances the shared clock without proving an enemy win:
   retain it for ordinary strategic evaluation.
4. An intermediate enemy Dominion is superseded by our final Ritual: respect
   the actual end-of-round result.
5. Pass already loses to scheduled pressure: preserve legal attempts to change
   the result instead of eliminating the entire candidate set.
6. Final Collapse, equal Tears and the living-Lord Ritual condition use current
   authority's precedence and ties.

The first complete-information Python settlement fixtures live in
`Scripts/Sim/u13_doctrine/test_diagnostics.py`. They establish the situations;
they do not give a policy knowledge of hidden orders or implement a proof
procedure. See [the doctrine start checkpoint](../docs/U13_DOCTRINE_START_2026-09-16.md).
