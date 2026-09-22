# Late-game soul bonus: round 20 versus round 18

Moving the experimental decisive soul bonus to round 18 had a negligible effect on the full roster mean: **14.5556 → 14.5247 rounds**, a decrease of **0.0309 rounds**. Three games finished sooner, saving five rounds in total.

| Measure | Round-20 bonus | Round-18 bonus |
| --- | ---: | ---: |
| Sample size | 162 | 162 |
| Before round 15 | 88 | 88 |
| Rounds 15–20 | 64 | 65 |
| After round 20 | 10 | 9 |
| Dominion wins | 95 | 94 |
| Ritual wins | 67 | 68 |
| Forced round-25 endings | 0 | 0 |
| Extra decisive souls awarded | 20 | 40 |

The three changed durations were:

| Seat order / seed repeat | Before | After |
| --- | --- | --- |
| Kanifous–Humbaba / 00 | Round 22, Kanifous Dominion | Round 19, Humbaba Ritual |
| Odradek–Kanifous / 01 | Round 23, Odradek Ritual | Round 22, Odradek Ritual |
| Kroni–Orias / 01 | Round 20, Orias Ritual | Round 19, Orias Ritual |

Only one winner and one victory type changed. The earlier bonus provides a small late-game acceleration in this sample. It does not materially change the overall mean or the early-ending rate.

## Paired method and validation

Baseline: completed `tempo-roster-162-03`, with two seeds for all 81 ordered Lord matchups. Candidate: `soul-round18-paired-01`.

**29 fresh games** reran every baseline case that reached round 18, using the same seeds, seat orders, loadouts, weights, and two recycled workers. **133 earlier finishes were reused**, explicitly labeled `unchanged_by_source_proof` in the evidence. They are not counted as newly simulated games.

The comparison fails closed unless all engine, observation, and policy Python source is byte-identical to the frozen baseline except the single soul-bonus timing change. Both versions return without effect before round 18; the bot has no changed decision logic or observations during that interval. Earlier completed games therefore cannot change. All 29 reruns additionally reproduced their entire baseline decision traces before round 18 exactly.

57 focused tests passed, including the round-17/18 reward boundary. All 29 fresh games completed without failures. Frozen-source and record hashes were validated. Baseline records are preserved under `control/` without replacing their identities; fresh records retain the candidate identity.

The sole rule change is `TEMPO_SOUL_START_ROUND = 18`. The bonus remains one extra soul for a successful Hunt banishment or Siege target destruction, at most once per player per round. Ward rewards, recruit ratios, monster restrictions, attack escalation, victory requirements, and seat order are unchanged. This is a Python-only experimental candidate; no Godot/playable integration is claimed.

The [complete paired evidence](evidence/U13_SOUL_ROUND18_PAIRED_2026-09-22.json) contains all 162 before/after rows and clearly distinguishes fresh and reused results.

Reproduce against the original round-20 frozen baseline:

```bash
python Scripts/Sim/compare_u13_soul_timing.py --baseline PATH_TO_TEMPO_ROSTER_162_03 --output NEW_OUTPUT_DIRECTORY
```
