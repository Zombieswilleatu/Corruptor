# Whole-roster balance audit — 20 September 2026

**Kurchin is the clearest strength outlier. Dotra now performs well. Every monster improved its army's aggregate results when added to its normal troops.** Muno is useful against ordinary formations but performs poorly against several monster armies. Fyra and Tumler sit near the middle; Kopita provides substantial healing. Sinodek and Sooge help despite costly collateral. Lemek and Varn remain useful, accessible summons.

This audit ran **8,384 controlled fights and 32 continuous games** on `U13_MONSTERS_V17_DOTRA_SHROUD`. It changes the audit harness and reporting, with no gameplay tuning. All qualifying commitments retain their ordinary marchers **plus** their monster. The earlier artificial replacement benchmarks are excluded from the balance conclusions here.

**What each monster adds.** Each row compares the same army with and without its monster against six ordinary enemy formations, using 16 seeds: 96 seed/formation comparisons per monster. Both versions retain exactly the same other entities, IDs, positions, attributes and recipe cards. The army has the ordinary troops produced by its recipe cards plus one Penitent, Butcher, Vulture and Wright. Varn adds its actual 3–5 bodies.

| Monster | Army wins without → with monster | Increase | Improved / worsened cases |
|---|---:|---:|---:|
| Kurchin | 22.9% → 96.9% | +74.0 percentage points | 71 / 0 |
| Muno | 13.5% → 50.0% | +36.5 | 35 / 0 |
| Dotra | 41.7% → 71.9% | +30.2 | 29 / 0 |
| Varn | 18.8% → 45.8% | +27.1 | 27 / 1 |
| Lemek | 15.6% → 40.6% | +25.0 | 24 / 0 |
| Sinodek | 49.0% → 70.8% | +21.9 | 22 / 0 |
| Tumler | 39.6% → 58.3% | +18.8 | 19 / 1 |
| Sooge | 43.8% → 58.3% | +14.6 | 14 / 0 |
| Kopita | 28.1% → 41.7% | +13.5 | 13 / 0 |
| Fyra | 50.0% → 60.4% | +10.4 | 13 / 3 |

Improvement counts score a win as 1, a resolved draw as 0.5 and a loss as 0. The win-rate column counts wins only. All these fights resolved. There are 16 distinct seeds reused across six formations; the 96 comparisons are not 96 independent random draws. Reflected seats verify symmetry and do not double the sample size.

The enemy formations are six or eight Butchers; three Penitents plus three Vultures or five of each; and a mixed force of one of each ordinary unit plus two Butchers, or three Penitents, three Butchers, two Vultures and two Wrights. These deliberately span easy and difficult fights. Different starting armies and ceiling effects make the increase a measure of contribution in these fixtures, not a universal monster ranking.

**Monster armies against each other.** Each pair receives its own legal monster recipe's ordinary troops, its actual monster summon, and the same four-unit support core. Each monster faces the other nine over 16 seeds: 144 normal-seat fights each. These are whole summon packages; recipe sizes, troop composition and availability differ. They are not equal-card-cost tests.

| Monster | Wins / losses / draws / unresolved | Wins out of all 144 | Assessment |
|---|---:|---:|---|
| Kurchin | 134 / 9 / 1 / 0 | 93.1% | Strong outlier across both army tests. |
| Dotra | 87 / 53 / 4 / 0 | 60.4% | Strong contribution; no evidence here for another buff. |
| Sooge | 83 / 50 / 6 / 5 | 57.6% | Dangerous artillery, with collateral and permanent-root limitations. |
| Sinodek | 83 / 53 / 7 / 1 | 57.6% | Useful disruption and the best tested Kurchin opponent. |
| Fyra | 70 / 68 / 6 / 0 | 48.6% | Competitive here despite the smallest ordinary-army lift. |
| Tumler | 70 / 67 / 6 / 1 | 48.6% | Middle of this field; hunt and evasion contribute. |
| Kopita | 56 / 81 / 7 / 0 | 38.9% | Useful support, lower overall combat conversion. |
| Muno | 43 / 87 / 11 / 3 | 29.9% | Largest concern among the harder summons after accounting for his positive ordinary-army contribution. |
| Varn | 37 / 103 / 4 / 0 | 25.7% | Easy-tier swarm; substantial added value but weak into harder packages. |
| Lemek | 24 / 116 / 4 / 0 | 16.7% | Easy-tier bruiser; substantial added value despite the low package win rate. |

Kurchin went 16–0 against each of Lemek, Varn, Fyra, Kopita, Tumler and Muno; 14–2 against Dotra; 15–1 against Sooge; and 9–6 with one draw against Sinodek. His contribution is protection and target control: low personal damage does not imply low army value. His current combination of taunt, six Armor, 15 HP and 75% deflection while Armor remains is the first tuning target suggested by these results. This audit does not isolate which component to change.

Dotra's +30.2-point contribution and 60.4% monster-army win rate support leaving him alone for now. Muno's +36.5-point contribution means he is far from useless; his low monster-army result also reflects the Wright-heavy troops his recipe creates. Kopita's support output is real, so her lower fight win rate is not evidence of a broken heal. Fyra's 50% starting win rate against ordinary formations limits her possible improvement; the monster-army result argues against calling her the weakest monster.

**Powers in continuous play.** Sixteen distinct normal-seat games ran 30 intervals each with automatic staging decisions and capacity 15. Another sixteen seat-swapped games reproduced them exactly. The figures below use only the normal-seat games. Unfinished summons are retained in the evidence; Fyra's per-summon charm estimate uses completed lifetimes.

| Monster | Summons / deployed bodies | Observed ability result |
|---|---:|---|
| Lemek | 206 / 198 | All 144 ordinary deaths created their slowing pool. Banishing does not trigger death effects. |
| Varn | 223 / 854 | 83 poison applications, but only 20 later poison damage ticks. Its bodies provide most of its observed damage. |
| Fyra | 61 / 59 | 55 charms across 56 completed lifetimes: **0.98 charms per completed summon**. 36 of those 56 charmed at least once. |
| Kopita | 48 / 47 | **218 useful healing pulses, 408 HP healed**, plus 241 damage pulses. Every observed heal restored HP. |
| Tumler | 62 / 59 | 403 evades from 829 incoming attacks; 92 melee hunt retargets; 75 hits on support targets. |
| Kurchin | 20 / 18 | 194 deflections from 378 total incoming attacks. Total incoming attacks include attacks after Armor depletion, so this is not the eligible deflection-roll rate. |
| Muno | 34 / 32 | 61 free strikes, recording 152 HP damage; no duplicate free strike in a round. |
| Dotra | 41 / 37 | 34 ambushes, exposure pulses and five-second shrouds; 172 affected-enemy instances; 27 ordinary attacks while shrouded; **zero directly aimed hits against a shrouded Dotra**. |
| Sooge | 9 / 9 | Seven rooted; 55 beams fired and detonated. Beams recorded **513 enemy / 153 allied HP damage**, with 35 enemy and six allied kills. |
| Sinodek | 7 / 6 | Seven portals banished **19 enemies and 18 allies**. |

The native directed checks also passed for power eligibility, timing, targeting and damage behavior. Fyra meets the approximate one-charm target on average; this does not guarantee a charm from each summon. Kopita's observed pulses occurred only at ticks 0 and 133. Dotra's emergence protection lasted exactly 67 ticks; 34 of 37 deployed Dotras ambushed, so an ambush is not guaranteed from every deployment. Damage totals are engine-recorded HP damage and can include overkill; support value and exposed targets' damage remain credited to the acting units.

Sinodek's collateral is substantial, but raw body counts do not measure equal value. His banished allies included five Varns, four Wrights, four Vultures, two Penitents, one Butcher, one Lemek and one Kurchin. His army still improved against ordinary formations and performed well against monster armies. Sooge and Sinodek have small natural continuous samples because their recipes are uncommon; the forced army fixtures provide broader combat coverage.

**The five unresolved fights.** The monster-army batch hit its 16-interval limit in five normal-seat fights, reproduced in their five reflections: Tumler–Sooge seed 4; Muno–Sooge seeds 4, 8 and 13; and Sooge–Sinodek seed 3. Each was replayed through 32 intervals and reproduced its original 16-interval world hash. Only rooted Sooge and fortifications remained. The opposing tower was outside Sooge's 1800 beam range and Sooge was outside its 600 range; no movement or attacks occurred after the cap. Native replay verification confirmed the sampled stalled phases. These are range stalemates from permanent rooting, with no mobile unit trapped in navigation. They remain unresolved in the table. New waves can reintroduce targets in continuous play.

**Ordinary marchers and recovery.** Butcher beat Penitent in all 16 solo and all 16 four-unit squad fights. Vulture beat Butcher in all 16 of each, confirming the present matchup advantage. Penitent won only 7/16 solo and 9/16 squad fights against Vulture: this counter remains weak. Both Penitent and Butcher beat Wright in every fixture. Wright beat solo Vulture every time, while Vulture squads beat Wright squads every time. These lane fights do not price Wright's wider construction utility.

Five of the sixteen continuous games changed goal leader and ended with the opposite side ahead from the first nonzero lead. Comebacks are possible, but several games remained very one-sided. This small seed set, without Lord powers, cannot establish a general comeback rate or prove snowballing is solved.

**Verification and scope.** The 6,944 main controlled fights resolved 25,264 intervals; the 1,440 monster-army fights resolved 8,424 intervals. All 4,192 reflected controlled pairs matched winners, caps, duration, goals, surviving forces and per-unit metrics. All sixteen continuous reflection pairs matched complete final totals, metrics and lifetime cohorts. Native export checked legal recipes and preserved ordinary spawns; separate input checks covered 1,920 reflected with/without pairs and all 1,440 army fixtures.

The native suites passed 816 assertions: 648 general monster, 110 targeting and 58 responsive-pulse checks. Native Godot and Python matched complete resulting worlds and events across 227 phases / 45,400 ticks: 84 general monster, 18 targeting, eight pulse, 40 main controlled, eight monster-army, 64 continuous and five stalemate phases. Godot 4.5.1 Linux headless and PyPy 3.11 v7.3.20 were used. The user's Windows runner uses Godot 4.7.2; this audit does not provide a new Windows visual check.

The [evidence folder](evidence/U13_WHOLESALE_MONSTERS_2026-09-20/) contains outcomes, summary, fixture configurations, replay samples, verification logs, stalemate traces and source hashes. Raw bulk exports and continuous event tapes are reproducible with the commands below. The summaries' `revision` is starting gameplay commit `b385b10fe84c80ad72d70cf071d510bd1b98d457`; `verification.json` identifies the audit source used. No Lord powers, unlock progression, strategic recipe-selection study or equal-rarity normalization are included.

To reproduce from the repository root, set `GODOT_BIN` and `PYPY_BIN` to the installed executables and choose `AUDIT_DIR` for output:

```bash
mkdir -p "$AUDIT_DIR"
"$PYPY_BIN" Scripts/Sim/audit_u13_monsters.py config --suite wholesale --seeds 16 --output "$AUDIT_DIR/cases.json"
"$GODOT_BIN" --headless --path . --script Scripts/Sim/U13MonsterAuditRunner.gd -- export "$AUDIT_DIR/cases.json" "$AUDIT_DIR/initials.jsonl"
"$PYPY_BIN" Scripts/Sim/audit_u13_monsters.py controlled --initials "$AUDIT_DIR/initials.jsonl" --workers 6 --output "$AUDIT_DIR/controlled.json.gz" --samples "$AUDIT_DIR/controlled-parity.jsonl"
"$PYPY_BIN" Scripts/Sim/audit_u13_monsters.py config --suite armies --seeds 16 --output "$AUDIT_DIR/army-cases.json"
"$GODOT_BIN" --headless --path . --script Scripts/Sim/U13MonsterAuditRunner.gd -- export "$AUDIT_DIR/army-cases.json" "$AUDIT_DIR/army-initials.jsonl"
"$PYPY_BIN" Scripts/Sim/audit_u13_monsters.py controlled --initials "$AUDIT_DIR/army-initials.jsonl" --workers 6 --output "$AUDIT_DIR/armies.json.gz" --samples "$AUDIT_DIR/army-parity.jsonl"
"$PYPY_BIN" Scripts/Sim/audit_u13_monsters.py native-waves --godot "$GODOT_BIN" --seeds 16 --rounds 30 --workers 4 --directory "$AUDIT_DIR/native"
"$PYPY_BIN" Scripts/Sim/audit_u13_monsters.py waves --directory "$AUDIT_DIR/native" --output "$AUDIT_DIR/continuous.json.gz" --samples "$AUDIT_DIR/waves-parity.jsonl"
"$PYPY_BIN" Scripts/Sim/summarize_u13_roster.py --controlled "$AUDIT_DIR/controlled.json.gz" --armies "$AUDIT_DIR/armies.json.gz" --continuous "$AUDIT_DIR/continuous.json.gz" --native "$AUDIT_DIR/native" --output "$AUDIT_DIR/summary.json"
```

For a controlled sample file, generate native hashes with `U13MonsterAuditRunner.gd -- hashes INPUT OUTPUT`, then run `audit_u13_monsters.py verify --input INPUT --native OUTPUT`. The continuous samples already carry native result hashes and use `verify --input INPUT`. The evidence's `inspect_caps.py` accepts `--sim-dir Scripts/Sim --directory "$AUDIT_DIR"` to replay the five current capped cases.
