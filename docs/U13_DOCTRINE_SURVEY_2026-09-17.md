# Common doctrine: 810-game behavior survey

The user requested a full spread to choose the next doctrine targets, then asked
whether the revised castle rules were producing faster destruction. This pass
ran **810 complete Python games: ten seeds for each of all 81 ordered Lord
matchups**, including mirrors. All games completed, with zero rejected plans,
rejected previews or censored games. The highest-value next change is paid-Rite
plan generation, followed by checks for conflicts between powers and the rest of
a plan. Opening castle defense also deserves focused examples before more HP tuning.

The engine and experimental policy are unchanged from
`c716b5514e4de743ce5fcfe575c0c50a12f4011e`, including the user's castle pressure
and Guard-pair adjustments. The survey runner, passive recorder and audit tools
are new. Exact hashes, counters and named replay cases are in
[evidence](evidence/U13_DOCTRINE_SURVEY_810_2026-09-17.json).

## Scope and controls

The policy is `U13_COMMON_SMART_CORE_ALPHA_V3_RECIPES_VEIL`, using its unchanged
default weights for both seats. Opposite-seat matchups share a seed per Lord
pair/repeat. This controls seed and seat coverage; it does not assign identical
hidden hands to a Lord across reversed seats. Every setup uses the existing
Keep / Stockpile / Summoning Circle / Siege Engine / Bastion loadout: the first
three begin commissioned, with Engine and Bastion built later. There is no
loadout sweep, hand preparation, opponent-policy comparison or weight tuning.

CPython 3.12.14 ran eight worker processes. The first 162 games completed in
202.76 seconds; the 648-game extension plus cached-record verification and
aggregation took 1,022.82 seconds. Analysis and extra replays overlapped the
extension. These timings include policy, diagnostics and persistence, and are
not a new isolated PyPy throughput measurement.

| Measurement | Result |
| --- | ---: |
| Complete games | 810 |
| Ordered matchups / games each | 81 / 10 |
| Rounds / explicit operations | 14,434 / 363,970 |
| Planning decisions | 28,868 |
| Mean / median rounds | 17.82 / 18 |
| Round range | 8–28 |
| Final Collapse / Dominion / Ritual endings | 506 / 160 / 144 |
| Monster summons | 28,050 |
| Ordinary powers / Breach Wishes selected | 23 of 23 / 5 of 5 |
| Monster types selected | 10 of 10 |
| Maximum assembled plans / authoritative previews per decision | 26 / 1 |

The 16 generated / four retained candidates per source and 32 plans / eight
previews limits held. Unknown legality, opportunity or effects remain unknown;
selected counts are not measurements of strategic benefit. This is Python
behavior evidence. It does not broaden the existing Windows/native parity gate
or establish Lord balance or policy strength.

## Priority 1: make paid Rites reachable

Invocation was generated **13,776 times and selected zero times**. Its intrinsic
score is 22; payment costs at least 11 face-value points, charged at two score
points each. Every candidate therefore has a score of zero or less. Assembly
only adds positive-value Rites and never anchors a plan on a Rite. Invocation
never reaches the whole-plan settlement evaluation, even when its extra Tear
could end the game.

The public-board audit found 536 decisions in 296 games where an Invocation-only
scenario wins and the chosen plan's scenario does not. These are possible wins
under the existing scenario model, not 536 proven mistakes: future enemy orders,
Soul gains and precedence can change settlement.

Six reproducibly selected examples from games lost by the relevant seat were
replayed through settlement, changing only that seat's plan and preserving the
recorded opponent order. Three became immediate wins; three did not. Every
replayed planning observation exactly matched the saved policy input, and every
alternative passed authority's legality preview. The unsuccessful examples are
retained to show why a projected win is not a guarantee.

A separate concrete example is `deimos_valak_00`, Valak at round 17. The original
trajectory loses to Deimos by Final Collapse in round 19. A legal Invocation
using the same visible hand wins Dominion in round 17 against that round's
recorded opposing order. This is a directed diagnostic, not an estimated win-rate gain.

Next implementation: give a bounded set of paid-Rite alternatives a route into
complete-plan evaluation before filtering them by immediate material value.
Add win, hold and adverse-settlement examples. Keep the candidate/preview caps
and the shared-Veil uncertainty rule; do not solve this by globally increasing
the Tear weight or treating the public scenario as a guaranteed terminal result.

## Priority 2: evaluate powers in their complete plan

| Decision | Observed result | Public-board conflict signal |
| --- | --- | --- |
| Projection | 779 casts; 111 whiffs | 201 plans forecast their own attack clearing every visible Guard in Projection's zone first |
| Consume | 1,950 declarations; 352 fizzles; 108 outcomes still unobserved at match end | 480 plans forecast their own attack clearing the target's entire visible Guard zone |
| Ravenous | 7,356 enemy and 4,809 friendly units consumed | 559 of 689 casts accompany recruitment into the same lane |

The forecast columns identify risk, not certain failure: new enemy Guards and
Ward can preserve targets. The counts overlap, so they must not be added to the
actual fizzle/whiff totals. Friendly casualties also need material and Hunger
context rather than a blanket prohibition.

Original-input replays of three named games reproduced their final state digests.
They confirm these exact cases:

- `deimos_valak_00`, round 9: Valak's Hunt kills all three Lord-zone Guards;
  Projection subsequently spends five Essence and hits nothing. Round 4 has the
  same problem after Siege, wasting three Essence.
- `gremory_kroni_00`, round 6: Kroni's Siege kills the same Vulture selected for
  Consume. Consume fizzles at the next round start.
- `kroni_kroni_00`, seat 1, round 2: Ward recruits and summons Kurchin in the
  same lane as Ravenous. That actor consumes nine friendly and five enemy units.
  This is an example to score with context, not evidence that every Ravenous cast
  is harmful.

Next implementation: adjust the bounded assembled plan for known own attack
results, power timing and new friendly recruitment. Preserve uncertainty about
opposing orders and spatial paths. There is no need for full-game candidate
rollouts or a combinatorial search.

## Castle destruction under the revised rules

Across all 810 games there were **4,656 `CASTLE_DESTROYED` events (5.75/game)**
and **350 additional Wish-Price ruins (0.43/game)**. These are event counts;
Deimos reconstruction can permit another loss of the same structure.

For exact timing and causes, one recorded seed for each ordered matchup was
replayed: 81 games, with all 81 final digests matching. These contained 511 loss
events affecting 510 distinct per-game castles. Of those events, 255 came from
Siege, 114 from artillery, 70 from Hunt, 52 from breaches, and 20 from Wish Prices.
Thus 439/511, approximately 86%, came from Siege/Hunt/artillery rather than
breaches or Prices.

| Timing or end-state measurement | 81-game sample |
| --- | ---: |
| Games with any castle lost | 80 |
| First loss, median / mean among those 80 | Round 1 / 2.96 |
| First-loss range | Rounds 1–17 |
| Games with first loss in round 1 | 52 / 81 |
| First round-1 loss: Summoning Circle / Keep | 27 / 25 |
| Commissioned surviving castles at the finish, both players combined | Mean 3.72 |
| Operational surviving castles at the finish, both players combined | Mean 3.00 |
| Games with at least one player losing all five castles | 31 / 81 |

Ruins later consumed by ProfaneRuins remain `profaned` rows. They are counted as
lost, not as survivors or additional destruction events. Construction is also
separated from commissioned survivors; every final classification reconciles to
ten starting structures.

Castles are falling regularly, and the first loss is often very early. The
opening loadout matters: no active Bastion screens other castles yet, and the
Summoning Circle starts at 14 Integrity after its opening summon payment. The
Keep's 17 Integrity can likewise be lost during a strong Hunt. These are game
rounds, not rounds of sustained attack on one fully guarded castle; they do not
replace the controlled 3–5-round pressure fixtures.

There is no identical-policy, matched-seed pre-tuning control here, so the pass
cannot assign a speed-up factor specifically to 21 → 17 Integrity or the other
rule changes. The next useful doctrine check is opening defense against strong
Hunt/Siege and selective Work/Guard allocation. Further durability reductions
should wait for that distinction.

## Full-roster follow-up

All nine Lords are active in the survey. The following are targeted follow-ups,
not an instruction to make all powers equally frequent or to specialize before
the shared fixes.

| Lord | Ordinary selections | Next question |
| --- | --- | --- |
| Gremory | Predator 1,213; Ruin 468 | Does delayed Ruin duplicate this round's damage or spend cards needed for defense? |
| Deimos | War Machine 1,375; Rout 745 | Measure incremental artillery and useful retreat, alongside opening infrastructure survival. |
| Humbaba | Muster 1,585; Breath 789 | Attribute actual regeneration/speed benefit; current power diagnostics do not measure it. |
| Kalligan | Inferno 1,079; Pyroclasm 1,105 | Separate friendly/enemy hazard exposure and relocation value; activation alone is not useful damage. |
| Orias | Web 1,107; Snare 1,090 | Measure actual denied Guard placements and the Threat tradeoff. |
| Odradek | Shift 772; False Orders 201; Redirect 9; Inversion 6 | Test resource-saving alternatives and lane value before assuming rare powers should fire more. |
| Kroni | Consume 1,950; Ravenous 689 | Fix delayed-target conflicts and account for new friendly recruits in the same plan. |
| Valak | Gravity 785; Projection 779 | Remove avoidable Projection overlap and price Essence defense and friendly exposure. |
| Kanifous | Death 1,806; Power 653; Resurrection 385; Longevity 40; Wealth 33 | Compare useful outcomes and Prices; rarity alone is not a bug. |

Inversion had 1,732 generated positive opportunities; 1,645 were assessed with
resource shortfall. That supports testing a resource horizon, but does not prove
saving to four is stronger than taking a valuable Allegiance Shift at three.
Redirect's nine selections likewise need lane-value cases rather than forced use.

Kopita was summoned **523 times**; the initial five-game sample understated its
activity. All ten recipes are exercised. Ward accounts for 18,171/28,868 decisions
(62.9%), Siege 26.6%, and Hunt 8.6%. Investigate recruitment/monster value against
pressure and defense with controlled policy comparisons. Extend actual monster
benefit attribution before treating summon frequency as balance evidence.

## Reuse

`run_u13_doctrine_survey.py` saves every game's explicit operations, complete
policy-visible planning observations, decisions, diagnostics and final digest in
an atomic compressed record. Resume verifies source/configuration identities and
record hashes. Raising repeats from two to ten preserves the original 162 cases.
Failures are recorded and are not counted as completed games.

The following Git Bash command updates the performance checkout without starting
another campaign; Git will stop if switching would overwrite local changes:

```bash
cd "C:/Users/jerem/OneDrive/Documents/Corruptor-U13-Perf" &&
git fetch origin u13-basic-doctrine &&
git switch --detach origin/u13-basic-doctrine
```

For a future local survey, select a new output directory:

```bash
"C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe" \
  Scripts/Sim/run_u13_doctrine_survey.py \
  --output "C:/Users/jerem/Downloads/Corruptor/Doctrine-Survey-next" \
  --repeats 2 --workers 8
```

`audit_u13_doctrine_survey.py` reconstructs the public-board diagnostics and a
bounded set of counterfactual round replays. `audit_u13_castle_pace.py` replays
one complete ordered-matchup spread for exact castle events and final statuses.
Three focused survey tests verify coverage/seed pairing, resume corruption
rejection and failed-game accounting. No production rules, balance weights,
shipping Godot policy, UI, U12 or assets changed.
