# One-game monster restriction probe

Same seed and seats as the archived decisive Kroni–Odradek game. Only Kroni's
recipe unlock list was emptied before the opening. Normal recruits, powers,
Soul income, victory targets and all other rules were unchanged. Both bots
replanned normally; no new monster prices or buffs were applied.

| Measure (Kroni / Odradek) | Archived control | Kroni cannot summon recipe monsters |
|---|---|---|
| Winner | Kroni | Kroni |
| End | Round 9, Ritual | Round 16, Dominion |
| Souls | 12 / 1 | 11 / 3 |
| Personal Tears | 1 / 1 | 5 / 2 |
| Recipe summons | 9 / 9 | 0 / 16 |
| Monster bodies spawned | 15 / 12 | 0 / 20 |
| Normal marcher spawns | 40 / 28 | 71 / 64 |

Removing Kroni's summons delayed its win by seven rounds and changed the victory
route, but did not reverse the winner. This is evidence of a substantial pacing
change in this particular seed, not an estimate of average monster value, proof
of Lord imbalance, or evidence that Soul-priced monsters need a blanket buff.
Normal strategy adjustments are part of this counterfactual.

Exactly one new policy-driven game was run. The original control was reused and
independently replayed from its recorded operations; its complete final-state
hash matched exactly. Both used the roster archive's frozen round-20 source and
weights. The restricted game had no rejected previews or failed submissions,
and produced zero Kroni recipe summons. This was a Python simulation probe.

Seed: `u13-tempo-roster-20260922:Kroni:Odradek:00`.

[Machine-readable result](evidence/U13_ONE_SIDED_MONSTER_PROBE_2026-09-22.json)
contains source fingerprints, final-state hashes and complete summon breakdowns.
[Compressed trace](evidence/U13_ONE_SIDED_MONSTER_PROBE_2026-09-22.trace.json.gz)
contains the counterfactual's operations, observations and policy decisions.

Reproduce using the retained `tempo-roster-162-03` archive:

```sh
python Scripts/Sim/run_u13_one_sided_monster_probe.py --baseline /path/to/tempo-roster-162-03 --output /path/to/result.json
```
