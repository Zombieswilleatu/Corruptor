# Five fresh seeds for the early-finishing matchups

The preceding tempo pilot's early finishes were Kanifous–Gremory at round 8
(Ritual), Gremory–Kanifous at round 12 (Dominion), and Humbaba–Kroni at round 14
(Dominion). Names retain seat order: the first named Lord occupies seat 0.

This follow-up uses five fresh seeds for **each** of those seat orders: fifteen
games total, excluding the original pilot seed from the new results. It uses
the same castle loadouts, policy, split Ward, Veil attack escalation, delayed
round-20 soul reward, and round-25 deadline. No gameplay or scoring changes.

Repeat indices 01–05 use the existing survey namespace. Gremory–Kanifous and its
reversed seat order share each unordered-pair seed, as before; these are paired
seat comparisons, not fifteen independent seeds. Matchups were deliberately
selected for prior early finishes, so their aggregate is not an unbiased
estimate of early-game frequency across the full roster.

Two simulation workers, recycled every four games, using optimized CPython.
The frozen runner passed its 34 focused checks; the case-list check confirmed
five cases per seat order, distinct case names and no original pilot seed.

Reproduce this exact fifteen-game follow-up:

```bash
bash Scripts/Sim/run_u13_lord_balance.sh --split-ward-experiment --early-check
```

This remains a Python-only experiment; native/playable rules were not changed.

## Results

New rounds are in seed-index order 01–05, not completion order.

| Seat order | Original round | Five fresh-seed rounds | Mean | Before round 15 |
|---|---:|---|---:|---:|
| Kanifous–Gremory | 8 | 18, 13, 12, 12, 13 | 13.6 | 4/5 |
| Gremory–Kanifous | 12 | 15, 17, 12, 13, 10 | 13.4 | 3/5 |
| Humbaba–Kroni | 14 | 15, 12, 11, 14, 12 | 12.8 | 4/5 |

Eleven of fifteen ended before round 15; four finished in the 15–20 window.
All ended by round 18. None used the round-20 soul bonus or round-25 deadline.
Nine ended in Ritual and six in Dominion; the early subset comprises seven
Rituals and four Dominions. Every Ritual ended with both players below five
personal tears. Early wins therefore recur through both victory paths.

Kroni beat Humbaba in all five trials (three Dominion, two Ritual). Across the
two Gremory/Kanifous seat orders, Gremory won six and Kanifous four. These small,
selected samples are a prompt to investigate matchup/resource behavior, not a
roster-wide balance estimate or proof of which rule causes early wins.

The original round-8 extreme did not repeat, but the broader early-finishing
pattern did. The new late-game rules alone have not brought these matchups into
the target window most of the time.

All fifteen games completed and all frozen source/record/trace/operation hashes
were verified. Gremory–Kanifous seed 01 had three legal-preview rejections with
reason `summon_payment_unavailable`; the selector continued to legal alternatives.
They were not failed submissions or censored games. No policy change or rerun
was introduced to remove those rejections.

Raw terminal resources, outcomes, winner identities and per-game evidence:
`docs/evidence/U13_EARLY_MATCHUP_REPEATS_2026-09-22.json`.
