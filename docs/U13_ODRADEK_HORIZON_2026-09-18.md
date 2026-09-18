# U13 common doctrine V7: Odradek saving and lane value

This continues the completed [V6 power coordination](U13_POWER_COORDINATION_2026-09-18.md)
at `0ed7d08`, on the newer Wright/field-combat rules at `435cbf4`.
The experimental Python planner now compares spending Reconfiguration with
retaining it for a visible Allegiance Shift or Inversion opportunity.
The native shipping bot, UI, assets, and shared material weights are unchanged.

## Decision contract

The old Odradek module suppressed cheap powers below a fixed three/four-point
reserve. A visible Marcher cluster took precedence over saving a fourth point.
The new module keeps the ordinary immediate values and prices saving inside
each complete plan instead:

- Consider only Shift/Inversion targets already generated within the existing
  power-proposal budget, including proposals rejected for resource shortfall.
- Value the best remaining opportunity, not the sum of mutually exclusive
  future casts. Look ahead at most two further one-point incomes.
- Use integer credit `net_material_value * 3^(missing_points+1) //
  4^(missing_points+1)`. The first discount reflects uncertainty; each missing
  point discounts another wait. These are explicit initial planning preferences,
  not learned weights, probabilities, or a prediction that Odradek survives.
- Remove future credit when the source is already banished, no target remains,
  the goal is beyond that horizon, or the paid-choice scenario settles now.
  A ready worthwhile power can beat saving, so reaching four does not itself
  create a reason to hoard indefinitely.
- Evaluate Inversion room after own Guard deployment and target survival after
  own attacks. False Orders' future targets use its planned lane change.
  Remove current False Orders credit if the own attack kills its specific Guard.
- Apply Redirects before Shifts, as authority does; targets moved out of a
  Shift circle cannot retain their capture credit. Already captured bodies
  cannot also count as a future Shift opportunity.
- Redirect earns pressure credit only for reducing the larger of the two
  visible lane deficits (enemy bodies minus friendly bodies). Merely moving an
  entire crowd from one lane to the other earns no such benefit. This is a
  bounded body-count estimate, not travel, casualty, castle-defense, or full
  lane-value prediction.

Up to four of the existing 32 plan slots compare a candidate with its
Reconfiguration spending omitted. This rebuilds declarations and all other
score terms. The limits remain 16 generated/four retained per category,
32 complete plans, and eight authority previews. No extra rollouts or hidden
information enter the policy. Greedy remains the default; no hard power veto
or equal-use requirement was added.

Enemy orders, source survival, artillery, pending effects, intervening spatial
movement, and later deployments can invalidate the public scenario. Inversion's
Neutral Tear is not treated as a guaranteed immediate closing reward. Diagnostics
separate a retained saving goal from a declared power and its actual resolution.

## Integration repair

The first full-game check exposed a Python-only crash introduced by tower
attackers: Gremory's Picking the Bones reaction directly indexed attacker
`suit`, which fortifications lack. The Python reaction now uses the same
optional lookup as `U13Gremory.gd`. A regression verifies that a tower kill
neither earns nor consumes the Vulture reward, and that a later Vulture kill
still earns it. Both policies in the comparisons use this same repaired engine.
This is not a new gameplay/balance rule or a new broad native parity claim.

## Validation and comparison

The first local candidate passed 119 tests and five games (83 rounds / 2,087
operations), then completed 34 matched games at 15-19 against frozen V6. It
selected Redirect 47 times and Shift 59 times versus V6's one and 76. Inspecting
that behavior exposed credit for moving intact crowds without reducing peak
lane pressure. Its raw records and exact prototype source hash are retained;
it was not accepted as a strength improvement.

After the directed Redirect correction, the **same 34 setups/seeds** completed
**556 rounds, zero failures, and zero rejected previews**. V7 and frozen V6
finished **17-17**: one sweep each and 15 split pairs. This is a development
comparison on reused seeds, not an independent strength/balance evaluation.

| Observed Odradek behavior | Frozen V6 | V7 |
| --- | ---: | ---: |
| Shift casts / affected Marchers | 74 / 690 | 73 / 696 |
| False Orders declarations | 20 | 19 |
| False Orders resolutions / fizzles | 10 / 8 | 13 / 2 |
| False Orders unobserved at game end | 2 | 4 |
| Redirect casts / moved Marchers | 1 / 2 | 6 / 46 |
| Inversion casts | 0 | 0 |

The candidate retained a Shift saving goal in 130 decisions and an Inversion
goal in one. Of the 127 Shift goals with a following decision, 75 could then be
afforded and 66 were cast. These counts do not establish causal benefit: the
old policy could also save, repeated goals are correlated, and targets change.
The Inversion saving decision occurred at two points in a game's final round,
so no following decision was observed.

A directed authority test separately demonstrates the favorable three-point
case: save instead of taking one Marcher, receive the fourth point, cast
Inversion, transfer three real Guards, and receive the next normal income.
Other tests preserve a valuable immediate Shift and useful cheap Redirect,
prevent ready-power hoarding, account for own attacks/deployments, respect
Redirect-before-Shift timing, bound the horizon, and verify determinism,
legality and unchanged authority during planning. Neither natural-game
Inversion reachability nor a better win rate has been established by this pilot.

The comparison has 17 ordered Odradek matchups, both policy assignments,
nine unordered seed clusters, one seed per cluster and one fixed loadout.
Maximum candidate work was 32 complete plans and one authoritative preview;
all generation and retention limits held. Both prototypes and the final pilot
use `435cbf4`'s engine plus the tower-reaction repair above. They predate the
concurrent friendly-passage/oscillation fix at `66ea09e`.

After integrating the friendly-passage fix, local CPython 3.12.14 passed
**120 tests and five games / 88 rounds / 2,220 operations**, with
zero failures or rejected previews, at `78719b9`. The policy hash is
identical to the final pilot; the engine hash differs as expected. The
34-game results are not attributed to the later movement rules.

The published implementation is `21dcc2b`. Its complete Git tree matches the
tested local commit `78719b9` exactly; only commit metadata changed when
publishing through the authenticated GitHub app. The reports retain the
original tested revision.

[Compact source and validation evidence](evidence/U13_ODRADEK_HORIZON_LOCAL_2026-09-18.json)
links the final checkpoint to the raw report archive.

## Windows acceptance

**Accepted at clean `f6f63be` on 2026-09-18.** The uploaded
`u13-common-doctrine-TtaoIX-2026-09-18_09-31-43-Zq3PUJ.zip` contains
**120 passing tests per runtime**, Windows CPython 3.14.7 and PyPy 7.3.23
(Python 3.11.15). Each completed the same five games, **88 rounds / 2,220
operations**, with zero failures or rejected previews. All decisions, final
states, diagnostics and complete input streams match; the runner exited zero
and its tracked worktree diff is empty.

An independent check recomputed report integrity and the engine, doctrine and
runner source fingerprints against the published checkout, checked the logs
and work limits, and matched the complete semantics and inputs to the saved
local CPython run at `78719b9`. No games needed to be rerun for this evidence
review. See [Windows acceptance evidence](evidence/U13_ODRADEK_HORIZON_WINDOWS_2026-09-18.json)
for the archive hash, runtime identities and per-game results.

This accepts the experimental Python doctrine on the integrated movement
rules. Greedy remains the default. The earlier 34-game pilot still predates
`66ea09e`; this check adds no native Godot parity or policy-strength/balance
claim. The later Kopita/Muno/Dotra update at `4651b01` postdates this ZIP and
is outside this acceptance. The bounded Windows gate at `f6f63be` is complete.
The command below is retained for reproduction:

```bash
git pull --ff-only origin u13-basic-doctrine
bash Scripts/Sim/run_u13_common_doctrine.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

The focused comparison can be reproduced with the published code and the
frozen V6 policy from `435cbf4`:

```bash
python Scripts/Sim/compare_u13_doctrines.py \
  --baseline 435cbf4 --lord Odradek --repeats 1 --workers 6 \
  --namespace u13-odradek-v7-2026-09-18 --output odradek-comparison
```

The next step is to review the recorded behavior and directed cases before
choosing further doctrine changes. Inversion frequency is not itself a tuning
target, and the small pilot does not establish balance.
