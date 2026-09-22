# Kroni full-kit ablation: 16 matched games

Powerless Kroni won **3/16**, compared with **13/16** with the
current bouncing-Consume kit on identical setups. Both bots replanned normally.

## Exact treatment

This is a Python experiment, not a playable rules change. It disables:

- Consume and Ravenous in both authoritative admission and bot availability.
- Cannibal Hunger's automatic own-guard meal and no-guard Hunger loss.
- Standalone Ward/Pass Hunger loss.
- All Hunger gains and the once-per-game personal-Tear milestone.
- Hunger defense bands: Hunger stays zero, leaving fixed Lord defense **4**.

The bot's standalone-Ward Hunger penalty was removed as well, so it does not
avoid Ward for a disabled cost. It uses the same ordinary planning, weights,
recipe access and opponent logic. Removing the entire kit includes removing
its drawbacks, not just its benefits.

Kroni retains his identity, base summon value 5, Fracture value 1, ordinary
Threat counter, and shared combat/economy/victory rules. Defense remains 4 even
at higher Threat, as specified for this experiment; he is not a newly designed
generic Lord with a different Threat defense curve. Opponents retain full kits.
Free monsters, split Ward, Veil timing and round limits are unchanged. Kroni's
absent-Lord breach is not in these matches because he is a participating Lord.

## Results

| Measure | Current bouncing kit | Powerless |
|---|---:|---:|
| Kroni wins | 13/16 | 3/16 |
| Mean ending round | 13.56 | 15.62 |
| Median ending round | 13.0 | 16.5 |
| Range | 10–19 | 9–21 |
| Games in rounds 15–20 | 5/16 | 8/16 |
| Kroni wins in seat 0 / seat 1 | 5/8 / 8/8 | 0/8 / 3/8 |

Victory routes, regardless of winner: current kit {'Dominion': 10, 'Ritual': 6}; powerless
{'Ritual': 12, 'Dominion': 4}. Historical exact-Consume controls won 14/16, but the primary
comparison here is the more recent 13/16 bouncing-kit sample with the same
underlying simulation source.

Each cell below lists Kroni in seat 0 / seat 1; W/L is from Kroni's viewpoint.

| Opponent | Bouncing kit | Powerless |
|---|---|---|
| Deimos | W R11 Dominion / W R10 Dominion | L R14 Ritual / L R11 Ritual |
| Gremory | W R13 Dominion / W R13 Dominion | L R12 Ritual / L R12 Ritual |
| Humbaba | W R14 Ritual / W R18 Ritual | L R19 Dominion / L R14 Dominion |
| Kalligan | L R10 Ritual / W R11 Dominion | L R17 Dominion / W R18 Ritual |
| Kanifous | L R13 Dominion / W R13 Ritual | L R21 Ritual / W R13 Ritual |
| Odradek | L R17 Ritual / W R10 Ritual | L R16 Ritual / W R9 Ritual |
| Orias | W R13 Dominion / W R15 Dominion | L R18 Ritual / L R20 Ritual |
| Valak | W R17 Dominion / W R19 Dominion | L R19 Ritual / L R17 Dominion |

## Interpretation and limits

This estimates the combined value of Kroni's full kit under the current bots,
including changed decisions and the removal of feeding costs. It does not
separate Consume's guard removal, Hunger defense, milestone Tear, or Ravenous.
Sixteen matched games across eight opponent/seed pairs cannot establish a
precise long-run win rate. Opposite seats share a seed.

The drop from 13 wins to 3 is strong evidence that the kit drives Kroni's
advantage in these matchups. All three powerless wins were also current-kit
wins: against Kalligan, Kanifous and Odradek, each with Kroni in seat 1.
Ten current-kit wins became losses, and no current-kit loss became a win.
This does not identify which ability needs changing or justify removing the kit.

The most useful next isolation would keep bouncing Consume and Ravenous but
hold defense at 4 and disable only the Hunger milestone Tear. That would test
the passive rewards separately from the eating powers; defense and the Tear
could then be separated if needed. This is a proposed next experiment, not a
change implemented here. No further tuning was performed for this run.

## Validation and reproduction

Two worker processes ran the same archived repeat `01` matchups. We verified
identical setups, weights and recursive simulation/doctrine source hashes
against the saved current-kit control. Experiment overrides live only in the
new runner's worker processes. Control games were reused, not rerun.

All 16 operation and semantic hashes passed. No Consume/Ravenous declarations,
Hunger-change/milestone events, guard meals or Ravenous rewards occurred. Zero
invalid actual submissions. Four candidate previews were rejected for
`summon_payment_unavailable`, two in each Kalligan game; the bot selected legal
alternatives and both matches completed. These are retained in the evidence,
not counted as valid proposals or hidden. Runtime assertions reject disabled
kit effects or declarations. This is a Python full-match experiment, not native Godot parity testing.

```sh
python Scripts/Sim/run_u13_powerless_kroni_sample.py \
  --baseline ../tempo-roster-162-03 \
  --output ../kroni-powerless-sample-16-reproduction
```

Evidence: `docs/evidence/U13_POWERLESS_KRONI_SAMPLE_16_2026-09-22.json` and its
adjacent `.traces.tar.gz`. The evidence records runner/source hashes, setups,
weights, outcome comparisons and the hash of the saved control report.
