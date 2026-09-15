# U13 PySim — swappable doctrine and early performance gates

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

The injected full-game policy interface is a **future implementation requirement**,
not a capability claimed by the current six-hook adapter. Build it when the
public-observation and complete-choice surfaces are available. Its input must
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

The [copying pass](U13_PYSIM_COPYING_2026-09-15.md) implements that optimization.
On the same local Python executable/hardware, sequential baseline/current/current/
baseline blocks measured 36.02 ms versus 10.08 ms mean partial-cycle time, with
identical exact results. Windows acceptance is pending. The comparison uses the
unchanged timing/fixture source and records separate instrumented profiles;
it remains a partial-engine measurement and does not satisfy the later full-match
throughput gate.

Apply these gates before committing to the rest of the performance plan:

1. **Profile the implemented slice before extending its hot path.** Separate
   transaction/snapshot copying, entity lookup, rule execution and event growth.
   Optimize measured costs with unchanged exact fixtures and rejection rollback.
   Do not copy the diagnostic export/comparison loop into the production batch
   loop. Avoid a speculative rewrite or removing correctness gates.
2. **Bring the spatial performance spike forward.** After the necessary ordinary
   resolution interfaces, exercise the first Python Marching kernel on Godot-owned
   ordinary, dense/contact-heavy and spatial-actor inputs. Measure cost per tick
   and round with exact field parity. Run this before completing the full Marching
   and Lord-effect port; it is a decision gate for representation/algorithm work,
   not evidence for complete matches or balance.
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
