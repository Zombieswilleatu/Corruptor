# Corruptor Human Agency / Human Legibility Harness

## Contract

The harness tests whether a human deliberately makes an informed decision.

Agency classes:

- PASSIVE
- AUTOMATIC
- TRIGGERED_CHOICE
- PLAYER_ACTIVATED

Only PLAYER_ACTIVATED satisfies the rule that every production Lord must have
at least one actively activated power.

To qualify as PLAYER_ACTIVATED, the live human path must ultimately prove:

1. human may decline / not activate;
2. game stops before applying the power;
3. explicit human input activates it;
4. no timeout/default silently chooses activate;
5. activation has a distinct decision/result;
6. cost/consequence is visible before confirmation.

## Layer A - production-truth census

Current true player-activated powers:

- Orias: Snare
- Kalligan: Inferno
- Gremory: Inevitable Ruin
- Humbaba: Toll

Current active-power gaps:

- Deimos
- Valak
- Kroni
- Odradek
- Kanifous

Audit corrections:

- Valak Projection is production PLAYER_ACTIVATED through the post-Resolution Life Essence spend window.
- Kroni Consume and Ravenous are automatic.
- Odradek Reconfiguration is automatic.
- Kanifous Invoke is triggered choice, not optional activation.


## Commitment timing axis

Agency and timing are independent contract axes.

- PRE_COMMITMENT — the power's meaningful effect/choice occurs before the
  Commitment lock.
- POST_COMMITMENT — it occurs at Reveal or later.
- CROSS_COMMITMENT — the same semantic power has meaningful effects on both
  sides of the Commitment lock.

Current 41-power census:

- PRE_COMMITMENT: 7
- POST_COMMITMENT: 29
- CROSS_COMMITMENT: 5

The five CROSS semantics are Orias Relentless Pursuit, Kroni Hunger Track,
Kalligan Wildfire, Gremory Ruinous Harvest, and Kanifous Breach: The Price of
Wishes.

This timing axis does not change agency classification. For example:
Orias Snare is PLAYER_ACTIVATED + PRE_COMMITMENT; Valak Projection is
PLAYER_ACTIVATED + POST_COMMITMENT; Kanifous Invoke is TRIGGERED_CHOICE +
POST_COMMITMENT.

## Layer B0 - runtime/source contract

Expected current failures:

- KALLIGAN/WILDFIRE/HUMAN_DECISION
  Current repair/destruction behavior auto-targets Scorch instead of stopping
  for a human target choice.

- KALLIGAN/INFERNO/DEFAULT_SAFE
  Siege resolution currently defaults omitted use_inferno to true. An omitted
  human decision must never silently mean ACTIVATE.

Do not weaken the contract to make these green.

## Next: Layer B1 - deterministic controller fixtures

Prove no mutation before confirmation, pass vs activation outcomes, and that no
bot doctrine answers a human decision.

## Later: Layer C - UI2 human legibility

Exercise real prompts, VIEW BOARD, card inspection, staged-choice retention,
invalid-input explanations, accepted-input feedback, and visible persistent
state.
