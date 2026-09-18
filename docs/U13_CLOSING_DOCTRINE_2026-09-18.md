# U13 common doctrine V5: bounded closing preference

> **Windows accepted at clean `725be5e`:** [Uploaded evidence](evidence/U13_CLOSING_WINDOWS_2026-09-18.json) passed 92 tests each under CPython 3.14.7 and PyPy 7.3.23. Complete semantic reports and explicit inputs match for five games / 85 rounds / 2,142 operations, and agree with the independent local check. This accepts the default greedy policy on the combined Penitent/range/monster revision; it does not broaden native Godot parity or the earlier campaign scope.

The experimental Python policy is `U13_COMMON_SMART_CORE_ALPHA_V5_CLOSING`.
It gives selected closing plans priority over ordinary material scores, while
retaining the existing credit for uncertain closing chances. Softmax stays off
for this comparison. This is a doctrine experiment, not a Godot shipping-policy
port or a balance change.

## Decision rule

The existing public paid-choice scenario includes own Rite payments, resource
costs, own Resummon and known round pressure. It evaluates Ritual, Final Collapse
and Dominion in the authority's precedence order. Its current-board winner is
not a prediction of all simultaneous orders.

For a projected own win, the new evaluator checks five fixed resource shocks:
one enemy Tear; a single-castle Siege reward of three Souls and one neutral Tear;
a Hunt reward of two Souls and one neutral Tear with own banishment and a lost
Soul; and each combat shock combined with one enemy Tear. Against Orias at own
Threat two or higher, a sixth check includes a possible Mark reward. These are
explicit hypothetical resource changes, not validated opposing plans, likelihoods
or upper bounds on every possible round. They do not read the opponent's hand,
sealed orders, future random events or simulation seed.

A plan that still wins every check is called `resilient` in diagnostics. A plan
using Profane remains conditional because its target must survive to resolution.
Resilient plans receive an increment larger than the current complete-score
span, placing them above ordinary plans without depending on a fixed material
weight scale. Their relative material ranking is retained. The resulting scores
stay ordered for the existing greedy/optional-softmax selector.

Fragile projections keep V4's 70-point win credit. The checks do not prohibit
them or reduce that credit: a possible enemy resource gain does not establish
the enemy's hidden order. All candidates still pass the same authority preview.
The proposal, complete-plan and preview caps remain 16 / four per category,
32 complete plans and eight previews. Closing evaluation adds at most six tiny
settlement evaluations per unique plan, without full-round rollouts or additional
plan generation.

Each decision records unique plan counts, resilient/fragile counts, selected
check outcomes, interrupted/adverse scenarios, base score, win credit and
priority increment. These are separate from the older per-Rite counts, which
include repeated assembled plans before deduplication. Actual round outcomes
remain separate measurements.

## Scope and known limits

The checks do not resolve enemy Resummon, additional paid Tears, multiple castle
losses, ordinary combat, public scheduled effects, Vacant Throne, Lord powers,
Marching or random reactions. The one-Tear and ordinary-reward checks are useful
sensitivity probes, not an exhaustive adversarial search. Passing them does not
prove a win; failing them does not prove a loss. No blanket Hunt/Veil veto is
introduced. In particular, the historical false-positive projections remain
regressions to measure, rather than being relabeled as guarantees.

## Validation and comparison

On the comparison authority at `b56c83a`, the local CPython 3.12.14 check passed **92 tests**, plus six separate
comparison/evidence tests. Five bounded games completed **84 rounds / 2,123
operations**, with no invalid operations or rejected previews. The later Windows acceptance covers the published combination described below.

The final comparison completed **162/162 games**, covering all 81 ordered Lord
matchups with each policy assigned to each seat once. It used one fixed loadout,
one seed repetition and the namespace below. Reversed Lord orders share seeds:
there are 45 seed clusters, not 162 independent samples.

| Measure | Frozen V4 | Candidate V5 |
|---|---:|---:|
| Wins | 80 | 82 |
| Planning decisions | 2,926 | 2,926 |
| Invocation selected / resolved | 14 / 14 | 21 / 21 |
| Maximum complete plans / previews | 30 / 1 | 30 / 1 |

There were **zero failures, censored games or rejected previews**. One matched
setup (`gremory_kanifous_00`) was swept by V5; the other 80 split, and none were
swept by V4. The small 82–80 difference is not established strength or Lord
balance evidence.

All **37 selected resilient projections** ended in an own win that round.
Seventeen selected fragile projections produced 13 own wins and four enemy wins.
These are observed associations, not 37 additional wins caused by this change,
and the checks remain non-exhaustive. Six decisions still had a public win
scenario available but chose a nonwinning scenario.

### Directed regressions on the previous rules

Before integrating the parallel range/monster update, the original operations
and final digests were independently reproduced for the saved cases. After
integration, the final candidate was rerun against a frozen Python authority
from `773615f`, preserving those exact historical inputs and digests. The seven
older paid-opening cases also restore their original opening from `ad53086`.
These results are separate from the current-rules campaign above.

Of 21 previously skipped public-scenario closing plans, 19 actually won against
the recorded opposing order and two lost. The final candidate chose 12
round-ending wins at those positions versus one for V4: **11 additional
same-round wins in this directed set**. Seven retrospective opportunities remain
unselected. These are correlated positions, sometimes from the same game, not
21 independent match results or a win-rate estimate.

All seven earlier paid-opening counterexamples retain V4's actual same-round
outcomes: two own wins, two enemy wins and three continuations. This includes the
known enemy Ritual and Collapse reversals; the new diagnostics expose their
fragility without promoting them to the resilient tier. Recorded opposing plans
are used only for replay, after the candidate selects from its public observation.

### Rejected conservative prototype

An initial version also removed the 70-point credit whenever a hypothetical
shock flipped a projected win. Its 162-game comparison split 81–81, with one
sweep by each policy. In `kanifous_valak_00`, it declined a real round-22 Collapse
win because a possible enemy Soul gain could reverse it, then lost round 23.
That penalty was removed. The final full comparison above uses the same seeds
and restores the successful closing choice. This is why fragile opportunities
remain available with their prior credit.

The [compact evidence](evidence/U13_CLOSING_DOCTRINE_LOCAL_2026-09-18.json)
records exact source hashes, the frozen policy identity, both comparison
summaries and directed results. The accompanying archive retains all final
operations/decision records, gate inputs, old-rule counterfactuals and the
prototype's decisive pair. Source changes were tested above `b56c83a`; that base
commit alone does not contain this policy. No throughput claim is drawn from
these verification runs.

### Subsequent integration: Penitent ranged block

Before publication, the parallel update `55d34fd` added the seeded Penitent
ranged block. The doctrine was rebased onto it without changing the policy.
The combined local gate passed **92 tests and five games / 85 rounds / 2,142
operations**, without invalid operations or rejected previews. Its engine
fingerprint is
`132b2742ffa6d273e1eb98ce94b1972dda2d35d25309c1a0fa4c19645dd4d40e`;
the doctrine harness fingerprint remains
`681c20309055be8e1568630a951776d0788ec1be69b0e1bb846f38d17a020fd8`.

This checks compatibility on the published combination. The 162-game comparison
above predates the Penitent block; its win totals are not a measurement of that
later ruleset. The archive includes both bounded checks, and the existing Windows
wrapper subsequently accepted the combined revision at clean `725be5e`: all
92 tests per runtime passed, and the complete semantic reports and inputs matched both
each other and this independent local check. This remains separate from native
Godot parity acceptance.

## Reproduction

The matched comparison freezes the whole V4 policy package at
`773615f81c99a46a3acd17574e2480c8b7d22431`. Both policies use the shared authority
from the parallel lane/monster update `b56c83a42e2fc1970d7badf261888e09db875c61`,
including its ranged and Sooge changes. That commit's existing Linux diagnostic
parity evidence does not become Windows 4.7.2 acceptance through this campaign.

```bash
python Scripts/Sim/compare_u13_doctrines.py \
  --baseline 773615f81c99a46a3acd17574e2480c8b7d22431 \
  --output verification/closing-comparison --repeats 1 --workers 8 \
  --namespace u13-closing-v5-2026-09-18
```

No repeat campaign is needed to inspect the retained results. The Windows
dual-runtime check remains the small common-doctrine wrapper:

```bash
bash Scripts/Sim/run_u13_common_doctrine.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

Power/plan coordination and Odradek's resource horizon remain the next competence
targets. Additional closing sensitivity or balance tuning needs its own measured
reason; this pass does not authorize a broader planner search or another rules
overhaul.
