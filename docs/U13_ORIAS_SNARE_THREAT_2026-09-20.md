# Orias V18: Snare aggression follows resulting Threat

V18 changes the experimental Python Snare doctrine. Web remains at V17,
including its targeting, scoring and retention. The shared planner is unchanged
except its policy version. This is not a new native Godot acceptance gate.

## Decision rule

The user requested aggressive Snare use while resulting Threat stays at two or
less, becoming selective above two, with Summoning Circle absorption included.

- Forecast the immediate +1 Threat through the same defense thresholds and
  operational-Circle condition as `Battle.conduit`. A Circle absorbs one only
  when that increment would reduce Lord defense. It loses three Integrity.
- At resulting Threat **0–2**, permit an opportunistic supported attack even
  when current Guard/Ward recruitment looks better. Discount the attack's
  opportunity value, capped at half its estimated benefit, rather than vetoing
  the cast. A positive benefit still has to cover its cost.
- At resulting Threat **above 2**, require the supported Hunt/Siege to score at
  least as well as the competing plan in **both** public new-Guard scenarios
  (Guard values two and four). Its marginal benefit must also cover its cost.
- Charge for the Circle's three Integrity. Charge extra if it falls below
  seven Integrity and loses operation. This is loss of function, not automatic
  destruction. A Lord Ward later in the round does not remove immediate
  selectivity or undo Circle damage.

The low-Threat base cost is four, plus two for an unabsorbed defense loss.
Above two, cost is `10 + 4 * min(3, resulting Threat - 2) + 4 * defense loss`.
When a Circle absorbs the increment, replace the defense-loss charge with six
for its Integrity, plus twelve if it loses operation. A later Lord Ward reduces
the non-Circle cost by two, with a floor of four. These integer costs are
untuned policy preferences, not measured win probabilities.

## Competing plans and bounded forecast

The forecast uses only cards left after the current plan's combat, Guard, Work
and Rite commitments. It carries forward conditional enemy Guard losses,
Castle damage and eligible public arrivals, plus own declared Guards
and recruitment screens. It assumes no future draw or private opponent order.
Current one-round deployment limits expire in the forecast.

The supported full-hand attack uses the ordinary attack, recruitment and recipe
score. Its alternatives use ordinary Ward and recipe proposals, recipe saving,
and two Guard-first bundles: the highest-scoring deployment in each lane,
followed by Ward or saving with disjoint remaining cards. The strongest of
those three bounded bundles is the opportunity-cost comparator. This shares
the default scoring vocabulary of the common doctrine; Snare's existing
benefit weights also remain fixed defaults.

This is deliberately a bounded opportunity-cost estimate, not recursive
planning or a promise of the next order. It does not forecast unknown enemy
orders, draws, full spatial survival, every defensive plan adjustment, or all
possible card subsets. The next-round planner remains free to change course.
Existing limits remain 32 complete plans and eight legality previews. Repeated
Snare forecasts are cached only within a single Facts/decision instance.

## Verification before matches

PyPy passes **61 focused tests** across Snare follow-up, Orias, coordination and
common planning. Seven new methods cover the two/three Threat boundary,
competitive high-Threat attacks, healthy/damaged Circle behavior, disjoint
Guard/Ward cards, recipe competition and Lord Ward timing. The Circle parity
test compares directly with `Battle.conduit` over six starting Threat values
and four Integrity values (24 combinations). Existing public-information,
immutability, both-seat, legality, budget and power-timing checks still pass.

AST/source identity checks verify that Web's functions/constants, all shared
planner code except its version, and the Orias power wiring match V17.

The saved-board audit re-scores **all 16 V17 Snare casts** from the preceding
Web experiment. All 16 were in the low-Threat band, and all remain positive and
selected on re-decision. Their actual historical next orders were twelve
Wards, two Hunts and two Sieges. Keeping those casts is intentional under the
user's revised risk rule; this audit does not establish better follow-through.
Saved-view re-decisions isolate scoring with a permissive preview stub; actual
legality is checked separately in tests and full matches.

## Fixed matched experiment

- Previous focal policy: V17 at `e99a9526144e734e2b21e14bedbcfba9648b4947`.
- Candidate: V18 described above, with Web fixed at V17.
- Opponent in both arms: V15 at `c92181268fae026f30d76d97c2c5b822185848ca`.
- Gremory, Deimos, Humbaba and Kalligan; one fresh seed per opponent, both
  seats, both variants: **16 games / 8 matched pairs / 4 seed-opponent blocks**.
- Namespace `u13-orias-snare-threat-v18-2026-09-20`, ordinary five-Castle
  loadout, fixed default weights, greedy selection, common engine, 40-round cap.
- Three PyPy workers, each recycled after one game to release accumulated
  memory. Worker count affects execution only, not policy or case identity.
- The manifest freezes cases, runtime, engine, policy/harness and runner hashes
  before play. Failed/censored cases remain explicit, not defeats. No policy
  edits or result-dependent stopping are permitted within this campaign.

Run or resume with `Scripts/Sim/run_u13_snare_comparison.py --output DIRECTORY
--workers 3` using PyPy with `PYTHONPATH=Scripts/Sim` from the repository root.
The launcher defaults to two workers for lower memory use.

This is a small diagnostic comparison, not a roster-wide balance result. The
two seats within each seed-opponent block are related observations. Raw attack
follow-through alone is insufficient to judge a rule explicitly allowing
cheap speculative casts; Threat, Circle costs and outcomes must accompany it.

## Match results

All **16/16 games completed**, totaling **330 rounds**, with zero failures,
zero censors, zero rejected previews and no worker interruptions. All source
identity checks passed. Every matched pair had the same winner: five pairs won
by Orias and three lost. Both versions won **5/8**.

| Measurement | V17 | V18 |
| --- | ---: | ---: |
| Wins | 5/8 | 5/8 |
| Mean rounds | 20.50 | 20.75 |
| Snare casts / activations | 14 | 13 |
| Hunt/Siege in the effective round | 3/14 (21.4%) | 4/13 (30.8%) |
| Ward in the effective round | 11 | 9 |
| Casts resulting in Threat one | 14 | 13 |
| Forecast Circle absorptions | 2 | 2 |
| Forecast Circle Integrity spent | 6 | 6 |
| Casts forecast to disable Circle operation | 1 | 0 |
| Web casts / activation-hit events | 53 / 1,030 | 52 / 1,016 |

Against each opponent, both versions won the same number: Gremory 2/2,
Deimos 0/2, Humbaba 1/2 and Kalligan 2/2. These fresh seeds differ from the
previous Web experiment; its 2/8 result is not this experiment's baseline.

V18 selected nine low-Threat opportunistic setups and four competitive
follow-ups. The four competitive forecasts are not a promise of four actual
attacks: the next planner still responds to the board it receives.

Every cast in both arms resulted in Threat one. All observed Orias planning
Threat values were zero or one, and no ready-Snare decision projected Threat
above two. Consequently, the selective high-Threat branch is verified by the
directed tests, **not exercised by this match cohort**. The batch also does not
show a higher cast rate: V18 used one fewer Snare overall.

There is one concrete Circle correction. In V17's Gremory seat-zero game,
round 12, a selected Snare forecast an operational Circle falling from eight
Integrity to five; the following order was Ward. Re-scoring that exact saved
plan under V18 changes its score from **+4 to -3**, accounting for the loss of
Circle operation. This same-board diagnostic supports the cost correction; it
does not establish that it caused a different match outcome.

Threat and Circle costs above are public pre-cast forecasts, with the cost
model independently checked against game authority. Follow-up orders and
combat resolutions are observed events. They are not counterfactual measures
of prevented enemy Guards or of the Circle's eventual survival.

## Disposition

Keep V18 as the requested risk-aware Snare experiment, with Web fixed at V17.
The small cohort shows **no strength gain**, and its one extra attack
follow-through is weak evidence by itself. The remaining pattern is that Ward
keeps Orias at low Threat, so the costly-cast cutoff rarely has an opportunity
to matter. Further strength work should examine the attack/recruitment tradeoff
rather than claim that this threshold alone solved the prior failures.

Machine-readable evidence: `docs/evidence/U13_ORIAS_SNARE_V18_2026-09-20.json`.
The full archive includes all sixteen checked game records, all three policy
packages, both saved-case audits, runner, logs and publication identity.
The manifest's source revision is the pre-edit V17 base; the frozen candidate
bytes and harness hash identify the measured V18 implementation.
