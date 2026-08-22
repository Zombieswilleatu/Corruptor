# Bot Doctrine — Veil Clock Sanity

## Hard invariant

The bot must not voluntarily take any action that advances the Veil clock
when the resulting state would award Dominion to the opponent.

This is a general doctrine rule, not a Cataclysmic Invocation special case.

Before any voluntary action that can increase total Veil / Neutral Tears /
otherwise advance Final Collapse, the bot must evaluate the resulting public
Dominion state.

Reject the action when:

- the action advances the Veil;
- that advancement reaches or materially advances toward a collapse state
  where the opponent is currently ahead enough to win; and
- the action does not itself change the resulting Dominion winner in the
  bot's favor.

The bot MAY advance the clock when doing so produces an immediate bot win,
or when simultaneous effects caused by the action alter the Dominion result
so that the opponent does not win.

## Canonical regression

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

## Future regression contract

Given a voluntary candidate action A:

1. Clone the current state.
2. Apply/evaluate A's clock-changing consequences.
3. Check the resulting winner / Dominion state.
4. If opponent wins and bot does not win, score A as forbidden.
5. This veto must occur above ordinary heuristic utility scoring.

Do not merely apply a large negative score. Immediate self-loss by voluntarily
advancing the clock should be excluded from the candidate set.
