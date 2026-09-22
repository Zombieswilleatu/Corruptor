# Decisive attack souls: Dominion guardrail pilot

Opt-in Python experiment, based on `e1c86aa`. Godot and playable rules have not
been changed. No recommendation to adopt the bonus yet.

## Rule

With split Ward enabled, setup `decisive_soul_bonus: true` grants one additional
soul for a Hunt that banishes its target or a Siege that destroys its final
target. Maximum one extra soul per player per round. Partial damage, pillage,
screening-structure destruction alone, artillery and counterfactual attacks do
not trigger it. Existing ordinary rewards and Ward's causal-save reward remain.
Ritual's 12-soul threshold and Dominion's five personal tears/strict lead/Veil
12 requirements are unchanged, as is victory evaluation priority.

Policy weights and candidate construction are fixed across the trial. No
special bonus score was added to attack proposals; the bot sees and spends its
actual additional souls through its existing resource logic. This is an initial
rules trial under the existing heuristic, not a fully adapted/tuned bonus bot.

## Three-arm paired pilot

Same six matchups, seeds, loadouts and seats as the earlier split-Ward trial;
18 games total, two workers recycled every four games, CPython 3.12 with the
existing optimized rollback. Both control arms reproduced their earlier
operation hashes exactly. The six matchups cover Gremory–Kanifous,
Deimos–Kalligan and Humbaba–Kroni in both seat orders.

| Measure | Current | Split Ward | Split Ward + bonus |
|---|---:|---:|---:|
| Games | 6 | 6 | 6 |
| Final Collapse | 1 | 3 | 0 |
| Dominion | 4 | 2 | 2 |
| Ritual | 1 | 1 | 4 |
| Mean rounds | 16.0 | 14.3 | 12.2 |
| Ended below Veil 26 | 4 | 3 | 5 |
| Rejected previews | 0 | 0 | 0 |

The bonus kept both Dominion outcomes from the split-Ward arm and changed all
three of its collapses into Ritual. But only two of those three ended earlier:

- Deimos–Kalligan: collapse round 15 became Ritual round 8; final tears 1–3.
- Kroni–Humbaba: collapse round 21 became Ritual round 15; final tears 2–2.
- Kalligan–Deimos: still round 16, still Veil 27, now Ritual instead of collapse.
  This is victory-priority relabeling, not avoidance of the collapse threshold.

The existing Kanifous–Gremory Ritual also moved from round 8 to round 7, with
tears still 1–1 and Veil only 11. All four bonus-arm Rituals ended with neither
player at five personal tears. The two Dominion games finished on rounds 12
and 15; their winners had five personal tears and respectively eight/five souls.

This supports investigating the bonus, but does not establish that Dominion
and Ritual are balanced. Dominion remained reachable in these matchups, while
early Ritual remains a concrete risk. There was already an early Ritual in the
split-only control, so not every low-tear Ritual can be attributed to the bonus.
Do not equate fewer collapse labels with more wins before collapse.

## Report and checks

`docs/evidence/U13_DECISIVE_SOUL_SCREEN_2026-09-21.json` contains all paired
terminal souls, personal tears, Veil totals, win conditions, round counts and
source identity. `dominion_qualified_players` means the tear/lead/Veil-12
criteria are satisfied; it does not override Ritual priority or the Veil-26
collapse check. Terminal metrics do not prove whether Dominion was reachable
under an alternative earlier strategy.

74 focused tests passed. New contracts cover real versus counterfactual Hunt
rewards, the cap, Siege destruction versus partial damage, no pillage reward,
profile validation, exact three-arm seed pairing, and preserved optimized
rollback. All 18 records and the frozen source were hash-verified. Veil-26
aggregates were derived afterward from recorded terminal states; the runner now
includes them automatically. No simulation or policy changes were made after
the pilot freeze.

## Larger comparison prepared, not run

The runner supports 81 ordered matchups per arm (all nine Lords, including
mirrors), 243 games total with two workers. The case construction and frozen
prepare-only path passed checks. This is one seed per ordered matchup, not 81
independent random replicates; seat reversals share an unordered-pair seed.

```bash
bash Scripts/Sim/run_u13_lord_balance.sh --split-ward-experiment --full-roster
```

The default without `--full-roster` is the 18-game pilot. The launcher prefers
PyPy; pass `python` first to explicitly select CPython. No old archive or Godot
binary is required.

Primary measures: collapse frequency **and** endings below Veil 26. Guardrails:
Dominion versus Ritual distribution, their round distributions, tears/Veil at
Ritual wins, and per-Lord/seat outcomes. Keep all three arms and avoid adjusting
thresholds or policy weights mid-batch.
