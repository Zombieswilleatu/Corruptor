# Kanifous V20: Wish timing and delayed Prices

V20 changes native Kanifous's experimental Python doctrine. It evaluates each
Wish with the cards, repair work, recruitment and Supplicants committed by the
complete order. Breach Wishes retain V19's proposal rules. The game engine and
native Godot code are unchanged.

## Decisions

| Wish | V20 judgment |
| --- | --- |
| Wealth | Count hand space after this order spends cards. Use the actual 20%/50%/30% distribution for one/two/three draws, capped at ten cards. These cards arrive after combat and cannot pay for the current order. |
| Longevity | Credit only healing left after own Guard/Work development, up to eight Integrity. Add value when that restores the seven-Integrity operational threshold. |
| Power | Credit one guaranteed body and bounded lane need after own recruitment. Additional random Wish bodies stay unknown. |
| Death | Value visible enemy material removed, subtract friendly material, and reserve for potential new friendly bodies if the circle overlaps their spawn region. Consider the densest cluster and the most valuable enemy in each lane. |
| Resurrection | Value current eligible losses at their restored profiles. Enforce limited living copies, including a copy recruited by this order. Give discounted credit for reachable public danger instead of treating every wounded unit as a casualty. |

Death and Resurrection use twice `(2 × Attack + Armor + HP)` as a material
heuristic, with a minimum of four points. Death uses current profiles;
Resurrection uses full restored profiles, including Sooge's permanent turret
form. Known own Supplicants consumed by an attack or Rite are excluded from
surviving bodies and prospective Resurrection credit. Resurrection fires after
Marching, so restored bodies do not participate in that same Marching phase.

Prospective Resurrection danger is a discounted geometric scenario, not a
death prediction. Current contact receives half material value; a possible
contact within nominal travel receives a quarter, and only if four enemy hits
could overcome current HP plus Armor. It does not solve pursuit, fort blocking,
target selection, healing, special monster attacks or survival. Enemy sealed
orders and future random outcomes are unavailable.

## Price reserve

A successful Wish schedules one Price one to three rounds later. An effectless
Wish schedules none. V20's score reserves for a successful Wish's prospective
liability; a negative score on an effectless scenario does not claim the engine
charges for failure.

The reserve uses current projected public asset pools, weighted by the rule's
eligible outcome categories: Cards 30, Blood 30, Guards 15, Stone 15, Soul 5,
Ruin 4, Wishmaster 1. A category's probability does not grow with its number of
targets. Cards and Blood expose up to two items; the other categories expose
one. The score includes the operational and destruction risk of Stone damage,
and recognizes active standing Castles below seven Integrity as eligible.

This is a heuristic in common score points, not an exact future expected loss.
It uses assets after known own card commitments and Work, excluding consumed
Supplicants. It does not forecast the intervening board, new random bodies,
future hand contents, Price targets, neutral-tear reactions, or the benefits of
subsequent responses. A ten-point minimum reserve remains. Each outstanding
own Price adds the previous ten-point debt penalty; a Price due by next round
adds four more. Enemy debts are excluded. No simulation seed is consulted.

## Bounded search

The common planner coordinates Wish scores with complete orders. An additional
source can replace or add a Wish while preserving an existing order's combat,
Guards, Work, Rites, recipe and other powers. It examines at most sixteen Wish
candidates and retains at most four alternatives within the existing total of
32 complete plans and eight legality previews. It is a small fixed search,
not an enumeration of all hand subsets. Ordinary hold/omission alternatives
remain available, and common assembly enforces at most one Wish.

## Verification

The focused PyPy suite passes **99 test methods**, including common planning,
coordination, Gremory, Orias, Snare follow-up, Kanifous and engine power tests.
The **13 new Kanifous methods** also pass under CPython. Tests cover card-space
accounting, capped draw expectations, repair overlap, operational thresholds,
Price weights and urgency, friendly fire and spawn exposure, limited copies,
reachable danger, consumed Supplicants, both seats, hidden-data independence,
input immutability, deterministic ordering and work limits. Authority checks
cover effectless Wishes, Price scheduling/eligibility, Death casualties and
Resurrection's next-round readiness. Existing engine tests exercise the actual
end-of-Marching hook and Sooge restoration.

The first complete-game attempt caught an observation-contract error: ordinary
planning views contain the current loss ledger but omit its redundant round
marker. The planner now uses the round-start reset contract and honors a round
marker only when a scenario explicitly supplies one. A regression test covers
the ordinary marker-free view. The failed attempt and its source identity are
preserved; the same predeclared game cases were restarted after the fix.

Eight non-Kanifous opening decisions and a directed Deimos Breach Wish decision
retain V19's exact plans, scores and work counts. This is bounded regression
evidence, not proof of all later trajectories. The two previously documented
Deimos replay subcase failures occur before planning on unchanged engine data;
that historical replay test is outside this focused suite.

## Four-game diagnostic

Against frozen V19 Gremory, with the same fixed seed in each seat:

| Kanifous | V19 | V20 |
| --- | ---: | ---: |
| Wins | 1 / 2 | 2 / 2 |
| Decisions | 40 | 35 |
| Resolved Wishes, including Breach | 39 | 32 |
| Effectless resolved Wishes | 0 | 0 |
| Prices collected | 35 | 27 |

All four games completed through ordinary Final Collapse with zero rejected
previews. Seat zero changed from a V19 loss in round 19 to a V20 win in round
18. Seat one remained a win, ending in round 17 rather than round 21. Totals
span different game lengths and board trajectories; fewer Prices alone is not
an efficiency finding.

On **75 saved decision points**, both versions received the identical public
board and authority legality preview. Complete plans differed on 54 boards;
ordinary Wish declarations differed on 45. V19 chose 66 Death, four Power and
three Resurrection Wishes; V20 chose 29 Death and 34 Resurrection Wishes.
These counts exclude Breach Wishes. This verifies a substantial behavior change,
not that each changed choice was better. The four-game result is encouraging
but provides no reliable general strength estimate.

The audit's first report-reader call had an argument mismatch after all games
had completed. Its corrected format-specific reader validated the untouched
case identities, trace hashes and operation hashes and produced the summary.
All policy sources matched the predeclared manifest; only the audit reader
changed afterward. Both runner versions and the postprocessing identity are
preserved with the raw evidence.

## Reproduce

From the repository root:

```bash
PYTHONPATH=Scripts/Sim pypy3 Scripts/Sim/run_u13_kanifous_audit.py \
  --output /tmp/kanifous-v20-audit --workers 2

PYTHONPATH=Scripts/Sim pypy3 -m unittest \
  u13_doctrine.test_common u13_doctrine.test_coordination \
  u13_doctrine.test_gremory u13_doctrine.test_orias \
  u13_doctrine.test_snare_followup u13_doctrine.test_kanifous \
  u13_pysim.test_powers
```

The audit freezes V19 (`3324566936834d42a52c8ff0173f3b612a709616`), runs old and
new Kanifous against frozen V19 Gremory with one fixed seed in both seats, and
saves the complete operation stream plus both policies' decisions on every
focal public board. Counterfactual choices receive the same authority legality
preview and no later events. Their downstream outcomes are not simulated on
that board. Repeated openings and both resulting trajectories are correlated.
This small diagnostic does not establish a change in win rate or native
Godot acceptance.
