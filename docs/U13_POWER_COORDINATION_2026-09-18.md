# U13 common doctrine V6: powers evaluated within the plan

The [behavior survey](U13_DOCTRINE_SURVEY_2026-09-17.md) found Projection spending
Essence after its own attack cleared its targets, Consume targeting a Guard its
own attack killed first, and Ravenous accompanying large friendly recruitment.
`U13_COMMON_SMART_CORE_ALPHA_V6_COORDINATION` evaluates those interactions when
scoring a complete plan. It follows the accepted V5 checkpoint at `0353ffe`.

This is an experimental Python policy change. U12, the game rules, native
shipping policy, UI and assets are unchanged. The roadmap and existing Lord
timing implementations supplied the scope; no balance values were changed.

## Decisions and limits

`coordination.py` builds a small public-board scenario. Valak and Kroni keep
their own adjustments in their separate Lord files:

- **Projection:** use the Guards expected to remain after the selected attack,
  including strict defeat equality, stable slot order, Penitent screens and
  Supplicants reserved for Rites. Keep the Essence charge when no affordable
  target remains. If only a weaker target survives, reduce its material credit.
- **Consume:** track the actual selected Guard ID, even if other Guards remain
  in the zone. Remove its benefit credit when the own-attack scenario kills it
  before next round's meal. Do not pretend that a replacement Guard is the meal.
- **Ravenous:** apply its existing nine-point body-count heuristic after adding
  ordinary recruits and monster bodies in its lane, and removing Supplicants
  spent on attacks or Rites. Include earlier own spawn powers. Varn and Wish
  Power use their minimum counts; future random rolls remain unknown. These are
  lane exposure estimates, not predicted casualties or future Hunger gains.

When a supported power is retained, reserve up to four of the existing 32
complete-plan slots for alternatives with the penalized powers omitted. These
keep the rest of that candidate's choices and rebuild the shared payment and
declaration ledger. No Cartesian products, extra previews or candidate rollouts
are introduced. Equal score and equal card count prefer fewer declared powers,
then the existing deterministic plan fingerprint.

The limits remain 16 generated / four retained proposals per category, 32
complete plans and eight authoritative previews. Closing judgment still runs
after these material adjustments. Default selection is greedy; opt-in softmax
can still admit penalized powers. There is no hard power veto.

Reports distinguish assessed and adjusted candidates, omission alternatives,
selected exposure and omitted powers. Existing observers still measure actual
resolutions, fizzles, Essence use and friendly/enemy consumption independently.
An omission label describes candidate construction, not proof of causal benefit.

## Local evidence

[Compact evidence](evidence/U13_POWER_COORDINATION_LOCAL_2026-09-18.json) records
source hashes and the raw archive identity. The engine hash is unchanged:
`132b2742ffa6d273e1eb98ce94b1972dda2d35d25309c1a0fa4c19645dd4d40e`.

Local CPython 3.12.14 passed **103 tests**, including 11 new coordination
regressions. The five usual behavior games completed **86 rounds / 2,168
operations** with no invalid operations or rejected previews. Tests include
actual attack-to-Projection execution, stable Guard order, shared Supplicant
spending, useful powers remaining selectable, declaration reindexing, softmax
admission and unchanged authority during planning.

The focused comparison ran **36/36 games** on one shared engine against the
entire frozen V5 policy package from `0353ffe`. Kroni and Valak each occupied
Lord seat zero against all nine Lords; each setup was repeated with policy
seats swapped. This gives 18 matched policy pairs, 17 unordered seed clusters,
one loadout and one seed repetition. It is not full Lord-seat coverage.

All games completed: **643 rounds, zero failures, zero rejected previews**.
V6 and V5 each won **18**: three V6 sweeps, three V5 sweeps and 12 splits.
These counts do not establish a strength or balance improvement.

| Observed power use | Frozen V5 | V6 |
| --- | ---: | ---: |
| Projection selections / resolutions | 51 | 42 |
| Projection whiffs | 7 | 0 |
| Guards removed by Projection | 44 | 42 |
| Essence spent on Projection | 162 | 147 |
| Consume declarations | 119 | 113 |
| Consume resolutions | 89 | 107 |
| Consume fizzles | 25 | 1 |
| Consume outcomes unobserved at game end | 5 | 5 |
| Ravenous casts | 45 | 37 |
| Ravenous enemy / friendly consumption | 435 / 306 | 391 / 239 |

V6 retained 17 Ravenous selections with a negative recruitment adjustment:
friendly exposure is a tradeoff, not a ban. Lower total friendly consumption
also accompanies fewer casts; it does not measure the value of the foregone
enemy casualties. Different decisions lead to different subsequent boards.

## Directed replay tradeoffs

Six positions from two pilot games were replayed after exactly reproducing the
original permitted observation and the frozen V5 decision. V6 decided from that
observation and a legality-only preview. Only afterward did the replay install
the recorded opposing order. All six games remained in progress at the tested
boundary; these are not additional match wins.

- `valak_gremory_00__candidate_p1`, round 5: V6 changes Siege to Hunt while
  retaining Projection. Its Projection removes a Guard; V5's whiffs.
- The same game, round 7: V6 omits Projection and avoids its three-Essence cost.
  V5's Projection actually removes a Guard after the opposing orders resolve.
  This is a real opportunity cost, demonstrating the scenario's uncertainty.
- `kroni_gremory_00__candidate_p1`, rounds 6 and 7: V6 changes its attack lane
  while retaining Consume. Both meals resolve; both original meals fizzle.
- The same game, rounds 5 and 13: V6 omits Ravenous alongside Ward. The original
  actors consume 11 enemy / nine friendly and 14 enemy / ten friendly bodies.
  Those positive raw enemy-minus-friendly totals are preserved in the report;
  avoiding these actors is not automatically a better outcome.

Enemy Guards/Ward, scheduled effects, artillery, other powers, spatial paths
and reactions can change these projections. Other interactions, including
delayed Ruin and Odradek Guard reconfiguration, are not evaluated in this pass.
The next planned target is Odradek's resource horizon.

## Windows check

Windows CPython/PyPy acceptance remains pending. On this published checkpoint,
use the existing bounded runner:

```bash
bash Scripts/Sim/run_u13_common_doctrine.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

It runs the tests and five behavior games on both runtimes and packages the
reports in Downloads. This does not invoke a new Godot export or repeat the
36-game pilot. Any later concurrent rules commits require separate attribution.
