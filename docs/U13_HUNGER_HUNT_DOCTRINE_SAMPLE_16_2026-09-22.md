# Hunger-aware Hunt doctrine against full-kit Kroni

Kroni won **9/16** with the new opponent valuation, compared with
**13/16** in the matched current-kit control. His gameplay rules,
Hunger, defense, powers, rewards and upkeep were unchanged.

## Exact scoring experiment

For Hunt against a living enemy Kroni, let H = min(Hunger, 3).

- Predicted banishment: add **8 × H** score (maximum +24).
- Otherwise, predicted guard removal: add **3 × H × min(guards removed, 2)**
  (maximum +18).
- No extra bonus for an attack that neither banishes nor removes guards, for
  Hunger 0, Siege, other Lords, or a banished Kroni. Existing damage/recruit
  value remains unchanged.

These are bot score points, not attack strength or damage. Banishment and guard
bonuses do not stack. The cap follows Hunger's highest defense/radius tier.
The once-earned milestone Tear receives no reclaim credit. Guard removal is a
bounded public-board proxy for useful pressure, not a promised future banishment.

The bonus is used by ordinary and recipe attack valuation, and corrected when
Rites spend Supplicants or artillery changes the predicted outcome. Existing
closing priorities and candidate budgets remain. All changes are installed
inside experiment workers; no playable doctrine or gameplay files were edited.
No coefficients were retuned during or after the batch.

## Results

| Measure | Current doctrine | Hunger-aware Hunt |
|---|---:|---:|
| Kroni wins | 13/16 | 9/16 |
| Mean ending round | 13.56 | 15.25 |
| Median ending round | 13.0 | 13.5 |
| Games in rounds 15–20 | 5/16 | 3/16 |
| Opponent Hunts | 21 | 73 |
| Kroni banishments from those Hunts | 8 | 27 |
| Guards removed by those Hunts | 15 | 87 |

New game range: 9–22 rounds. Victory routes, both
winners combined: {'Dominion': 6, 'Ritual': 10}. Kroni wins by seat 0 / seat 1:
3/8 / 6/8.

The archived doctrine counts selected Hunts; the new event counts resolved
Hunts. Trace operations were also checked below to confirm the new selections
and reported resolutions agree. Totals include different game lengths.

## Hunt choice by observed Hunger

Hunts selected / decisions while enemy Kroni was alive:

| Hunger | Current doctrine | Hunger-aware Hunt |
|---|---:|---:|
| 0 | 7/52 | 7/55 |
| 1 | 3/30 | 11/44 |
| 2 | 3/37 | 17/40 |
| 3+ | 8/90 | 38/81 |

These are observations from diverging games, not identical-board evaluations.
Changes in Hunger exposure, guard layouts and survival can alter these rates.
They do not prove a specific rejected candidate was objectively superior.

## Matchups

Each cell lists Kroni in seat 0 / seat 1; W/L is from Kroni's viewpoint.

| Opponent | Current doctrine | Hunger-aware Hunt |
|---|---|---|
| Deimos | W R11 / W R10 | W R12 / W R12 |
| Gremory | W R13 / W R13 | W R14 / L R14 |
| Humbaba | W R14 / W R18 | W R13 / W R22 |
| Kalligan | L R10 / W R11 | L R9 / L R20 |
| Kanifous | L R13 / W R13 | L R13 / W R13 |
| Odradek | L R17 / W R10 | L R12 / W R16 |
| Orias | W R13 / W R15 | L R11 / W R21 |
| Valak | W R17 / W R19 | L R20 / W R22 |

## Interpretation

Kroni fell from 13/16 wins to 9/16 without any rule/stat nerf. Opponent Hunts
rose from 21 to 73 and banishments from 8 to 27. While facing living Kroni at
Hunger 3+, Hunt selection rose from 8/90 decisions (8.9%) to 38/81 (46.9%).
That is substantial support for the hypothesis that opponent valuation was
part of his apparent dominance. It does not prove the old avoidance was caused
only by high defense: these are different evolving game states, and the new
bonus explicitly rewards pressure.

This is a more promising direction than immediately removing Hunger. A 9/16
result in these repeatedly used seeds is not proof of balance or evidence that
this coefficient is optimal. Fresh paired seeds should be the next validation
before adopting the doctrine or deciding another stat nerf is needed.

Pacing remains uneven: 10 games finished before round 15, three in rounds
15–20, and three after round 20. The improved 15.25-round mean alone does not
meet the goal of most games lasting 15–20 rounds.

## Validation and limits

Two workers completed 16 matches, same seeds, seats, castles, flags and weights
as the bouncing-kit control. Recursive source hashes match the control; only
the experiment runner's installed valuation overrides differ. Both players
replan normally. This tests the intervention under these bots, not optimal
human play or a universal balance claim. All sixteen seeds have already been
used for exploratory tests; a successful result needs fresh-seed confirmation.

36 focused scoring checks covered increasing/capped Hunger, banishment versus
guard credit, ineffective Hunts, other Lords and dead targets. Exact-source
guards verified the Supplicant correction patch. Another 34 real-board
checks confirmed the predicted material outcomes and strength were unchanged,
and valuations changed by exactly the computed bonus. All control and experiment
operation/semantic hashes passed. Rejected previews: **2**, details
retained in evidence; all actual submissions were legal. No Godot gameplay
change or new native parity run was required for this process-local bot test.

```sh
python Scripts/Sim/run_u13_hunger_hunt_doctrine_sample.py \
  --baseline ../tempo-roster-162-03 \
  --output ../kroni-hunger-hunt-sample-16-reproduction
```

Evidence: `docs/evidence/U13_HUNGER_HUNT_DOCTRINE_SAMPLE_16_2026-09-22.json`
and adjacent `.traces.tar.gz` containing all new operations and policy traces.
