# U13 PySim — swappable doctrine and early performance gates

**Current implementation:** [the first complete-game gate](U13_PYSIM_FULL_MATCH_2026-09-15.md)
now supplies a four-Lord ordinary setup-to-victory path and a real match timing
harness. Its reference policy is injected separately and receives a detached own-hand/public-board
observation. The full experimental legal-choice/RNG/counter/sweep interface below
remains future work. Windows 4.7.2 acceptance is pending; the earlier partial and
isolated timings below retain their dated scopes.

The first local complete-game measurements are in seconds, well above the
proposed 50 ms target. Transaction and retained event-history copying dominate
those profiles. Preserve that exact reference while addressing the measured
cost; the earlier partial timings cannot establish the full-match budget.

User steering on 2026-09-15: the simulator should shorten the experiment loop,
including quickly identifying inert doctrine terms. Do not hard-code the
current BasicDoctrine into Python rules or require each experimental policy to
be ported to Godot. Do not assume planning parity establishes full-match speed.

## Rules and policies have different contracts

The existing Python engine takes explicit operations through `apply(operation)`.
Its Development replay and timing harness use explicit fixture inputs and import
no BasicDoctrine. Keep this boundary as the full-match harness grows.

| Layer | Required contract |
| --- | --- |
| Rules engine | Same setup, seed and explicit decisions produce exact matching Godot state, event order and outcomes. Keep digest/field parity; no tolerances or approximations to gain speed. |
| Experimental Python policy | Selected by the harness, with an injected decision/scoring function and versioned configuration or weight vector. It must obey rules and information boundaries. A Godot counterpart is unnecessary. |
| Shipping doctrine | The selected production policy must also reproduce Godot decisions on shared observation/legal-choice fixtures, including tie-breaking and policy RNG. Port and verify the selected policy when preparing it to ship. |
| Experiment harness | Schedules seeds/seats/matchups, loads policies/configurations, captures explicit decisions and measures results independently of the rules implementation. |

The complete experiment interface is a **future implementation requirement**.
The current adapter already accepts a replaceable policy and weights through
`next_operation`; the legal-choice and policy-RNG surfaces still need to be built.
The complete interface's input must
contain the acting player's permitted observations, legal choices and a separate
deterministic policy RNG key. It must never receive the authoritative parity
trace, an opponent's hand or unrevealed simultaneous order. Deployed Guards and
intact pairs are public, as already accepted. The policy returns a choice; the
engine validates and resolves it. Scoring cannot mutate authority.

A harness run must record rules/source identity, seed/setup, each seat's policy
ID and code/configuration hash, and policy RNG identity. Distinguish experiment
provenance from rules identity: replaying recorded decisions does not require
reproducing the policy that originally selected them. Keep the existing broad
source fingerprint honest; changing an experimental configuration is not a
reason to rewrite the rules engine or its accepted corpus.

Before weight sweeps, add per-term exposure, eligibility, selection and actual
resolution/effect counters. A branch firing zero times cannot be judged from
win rate. Keep the denominator and matchup/seat context. Use matched seeds and
crossed seats for comparisons, report uncertainty and distinguish exploratory
weight searches from held-out evaluation. These are harness responsibilities,
not mechanics changes or a request for another campaign now.

## Measure before assuming the experiment budget

The [Development implementation](U13_PYSIM_DEVELOPMENT_2026-09-15.md) introduces
a separate Python-only partial timing probe. It excludes input selection,
export and parity comparisons, but retains actual engine copying and events.
The accepted Windows `108fc15` run measured 31.35 ms mean, 26.65 ms median and
52.74 ms p95 for opening through the first Development, across 270 cycles on
one CPython 3.14.7 worker. Its full report is retained in the
[accepted evidence](evidence/U13_PYSIM_DEVELOPMENT_108fc15.json). The earlier local
Linux mean was 37.59 ms; this comparison changes runtime and hardware, so it
does not measure an optimization. Neither run answers the cost of a complete
round or match.

For scale, 50,000 matches in one hour requires 13.89 aggregate matches/second.
On one worker that allows **72 ms per complete match**; twelve hours allows
864 ms. These are arithmetic budgets, not measured capacities. Multi-worker
scaling must be measured on the target hardware, not multiplied by the CPU
count. The partial result consumes a substantial part of the single-worker
hourly budget before combat, Marching or later rounds have run.

A bounded local `cProfile` diagnostic identified recursive `deepcopy` and the
planning adapter's `snapshot()` calls as the dominant cumulative cost. That
profile included fixture preparation and warmup; its instrumented duration is
not a throughput measurement. It identifies copying as the first optimization
candidate, with transaction rollback and exact snapshots retained as gates.

The [copying pass](U13_PYSIM_COPYING_2026-09-15.md) implements that optimization
and passed Windows Godot 4.7.2 acceptance at clean `88ef438`. On the same Windows
Python executable/hardware, sequential baseline/current/current/baseline blocks
measured **20.31 ms versus 7.98 ms** mean partial-cycle time: **2.54× throughput,
60.71% less wall time**, with identical exact results. This is the matched
optimization comparison; the older 31.35 ms observation is not its denominator.
The earlier local Linux diagnostic measured 36.02 ms versus 10.08 ms (3.57×).
The comparison uses unchanged timing/fixture source and records separate
instrumented profiles. It remains a partial-engine measurement and does not
satisfy the later full-match throughput gate. Full-match speed remains unknown.
Ordinary resolution
is now implemented in a separate [nine-hook adapter](U13_PYSIM_RESOLUTION_2026-09-15.md),
with focused Windows 4.7.2 acceptance passed at clean `e51588d` and no new
throughput claim. The early spatial spike now has Windows acceptance as scoped below.

Additional user steering: consider parallel arrays before writing the tick loop,
preserve Godot's explicit contact ordering, and establish the first complete-game
reference before trusting an optimized path. Inspect `U13MarchingBuffer` and
measure candidate layouts, including conversion cost; flat Python arrays are not
an assumed speedup. The current contact selector first uses stable ID order and
earliest arrival, then keyed `CONTACT_TIE` selection. Match that sequence and
capture tick/field/event differences, including registry-order permutations.

The [isolated Marching spike](U13_PYSIM_MARCHING_2026-09-15.md) now uses flat
parallel Python lists, with exact contact-order/registry-permutation coverage.
Windows Godot 4.7.2 acceptance passed at clean `e8cc3f9`: all 5,600 tick frames
across 28 phases and the batch projection retaining every non-tick event and
final field matched, with 394 Godot checks, 46 Python tests and 14 corruption
rejections. Independent replay reproduced the complete uploaded summary.
On one Linux CPython 3.12.14 worker, the earlier diagnostic batch phase times
were **30.22 ms ordinary, 106.19 ms dense and 6.80 ms Gravity**. The Gravity case
consumes 13 of 14 units; this is not a representative game workload distribution.
Movement and nearby searches dominate the separate instrumented profile. Import
and publication are measured against owned row dictionaries, but no competing
row tick kernel exists, so no array-loop speedup is established. The exact trace
path remains the reference for the mode that omits visual tick records.

On the user's Windows CPython 3.14.7 machine, 20 samples per case measured
**57.73 ms ordinary, 130.52 ms dense and 6.37 ms Gravity** mean batch phase time.
Ordinary median/p95 were 60.11 / 76.82 ms; dense were 96.78 / 210.33 ms.
Preserve this observed variability rather than presenting a guaranteed rate.
The Windows profiles also identify movement/nearby searches as dominant.
CPU samples in this report occur in 15.625 ms increments; zero short boundary
samples do not mean zero cost. The [accepted evidence](evidence/U13_PYSIM_MARCHING_e8cc3f9.json)
retains all wall/CPU distributions, profiles, layout costs and output hashes.
The Linux/Windows difference changes hardware and Python, so it does not measure
an optimization or regression. The gate establishes correctness at this scope
and records performance; it is not a passed full-match speed target.

Ordinary and dense phase means exceed the suggested 50 ms whole-match target in
this Windows run.
The nine-hook full-game adapter has not advanced, and full-game speed and
50,000-game wall time remain unknown. Use this measured cost to guide algorithm
work while completing the first legitimate full-game reference.

The 7.98 ms Windows and 10.08 ms Linux figures measured the same six-hook slice
on different runtime/hardware. They show neither free extra hooks nor 42 ms
remaining in a demonstrated 50 ms full-match budget. A match has many rounds and
changing board sizes; the 50 ms suggestion remains an unmeasured target. The
early spatial spike can inform implementation while the first legitimate full
game is being completed; it cannot substitute for that game's exact reference.

Apply these gates before committing to the rest of the performance plan:

1. **Profile the implemented slice before extending its hot path.** Separate
   transaction/snapshot copying, entity lookup, rule execution and event growth.
   Optimize measured costs with unchanged exact fixtures and rejection rollback.
   Do not copy the diagnostic export/comparison loop into the production batch
   loop. Avoid a speculative rewrite or removing correctness gates.
2. **Spatial gate completed at `e8cc3f9`.** The isolated ordinary,
   dense/contact-heavy and Gravity phase probes have Windows exact evidence,
   conversion costs and CPU/wall distributions. Use the measured search costs
   to guide optimization against the retained exact traces while integrating
   the remaining round lifecycle. This gate measures isolated phases, not
   complete rounds, matches or balance; a documentation update needs no rerun.
3. **Measure the first supported complete-match path promptly.** Once a legitimate
   setup-to-victory Python path exists, measure fresh matches with recorded legal
   decisions and then include policy cost separately. Record rounds, unit/contact
   peaks, termination and CPU/wall distributions. No fixture mutation may bridge
   missing rules in something labeled a full match. Keep conclusions limited to
   the supported path until Lord and dense-board coverage is representative.
4. **Set a real sweep budget.** Compare one versus several workers on the same
   seeds/hardware, separating startup, policy evaluation, simulation and report
   costs. Decide whether 50,000-game experiments fit the measured iteration budget
   before building the large sweep harness. If not, profile the bottleneck and
   revise the implementation or budget; do not weaken exact rules parity.

The approximately 50–100 full reference games remain the later cross-engine
correctness gate before trusting balance results. Full parity, Common Smart
Core plus Lord doctrines, serious balance and roguelite work retain their
dependency order. **Performance investigation starts during parity work**, not
only after every spatial mechanic has been ported.
