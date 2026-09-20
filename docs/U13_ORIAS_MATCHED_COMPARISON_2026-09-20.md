# Orias V15 versus V16: matched comparison

## Design fixed before launch

The experiment changes only the focal Orias policy. Both arms use engine tree
`91e199279b684760d4852828f6be23780750e762` (published commit
`9659d8fc70466b98f95a47ee8a20bef9416f8570`). Every opponent, including the
other Orias in mirror matches, uses the complete frozen V15 doctrine package
from `c92181268fae026f30d76d97c2c5b822185848ca`.

- Nine opponents, two seeds each, both focal seats, old and new variants:
  **72 games / 36 matched old-new pairs / 18 seed-opponent blocks**.
- Both seats of a block share a seed. Old and new have identical setup within
  each pair. Mirror matches retain an explicit focal seat.
- Both players use Keep, Stockpile, SummoningCircle, SiegeEngine and Bastion.
- Default fixed weights and greedy selection. No tuning during measurement.
- PyPy 7.3.20 / Python 3.11.13. Independent game processes.
- All 72 game identities, engine/policy/harness hashes and weights were written
  to the manifest before the first two games. The admission pair counts toward
  the full campaign.
- Forty-round cap; failures and censored games are reported explicitly and
  never converted to defeats or omitted from the requested denominator.

The runner is `Scripts/Sim/run_u13_orias_comparison.py`. It freezes only the old
policy, so both old and new use the same current engine. The comparison should
be reproduced on the pinned engine, rather than on a later branch head whose
mechanics may differ. Its manifest rejects source changes on resume.

## Measurements

Win/loss is always from the focal Orias seat. Matched outcomes distinguish
new-only wins, old-only wins, both wins and both losses. Per-opponent and
per-seat results accompany game lengths and incomplete cases.

Web and Snare selections are counted per focal planning decision and completed
game. Web activation hits come from attributed authority events; they do not
measure time slowed or total benefit. A passive observer records actual Snare
activation and whether the focal player selects and resolves a Hunt or Siege in
that same effective round. A game that ends before this decision is reported
separately. These are follow-through measurements, not proof of causality or a
count of prevented deployments. The observer does not modify authority state
or supply hidden data to the planner.

Five focused harness tests cover paired setups, focal seat/card-choice routing,
failed-game denominators, Snare activation-round attribution, and implicit Pass
orders. Earlier 51
Orias/coordination/Rout/planner checks were already completed and are not
repeated as evidence of match strength.

## Scope

Two seeds per opponent provide a preliminary controlled sample. The two seats
sharing a seed are related observations. This experiment compares doctrine
against fixed V15 opponents under one loadout; it does not establish general
Lord balance, native Godot parity, or performance against humans.

## Observer correction during measurement

The first observer assumed every combat order explicitly contained `action`.
The engine legally permits an omitted action (Pass). At 16 completed attempts,
one new-policy Humbaba case raised `KeyError: action` in this observer. The
workers were stopped and the observer changed to `get('action', 'Pass')`.
A focused regression verifies that branch.

The original 15 successfully completed records are retained **byte-for-byte**,
with their original manifest and source identity. Admission to the corrected
campaign verifies every record hash, identical engine, complete frozen baseline,
weights, cases, policy versions and all other policy/driver source hashes. Each
reused focal trace explicitly contains an action throughout, so the correction
cannot affect its observations. Their file hashes and the full original
manifest are embedded in the corrected manifest. Original error evidence is
retained separately. The failed and unfinished cases are rerun with identical
setups. This is a measurement correction, not a policy/weight adjustment or a
change to the predeclared 72-game sample. The corrected run uses eight workers.

## Results

The user stopped the campaign after **29 successfully completed games** to
investigate the behavior and consider a different approach. There are **14
complete matched pairs** plus one unmatched old-policy game. Forty-three
predeclared cases remain unfinished. This is an outcome-informed partial
sample, not a completed confirmatory campaign. No simulation/policy failures or
censored games were recorded among the 29 completed results; the earlier
observer failure was corrected and that exact case completed on retry.
All 29 completed games had zero rejected legality previews.

The following table uses only the 14 complete pairs:

| Measurement | Old V15 | New V16 |
| --- | ---: | ---: |
| Focal wins | 6/14 | 5/14 |
| Mean rounds | 21.64 | 19.79 |
| Web selections | 97 | 91 |
| Web selections per planning decision | 32.0% | 32.9% |
| Web activation-hit events | 1,777 | 992 |
| Activation hits per Web | 18.32 | 10.90 |
| Snare selections | 93 | 18 |
| Snare activations | 91 | 18 |
| Hunt/Siege selected and resolved in Snare's effective round | 22/91 (24.2%) | 5/18 (27.8%) |

New-only wins: **2**. Old-only wins: **3**. Both win: **3**. Both lose: **6**.
Across seven completed seed-opponent blocks (both seats together), one improves,
two regress and four tie. A one-win difference in this small, partially observed
roster does not establish a general strength regression.

| Opponent | Old wins | New wins | Complete pairs |
| --- | ---: | ---: | ---: |
| Gremory | 3/4 | 2/4 | 4 |
| Deimos | 0/4 | 0/4 | 4 |
| Humbaba | 3/4 | 2/4 | 4 |
| Kalligan | 0/2 | 1/2 | 2 |

One further old-versus-Kalligan game lost; it has no completed new counterpart
and is excluded from all paired comparisons above. The other five opponents
were not completed and must not be represented as zero-win results.

## Useful failure evidence

**Snare is more selective without much improvement in follow-through.** New
Snare activated 18 times. The next-round action was Ward 13 times, Siege four
times and Hunt once. Seven casts occurred in round one. The forecast checks
whether retained resources can support a plausible attack and measures its
benefit under hypothetical Guard deployment. It does not require that the
attack outperform the planner's competing recruitment, Guard, monster and
Ward bundles on the next turn. A supported attack is not necessarily the plan
the bot will prefer. For example, Gremory seed 0 / focal seat 0 forecasts a
round-two Siege from two retained cards, casts Snare at round one with score 3,
then chooses Ward in round two. The actual next decision retains a Siege
proposal but chooses a different complete bundle. The intended attack was not
simply absent from consideration.

**Web's scoring discards much of the value of dense activation hits.** V16 uses
`3 * min(6, initial_hits) + 6 * min(3, potential_kills)` for immediate hit value.
Without different kill bonuses, six and twenty initial hits receive the same
18-point damage component. Its control component can add 48 points. V15 gave
12 points per target in the best current cluster. V16 also samples up to three
anchors per lane and does not guarantee retaining V15's densest cluster as a
candidate. These are concrete scoring/search changes worth isolating.

Measured hits per Web fell from 18.32 to 10.90 in the matched subset, about 40.5%.
This is an activation-hit count, not measured HP damage or total Web value.
The compared games also develop different boards after their first divergence.
The count therefore supports investigating targeting but does not prove that
Web caused every lost game or that slowing has no value.

In the Gremory seed 0 / focal seat 0 old-only win, the first difference is Web's
round-two location on an identical public board with an identical combat order.
Other outcome flips begin with Snare or complete-order differences. Both powers
changed together, so an isolated test is necessary for causal attribution.

## Recommended next experiment (not yet implemented)

1. Keep the ordinary best-cluster Web candidate and reward additional real hits
   beyond six. Start with a modest, bounded control bonus and keep the existing
   checks against imaginary attack-speed suppression.
2. Test that Web-only revision with Snare held fixed. Separately test revised
   Snare with Web held fixed. Use the same saved decision boards first, then a
   small predeclared matched sample; do not mix both revisions in one test.
3. For Snare, compare the projected supported attack against realistic competing
   complete plans. Require a meaningful competitive attack before paying the
   preparation cost. Reassess next round rather than forcing an attack when the
   board has changed. Avoid simply raising a generic score threshold.

No gameplay or doctrine changes were made during this comparison. The recorded
V16 is still the policy under study. The measurement runner and this report are
separate from any future policy revision.
