# Corruptor monster recipes — v0.1

Established September 15, 2026 as the starting design baseline. This records the current recipe proposal accepted for iteration; it does not implement monsters in the game. Tier labels describe intended accessibility, not guaranteed summon frequencies.

## Recipes

Recipes count subjects, irrespective of printed card value. Every named subject is required; there are no wildcard ingredients in this baseline.

| Tier | Monster | Required committed cards | Shape | Attack / Armor / Speed |
|---|---|---|---|---|
| Easy | Lemek — Swamp Bruiser | 2 Penitents | 2 | 3 / 4 / 2 |
| Easy | Varn — Swarm Creature | 2 Vultures | 2 | 1 / 0 / 2 each |
| Moderate | Fyra — Flying Charmer | 2 Butchers + 2 Vultures | 2+2 | 2 / 1 / 4 |
| Moderate | Kopita — Swamp Witch | 2 Wrights + 2 Penitents | 2+2 | 2 / 1 / 2 |
| Moderate | Tumler — Support Hunter | 2 Vultures + 2 Wrights | 2+2 | 2 / 1 / 3 |
| Hard | Kurchin — Ancient Tank | 3 Penitents + 1 Wright | 3+1 | 1 / 6 / 1 |
| Hard | Muno — Prism Wraith | 3 Wrights + 1 Vulture | 3+1 | 3 / 1 / 2 |
| Hard | Dotra — Ambush Predator | 3 Butchers + 1 Vulture | 3+1 | 2 / 2 / 2 |
| Very hard | Sooge — Living Turret | 3 Butchers + 2 Wrights | 3+2 | Mobile: 1 / 2 / 2; rooted: 3 / 6 / 0 |
| Very hard | Sinodek — The Banishment Horror | 3 Wrights + 2 Vultures | 3+2 | TBD |

Varn produces 3–5 creatures; this counts as one summon. The swarm-size distribution remains to be specified. Tumler is the multiheaded devil dog, currently represented by Dogger artwork. Dotra uses Batboy artwork. Sooge remains in turret form after transforming.

## Commitment and eligibility

1. Only cards actually committed this round count toward a recipe. Cards used earlier for defense or another function, and cards retained in hand, do not count.
2. A commitment qualifies when it contains at least the required number of each subject. Extra committed cards are allowed.
3. A commitment can produce at most one monster summon, alongside its normal marchers. Recipe cards are part of that commitment, not an additional payment beyond it.
4. Only unlocked, currently eligible recipes are offered. When several qualify, the player chooses which one to summon before finalizing commitment; higher tiers do not automatically override lower tiers and qualifying recipes do not all spawn.
5. Lemek is available from the start. Unlock timing for the other monsters remains to be specified.
6. Each player may have at most one living Sooge and one living Sinodek at a time. These are separate per-type caps; a player may have both. Death or banishment frees that type's slot. There is no additional fixed cooldown in this baseline.
7. The Slaver remains available every round. Alternate events are deferred.

## Shared demand with defensive pairs

Keep the overlap between defensive pairs and monster ingredients deliberately. Defensive needs compete with summoning and saving; intact formations can leave pairs available for offensive commitment.

Current defensive effects, as described by the designer:

| Subject pair | Defensive benefit |
|---|---|
| Penitents | Add 5 defense to their guard zone. |
| Wrights | Immediately add 5 repair or construction value. |
| Vultures | Gain a card every round. |
| Butchers | Kill a random marcher when attacked. |

These summaries do not change existing placement eligibility, duration, targeting, or stacking rules. Defensive opportunity cost must inform recipe balance alongside draw frequency. In particular, recurring Vulture card generation and weaker demand for defensive Butchers may make otherwise similar recipe shapes play differently.

## Simulation assumptions — not gameplay rules

The exploratory simulations used 20-round games, a shared 60-card deck with 15 cards per subject, five cards drawn per round, a ten-card hand limit, and an always-available Slaver with a three-card market and one optional swap per player per round.

The saving policy retained its previous recipe bank and added at most one card per round. This was a simulated strategy, not a newly imposed save restriction. All remaining non-saved cards were used that round.

Sooge and Sinodek were assigned three-round lifetimes solely to estimate availability under their living-copy caps. They do not automatically expire after three rounds under these design rules.

The defensive-pressure experiment independently spent each non-overlapping same-subject pair with 50% probability before commitment. Its protected-saving variant excluded previously saved cards before forming eligible pairs. Neither is a gameplay requirement or an accurate model of board-dependent defensive demand.

That experiment averaged 9.85 summons per player without saving, or 10.78 with protected recipe saving, including 0.65 versus 4.08 combined Sooge/Sinodek summons. With only Lemek and Varn unlocked, no-saving players averaged 9.42 summons. These are heuristic draw-model results, not combat balance predictions or target guarantees.

## Next balance questions

- Measure defensive spending when formations actually have available placements, rather than applying a flat random expenditure rate.
- Check whether moderate monsters provide enough immediate value to interrupt saving for very-hard monsters.
- Evaluate subject-specific opportunity costs, especially Vulture income and Butcher defense.
- Set unlock pacing, Sinodek stats, Varn swarm-size distribution, and remaining ability probabilities/ranges separately.
- Retune recipes only after these interactions are observed; v0.1 is the reference point for comparisons.
