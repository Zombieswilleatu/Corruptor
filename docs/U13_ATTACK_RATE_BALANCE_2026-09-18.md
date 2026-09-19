# Attack frequency and tank survival — 2026-09-18

**Six ordinary melee attacks and four ranged attacks per round is a workable first playtest.** Units still die regularly. It meets “most engaged units die within one round” by a narrow majority across the tested basic armies, and more comfortably in ordinary mixed and melee armies. Five melee attacks is a weaker fit for that goal. Keep current damage per hit for the first playtest; lowering Butcher damage as well noticeably weakens melee armies against Vultures.

For a Kurchin that survives a full round of three-Butcher pressure, the most useful tested candidate is **15 HP / 6 Armor / Attack 1 / −2 incoming damage, floor 1**. The earlier 10-HP/−1 proposal still dies quickly. These are experimental recommendations, not changes to the live attack rates or monster stats.

## Scope

Completed **24,192 trials**, using 32 deterministic seeds in both seats for every matchup/variant. Each rate uses the same identities and deployment. This pass includes 7,680 basic duels, 2,688 basic army battles, 7,680 monster-versus-one/two-Butcher fights, 1,920 monster army battles, 640 focused Tumler/Lemek candidate fights, and 3,584 Kurchin tank/escort comparisons. Contact fixtures are deliberately coordinated worst cases; repeated deterministic outcomes are not independent samples of player behavior.

The baseline is live commit `8591fae49ce13b216f50554d92e9b1506589131e`, including Wright repair and Tumler cluster pursuit. It differs from the earlier pre-repair audit. These are isolated lane encounters, without Lords, economy, reinforcements or bot decisions. Monster abilities, regeneration, movement and construction retain their current timings. The ordinary ranged rate applies to both Vultures and towers. Melee/ranged transition cooldowns change together with ordinary melee, preserving the existing shared cooldown behavior.

“One round of fighting” means 200 simulation ticks after a unit first attacks or is attacked by an enemy. Walking before combat is excluded. Survivors stay in the denominator. A separate whole-army metric starts at the very first hostile attack; it is stricter because other units can join much later.

Fights stop after the first decisive phase or ten phases. Surviving fortifications are not pursued after the last original marcher dies. Goal counts in the raw records stop at that cutoff. Escapes and charms can leave an unresolved result without an ongoing battle; they are not silently classified as wins, losses or stalemates.

## Does the proposed rate still kill units?

| Maximum melee / ranged attacks | Cooldown ticks | Engaged basic army bodies dead within one round of joining | Starting basic army bodies dead by battle cutoff | Contact duels with a death within one round |
| --- | --- | ---: | ---: | ---: |
| Current: 25 / 7 | 8 / 32 | 62.2% | 68.8% | 100% |
| 8 / 4 | 25 / 50 | 56.6% | 74.5% | 100% |
| **6 / 4** | **34 / 50** | **51.5%** | **72.5%** | **70%** |
| 5 / 4 | 40 / 50 | 50.1% | 72.6% | 40% |
| 6 / 3 | 34 / 67 | 49.6% | 74.2% | 70% |

Army cells pool six specified 5-vs-5 matchups, 384 battles per rate; contact-duel cells pool ten basic type pairings, 640 battles per rate. These are composition-specific measurements, not estimates of a game's universal casualty rate. Attack counts are maxima with continuous access to a target; cooldowns carry across rounds. A 34-tick interval averages 5.88 attacks per 200 ticks rather than refilling six charges each round.

At 6/4, **62.6%** of engaged bodies in the balanced mirror and **69.4%** in the melee-heavy mirror die within their first combat round. Across all six armies, 70.9% of the units that eventually die do so within that window; this is a different denominator from the 51.5% figure above. The whole-army first-shot window captures only **37.7%** of starting bodies, compared with **45.9%** at the current rate. Therefore this is not a promise that most of the entire army disappears before the next round boundary.

All tested basic duels and army battles eventually resolve. None still has both original sides actively fighting at the ten-phase cutoff. Regeneration and Wright repair did not create an endless basic-unit fight in these samples. Durable low-damage duels do take longer: three of ten contact pairings do not produce a death in the first 200 ticks at 6/4, versus six at 5/4. Median time to the first death in contact duels is 0.85 rounds at 6/4, versus 1.20 at 5/4.

## Damage per hit and the Vulture counter

Six attacks still gives one Butcher up to 18 raw damage per round; three together can attempt 54. The rate reduces the damage delivered over time without changing the lethality of their first simultaneous swing.

Two Penitents and three Butchers against five Vultures, 64 trials per candidate:

| Candidate | Melee army wins |
| --- | ---: |
| Current rate | 0 / 64 |
| 8 melee / 4 ranged | 22 / 64 |
| **6 melee / 4 ranged** | **21 / 64** |
| 5 melee / 4 ranged | 19 / 64 |
| 6 melee / 3 ranged | 64 / 64 |
| 6 / 4, Butcher damage 3 → 2 | 4 / 64 |
| 6 / 4, Penitents lead with a 90-unit gap | 64 / 64 |

In the mixed counter matchup—two Penitents, two Butchers and one Vulture against one Butcher, one Penitent and three Vultures—6/4 raises counter-army wins from 25/64 to 54/64. Reducing Butcher damage as well lowers that to 35/64. The closer Penitent formation gives 64/64.

The rate change therefore does not simply make Vultures stronger: fewer shots during the approach let more enemies reach them. However, three ranged shots or the close Penitent formation produces a very strong counter in these compositions. Keep four ranged shots initially and assess formation separately. The formation experiment exempts Wrights throughout their extended repair/guard state, including after the original minimum guard timer.

## Kurchin's tank role

All rows below use 6 melee / 4 ranged, original Armor 6 and Attack 1. Three Butchers begin together in melee. Survival is elapsed time from their first landed hit, not spawning time. Every cell has 64 trials; every Kurchin eventually dies.

| HP | Damage reduction per attack | Rounds survived | Butchers killed |
| ---: | ---: | ---: | ---: |
| Current 5 | 0 | 0.17 | 0 |
| 10 | 1 | 0.34 | 0 |
| 20 | 1 | 0.68 | 0 |
| 30 | 1 | 0.85 | 1 |
| 40 | 1 | 1.36 | 1 |
| 10 | 2 | 0.85 | 1 |
| **15** | **2** | **1.19** | **1** |
| 20 | 2 | 1.70 | 1 |

Reduction applies before Armor, with a minimum of one for positive incoming damage. Zero damage, blocks and evasion stay zero. Armor bypass still bypasses Armor; banishment is unchanged. Ordinary one-damage Vulture/tower shots and poison remain one. Prevention is recorded separately from consumed Armor.

At −1, three Butchers deal six combined damage per swing. At −2, they deal three. This makes 15 HP plus 6 Armor sufficient to survive the first full contact round while dealing little damage himself. His average normal-deployment survival is also about 1.17 rounds, with one kill. Regeneration can make total HP lost over a multi-round fight exceed starting HP.

With two Vultures behind him against three Butchers, the 15-HP/−2 candidate wins 61/64 battles, with 47 allied Vulture deaths out of 128. The 10-HP/−1 candidate loses all 64 and all 128 allies die. The 40-HP/−1 candidate also wins 61/64 with 47 ally deaths; 20 HP/−2 adds little in this escort matchup at 62/64. This is a large buff, so 15 HP/−2 is a playtest candidate, not a claim of final balance.

With two Butchers as allies, the 15-HP/−2 team wins 55/64, but all 128 allied Butchers still die. They advance ahead of him. Better durability helps Kurchin finish those fights; it does not solve that formation problem or guarantee protection for every nearby ally.

## Existing monster candidates need another look at the new rate

The earlier HP recommendations were measured at the faster attack rate. In this pass's matched normal deployments against two Butchers:

| Candidate | Current-rate wins / 64 | 6/4 wins / 64 | Additional near-even losses at 6/4 |
| --- | ---: | ---: | ---: |
| Tumler: HP 10, Attack 2, Armor 1, constant 50% evasion | 36 | 19 | 15 |
| Lemek: HP 10, Attack 4, Armor 4 | 50 | 0 | 64 |

“Near even” means exactly one enemy remains at no more than 2 combined HP and Armor. Lemek still meets that strict trade benchmark, but no longer wins the pair fight in this sample. Tumler's previous candidate does not reliably meet the intended two-basic target at the slower rate. Keep his tuning open.

Support units should still be judged through their powers. Sooge's mean contribution in the tested balanced army rises from 6.69 enemy HP damage / 0.77 kills to 8.34 / 0.98, even though his team's wins fall from 32/64 to 26/64. Kopita's team wins fall from 23/64 to 5/64, so he needs particular attention in a later monster pass. Team wins alone do not isolate an individual power's value. The raw records retain healing, banishment, damage absorption, kills and goal arrivals for both sides.

## Verification and reproduction

Native Godot 4.5.1 Linux and the Python simulator matched **309 complete battle phases / 61,800 ticks** across 17 variants, including full worlds and nonvisual events. An additional **12 phases / 2,400 ticks** matched every visual tick and event while explicitly checking uninterrupted melee, Vulture and tower cooldowns over four consecutive rounds. All 46 Penitent-formation boundary assertions and 378 saved-record replays passed. Godot 4.7.2 Windows acceptance was not run.

From this experiment branch, with `PYTHONPATH=Scripts/Sim`:

```bash
python -m u13_pysim.cadence_balance --samples 32 --workers 6 --output /tmp/cadence-main
python -m u13_pysim.cadence_balance --samples 32 --workers 6 --tank-followup --output /tmp/cadence-tanks
python -m u13_pysim.verify_cadence project /tmp/native-cadence m6r4_plain
python -m u13_pysim.verify_cadence export /tmp/check-cadence m6r4_plain
```

Run `U13UnitBalanceParityRunner.gd` in the isolated project with the exported `inputs.jsonl` and an output `native.jsonl`, then `python -m u13_pysim.verify_cadence compare /tmp/check-cadence`. Run `U13CadenceTestRunner.gd` with an output JSONL path for cooldown boundaries, then use the `boundaries` action with the same variant. Overrides remain in experiment helpers and disposable projects; production rule files retain the live rate.

Evidence: [summaries, manifests and verification](evidence/U13_ATTACK_RATE_BALANCE_2026-09-18.json), [all raw trials](evidence/U13_ATTACK_RATE_BALANCE_2026-09-18.jsonl.gz).

Raw trial archive SHA-256: `400f716f50056e1df8b79506a213b0b6b0c6235656e6479169531fc5dcdb01e2`.
