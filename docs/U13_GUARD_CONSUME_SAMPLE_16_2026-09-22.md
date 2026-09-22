# Kroni bouncing Consume: 16-game follow-up

The prototype creates meaningful friendly-fire risk, but this sample does not
establish it as a sufficient Kroni balance fix. Kroni still won 13/16 games.
Keep it as a playable prototype, not a balance sign-off. No additional rule,
stat, pricing, or doctrine changes were made for this batch.

## Matched results

| Measure | Historical control | Current prototype |
|---|---:|---:|
| Kroni wins | 14/16 (87.5%) | 13/16 (81.25%) |
| Mean ending round | 15.06 | 13.56 |
| Median ending round | 15.5 | 13 |
| Range | 9–21 | 10–19 |
| Finished before round 15 | 7/16 | 11/16 |
| Finished in rounds 15–20 | 8/16 | 5/16 |
| Finished after round 20 | 1/16 | 0/16 |
| Dominion / Ritual finishes | 7 / 9 | 10 / 6 |
| Round-25 cutoff | 0 | 0 |
| Consume enemy meals | 139 | 76 |
| Consume friendly meals | 0 | 40 |
| Consume selections | 150 | 133 |

Enemy guard removals fell 45.3% in total, while 34.5% of current Consume meals
were friendly. These totals include changed game lengths. Enemy meals per
game-round fell from 139/241 (0.577) to 76/217 (0.350), about 39.3%.
The current bot still chooses Consume frequently. One flight missed; selections
also include pending or fizzled declarations and need not equal completed meals.
Kroni additionally lost 64 guards to automatic Cannibal Hunger, giving 104 own
guards lost across the two feeding mechanisms. There were 43 Ravenous uses and
19 Ravenous rewards in the prototype sample.

The prototype had two win-to-loss flips (Kalligan and Kanifous) and one
loss-to-win flip (Orias), all with Kroni in seat 0. Kroni won 5/8 in seat 0 and
8/8 in seat 1, versus 6/8 and 8/8 historically. This tiny Kroni-specific sample
cannot establish a general seat advantage; it does not support blaming seat 0
for these wins. Reversed seats share a seed, so 16 games are not 16 independent
random matchups.

## Opponents

Each cell lists Kroni in seat 0 / Kroni in seat 1. W/L is from Kroni's viewpoint.

| Opponent | Historical | Prototype |
|---|---|---|
| Deimos | W R9 / W R11 | W R11 / W R10 |
| Gremory | W R21 / W R16 | W R13 / W R13 |
| Humbaba | W R18 / W R18 | W R14 / W R18 |
| Kalligan | W R16 / W R14 | L R10 / W R11 |
| Kanifous | W R16 / W R12 | L R13 / W R13 |
| Odradek | L R15 / W R10 | L R17 / W R10 |
| Orias | L R20 / W R14 | W R13 / W R15 |
| Valak | W R18 / W R13 | W R17 / W R19 |

## Interpretation

Removing precise targeting substantially reduced enemy guard consumption,
but did not remove Kroni's dominant results in this sample. Friendly meals also
satisfy Cannibal Hunger, so a friendly bite is not entirely wasted. Dominion
became more common overall; eliminating one route to dominance can leave other
routes viable. The batch does not isolate which mechanic caused those wins.

For the 15–20-round goal, this sample moved in the wrong direction: only 5/16
finished in that band, versus 8/16 historically. There was no return to long-game
stalling, but no evidence here that the redesign solves early dominance.
Final Collapse is disabled in this ruleset, so its absence is not itself a
balance result.

Before another tuning change, inspect the quick Dominion wins and their Hunger,
Tear and feeding events. A freshly replanned exact-Consume control with the
same eleven-enemy Ravenous rule would isolate Consume better. Neither that
additional run nor another rules change was performed here.

## Reproduction and limits

- Exactly 16 completed new games: all eight non-Kroni opponents, both seats,
  archived repeat `01`, using two Python worker processes. These are different
  seeds from the previous `kroni_odradek_00` one-game probe.
- Seed, seat order, castle loadout, experiment flags and policy weights were
  retained from each corresponding `tempo-roster-162-03` archived game.
- Current simulation source: commit `7dcd7a0`; the evidence includes recursive
  Python source hashes, weights, setup, archived record hashes and runner hash.
  Source hashes were unchanged across the completed run.
- The historical controls used exact-target Consume and the former Ravenous
  reward threshold/scoring. Current games use bouncing Consume and eleven-enemy
  Ravenous. This is a combined-change comparison, not an isolated Consume test.
- All sixteen traces and operation hashes were checked. Meal counts match
  separate doctrine diagnostics. Zero rejected previews or invalid submissions.
- This is a Python batch. Earlier focused Godot rules and board parity checks
  remain the native validation; this is not a new 16-game Godot parity claim.
- An initial reporter attempt failed on an absent optional summary field. It
  was stopped; the reporter was corrected and the same seeds rerun. No seeds
  were replaced or gameplay rules edited. The final batch has zero failures.

Run from the repository root:

```sh
python Scripts/Sim/run_u13_guard_consume_sample.py \
  --baseline ../tempo-roster-162-03 \
  --output ../kroni-guard-sample-16-reproduction
```

Evidence: `docs/evidence/U13_GUARD_CONSUME_SAMPLE_16_2026-09-22.json`.
The adjacent `.traces.tar.gz` contains all 16 operation, semantic and policy traces.
