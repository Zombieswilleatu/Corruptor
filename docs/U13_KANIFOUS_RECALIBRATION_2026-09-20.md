# Kanifous V21: separate valuation experiments

The completed Windows V19/V20 screen returned 16/36 V19 wins and 13/36 V20
wins. There were four V20-only wins, seven V19-only wins, nine shared wins and
16 shared losses. All 72 games completed with zero rejected previews. Raw
case identities, policy files, decision/operation hashes and the reconstructed
summary were verified from the uploaded archive.

Native Power fell from 126 casts to zero. Native Wealth rose from six to 15.
Native Resurrection rose from 27 to 313; 188 V20 selections had no known losses
and relied entirely on forecast exposure. Native Death's friendly casualties
fell from 54 in 475 casts to six in 236 casts. Breach Wishes have separate
proposal rules and are excluded from these native counts.

On V20's 697 saved orders, Wealth was positive and available only 17 times,
and was selected 15 times. Its usual 21-point gross value was below the median
39-point Price reserve. Hand capacity was not the problem: 695 orders left
room for the entire possible three-card draw. Power's standalone opening
score was nonpositive on all 36 initial boards. These findings motivated the
following independently switchable experiments.

## Calibration

| Profile | Change from V20 |
| --- | --- |
| `v20` | Original formulas, used to check compatibility; the match control uses the actual frozen V20 package. |
| `power` | Replace the flat 18-point body value with expected material from the actual 70%/25%/5% one/two/three spawn distribution and uniformly random suits. |
| `wealth` | Restore V19's three-point bonus for each card below five, capped at 15, using the hand remaining after this order's commitments. |
| `resurrection` | Cap total speculative casualty credit at two average ordinary marcher values. Known eligible losses retain full restored-material credit. |
| `combined` | Apply all three recalibrations. This is the V21 default candidate. |

Power's expected body count is 1.35. Current ordinary profiles total 78 material
points across the four equally likely suits, making its expected spawn value
`floor(1.35 × 78 / 4) = 26`, before the existing bounded lane-need bonus.
Only one body is guaranteed; extra bodies and suits remain unknown.

Wealth still uses the exact 20%/50%/30% capped draw distribution and cannot
spend the drawn cards in the current order. Its gross value now ranges up to
36 instead of 21. The shortage bonus is a heuristic for future options, not
an assertion that a particular card, suit or monster recipe will arrive.

Resurrection's speculative ceiling is currently `2 × 78 / 4 = 39` points.
The per-unit reachable-danger calculation remains visible in diagnostics as
raw exposure. The ceiling applies only to summed forecast credit, not actual
casualties, restored unit counts, or the game's ability rules. It is a
conservative calibration parameter, not a proven optimum.

All three leave the Price reserve, debt urgency, Death valuation and friendly
spawn exposure, repair coordination, legality rules and Breach proposals
unchanged. No engine or Godot balance rule changes are included.

## Saved-board verification

The audit reproduced all **570 selected native V20 scores** exactly using the
compatibility profile. It also reconstructed the 36 first submission states
from authority operations, matched their public-view hashes, and checked each
profile's complete opening plan with authoritative legality Preview.

| Opening choice across 36 boards | V20 | Power only | Wealth only | Resurrection only | Combined |
| --- | ---: | ---: | ---: | ---: | ---: |
| Power | 0 | 29 | 0 | 0 | 0 |
| Wealth | 15 | 0 | 36 | 15 | 36 |
| Hold | 21 | 7 | 0 | 21 | 0 |

The combined candidate currently prefers Wealth at every opening. This is
explicitly a testable preference, not evidence that Power is fixed in every
situation or that the combination is best.

When ranking Wishes against the same 697 saved V20 orders, combined V21 made
Wealth positive and available 160 times instead of 17. Its highest positive
Wish was Death on 504 boards, Resurrection on 65, Wealth on 44, Longevity on
seven and Power on three; 74 had none. Original V20's corresponding ranking
was Death 267, Resurrection 316, Wealth 15, Longevity seven and none 92.
These are fixed-order scores, not new complete-game decisions or win results.

Eight other Lords' opening plans, scores and work counts plus a directed
Breach Wish case matched frozen V20 exactly. **95 focused test methods pass**,
covering the new distribution, bonus/cap boundaries, independent profiles,
known losses, unchanged Price scoring and existing common/power coordination.
No new full games were run during this recalibration.

## Local comparison

Use the separate `Corruptor-U13-Perf` checkout. Fetch the branch and switch that
checkout to the published runner commit, then run:

```bash
U13_KANIFOUS_CONTROL_ZIP="$HOME/Downloads/u13-kanifous-v19-v20-72-e8KIR3-2026-09-20_13-30-46-LXQcEV.zip" \
  bash Scripts/Sim/run_u13_kanifous_calibration.sh
```

This evaluates V20, each separate factor, and combined V21 across the same
36 setups. The previous ZIP supplies 36 verified V20 controls, leaving **144
new games**. Without a control ZIP, all 180 games are run. Four workers are
the default; `U13_KANIFOUS_WORKERS` overrides that count. The shell wrapper
detects the usual PyPy installation and packages results into Downloads.

Control reuse checks the exact engine, baseline/candidate revisions, weights,
case list, round limit, frozen policy hashes, and each record's status and
trace/semantic/operation hashes. Imported records retain their original
semantic data and an explicit provenance record. Failed cases are reported,
not silently retried or counted as losses. All opposing Lords remain frozen
V19, including mirrors. Candidate profiles load from the committed checkout
snapshot, so the run does not use mutable live policy files.

These are the seeds that exposed the problem, so the experiment diagnoses
the individual changes and their combination. Any promising result still
needs independent seeds before claiming a general improvement.
