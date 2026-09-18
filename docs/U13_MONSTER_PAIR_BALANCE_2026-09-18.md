# Monster power and Penitent formation experiments — 2026-09-18

Try the closer Penitent-led approach before another general Vulture nerf. Keep the current 50% ranged block and Vulture firing interval for that playtest. Permanent Tumler evasion helps, but he needs damage and durability as well to meet the requested one-monster-versus-two-marchers target. A universal +3 Armor does not meet that target.

These are isolated experiments, not applied gameplay balance changes. The baseline includes the previously tested Tumler cluster-pursuit fix: he pursues through enemy bodies while still avoiding slowing pools. That fix and the preceding audit were recovered from the prior saved Git tree.

## Scope and definitions

Completed **22,464 trials**, covering **21,184 distinct fixtures**. Repeated baseline fixtures connect the focused comparisons; they are not additional independent evidence. Each matchup/variant uses 32 deterministic seeds in both seats (64 trials), with the same identities and deployment across variants. These are lane combat fixtures with no Lords, Castle attacks, economy, reinforcements or bot decisions.

A combat win means the opposing original marcher force is gone while at least one original friendly body remains. Both gone is a mutual kill. Portals count as removal; a charmed original unit reaching the opposing side's goal is counted as lost to its original team. Stop after the first decisive 200-tick phase, or ten phases. Surviving fortifications are not followed through after the last original marcher dies, so especially Wright matchups are marcher-elimination results, not full-game victories. Unresolved fights remain unresolved.

“Near even” is a separate, deliberately strict loss category: exactly one enemy remains with at most 2 combined HP and Armor. Varn is one summon of 3–5 bodies. Armor is consumed when hit; +3 Armor is three additional points of absorption, not three damage reduction per attack.

Goal arrivals in the raw records stop at the combat cutoff and should not be compared as final goal rates. The preceding [unit audit](U13_UNIT_BALANCE_2026-09-18.md) contains the full-phase goal, damage absorption, kill and support-value analysis.

## Penitents leading the approach

The experiment slows nearby ordinary Butchers and advancing Wrights to quarter speed while a friendly Penitent takes the lead. It uses the existing local search radius of 420 and lateral width of 180. Followers keep a 90-unit or 180-unit gap, then resume full speed as soon as their leading Penitent reaches melee. No eligible Penitent means normal speed. Retreating, hidden, waiting, unready or fleeing Penitents cannot hold followers back. Existing Vulture/monster support pacing stays intact. Wright building and guarding keep normal movement. Both teams use the same rule.

Defender wins below; 64 trials per cell. “Screened Vultures” means three Vultures, one Butcher and one Penitent.

| Defending army | Opponent | Current | 90-unit gap | 180-unit gap |
| --- | --- | --- | --- | --- |
| 1 Penitent, 2 Butchers, 1 Vulture, 1 Wright | Screened Vultures | 1.6% | 34.4% | 10.9% |
| 2 Penitents, 2 Butchers, 1 Vulture | Screened Vultures | 46.9% | 95.3% | 82.8% |
| 3 Penitents, 1 Vulture, 1 Wright | Screened Vultures | 42.2% | 32.8% | 50.0% |
| 1 Penitent, 2 Butchers, 1 Vulture, 1 Wright | 5 Vultures | 0.0% | 26.6% | 4.7% |
| 2 Penitents, 3 Butchers | 5 Vultures | 0.0% | 90.6% | 90.6% |
| 2 Penitents, 2 Wrights, 1 Butcher | 5 Vultures | 0.0% | 26.6% | 9.4% |

The improvement is strongest when Penitents escort Butchers. Against five Vultures, the two-Penitent/three-Butcher army sends 51.6% of incoming Vulture shots at Penitents currently, versus 84.9% with the closer formation. Only 60 of 192 Butchers make any melee attack currently; 178 of 192 do so with the closer formation. Their mean first attack among those that attack is later: tick 318 → 401. They survive the approach and join the fight more often, but the rule really does delay melee participation.

In the two-Penitent/two-Butcher/Vulture army, Penitents receive 55.8% → 77.3% of incoming Vulture shots, and every Butcher reaches a melee attack with the closer spacing. The corresponding defender-win improvement is 48.4 percentage points, with a paired seed-cluster bootstrap 95% interval of +35.9 to +60.9 points. Against five Vultures, the melee army improves by 90.6 points (+81.2 to +98.4).

This is not a uniform buff. The Penitent-heavy army without Butchers falls from 42.2% to 32.8% wins with close spacing; the interval for that change is −25.0 to +6.3 points, so the sample does not establish a reliable penalty. Five-Butcher controls beat all three tested mixed defending rosters under every formation. Those controls are a losing floor and cannot establish that the formation has no downside against melee. In mixed-versus-mixed fights, both armies change their approach, and incoming-shot shares do not always rise.

### Is the Penitent counter working?

Yes, when the Penitent is actually taking the shots. Vulture wins against equal numbers of pure Penitents:

| Matchup | No ranged block | Current 50% block | 75% block | Vulture interval 32 → 40 ticks |
| --- | --- | --- | --- | --- |
| 1 vs 1 | 100.0% | 10.9% | 1.6% | 4.7% |
| 2 vs 2 | 96.9% | 35.9% | 7.8% | 15.6% |
| 4 vs 4 | 96.9% | 6.2% | 1.6% | 3.1% |

Block protects the Penitent himself; it does not intercept arrows aimed at a faster Butcher. Merely raising block to 75% barely helps the melee army against five Vultures (2 wins of 64), while the close formation at the existing 50% block gives 58 wins. Slowing Vulture fire from every 32 to every 40 ticks gives that army only 8 wins. Formation addresses the observed exposure problem more directly. Keep the close formation as the next playtest candidate; these fixtures do not justify declaring Vultures balanced across full games.

## Tumler: constant 50% evasion

Permanent means all direct attack rolls, including contact, hold, retreat and fear. Poison remains undodgeable. A landed melee hit still redirects a hunt; ranged damage does not. The cluster-pursuit fix remains part of every comparison.

| Tumler candidate | Wins vs 1 Butcher | Wins vs 2 Butchers | Mutual vs 2 |
| --- | --- | --- | --- |
| Current: Attack 2, Armor 1; hunt-only evasion | 0.0% | 0.0% | 0.0% |
| Permanent evasion; Attack 2, Armor 1 | 57.8% | 7.8% | 1.6% |
| Permanent evasion; Attack 2, Armor 4 | 87.5% | 26.6% | 4.7% |
| Permanent evasion; Attack 3, Armor 1 | 76.6% | 35.9% | 1.6% |
| Permanent evasion; Attack 3, Armor 4 | 100.0% | 65.6% | 6.2% |

The strongest tested candidate is **Attack 3, Armor 4, HP 5, constant 50% evasion**: all 64 single-Butcher fights won; 42 wins and 4 mutual kills against two. Constant evasion by itself is useful but still too unreliable for the stronger monster benchmark. At Attack 2/Armor 4 it wins 63 of 64 against two Vultures, so raising damage is particularly about handling hard-hitting melee opposition.

In the balanced 5-vs-5 squad, permanent evasion plus Attack 3/Armor 4 increases Tumler's mean HP damage from 0.97 to 7.23 and kills from 0 to 1.30 per summon. Squad wins rise from 0 to 39 of 64, with 3 mutual results. These are complete formation outcomes, not solo Tumler wins.

## Lemek against two Butchers

| Lemek stats (HP stays 5) | Spawn: wins / mutual / near losses | Tight: wins / mutual / near losses |
| --- | --- | --- |
| Attack 3 / Armor 4 | 0 / 0 / 0 | 0 / 0 / 0 |
| Attack 3 / Armor 7 | 0 / 7 / 0 | 0 / 0 / 0 |
| Attack 4 / Armor 7 | 0 / 7 / 43 | 0 / 0 / 0 |
| Attack 3 / Armor 10 | 49 / 0 / 0 | 0 / 0 / 0 |
| Attack 4 / Armor 9 | 49 / 0 / 15 | 0 / 0 / 64 |

Each cell contains 64 trials; all remaining outcomes are ordinary losses. Tight deployment puts the two Butchers alongside each other so both can pressure Lemek together.

**Attack 4 / Armor 9** is the best tested fit for “ahead, or nearly even”: 49 wins in the normal deployment; the other 15 leave one Butcher at 2 HP. Tight deployment still produces no outright wins, but all 64 losses leave exactly one Butcher at 2 HP. It meets the near-even benchmark, not a guarantee of beating two coordinated Butchers. A simple +3 Armor produces no wins in either layout.

## All monsters under the stronger benchmark

Single-Butcher cells contain 64 trials. Other cells pool 256 trials: equal numbers of Butcher, Penitent, Vulture and Wright matchups. Outright wins only; mutual and unresolved fights are not wins. +3 applies to each monster body, including Sooge after rooting.

| Monster | Vs 1 Butcher, current | Vs 1 basic, current | Vs 2 basics, current | Vs 2 basics, +3 Armor |
| --- | --- | --- | --- | --- |
| Lemek | 100.0% | 100.0% | 39.8% | 75.0% |
| Varn | 35.9% | 66.4% | 8.2% | 70.7% |
| Fyra | 4.7% | 58.6% | 4.3% | 32.4% |
| Kopita | 0.0% | 50.0% | 0.0% | 32.0% |
| Tumler | 0.0% | 75.0% | 0.8% | 50.4% |
| Kurchin | 0.0% | 50.0% | 0.0% | 0.0% |
| Muno | 100.0% | 100.0% | 46.1% | 50.0% |
| Dotra | 42.2% | 85.5% | 29.3% | 53.9% |
| Sooge | 29.7% | 25.8% | 1.6% | 3.1% |
| Sinodek | 6.2% | 32.0% | 4.7% | 4.7% |

Current Tumler here retains hunt-only evasion. Fyra has unresolved charm/escape outcomes: 45 of 256 single fights and 36 of 256 pair fights currently; 47 and 74 respectively with +3 Armor. They remain visible in the raw outcomes rather than being silently counted as wins or losses.

For two-basic baseline fights, mean contribution per monster summon:

| Monster | Enemy HP dealt | HP taken | Armor absorbed | Marchers killed |
| --- | --- | --- | --- | --- |
| Lemek | 7.76 | 3.88 | 4.00 | 1.45 |
| Varn | 3.45 | 7.86 | 0.00 | 0.31 |
| Fyra | 4.69 | 4.86 | 1.00 | 0.41 |
| Kopita | 3.34 | 5.14 | 1.00 | 0.35 |
| Tumler | 5.35 | 5.20 | 1.00 | 0.73 |
| Kurchin | 1.89 | 5.05 | 6.00 | 0.04 |
| Muno | 7.12 | 4.30 | 1.00 | 1.21 |
| Dotra | 6.68 | 4.66 | 2.00 | 1.06 |
| Sooge | 3.51 | 5.12 | 4.60 | 0.18 |
| Sinodek | 1.34 | 5.00 | 2.95 | 0.04 |

The user's stronger target changes the prior recommendation. “Useful in a squad” is not enough if every summon must comfortably beat a basic and trade against two. Kopita, Kurchin, Sooge and Sinodek remain especially far away. Kurchin wins zero of 256 pair fights even with +3 Armor. Sooge's turret loses ordinary melee and fires once per round; extra Armor does not fix the long gap between attacks. Sinodek relies on a conditional portal rather than reliable damage. These need targeted changes to damage, durability or ability reliability.

Do not treat Varn's +3 as the same-sized buff: it gives 9–15 extra Armor across one swarm. The prior squad audit also found a large kill/goal increase from that change. The current 1-vs-2 benchmark supports stronger monsters, but not an identical per-body adjustment across the entire roster.

## Verification and reproduction

Native Godot 4.5.1 Linux and the independent Python simulation matched **285 full phases / 57,000 ticks**, including complete worlds and nonvisual combat events. There were 256 permanent-evasion boundary checks and 44 formation checks, all passing. 351 saved trial records reproduced exactly using the final experimental implementation. Godot 4.7.2 Windows acceptance has not been run.

The final evasion override also removes the separate ability-damage fear gate. Explicit native/Python fixtures verify a dodged Muno strike while feared, undodgeable poison, and Sooge's guaranteed-root Armor replacement. The ordinary-marcher benchmark results reproduce unchanged after that completion.

From the repository root (set `PYTHONPATH=Scripts/Sim` before each command):

```bash
python -m u13_pysim.monster_pair_balance --suite monsters --samples 32 --workers 6 --output /tmp/pair-monsters
python -m u13_pysim.monster_pair_balance --suite tumler --samples 32 --workers 6 --output /tmp/pair-tumler
python -m u13_pysim.monster_pair_balance --suite tumler --samples 32 --workers 6 --variants always50_attack3 always50_attack3_armor3 --output /tmp/pair-tumler-damage
python -m u13_pysim.monster_pair_balance --suite lemek --samples 32 --workers 6 --layouts spawn tight --output /tmp/pair-lemek
python -m u13_pysim.monster_pair_balance --suite vultures --samples 32 --workers 6 --output /tmp/pair-vultures
```

Native projects are created by `python -m u13_pysim.verify_monster_pair_balance project NEW_DIRECTORY VARIANT`; use its `export` and `compare` commands with `U13UnitBalanceParityRunner.gd` for exact phase replay. Run `U13PairExperimentTestRunner.gd -- always` in the permanent-evasion project or `-- leader` in a Penitent-lead project for the boundary checks. Production rule files are not modified by these helpers.

Evidence: [machine-readable summaries](evidence/U13_MONSTER_PAIR_BALANCE_2026-09-18.json), [all raw trials](evidence/U13_MONSTER_PAIR_BALANCE_2026-09-18.jsonl.gz). Raw archive SHA-256: `6b188d5cbde59ef7382c2090729b415b3b1bff7a21159993e2e90eb74ab6ab7f`. Manifests retain the batch source hashes, fixture counts and revision; the report records final source hashes and native verification.
