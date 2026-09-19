# Kurchin: Armor-gated deflection — 2026-09-19

**Recommended first playtest: 15 HP, 6 Armor, Attack 1, and 75% deflection while Armor remains.** Keep ordinary regeneration at 1 and remove the experimental flat damage reduction. Eight Armor is a stronger alternative, but its extra ally protection is modest and it wins substantially more solo fights against low-damage groups. Address formation before raising durability further.

This recommendation comes from **8,640 completed trials**. It is an experiment, not a change to live stats or attack rates.

## The exact rule tested

- Check Armor immediately before each incoming direct attack.
- While Armor is positive, independently roll the stated deflection chance.
- A deflected attack consumes **neither Armor nor HP**.
- A landed attack deals normal damage: Armor absorbs what it can, and overflow reaches HP.
- At zero Armor, deflection stops completely, including for later attacks in the same tick.
- Existing Armor bypass, poison and banishment rules remain. Ongoing poison is not deflected. The Armor defense works during fear; it does not depend on moving or hunting.

All candidates have **15 HP, Attack 1, normal speed and taunt, and regeneration 1**. The tested ordinary attack intervals are 34 ticks for melee and 50 for ranged: up to six melee/four ranged attacks in a 200-tick round, with cooldowns carried between rounds. Monster power and movement timings are unchanged. There is no additional flat mitigation or regeneration buff.

The baseline is experiment commit `d853e23af35aa6f42ddb4f884a5cefc5e5941b88`, which includes the live Wright repair and Tumler pursuit fixes from `8591fae49ce13b216f50554d92e9b1506589131e`. The production game remains untouched.

## Sweep and controls

The initial sweep tested Armor **2, 4, 6, 8 and 10**, each with **0%, 50% and 75%** deflection. Each candidate had 15 solo scenarios and nine squad scenarios, using eight seeds in both seats. Penitent squad controls bring this initial batch to **5,904 trials**.

The two finalists—6/75% and 8/75%—and the Penitent control then used 24 additional seeds in both seats, adding **2,736 trials**. Thus each finalist has **64 battles per matchup**, including 576 squad battles. These are distinct fixtures, not reruns counted as new trials. The earlier exploratory simulations and pilot are excluded.

Solo encounters cover one, two and three of each basic marcher, plus mixed groups of four, six and eight. Squad encounters use groups of four, six and eight against balanced, melee-heavy and ranged-heavy opposition. The friendly roster is held fixed except for replacing its final Penitent with Kurchin. The control keeps that Penitent.

These are body-matched lane encounters, not summoning-cost or full-game balance estimates. There are no Lords, economy, reinforcements or bot decisions. The fixed roster selection deliberately includes difficult opposing compositions; its pooled win rate is not a predicted overall game win rate.

## How much Armor is useful?

Initial mixed-army win rates, **144 battles per cell** across the same nine scenarios and seeds. HP is 15 throughout; “none” means no deflection, not current live Kurchin.

| Armor | No deflection | 50% deflection | 75% deflection |
| ---: | ---: | ---: | ---: |
| 2 | 26.4% | 29.9% | 36.1% |
| 4 | 29.9% | 34.7% | 43.1% |
| **6** | **31.3%** | **37.5%** | **54.9%** |
| 8 | 33.3% | 41.7% | 59.0% |
| 10 | 36.1% | 47.2% | 63.9% |

At six Armor, 50% helps but is a modest change. Seventy-five percent produces a clearer benefit: wins rise from 45/144 without deflection to 79/144, and the other allies suffer 35 fewer deaths across those same trials. This comparison isolates deflection at the same HP and Armor.

Armor 10 with 75% is the strongest option in this sweep, but strength alone is not the selection criterion. It beat three Vultures alone in all 16 initial trials and three Penitents in 10/16. The middle settings leave more room for basic units to answer the tank.

## Finalists in groups of four to eight

Combined initial and fresh-seed results, **576 battles per row**:

| Focal unit | Team wins | Team win rate | Other ally deaths per battle | Focal unit survived |
| --- | ---: | ---: | ---: | ---: |
| Penitent control | 113/576 | 19.6% | 4.59 | 44/576 |
| **Kurchin: 6 Armor, 75%** | **335/576** | **58.2%** | **4.18** | **309/576** |
| Kurchin: 8 Armor, 75% | 373/576 | 64.8% | 4.12 | 358/576 |

The control has two mutual eliminations; the eight-Armor candidate has one. All other outcomes are wins or losses. There are no unresolved fights in the complete sweep at the ten-phase cutoff.

The six-Armor candidate saves **232 additional nonfocal allies out of 2,880**, compared with replacing him with a Penitent: about **0.40 ally per battle**. Its mean contributions are 8.49 enemy HP damage, 1.74 Armor damage and 1.67 kills. It loses 9.25 HP, consumes 5.09 Armor and deflects 15.22 damage per battle on average. Surviving tanks do not necessarily exhaust their starting defenses; these are contributions actually observed, not theoretical capacity.

Eight Armor wins another **38 battles**, a real 6.6 percentage-point improvement, but saves only **36 more allies out of 2,880**—0.0625 per battle. Much of the gain is Kurchin himself surviving and finishing the fight. The Penitent comparison also includes the candidates' larger HP pool and monster behavior; it must not be attributed entirely to deflection.

Observed deflection rates while armored are 74.89% for the six-Armor finalist and 74.88% for eight Armor, over 9,244 and 11,630 incoming attacks respectively.

## Can ordinary units still kill him?

Solo wins, **64 trials per cell**, with normal deployment:

| Opposition | 6 Armor / 75% wins | 8 Armor / 75% wins |
| --- | ---: | ---: |
| One Butcher | 62/64 | 64/64 |
| Two Butchers | 9/64 | 16/64 |
| Three Butchers | 0/64 | 0/64 |
| Three Penitents | 5/64 | 13/64 |
| Three Vultures | 22/64 | 39/64 |
| Three Wrights | 32/64 | 55/64 |

The six-Armor one-Butcher row has two mutual eliminations. Both three-Penitent rows have one mutual elimination. The three-Wright rows have four and one mutual eliminations respectively. Remaining nonwins are losses.

Against three Butchers, average survival is **0.65 combat rounds at six Armor** and **0.87 at eight**. Both always die. This clock starts at the first attack aimed at Kurchin, including a miss; it includes the opening time his deflections buy. It is intentionally different from the earlier “first landed hit” duration, which undercounts this defense.

Butchers retain their damage advantage. The defense gives a chance to avoid a whole hit, rather than reducing every basic attack to the same one-damage floor. Eight Armor nevertheless makes solo victories over low-damage groups much more common. Six is the more conservative starting point for a unit intended to tank while allies supply damage.

Survival durations in the JSON are explicitly conditional on death. Surviving units are listed separately rather than assigned an invented death time.

## Formation is still limiting the tank role

Kurchin took the first incoming attack in **0 of 576 squad trials** for each finalist. The Penitent used in the same final roster slot also was not the first target. This formation sends the faster units into contact first.

For one concrete six-Armor example (four-unit balanced encounter, seed index 0, seat 0), the allied Butcher was first targeted at tick 262. Kurchin was first targeted at tick 478—more than a combat round later, after that Butcher died. His current movement step is 2, compared with 3 for Penitents and 4 for ordinary Butchers/Wrights.

The improved team results are real, but more Armor does not make him lead the charge. Before buffing beyond six Armor, the next useful experiment is getting him into the front of the actual group and then measuring whether his allies survive more often. These tests do not change deployment or movement behavior.

## Goals, verification and reproduction

Raw records retain both sides' damage, kills, regeneration and goal arrivals. Across the 576 finalist squad battles, the six-Armor side has zero goal arrivals before the cutoff and its opponents have 12; the eight-Armor side has zero and its opponents have five. These are truncated encounter counts: the harness stops after the first decisive phase, so winners are not marched onward to manufacture a full-game scoring estimate.

Python and native **Godot 4.5.1 official Linux** matched **595 complete phases / 119,000 ticks**, including complete world state and combat events. Forty-six directed boundary cases cover roll thresholds, zero Armor, Armor consumption/overflow, protection ending at depletion, both seats, melee/ranged attacks, and direct abilities during fear while poison remains undodgeable. These are diagnostic native checks; Godot 4.7.2 Windows acceptance was not run. Visual tick snapshots were not compared in this pass.

From this experiment branch, with `PYTHONPATH=Scripts/Sim`:

```bash
python -m u13_pysim.kurchin_armor_balance --samples 8 --output /tmp/kurchin-main
python -m u13_pysim.kurchin_armor_balance --samples 24 --start-sample 8 --variants a6_d75 a8_d75 penitent_control --output /tmp/kurchin-followup
```

For native parity, repeat with `CHANCE` replaced by 0, 50 and 75, using fresh directories and your Godot executable:

```bash
python -m u13_pysim.verify_kurchin_armor project /tmp/kurchin-native-CHANCE CHANCE
python -m u13_pysim.verify_kurchin_armor export /tmp/kurchin-check-CHANCE CHANCE
godot --headless --path /tmp/kurchin-native-CHANCE --script res://Scripts/Sim/U13UnitBalanceParityRunner.gd -- /tmp/kurchin-check-CHANCE/inputs.jsonl /tmp/kurchin-check-CHANCE/native.jsonl
python -m u13_pysim.verify_kurchin_armor compare /tmp/kurchin-check-CHANCE
```

Evidence: [all summaries, manifests and verification](evidence/U13_KURCHIN_ARMOR_BALANCE_2026-09-19.json), [all 8,640 raw trials](evidence/U13_KURCHIN_ARMOR_BALANCE_2026-09-19.jsonl.gz).

Raw archive SHA-256: `6656f865aaa4e7e30825a605b28e7cf18ae37ac4698e958bc0a2914149c65ff1`.
