# Optional doctrine plan selection

> Windows accepted at clean `ba35bd6`: [uploaded evidence](evidence/U13_PLAN_SELECTION_WINDOWS_2026-09-18.json) passed all 83 tests under CPython 3.14.7 and PyPy 7.3.23, including the fixed softmax vectors. Both runtimes produced identical reports and inputs for five default games / 94 rounds / 2,361 operations. Complete semantics also match the independent local report. No repeat of this gate is needed.

`PlanSelector` adds a replaceable final selection step to the experimental Python
common doctrine. Temperature zero retains existing best-legal-plan behavior,
including tie order and the first-legal preview fast path. Softmax is opt-in.
No weights, rules, Godot bot, U12, assets or difficulty presets change.

## Selection contract

- Complete-plan generation, scoring and deterministic ranking remain in
  `common.py`. A selector receives this ranking and the existing legality callback
  and work budget; it receives no match object or private simulation seed.
- `SelectionSettings` contains `temperature`, `max_score_gap` and `policy_seed`.
  Temperature and gap are finite, nonnegative numbers in current score units.
  Both default to zero. Positive temperature requires an explicit policy seed.
- Greedy mode returns the first legal plan and performs no random draw. Its policy
  ID remains `U13_COMMON_SMART_CORE_ALPHA_V4_RITE_PLANS` because its decisions are
  unchanged. Reports additionally identify the selector version and settings.
- Softmax finds the best legal plan, then previews lower-ranked alternatives
  within `max_score_gap` of its score. Invalid alternatives never enter the pool.
  The existing eight-preview cap covers all admission work, including failures.
  A cap can truncate the pool; that is recorded, and the best admitted plan remains
  available. No extra allowance or exhaustive legality search is introduced.
- Sampling uses `exp((score - best_legal_score) / temperature)` over that admitted
  pool. Subtracting the maximum avoids overflow; probabilities are model-score
  weights, not estimates of winning. A zero gap permits only ties. A one-plan
  pool performs no random draw.
- A SHA-256 domain key combines selector version, explicit policy seed, public
  round/seat and admitted plan identities/scores. Its top 53 bits supply the draw.
  Repeated observations/configurations produce the same choice regardless of
  interleaved calls or worker scheduling. No global or simulation RNG advances.
  The harness must supply an independent policy seed, never expose its private
  simulation seed for this purpose.
- Softmax policy IDs distinguish temperature/gap and selector version. Seeds
  distinguish repetitions and are recorded separately, rather than creating a
  new policy identity for every seed.

Each decision records mode/settings, admitted plan hashes/scores/ranks, selected
rank, score gap from the best admitted plan, truncation, draw and draw-key hash.
The passive observer aggregates ranks, lower-score choices and draws, and retains
selection details in its bounded examples. Unmeasured historical selection gaps
remain null. Full campaign traces already retain every decision.

Stockpile/Slaver choices remain deterministic. There are no difficulty presets,
new search depths or win-preference changes. Uncertain public-board settlement
projections remain uncertain; this feature adds no hard veto or guaranteed-win
claim. The separately identified settlement-scoring misses remain the next task.

## Verification

All results below are local Linux CPython 3.12.14 diagnostics:

- **83 tests passed**, including nine selector tests for legality/score bounds,
  preview limits, deterministic ties, stable weights, invalid settings, private
  state isolation, observer measurements and fixed draw/choice vectors.
- All **2,916 saved V4 decisions** from the prior 162-game comparison reproduced
  exactly after removing only the new selection diagnostic. These pointwise
  checks reused each public observation and its recorded first-legal preview
  outcome; they do not repeat authority legality validation.
- The default five-game check did validate real admission and reproduced all
  **2,361 operations / 94 rounds**, final state hashes and prior diagnostic fields
  from accepted V4. Only the new selector metadata differs.
- A separate opt-in smoke configuration (`temperature=2`, `max_score_gap=10`,
  seed `selector-smoke-2026-09-18`) completed five games / 83 rounds / 2,082
  operations. All 166 decisions were admitted, with zero rejected previews or
  invalid operations. It made 116 draws, chose a lower-scoring plan 11 times,
  and never exceeded five previews or a selected score gap of five. These values
  exercise the feature; they are not a calibrated difficulty recommendation.

The tested modified worktree was based on `5e93ce0`. Engine fingerprint
`2b235e1b6107cb15ac3ff4c2c93d5ade7c3ab4de0e695171e6bf501d5e11ff9c` is unchanged
from that accepted Windows run. Selector harness fingerprint is
`a94e0716449f5605bd619492b857e6b5d0d6ee84601bea6c0d35ab1571596bac`.
[Compact evidence](evidence/U13_PLAN_SELECTION_LOCAL_2026-09-18.json) records exact
identities, game hashes, configuration, counters and the saved-decision check.

The parallel lane-sandbox commit `a591f76` was preserved before publication. Its
three added GDScript files change the broad engine fingerprint to
`c1b7d0c67b26e5ff156fa732f2bf3ea1be8e57681ec06ec6a24c6905cc489edb`. Excluding
only those additions reproduces the tested fingerprint exactly. Existing native
rules, Python authority and the tested selector harness are unchanged; the compact
evidence records the full path list and identity reconciliation.

Windows CPython/PyPy accepted the selector scaffold and default behavior at clean
`ba35bd6`, as recorded above. The complete games used temperature zero; full-game
positive-temperature Windows acceptance remains unmeasured. Fixed positive-
temperature unit vectors passed on both runtimes. The earlier uploaded
[V4 Windows gate](evidence/U13_RITE_PLANS_WINDOWS_2026-09-18.json) passed separately
at clean `5e93ce0`: 74 tests per runtime, five games / 94 rounds / 2,361 operations,
identical complete semantic reports and inputs, and zero failures. Its semantics
also exactly match the independently generated local V4 report. That upload is
the Python doctrine gate and does not claim another native Godot parity run.

The latest five-game validation pass measured 218.73 seconds for CPython and
162.09 seconds for PyPy in planning plus simulation: 1.35x observed throughput,
approximately 26% less time. These exclude other runner overhead and are not a
controlled warmed campaign benchmark. Variation from the earlier pass does not
establish a performance regression or a cost attributable to the selector.

## Use

The ordinary runner and all existing survey/comparison commands continue to use
greedy selection. No retuning or repeat matchup campaign is needed for this hook.
The usual Windows wrapper now runs 83 tests and the same five default games per
runtime; the fixed selector vectors are included in both test runs.

For a future Python experiment, inject a selector explicitly:

```python
from u13_doctrine.common import CommonSmartCore
from u13_doctrine.selection import PlanSelector, SelectionSettings

policy = CommonSmartCore(selector=PlanSelector(SelectionSettings(
    temperature=2, max_score_gap=10, policy_seed="my-independent-policy-seed")))
```

The bounded probe also accepts a JSON file with these three fields:

```bash
python Scripts/Sim/run_u13_common_doctrine.py check \
  --selection selector.json --report verification/selector-check.json
```

This optional path records settings and the distinct policy ID in its input and
result reports. To accept full softmax behavior across runtimes, run the same
configuration through both executables and compare their reports; the ordinary
wrapper's complete games intentionally remain greedy. Establish strong shared
judgment first, then calibrate temperatures/gaps against the finalized score
scale and evaluate coherent weaker play.
