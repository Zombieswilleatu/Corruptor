# Targeted monster powers — September 19, 2026

This is the validated **V12 checkpoint**, before the subsequent Kopita/Dotra request. The [V13 follow-up](U13_MONSTER_SUPPORT_BALANCE_2026-09-19.md) contains the current combined build and its fresh results. The V12 source is preserved at [800fd27](https://github.com/Zombieswilleatu/Corruptor/commit/800fd27b8983a3279bf4efe55d1b0303f3299aa4).

Sinodek now aims portals at enemies, Fyra's charm chance rises from 15% to 30% per hit, and Tumler gains +1 damage against his marked prey. Fyra averaged **1.04 charms per completed lifetime** in the native continuous runs. Kopita and Dotra remain the clearest next tuning candidates; Sinodek's friendly collateral and Sooge's immediate recipe value also need attention.

## Implemented behavior

| Monster | Change |
|---|---|
| Sinodek | Selects the nearest visible enemy marcher in his lane within **600** (Vulture range 400 × 1.5). Makes one **25%** attempt per active round, waiting until an enemy enters range. The portal opens at that enemy's current position. Failed rolls spend the round's attempt. Birth hold, creator immunity, area fear, allied collateral, and banishment rules remain in effect. |
| Fyra | **30%** charm chance on a hit against a surviving, eligible target. Existing temporary control, living-copy limits, ownership restoration, and pink hearts remain. |
| Tumler | Base attack stays **2**. An attack against the individual stored as his hunt target deals **3 before Armor**. Interception transfers that bonus to the new mark; other enemies, unmarked taunts, and structures receive normal damage. |

Both the native game and Python simulator use `U13_MONSTERS_V12_TARGETED_POWERS`. Tooltips and the runner banner identify these changes. Vulture range 400, tower range 600, the Vulture's Butcher bonus, protected staging, and the current Rout rules are unchanged.

## Fyra calibration

The controlled calibration used one Fyra with the common four-unit support core against four opponent compositions: the same-card recipe conversion, six Butchers, a Penitent/Vulture screen, and a mixed army. Each rate used 16 seeds and both reflected seats: **128 completed summons**.

| Chance per hit | Charms in 128 summons | Charms per summon |
|---|---:|---:|
| 15% | 60 | 0.47 |
| 25% | 100 | 0.78 |
| **30%** | **136** | **1.06** |
| 35% | 164 | 1.28 |
| 45% | 190 | 1.48 |
| 60% | 256 | 2.00 |

The final native check used eight actual card-stream seeds, including both supplied screenshot seeds, each from both seats for 30 intervals. Auto staging and normal profiles were used.

| Native batch | Summons observed | Completed lifetimes | Charms by completed Fyra | Per completed lifetime |
|---|---:|---:|---:|---:|
| Previous build, 15% | 52 | 46 | 10 | 0.22 |
| **Selected build, 30%** | **52** | **48** | **50** | **1.04** |
| Rejected calibration, 60% | 52 | 48 | 92 | 1.92 |

The selected build produced 50 total charms: **0.96 per observed summon** when including two still staged and two still alive at the cutoff. Twenty-six of the 52 summoned Fyra charmed at least once. This targets an average, not a guaranteed proc for every summon. All 576 Fyra appearances across the broader controlled matchup matrix produced 472 charms, or **0.82 per summon**; opponent composition still matters.

Seat reflections reproduce the same random history; they are not additional independent random samples. The 60% trial and selected build both include the Sinodek and Tumler changes. Comparisons against the previous build include all three changes, while the controlled charm grid changes only Fyra's rate.

## Balance results and the next weak units

The final batch repeats the previous **4,704 fights**: 147 scenarios × 16 seeds × two seats, resolving **15,644 intervals** with no round-cap outcomes. These are lane outcomes without Lord powers or further draws after controlled deployment. Same-card comparisons use the ordinary bodies those exact printed cards would produce. Both supported teams also receive one Penitent, Butcher, Vulture, and Wright.

| Changed monster | Alone versus its cards: previous → current W–L–D | With common support: previous → current W–L–D |
|---|---|---|
| Fyra | 0–32–0 → **4–28–0** | 0–32–0 → **0–32–0** |
| Tumler | 22–10–0 → **30–2–0** | 0–32–0 → **6–26–0** |
| Sinodek | 0–32–0 → **4–28–0** | 0–32–0 → **2–28–2** |

These changes improve power delivery without establishing that every recipe is now efficient. Fyra and Sinodek still struggle against their ordinary-unit conversion in supported fights.

- **Kopita:** 0–32 with support against his cards. In continuous play only **38 of 118 heal pulses** restored health; 80 healed nobody. His mixed-army benchmark was much better at 32–0, so I would examine wasted opening/healing pulses before raising every stat.
- **Dotra:** 0–32 alone and 4–28 supported against his cards. Continuous play recorded **14 ambushes from 30 summons**. The first ambush's reliability and timing look more promising to tune than general attack damage.
- **Sooge:** 0–32 in both same-card comparisons. Eight of 14 continuous summons rooted, producing **88 beams**. Those beams recorded 1,046 HP damage, including 224 friendly HP; reported damage can include overkill. His vulnerable mobile phase and expensive recipe deserve review, while established turrets still contribute heavily.
- **Sinodek's collateral:** controlled enemy banishments rose from **18 to 302**, with 10 friendly banishments in the new batch. However, the native continuous sample recorded **8 enemy and 18 friendly banishments across six portals**. Every portal selected an enemy; friendly units can subsequently advance into the lingering field. Enemy targeting fixes placement, but friendly collateral remains a real balance problem.

Kurchin remains strong with support: 32–0 against his recipe conversion, the screen, and the mixed benchmark, but 0–32 against the six-Butcher shock army. Ordinary-only matchups are unchanged. The sample supports targeted follow-up work rather than declaring one universal strongest unit.

## Verification and reproduction

**1,085 native directed checks** passed: 110 new targeting/damage checks, 641 existing monster checks, 234 support/hunt checks, and 100 charm-feedback checks. **40 Python unit tests** passed. Complete native/Python worlds and event tapes matched across **276 phases / 55,200 ticks**: 18 targeting, 84 monster, 32 support/hunt, 90 movement/range/navigation, 20 controlled samples, and 32 continuous samples.

All 2,352 controlled seat pairs agreed on outcomes. All eight native continuous seat pairs agreed on goals, totals, and ability counts. The continuous batch spans **480 intervals** with real protected reserves, independent card streams, and Auto release decisions. Native execution used **Godot 4.5.1 Linux headless**; the supplied runner targets the user's **Godot 4.7.2 Windows** installation. A Windows visual review was not performed here.

The [verification manifest](evidence/U13_MONSTER_TARGETING_2026-09-19/verification.json) records source hashes and evidence. [Controlled outcomes](evidence/U13_MONSTER_TARGETING_2026-09-19/controlled.json.gz), [continuous outcomes](evidence/U13_MONSTER_TARGETING_2026-09-19/continuous.json.gz), charm lifetime counts, candidate grids, replay inputs/hashes, and check logs are stored alongside it. The [previous audit](U13_MONSTER_BALANCE_AUDIT_2026-09-19.md) remains the baseline.

To reproduce these V12 values, check out the checkpoint above and use the previous audit's reproduction commands. Additional directed and calibration commands, with `GODOT`, `PYTHON`, and `AUDIT` set by the caller:

```bash
"$GODOT" --headless --path . --script Scripts/Sim/U13MonsterTargetingTestRunner.gd -- "$AUDIT/targeting-phases.jsonl"
PYTHONPATH=Scripts/Sim "$PYTHON" -m u13_pysim.verify_monsters "$AUDIT/targeting-phases.jsonl"
"$GODOT" --headless --path . --script Scripts/Sim/U13MonsterAuditRunner.gd -- export docs/evidence/U13_MONSTER_TARGETING_2026-09-19/fyra-cases.json "$AUDIT/fyra-initials.jsonl"
"$PYTHON" Scripts/Sim/tune_u13_monster_powers.py charm-grid --initials "$AUDIT/fyra-initials.jsonl" --chances 15 25 30 35 45 60 --workers 4 --output "$AUDIT/charm-grid.json.gz"
"$PYTHON" Scripts/Sim/tune_u13_monster_powers.py cohorts --directory "$AUDIT" --output "$AUDIT/fyra-lifetimes.json"
```
