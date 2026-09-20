# Dotra's emergence protection — V17

Dotra is now **untargetable for five game seconds after emerging from his ambush**. He stays visible, moves and attacks normally, and enemies acquire other available targets. A pale purple crossed-eye marker and draining arc show the protection. It starts on emergence, not on his initial summon.

The window lasts 67 simulation ticks (5.025 seconds at 200 ticks per 15-second interval). It follows the simulation clock, scales with playback speed, and carries across interval boundaries and save/load. Melee units, Vultures, towers, Muno, Sinodek and monster target selection respect it. Retained navigation drops Dotra as a target, and enemies in contact can move toward someone else. His physical footprint remains.

Area damage, existing poison, and allied healing still affect him. Directly aimed Muno and ambush packets recheck legality when they resolve. Replay arrows and Muno's dash respect the recorded expiry. His first hide still occurs once, after 15 active field seconds; his full-speed hidden approach, 5-damage ambush and one-round exposure pulse are unchanged.

Both engines use `U13_MONSTERS_V17_DOTRA_SHROUD`, with `dotra_shroud_ticks: 67`. The launcher identifies **Dotra shroud V17**, and the arena title shows **shroud V17**.

## Matched balance comparison

**Interpretation corrected:** a qualifying commitment summons its normal marchers **plus** the chosen monster. The recipe rows below are artificial replacement benchmarks that pit Dotra against the ordinary troops his recipe cards produce. They do not represent a gameplay tradeoff, and losing them does not mean summoning Dotra is a poor use of those cards. The continuous games already use the correct additive spawning rule in both engines.

The same 576 fights cover 18 Dotra scenarios, 16 seeds and both reflected seats. All 288 seat pairs matched outcomes, goals, surviving forces and duration. The batch resolved 1,556 intervals with no round caps. The [V16 report](U13_DOTRA_TIMED_HIDE_2026-09-19.md) supplies the previous results.

Each row is from Dotra's side. Counts include both seats: there are 16 independent seeds per scenario, not 32 independent draws.

| Scenario | V16 wins / losses | V17 wins / losses |
|---|---:|---:|
| Dotra versus ordinary units from his recipe cards | 4 / 28 | 22 / 10 |
| Artificial replacement benchmark with identical support | 4 / 28 | 4 / 28 |
| Supported versus six Butchers | 0 / 32 | 0 / 32 |
| Supported versus three Penitents and three Vultures | 0 / 32 | 32 / 0 |
| Supported versus mixed army | 22 / 10 | 32 / 0 |

Support is one of each ordinary marcher. The mixed opponent has that core plus two additional Butchers. This is a substantial buff against several formations, especially the ranged formation; it does not settle his overall balance. The 4/32 supported replacement result and 0/32 six-Butcher result describe those particular test forces, not the value of choosing Dotra in a real commitment. He does not need to outperform all the regular troops his recipe produces, because the player receives those troops too.

To assess his actual contribution, compare the army his commitment produces with and without Dotra against fixed opposing forces. Compare that improvement, recipe availability and competing uses of the cards with other monsters. Do not use the artificial replacement win rate as a requirement for further buffs.

The controlled batch still produced exactly 576 ambush/exposure pulses and 910 affected-enemy instances. Dotra's recorded HP damage rose from 5,116 to 6,054, kills from 564 to 742, and deaths fell from 252 to 176. The new protection changes what happens after the ambush rather than adding more ambushes. Damage from allies hitting exposed enemies remains credited to those allies.

## Continuous runs

Eight native games ran 30 intervals each, using the two screenshot seeds and `monster-mixed:2` / `monster-mixed:3`, with both seats. All four pairs mirrored their complete final session totals.

| Dotra measure | V16 | V17 |
|---|---:|---:|
| Summons | 18 | 18 |
| Deployed Dotras / ambushes | 16 / 16 | 16 / 16 |
| Affected-enemy instances | 100 | 112 |
| Active body-intervals | 56 | 62 |
| Own recorded HP damage | 214 | 202 |
| Kills | 24 | 26 |
| Deaths | 14 | 10 |

All 16 emergences started exactly one 67-tick protection window. Dotra made 18 ordinary attacks for 36 recorded HP damage during those windows. There were zero directly aimed hits against a protected Dotra. The other two summons remained staged at the final interval.

The continuous sample shows improved survival with slightly lower personal damage. It is not evidence of higher damage in every game. Final normal-seat goals were `[0, 17]`, `[2, 46]`, `[17, 7]` and `[19, 51]` in seed order; swapped seats reversed each result.

## Verification

- 1,048 native assertions passed: 125 shroud, 196 hide timing, 648 general monster and 79 exposure checks.
- Coverage includes both seats, continued outgoing attacks, allies drawing melee and ranged attacks, tower retargeting, monster acquisition, released navigation, exact expiry, interval-boundary save/load, area/poison exceptions, healing, marker expiry, both lane views, and projectile/dash playback.
- 163 complete native/Python phase comparisons passed: 15 shroud, 43 timing, 84 general monster, three exposure, two controlled and 16 continuous phases, covering 32,600 ticks and complete resulting worlds/events.
- 22 native/Python damage-adapter comparisons passed: five new protection cases and 17 existing exposure cases.
- Launcher syntax and patch whitespace checks passed.

Tests used Godot 4.5.1 Linux headless and PyPy 3.11 v7.3.20. The Windows runner requires Godot 4.7.2 stable; Windows visual acceptance was not performed here.

The [evidence folder](evidence/U13_DOTRA_SHROUD_2026-09-20/) contains fight summaries, replay samples, parity logs, window counts and source hashes. The audit summary's inherited `revision` field is the starting V16 commit; `verification.json` identifies the tested V17 source files.

## Runner

From Windows Git Bash in the project folder:

```bash
git pull --ff-only origin u13-basic-doctrine
bash Scripts/Sim/run_u13_vulture_balance.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

Check for **Dotra shroud V17** in the launcher and **shroud V17** in the arena title.
