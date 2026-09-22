# Kroni: current kit, experiments and 16-game follow-up

This document describes the local bouncing-Consume prototype tested on
2026-09-22. Rules were checked against source at `0d71289` (gameplay unchanged
from `7dcd7a0`). The prototype and results are local; they have not been pushed.

## Kroni's full current kit

### Core stats and Hunger

| Element | Current rule |
|---|---|
| Base summon value | 5; ordinary summon modifiers apply. The current match opening summons Lords for free. |
| Fracture value | 1, using the shared Fracture system. |
| Starting Hunger | 0. Hunger cannot fall below zero. |
| Lord defense | 4 at Hunger 0; 6 at Hunger 1–2; 8 at Hunger 3+. |
| Hunger milestone | First reaching 3 Hunger grants **1 personal Tear, once per game**. Falling below 3 and returning does not repeat it. |
| Threat interaction | Kroni still has a Threat counter, but his own defense calculation uses Hunger rather than the normal Threat-based defense reduction. |
| Passive Hunger loss | A standalone Ward or Pass loses 1 Hunger before combat resolves. A Hunt/Siege with an accompanying Ward is still an attack and avoids this particular penalty. |

Hunger strengthens defense and Ravenous's eating radius. It does **not** give
Kroni a direct attack-strength bonus or a special castle-destruction bonus.
Normal Siege rewards still apply to him.

### Cannibal Hunger — automatic feeding

At the round-start feeding check, a living Kroni who has not already been fed
by Consume that round eats his own lowest-value guard, across both guard zones.
Equal values use a stable entity-ID tie-break. This removes the guard but does
not grant Hunger. If he has no guard, he instead loses 1 Hunger.

A successful Consume meal, friendly or enemy, satisfies this requirement for
that round. Consequently, a friendly Consume meal has an opportunity benefit:
it avoids the additional automatic feeding loss. It may still eat a much more
valuable guard than Cannibal Hunger would have selected.

### Consume — current neutral-bounce prototype

- **Cost:** no Soul or card cost. No skipped-round cooldown; it can be declared
  each round when legal.
- **Timing:** declared now, resolves at the next round's scheduled start.
- **Input:** one activation, with no choice of guard, lane or launch position.
- **Launch:** fixed neutral position between the players' guard areas,
  approximately behind the normal modal. The initial direction favors the
  enemy half 60% of the time and the friendly half 40% of the time.
- **Movement:** bounces around the guard arena until it hits one guard. All
  friendly and enemy Lord/Castle guards are eligible; the first collision wins.
  The flight stops after that single meal. Initial enemy direction does not
  guarantee an enemy meal.
- **Enemy meal:** removes the guard, grants **+1 Hunger**, and satisfies feeding.
- **Friendly meal:** removes the guard, grants **no Hunger**, and satisfies feeding.
- **Availability/failure:** no guards anywhere means no legal activation. If
  guards disappear before firing, it can miss; a miss does not satisfy feeding.
  A banished Kroni cannot perform the scheduled bite.
- **Safety and replay:** a deterministic 2,048-tick bound prevents an endless
  flight; keyed randomness and the recorded route support repeatable playback.

The former power selected a specific enemy guard, removed it at the next
round's start, granted +1 Hunger and satisfied feeding. That exact-target form
remains accepted for legacy pending orders/replays, but current bots and the
playable UI generate only the neutral-bounce form.

### Ravenous — battlefield crossing

- **Cost:** no Soul or card cost. Two blocked rounds after activation: using it
  in round N makes it available again in N+3.
- **Timing/input:** choose a lane and a launch point on your own field edge.
  It arms after combat resolution and crosses the battlefield during Marching.
- **Movement:** travels toward the opposing edge, bouncing laterally. Current
  source chooses an enemy-favored route when it finds a candidate crossing at
  least two currently placed enemies; otherwise it uses a random route.
  Angles are weighted toward steeper diagonals. This is not the older proposed
  75%/25% launch split.
- **Meals:** eats both friendly and enemy field bodies, including monsters.
  There is no fixed meal count: actual collisions determine how many it eats.
  Reaching the reward threshold does not stop the crossing.
- **Radius:** base eating radius is multiplied by 1.00 / 1.10 / 1.20 / 1.35
  at Hunger 0 / 1 / 2 / 3+. Radius growth stops at the 3+ tier.
- **Fleeing:** nearby mobile bodies flee away from him within twice the eating
  radius, staying in their lane. The 1.1-second flee timer refreshes while near;
  a chomp has a 0.55-second interval during which fleeing continues. Committed
  Tumler windup/charge movement has a specific exception to flee displacement.
- **Reward:** eating **11 enemy bodies in one use** grants **+1 Soul, +1 Hunger,
  and +1 neutral Tear**, once for that use. Friendly bodies do not advance it.
  Neither another eleven kills nor kills accumulated across uses repeat it.

The reward was previously available at six total consumed bodies. The current
rule raises the threshold to eleven and requires those bodies to be enemies.

### Insatiable Hunger — absent-Lord Veil manifestation

When Kroni is an active absent-Lord breach, a neutral eating actor manifests
at Marching start. It launches at a random field location/direction, bounces
around briefly, and can eat either side's unprotected bodies. Personal-Tear
breach protection applies. It has no owning player and grants no Ravenous
Soul/Hunger/Tear reward. This is the shared Veil manifestation of an absent
Kroni, not another activatable benefit for someone playing him.

## What we have tested so far

### Historical roster baseline

The retained 162-game roster run used the round-20 late-Soul bonus rules,
precise enemy-targeted Consume and the earlier Ravenous reward rule. Kroni won
**29 of 32 non-mirror games (90.6%)**. Across those 32 games, Consume ate 246
enemy guards; Ravenous had 77 uses and 66 reward events. These historical games
are reused controls, not additional games run for this follow-up.

### Same Kroni–Odradek seed: targeted probes

All rows below use the archived `kroni_odradek_00` seed, Kroni in seat 0.
Both bots replanned in each changed experiment. Souls are final balances in
Kroni/Odradek order, not total lifetime income.

| Configuration | Winner and finish | Final Souls | Main observation |
|---|---|---|---|
| Historical exact Consume, free monsters | Kroni, R9 Ritual | 12 / 1 | Four enemy guards consumed; four final Siege targets destroyed. |
| Only Kroni forbidden recipe monsters | Kroni, R16 Dominion | 11 / 3 | Removing summons delayed his win seven rounds but did not reverse it. |
| Consume disabled; eleven-enemy Ravenous | Odradek, R15 Ritual | 0 / 13 | Kroni lost 12 guards to automatic feeding and destroyed two Siege targets. |
| Bouncing Consume; eleven-enemy Ravenous | Kroni, R14 Dominion | 6 / 4 | Six Consume meals: three enemy, three friendly; seven additional automatic meals. |

In the original round-9 win, four Siege destructions supplied **11 of Kroni's
12 Souls**, and one Ravenous reward supplied the remaining Soul. Those Sieges
used card strength without Supplicant or Veil attack bonuses. This established
where that game's income came from; it did not prove Consume alone caused it.

With Consume disabled, Ravenous ate 14 enemy/1 friendly, then 9/0, then 7/0
across three uses. Only the first use earned the new reward. In the first
bouncing-Consume game, Kroni never used Ravenous and still won by Dominion.

Recorded original operations reproduced the original outcome/Souls/Tears under
the eleven-enemy threshold: its single Ravenous ate 16 enemies. That replay is
not a fresh policy-driven test of the threshold nerf alone. The no-monster
probe used the older frozen rules; later Consume probes include the new
Ravenous rule/scoring. These rows are diagnostic examples, not isolated
estimates of each power's average value.

### Related monster-economy probes (not Kroni balance evidence)

We also tested Deimos versus Odradek to avoid relying solely on Kroni:

- Original: Deimos won R14 Ritual, Souls 15/0.
- Deimos alone denied recipe monsters: Odradek won R15 Dominion, Souls 5/6.
- Both sides charged 0.25/0.50/0.75/1 Soul by recipe tier: Deimos won R20 Ritual,
  Souls 12.25/4. Total recipes stayed at 28 across the longer game.

Those were one-game experiments. Monster prices, stat buffs and multiple
summons per round were **not adopted** in the Kroni prototype or 16-game batch.
Normal free recipes remain available, at most one recipe summon per round.

### Implementation checks completed before the larger sample

- 23 focused Python checks passed, covering routes, ownership, reward limits,
  doctrine, coordination, seat reflection and repeatability.
- Native guard-Consume suite: 784 checks, zero failures.
- Python/Godot comparison: 200 keyed routes and 24 resolved meals matched in
  events/views, remaining entities, resources and feeding flags.
- Existing native Kroni suite: 973/973 checks.
- Native board checks passed for one-click activation, delay, path playback
  and skipping. Visual feel still needs a human playtest.
- All 288 single-occupied-slot/direction cases found a meal, at most 1,178 ticks.
- On a fully occupied test layout, 1,000 seeded launches produced 582 initial
  enemy directions and 539 enemy meals. That layout-specific 53.9% meal rate
  is not a universal probability.
- An unrelated pre-existing Valak projection fixture still fails; its failure
  was reproduced on the earlier source and is not included in passing counts.

### Larger follow-up: 16 new Kroni games

All eight opponents, both seats, using archived repeat `01` and two Python
workers. These seeds differ from the single `00` seed above. The complete
paired results and limitations follow.

The prototype creates meaningful friendly-fire risk, but this sample does not
establish it as a sufficient Kroni balance fix. Kroni still won 13/16 games.
Keep it as a playable prototype, not a balance sign-off. No additional rule,
stat, pricing, or doctrine changes were made for this batch.

## Matched results

| Measure | Historical control | Current prototype |
|---|---:|---:|
| Kroni wins | 14/16 (87.5%) | 13/16 (81.25%) |
| Mean ending round | 15.06 | 13.56 |
| Median ending round | 15.5 | 13 |
| Range | 9–21 | 10–19 |
| Finished before round 15 | 7/16 | 11/16 |
| Finished in rounds 15–20 | 8/16 | 5/16 |
| Finished after round 20 | 1/16 | 0/16 |
| Dominion / Ritual finishes | 7 / 9 | 10 / 6 |
| Round-25 cutoff | 0 | 0 |
| Consume enemy meals | 139 | 76 |
| Consume friendly meals | 0 | 40 |
| Consume selections | 150 | 133 |

Enemy guard removals fell 45.3% in total, while 34.5% of current Consume meals
were friendly. These totals include changed game lengths. Enemy meals per
game-round fell from 139/241 (0.577) to 76/217 (0.350), about 39.3%.
The current bot still chooses Consume frequently. One flight missed; selections
also include pending or fizzled declarations and need not equal completed meals.
Kroni additionally lost 64 guards to automatic Cannibal Hunger, giving 104 own
guards lost across the two feeding mechanisms. There were 43 Ravenous uses and
19 Ravenous rewards in the prototype sample.

The prototype had two win-to-loss flips (Kalligan and Kanifous) and one
loss-to-win flip (Orias), all with Kroni in seat 0. Kroni won 5/8 in seat 0 and
8/8 in seat 1, versus 6/8 and 8/8 historically. This tiny Kroni-specific sample
cannot establish a general seat advantage; it does not support blaming seat 0
for these wins. Reversed seats share a seed, so 16 games are not 16 independent
random matchups.

## Opponents

Each cell lists Kroni in seat 0 / Kroni in seat 1. W/L is from Kroni's viewpoint.

| Opponent | Historical | Prototype |
|---|---|---|
| Deimos | W R9 / W R11 | W R11 / W R10 |
| Gremory | W R21 / W R16 | W R13 / W R13 |
| Humbaba | W R18 / W R18 | W R14 / W R18 |
| Kalligan | W R16 / W R14 | L R10 / W R11 |
| Kanifous | W R16 / W R12 | L R13 / W R13 |
| Odradek | L R15 / W R10 | L R17 / W R10 |
| Orias | L R20 / W R14 | W R13 / W R15 |
| Valak | W R18 / W R13 | W R17 / W R19 |

## Interpretation

Removing precise targeting substantially reduced enemy guard consumption,
but did not remove Kroni's dominant results in this sample. Friendly meals also
satisfy Cannibal Hunger, so a friendly bite is not entirely wasted. Dominion
became more common overall; eliminating one route to dominance can leave other
routes viable. The batch does not isolate which mechanic caused those wins.

For the 15–20-round goal, this sample moved in the wrong direction: only 5/16
finished in that band, versus 8/16 historically. There was no return to long-game
stalling, but no evidence here that the redesign solves early dominance.
Final Collapse is disabled in this ruleset, so its absence is not itself a
balance result.

Before another tuning change, inspect the quick Dominion wins and their Hunger,
Tear and feeding events. A freshly replanned exact-Consume control with the
same eleven-enemy Ravenous rule would isolate Consume better. Neither that
additional run nor another rules change was performed here.

## Reproduction and limits

- Exactly 16 completed new games: all eight non-Kroni opponents, both seats,
  archived repeat `01`, using two Python worker processes. These are different
  seeds from the previous `kroni_odradek_00` one-game probe.
- Seed, seat order, castle loadout, experiment flags and policy weights were
  retained from each corresponding `tempo-roster-162-03` archived game.
- Current simulation source: commit `7dcd7a0`; the evidence includes recursive
  Python source hashes, weights, setup, archived record hashes and runner hash.
  Source hashes were unchanged across the completed run.
- The historical controls used exact-target Consume and the former Ravenous
  reward threshold/scoring. Current games use bouncing Consume and eleven-enemy
  Ravenous. This is a combined-change comparison, not an isolated Consume test.
- All sixteen traces and operation hashes were checked. Meal counts match
  separate doctrine diagnostics. Zero rejected previews or invalid submissions.
- This is a Python batch. Earlier focused Godot rules and board parity checks
  remain the native validation; this is not a new 16-game Godot parity claim.
- An initial reporter attempt failed on an absent optional summary field. It
  was stopped; the reporter was corrected and the same seeds rerun. No seeds
  were replaced or gameplay rules edited. The final batch has zero failures.

Run from the repository root:

```sh
python Scripts/Sim/run_u13_guard_consume_sample.py \
  --baseline ../tempo-roster-162-03 \
  --output ../kroni-guard-sample-16-reproduction
```

Evidence: `docs/evidence/U13_GUARD_CONSUME_SAMPLE_16_2026-09-22.json`.
The adjacent `.traces.tar.gz` contains all 16 operation, semantic and policy traces.


## Follow-up: full-kit ablation

The same sixteen setups were subsequently replayed with both activated powers
and all Hunger benefits/costs disabled, fixed Lord defense 4, and the bot's
Hunger-related Ward penalty removed. Powerless Kroni won **3/16**, versus
**13/16** with the bouncing kit. Mean game length rose from **13.56 to 15.63**
rounds. All three wins were in seat 1, against Kalligan, Kanifous and Odradek.
Ten current-kit wins became losses; no loss became a win.

This identifies substantial combined kit value in the sample, not the individual
contribution of either power, defense scaling or the milestone Tear. No
production rules changed. The four rejected summon-payment previews in the
Kalligan pair were discarded; all actual submissions were legal.

Full scope, results and evidence are in
[the power-ablation report](U13_POWERLESS_KRONI_SAMPLE_16_2026-09-22.md).


## Follow-up: Hunger alone removed

A further sixteen matched games retained both powers and automatic guard
feeding, but removed all Hunger gains/losses, defense/radius scaling and the
milestone Tear. Kroni won **4/16**, compared with **13/16** for the current kit
and **3/16** for full-kit ablation. Mean duration was **14.06 rounds**.
Consume still ate **77 enemy guards** (current kit: 76); Ravenous still granted
**17 Soul/neutral-Tear rewards** (current kit: 19). No rejected previews or
invalid actual submissions occurred.

This strongly implicates the combined Hunger package in these matchups but
does not identify one benefit, establish balance, or make it a playable change.
See [the Hunger-only ablation report](U13_NO_HUNGER_SAMPLE_16_2026-09-22.md).


## Follow-up: Hunger-aware opponent Hunt valuation

With Kroni's entire kit unchanged, a bounded bot bonus for banishing hungry
Kroni or removing his Lord guards reduced his wins from **13/16 to 9/16**.
Opponent Hunts rose **21 → 73** and banishments **8 → 27**. Hunt selection
against living Hunger-3+ Kroni rose **8.9% → 46.9%**. This supports opponent
doctrine contributing to his advantage, without proving the chosen scores
optimal. Mean duration was 15.25 rounds, but only 3/16 landed in rounds 15–20.

This remains a process-local experiment. See
[the Hunt-doctrine report](U13_HUNGER_HUNT_DOCTRINE_SAMPLE_16_2026-09-22.md)
for coefficients, per-match outcomes, validation and limitations.
