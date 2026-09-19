# Deimos Rout: the answer available in the current plan

**V12 remains the default.** The available-plan Rout candidate was initially
promising, but the fresh comparison after merging the parallel monster-control
fixes does not support adoption. Commit `2b99c7f` restores the exact V12 policy
implementation and keeps reviewed replay expectations for the combined engine.

| Same-engine experiment | Candidate revision | Runtime | Games / rounds / operations | V13–V12 |
| --- | --- | --- | --- | --- |
| Rules through `3360d6c` | `fd13b3f` | CPython 3.12.14 | 34 / 644 / 16,220 | 19–15 |
| Rules through `bcf1fad` | `8263515` | PyPy 7.3.20 | 34 / 644 / 16,240 | 15–19 |

Both cohorts use the same seeds and policy-seat assignments, with one seed per
ordered matchup. Each comparison freezes V12 on the same engine as V13; they
are separate, correlated experiments and should not be pooled into a strength
claim. All games complete with zero caps, failures or rejected previews and
within the unchanged budgets. The V12 package digest is identical in both.

On the combined engine, none of the sixteen non-mirror Deimos setups improves:
seven wins under V13 versus eight under V12, one lost setup and fifteen unchanged.
The lost setup is Gremory/Deimos with Deimos in seat 1. **V12 wins both mirror
policy assignments in both cohorts.** The new paired results are zero V13
sweeps, two V12 sweeps and fifteen splits. This is enough to reject promotion,
not to establish general Lord balance or a precise strength difference.

The experiment and its seven directed tests remain in Git at `fd13b3f` and
`8263515`. The active policy is `U13_COMMON_SMART_CORE_ALPHA_V12_HUMBABA_PRESSURE`;
the candidate scoring module and tests are removed from the active package.
Diagnostic tools remain and default to the frozen candidate revision explicitly.
Windows acceptance of the combined revision remains pending.

## Combined-engine replay review

The parallel `bcf1fad` change repairs taunted movement and the Python contact
snapshot update. The original prefixes and opposing orders of all thirteen
saved doctrine replay cases are retained. Two observations change:

- `deimos_deimos_current_r16_s0`: changed marcher survivors and positions;
  the artillery retarget, original fizzle, preserved commitment and positive
  revised Siege-damage assertions remain intact.
- `deimos_deimos_00_r10_s0`: both V12 and V13 now select the same Castle plan.
  V13 scores Castle 160 and Lord 96 after considering the changed survivors.
  Three legal continuations compare Castle, Lord and holding, with the recorded
  opposing order and frozen V12 afterward. Castle saves two allied Castle bodies
  and seven HP immediately. After round 12, its Keep has eight Integrity versus
  four when routing Lord; holding also leaves eight. No branch finishes by
  round 13, so this establishes a local tradeoff rather than a full-game win.

Fixture histories preserve the prior views and the earlier V13 Lord-lane plan.
The current expectation is Castle. No tactical assertion was removed to refresh
a fingerprint. The initial diagnostic capture deliberately records digest
mismatches and a lane mismatch; it is not a passing acceptance gate.
Corpus-level source fields retain their historical collection identity; each
changed case's `monster_control_review` pins the newer engine and review.

## Candidate mechanics (historical experiment)

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

The candidate itself changes no game rules, movement engine, Lord powers,
balance weights, native bots or lane-sandbox behavior. The parallel changes
merged at `8263515` are preserved separately. Rout still retreats its snapshot
cohort this round, halves its speed next round, and becomes ready in round N+4.
Monster specials are not silenced. Existing own-artillery coordination remains.

## First-engine observations and full-game behavior

Nine fresh frozen-V12 source games use the `3360d6c` navigation engine and the
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

On the later combined-engine cohort, V12 makes 344 Deimos decisions, with Rout
ready 116 times, cast 84 and held 32. V13 makes 342 decisions, ready 126 times,
cast 75 and held 51. More conservation accompanies worse matched results.

## First-engine controlled hold/cast results

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

## First-engine historical lane-choice review

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

## Published source identities

Shell Git credentials were unavailable, so publication uses the connected
GitHub app. Commit metadata changes; each published source tree is verified
identical to its local experiment or gate tree. Historical reports retain their
original local IDs. Use these published revisions in a fresh checkout:

| Purpose | Local tested revision | Published equivalent |
| --- | --- | --- |
| V13 candidate | `fd13b3f` | `63d8f8582bb4ec4ce5099ac04cd0c549b8c8b1e4` |
| Diagnostic tools / first engine | `2e1353d` | `9a8e42f1ee651b3a96a6aa35e00ec61ba867f087` |
| First-engine V13 gate | `82000ee` | `3c49df2352da991d13b93234d270607a88dd7679` |
| Combined-engine V13 comparison | `8263515` | `0a843d33fdde388f2344631b4b894c8d54092982` |
| Restored-V12 dual-runtime gate | `2b99c7f` | `60d72a86caaed02b728316e10af1735f384c5934` |

The compact evidence and archive include the full local-to-published tree map.
The shared branch's final checkpoint adds publication documentation and points
`audit_u13_rout_answers.py` at the published candidate by default.

## Source and reproduction

The first experiment's policies share source identity
`e093e1fd92bd619129cc56a7483056335b951d837d91fa4bc5e61014d892bd61`.
This differs from the earlier integration digest because source identity also
includes Godot scripts, including the sandbox lookahead additions at `3360d6c`.
The Python engine and V12 policy files are unchanged between `e5ef031` and
`3360d6c`. The pre-navigation experiment at `2099326` remains historical.

From a separate checkout of published `63d8f85` (the exact `fd13b3f` tree),
reproduce the matched pilot with:

```bash
python Scripts/Sim/compare_u13_doctrines.py --baseline 3360d6c \
  --output rout-v13-comparison --namespace u13-rout-answer-2026-09-19 \
  --lord Deimos --repeats 1 --workers 6
```

Use the diagnostic tools at published `9a8e42f` (local `2e1353d`), which still
has that engine, and fresh
output directories for the original controlled experiment. Collection freezes
V12 even though that checkout contains V13:

```bash
python Scripts/Sim/audit_u13_rout_timing.py collect --baseline 3360d6c \
  --output rout-current-v12 --workers 4
python Scripts/Sim/audit_u13_rout_answers.py assess --candidate 63d8f85 \
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

No additional native gate is requested by this doctrine experiment. The
parallel monster-control change has its own native evidence in
[the monster audit](U13_MONSTER_BALANCE_AUDIT_2026-09-19.md).

To reproduce the combined-engine candidate comparison, use a separate checkout
of published `0a843d3` (the exact `8263515` tree), which contains V13 and the
`bcf1fad` engine:

```bash
python Scripts/Sim/compare_u13_doctrines.py --baseline bcf1fad \
  --output rout-v13-monster-comparison --namespace u13-rout-answer-2026-09-19 \
  --lord Deimos --repeats 1 --workers 6
```

That engine identity is
`168615d04ff50b7ba9cb4111a749508eebe451d41d0535b98d0fd3efea9c44cf`.
Running the same comparison at the final restored-V12 checkout would compare
V12 against V12; the historical candidate revision is required.

## Local validation and next step

The historical V13 gate at `82000ee` passed 175 CPython tests and five games /
93 rounds / 2,338 operations, with semantic SHA-256
`e30e7a46cae47cfaf615899faa06d4b3b6622dae362ca6f2108fa4fb359b092c`.
This is evidence for the first engine only.

At `2b99c7f`, restored V12 passes **168 tests per runtime** under local Linux
CPython 3.12.14 and PyPy 7.3.20 / Python 3.11.13. Both complete the same five
games: **85 rounds / 2,144 operations**, zero failures or rejected previews.
The strict report comparison matches every decision, final state and diagnostic;
recorded input files are byte-identical and each operation digest is verified.
All thirteen fixture prefixes and recorded opposing plans match the shared
baseline. Policy implementation files match V12 byte-for-byte.

The combined gate's semantic SHA-256 is
`00051204261597a4ff0489de8bf3f2e463c083438d1a2db61a081b9df88b727c`;
input-file SHA-256 is
`32ac308c89533bf4bc0bc0b45ec8a0fe1b71698eefe4c098faf82d84e9cce66b`.
Both reports also match engine, harness and runner identities. Subsequent
checkpoint changes are documentation, evidence and the diagnostic candidate
default pointing to its published equivalent; the tested engine, policy, harness
and gate runner remain unchanged. This local acceptance
does not substitute for the user's Windows gate or the separate native evidence.

See the [compact evidence](evidence/U13_ROUT_ANSWER_2026-09-19.json) and delivered
`Corruptor-Rout-Answer-Evidence-2026-09-19.zip` for both engine cohorts, controls,
reviewed replay data and runtime reports.

Next: accept the combined V12 revision under Windows CPython/PyPy. A further
Rout pass should investigate the mirror losses and lost Gremory setup, actual
contact timing and special-heavy fights before proposing another heuristic.
The initial outmatched-wave loss remains scoped to its original engine.
Do not tune merely to cast less or impose an emergency-only rule. Shared
navigation/playback and unit balance remain separate work.
