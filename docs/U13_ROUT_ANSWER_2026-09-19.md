# Deimos Rout: the answer available in the current plan

The V13 candidate finished **19–15 against frozen V12** in 34 matched games
on the rules at `3360d6c`: 644 rounds and 16,220 operations, with no failures,
round caps or rejected previews. Four policy pairs favored V13 twice, two
favored V12 twice, and eleven split. This is a focused pilot with one seed per
ordered matchup, not an established strength or Lord-balance result.

Excluding the mirror, the same sixteen Deimos/opponent/seat setups produced
nine Deimos wins under V13 and six under V12: four gained, one lost, eleven
unchanged. **V12 won both Deimos-mirror policy assignments.** Preserve that
counterexample when evaluating later changes.

Local candidate implementation: `fd13b3f`. Diagnostic tools: `2e1353d`.
Reviewed replay expectations: `82000ee`. The default Python policy identifies
itself as `U13_COMMON_SMART_CORE_ALPHA_V13_ROUT_ANSWER_EXPERIMENT`.
Local CPython 3.12.14 passed **175 tests and five games / 93 rounds / 2,338
operations**, with no rejected previews. Windows CPython/PyPy acceptance is
still pending. The candidate is retained on this scoped evidence; its name
continues to identify it as an alpha experiment.

## What changes

The standalone Rout proposal retains V12's reachable-fight/gate estimate.
Complete-plan scoring now discounts that credit when the proposed answer has
a substantial material advantage over the visible advancing wave.

- Existing defenders contribute current HP, remaining Armor and an estimate
  of ordinary attack rate. Known Vulture/Butcher damage, Penitent ranged block,
  Tumler evasion and armored Kurchin deflection enter as expected rates, never
  as sampled outcomes. Armor is treated as a consumable pool.
- The actual plan supplies ordinary recruits by suit, committed recipe bodies
  and lane. Varn contributes its guaranteed three bodies. New bodies use the
  public spawn edge and their real readiness round, without keyed placement.
- A fresh recruit can defend if the enemy can reach it, but cannot be credited
  with advancing this round. Reinforcements only reachable next round are
  reported separately and do not erase current pressure. No future draw is
  assumed to supply an answer.
- Hidden, spent, waiting, turret and already-passed allied bodies do not receive
  ordinary defensive credit. War Machine damages castles, so it is not invented
  as an answer to marchers. Unknown breach-wish spawns receive no certain credit.
- At parity or a disadvantage, Rout keeps its old score. With a material edge,
  its score decreases toward zero at twice the opposing force estimate. This
  is a preference, not an emergency-only legality restriction.

The estimate multiplies total durability by aggregate ordinary damage rate.
It is deliberately not a Marching simulation: contact timing, terrain, pathing,
spatial coverage, special powers, opposing recruits/orders and later survival
remain uncertain. A material-edge label does not prove the wave is beaten.
It assesses the generated plan, not every possible use of the hand.

Rout joins the existing power-coordination omission mechanism. Up to four
same-choice omission alternatives are reserved inside the existing limits:
16 generated and four retained proposals per category, 32 complete plans and
eight previews. Greedy remains default. The complete-policy comparison includes
this bounded assembly change; it is not a pure cast-frequency experiment.

No game rules, movement engine, Lord powers, balance weights, native bots or
lane-sandbox behavior change. Rout still retreats its snapshot cohort this
round, halves its speed next round, and becomes ready in round N+4. Monster
specials are not silenced. Existing own-artillery coordination remains active.

## Same observations and full-game behavior

Nine fresh frozen-V12 source games use the current navigation engine and the
historical Rout diagnostic namespace. On their 69 Deimos decisions with Rout
ready, V12 casts 46 times and V13 would cast 35: eleven casts become holds and
no hold becomes a cast. Other choices are identical in 59 of the 69 positions.
All 157 saved non-Deimos decisions select the same plans under both policies.
These are public-view screening comparisons; the six selected interventions
also pass actual engine admission before replay.

| Actual matched-campaign behavior | V12 | V13 |
| --- | ---: | ---: |
| Deimos decisions | 334 | 352 |
| Rout ready | 114 | 138 |
| Rout cast | 81 | 79 |
| Held while ready | 33 | 59 |

Game lengths and opportunities diverge. Neither fewer casts nor more holds is
itself a success criterion. Matched outcomes, controlled preservation, attack
timing and later availability are assessed separately.

## Controlled hold/cast results

The nine source games completed 179 rounds and 4,503 operations. Six selected
positions produced twelve complete continuations: 218 rounds and 5,467
operations including replayed prefixes. All six original-choice controls
reproduce the full source operation stream and final state exactly. All final
plans are legal, with no rejected policy previews or exceeded work budgets.
Other powers' semantic fields and pre-Rout artillery targets/damage match
within each pair.

| Position, Deimos seat | Purpose | Hold result | Cast result | Immediate extra allied HP with cast |
| --- | --- | --- | --- | ---: |
| Deimos/Gremory r2, seat 0 | Conserve an available answer | Win r13 | Loss r18 | 0 |
| Deimos mirror r3, seat 1 | Conserve an available answer | Loss r22 | Loss r22 | 0 |
| Deimos/Gremory r6, seat 0 | Delay an outmatched wave | Win r15 | Loss r18 | 36 |
| Gremory/Deimos r6, seat 1 | Delay an outmatched wave | Win r17 | Win r15 | 40 |
| Deimos mirror r2, seat 0 | Preserve an early hold | Win r22 | Win r18 | 0 |
| Deimos mirror r2, seat 1 | Preserve an early hold | Loss r22 | Loss r16 | 0 |

In both pressure cases, seven extra allied bodies survive the cast round.
The routed cohort's first ordinary attack moves from tick 6 to tick 200 in
the first case, and from tick 7 to tick 256 in the second (200 ticks per round).
Nevertheless, the first case wins only by holding. V13 still chooses to cast
in that position, as V12 does. This is an unresolved tactical miss: useful
delay and greater immediate preservation do not prove that spending Rout is
the best route to victory.

In the first conservation case, holding at round two allows V12 to cast at
round three instead. The earlier cast delays the original cohort's first
ordinary attack, yet costs the eventual win. The second conservation case
changes neither winner nor finishing round. In both early-hold cases, neither
branch has an ordinary attack from the routed cohort within the three observed
rounds; the hold branch casts at round three, while an early cast blocks it.
The winner stays the same, although finishing times change.

These six positions reuse **three** source games; they are not twelve
independent strength comparisons. The two early-hold selections are both seats
of one current-engine mirror. They do not rerun or supersede the two historical
pre-navigation losses from `2099326`. Those earlier counterexamples retain
their original source and engine scope. Monster specials are excluded from
the ordinary-attack timing metric. Later HP/body differences also include
diverging recruits and actions; displacement compares only shared survivors.

## Reviewed historical lane choice

One of the 25 initial lane-support/artillery tests changed its plan fingerprint:
`deimos_deimos_00_r10_s0`. V12 routes Castle; V13 routes Lord because the smaller
Lord wave outmatches its defenders, while the larger Castle wave faces a
stronger allied force. The other 24 tests passed without changed expectations.

Four legal continuations on the same prefix and recorded opposing order compare
V12, the full V13 plan, only changing Rout to Lord, and holding Rout. Frozen V12
responds thereafter. Through rounds 10–12, V13 and the Rout-only variant have
identical checkpoints, separating the lane effect from the changed Work target.

V12 preserves one additional Castle-lane body and five HP immediately. V13 has
six additional allied Lord-lane HP after round 11. Castle integrity is identical
through round 12. None of these continuations has finished by round 13: this
establishes a tradeoff, not a winning continuation. The fixture records the
review, original fingerprint, original inputs and opposing orders alongside
the new expectation. Artillery's 10/12-damage assertions, Keep preservation,
Breath healing/recruit support and Kalligan's friendly-fire assertions remain.

## Source and reproduction

Both policies share source identity
`e093e1fd92bd619129cc56a7483056335b951d837d91fa4bc5e61014d892bd61`.
This differs from the earlier integration digest because source identity also
includes Godot scripts, including the sandbox lookahead additions at `3360d6c`.
The Python engine and V12 policy files are unchanged between `e5ef031` and
`3360d6c`. The pre-navigation experiment at `2099326` remains historical.

From a separate checkout of `fd13b3f`, reproduce the matched pilot with:

```bash
python Scripts/Sim/compare_u13_doctrines.py --baseline 3360d6c \
  --output rout-v13-comparison --namespace u13-rout-answer-2026-09-19 \
  --lord Deimos --repeats 1 --workers 6
```

Use the current diagnostic tools and fresh output directories for the controlled
experiment. Collection freezes V12 even though the checkout contains V13:

```bash
python Scripts/Sim/audit_u13_rout_timing.py collect --baseline 3360d6c \
  --output rout-current-v12 --workers 4
python Scripts/Sim/audit_u13_rout_answers.py assess --candidate fd13b3f \
  --output rout-current-v12
python Scripts/Sim/audit_u13_rout_answers.py replay \
  --output rout-current-v12 --workers 2
python Scripts/Sim/audit_u13_rout_answers.py summary --output rout-current-v12
```

The selected positions are chosen without consulting outcomes. Interventions
change Rout alone, retain ordinary actions and the opposing order, and resequence
declaration identities legally. Original-choice controls must reproduce the
entire source operation stream and final state. The initial collection's generic
`positions.json` is not this experiment's selection; use `positions-answer.json`.

The normal Windows Git Bash gate uses the previously verified installation:

```bash
bash Scripts/Sim/run_u13_common_doctrine.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

No additional native gate is requested for this doctrine-only change. Local
execution uses CPython 3.12.14; no local PyPy result is claimed.

The local gate at `82000ee` has semantic SHA-256
`e30e7a46cae47cfaf615899faa06d4b3b6622dae362ca6f2108fa4fb359b092c`;
its inputs are checked against every recorded decision digest. Later additions
in this checkpoint are documentation/evidence only. See the
[compact evidence](evidence/U13_ROUT_ANSWER_2026-09-19.json) and delivered
`Corruptor-Rout-Answer-Evidence-2026-09-19.zip` for raw records and reports.

Next: accept the combined revision under Windows CPython/PyPy. A further Rout
pass should investigate the mirror weakness, actual contact timing and the
outmatched-wave loss before changing the material margin or adding an
emergency-only rule. Shared navigation/playback and unit balance remain separate.
