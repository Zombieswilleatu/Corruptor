# U13 PySim — swappable doctrine and early performance gates

**Current implementation:** [the first complete-game gate](U13_PYSIM_FULL_MATCH_2026-09-15.md)
now supplies a four-Lord ordinary setup-to-victory path and a real match timing
harness. Its reference policy is injected separately and receives a detached own-hand/public-board
observation. The full experimental legal-choice/RNG/counter/sweep interface below
remains future work. Windows 4.7.2 acceptance passed at clean `d059b95`; the earlier partial and
isolated timings below retain their dated scopes.

The accepted Windows CPython complete-game means are 11.34 and 19.07 seconds.
The subsequent [PyPy 7.3.23 replay and timing](U13_PYSIM_PYPY_2026-09-15.md)
passed at the same `d059b95` source/input fingerprints and measured 3.73 / 6.53
seconds, an observed 2.96× gain across the two means. The proposed 50 ms target
remains unmet. Transaction and retained event-history copying still dominate
the separate profiles. Preserve both runtime references while addressing that
cost; earlier partial timings cannot establish the full-match budget.

The [full-match rollback copying pass](U13_PYSIM_FULL_MATCH_COPYING_2026-09-15.md)
now implements sharing for unchanged history/presentation with conservative
fallback and live-state escape protection. All 63 local tests/exact replay pass;
the matched Linux CPython diagnostic measured 4.57×. Windows CPython/PyPy
acceptance and the sustained comparison remain pending.

## First complete-game profile and next optimization

The [Windows CPython evidence](evidence/U13_PYSIM_FULL_MATCH_d059b95.json) supports the
central diagnosis in the user's supplied profile review: `PlanningMatch.apply()`
calls `snapshot()` before every operation, copying the complete growing state and
retained semantic event history even when little game work follows. The 13- and
17-round cases make 334 and 433 operations; transaction snapshots account for
18.47 / 24.81 and 31.01 / 40.84 profiled seconds. `copy_data` including its nested
work accounts for 76% and 78%; `_clone` exclusive time is 62% and 63%.

There are **20 production hooks per round**, not 24. The 25 timing buckets include
setup, Stockpile, Slaver, submission and next-round operations as well as those
hooks. These are instrumented per-match totals, not uninstrumented per-call
timings. An empty power slot does not establish that a hook is mutation-free:
the implementation still advances clocks/ledgers, reconciles Guard pairs, checks
Kalligan's Defunct episodes, clears Sigils and records Lord presence. Do not skip
transactions merely because a hook's main effect is absent.

The copier is already a specialized plain-data copier. Its memo preserves
**shared container identity** as well as cycles; accepted tests explicitly require
that two aliases remain aliases inside a detached copy. Acyclic data can still
contain aliases. `id()` itself occupies about 3% of either profile, so its call
count does not establish that removing memoization will yield a several-fold
speedup. Benchmark any copier specialization and preserve its ownership contract.

The implemented first optimization reduces the amount copied: transaction
rollback is separate from public snapshots, and audited hooks share unchanged
history/presentation in their backups. Live-state access upgrades the active
backup and keeps later transactions conservative; custom match handlers also
use full copies. Preserve rollback after rejected and exceptional handlers,
including nested world/presentation/history mutations, and keep returned
snapshots and event views detached. Retain the accepted `d059b95` reference and
complete the focused before/after comparison under both runtimes.

Marching integration itself accounts for about 19–20% of these profiles; it is a
secondary target that may matter more after copying is reduced. Adding cumulative
times for nested functions double-counts work, while adding only their exclusive
times misses callees. These profiles do not establish that Marching costs only 5%
or that its final throughput is sufficient.

The 15.21-second mean implies about 237 repetitions per hour on one worker by
simple arithmetic. Multiplying that fixed-input mean into a 50,000-game duration
is not a measured nine-Lord doctrine capacity estimate. A matched pure-match
Godot/Python comparison must use the same explicit games, rules, hardware and
event retention, with policy selection, replay, export and comparison outside
both timers. Optimize and measure this supported path before extending the port;
do not replace exact parity with approximations to meet a speculative budget.

## PyPy runtime candidate

**Measured and replay-verified on Windows at `d059b95`.** The user supplied
56 passing unit tests under PyPy 7.3.23 / Python 3.11.15, then the
[runtime archive](evidence/U13_PYSIM_PYPY_d059b95.json). Its entire verifier
summary matches the accepted CPython summary, including two complete games,
30 rounds / 767 operations, all semantic rows/views and 13 corruption rejections.
The existing Godot 4.7.2 stream was reused. Source/input fingerprints and final
digests are unchanged; no code optimization is included in this comparison.

PyPy's ten samples per game average 3.73 / 6.53 seconds, versus CPython's earlier
three-sample means of 11.34 / 19.07. The equal-weight mean falls 15.21 → 5.13
seconds: an observed 2.96× gain and 66.27% less wall time. These separate runtime
runs were not interleaved; the CPython short case has substantial variability.
See the [complete comparison and raw-sample interpretation](U13_PYSIM_PYPY_2026-09-15.md).

The shorter PyPy case declines over early samples: first-five mean 3.84 seconds,
last-five 3.61. The longer case's corresponding means are 6.55 / 6.51 seconds.
This is consistent with warmup but does not isolate its cause. Retain all ten
samples; one explicit warmup is not proof of steady state. Cold-start cost,
memory use and runtime/JIT environment options were not recorded.

Copying remains dominant in the separate PyPy profiles (59% / 71% cumulative
for `copy_data`), supporting the existing transaction/history optimization
priority. Those fractions are instrumented observations, not unprofiled timing
fractions. Keep profiling outside comparisons: PyPy's
[performance guidance](https://pypy.org/performance.html) warns about distortion.

Preserve both accepted runtime results when measuring code changes. Record
warmup/cold-start behavior and memory before later worker-scaling claims.
PyPy is an explicit verified option for the supported path; the default
interpreter and unsupported mechanics boundary are unchanged.

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
