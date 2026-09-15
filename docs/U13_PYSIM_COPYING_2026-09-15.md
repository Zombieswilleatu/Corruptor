# U13 PySim — reduce copying overhead without changing rules

**Windows Godot 4.7.2 acceptance passed** at clean revision
`88ef43870e736bd0a1ad5df5ee06d714367276c3`. The matched Windows comparison
measured **20.31 ms before and 7.98 ms after**, or **2.54× throughput / 60.71%
less wall time**, for opening through first Development. Full-match speed remains
unknown. See the [accepted evidence](evidence/U13_PYSIM_COPYING_88ef438.json).

Implemented after the accepted Development checkpoint, based on
`1fc29d78b1650084f3d462883ffdfbd144c76de4`. The earlier Windows Development gate
at `108fc15` and its 31.35 ms partial timing baseline keep their original identity;
the optimization ratio uses the matched comparison, not that earlier run.

## What changed

Profiling the accepted Python adapter found that it copied the complete state
twice for each hook, copied the world for submission previews, then copied it
again inside Development's enclosing transaction. Generic `copy.deepcopy`
also performed Python object-copy dispatch on every scalar in these plain-data
graphs. This copying dominated the implemented slice.

The optimization makes four bounded changes:

1. `copying.copy_data` clones built-in dictionaries and lists and reuses immutable
   scalars. It preserves exact float bits, integer/bool types, order and internal
   aliases with a memo. Every mutable container is detached from the input.
   This is a copier for already-admitted data, not a normalizer, serializer,
   projection or replacement for validation. The module-level recursive helper
   avoids creating a recursive closure that would retain copied graphs until
   cyclic garbage collection.
2. Each `apply` still creates one complete rollback state and backs up the clock.
   Hook rejection reuses that backup instead of taking a second snapshot.
   Unsupported boundaries and unexpected exceptions also restore the backup.
3. Submission preview runs the same validation as lock, with reservation disabled.
   Checks retain their order; all ledger writes, card commitments and events occur
   after validation at lock. Preview no longer copies a world or constructs
   throwaway reservation events.
4. Development mutates its owned world within the match transaction. The standalone
   `deploy` component remains a pure transform with its own detached world. A
   second-player failure still rolls back first-player placement and hook clocks.

Opening presentation copies, complete exported snapshots and economy event
payload/view copies use the plain-data copier. Event history and private views
remain complete; the presentation baseline stays independent of later state.
Godot mechanics, exporters, trace schemas, accepted fixtures, numeric comparison,
RNG, legality, rules identity and implementation boundaries are unchanged.
The original Python planning adapter still stops before Development; the
Development adapter still stops before artillery.

One full transaction backup per operation remains. Its cost still grows with
world/history size. This pass does not establish the cost of a populated late
round, remove history, or claim a final representation for spatial simulation.

## Same-machine comparison

`benchmark-copying` loads the Python package from the pinned accepted commit
`1fc29d7` into a temporary directory. It does not switch or modify the user's
checkout. Each worker uses the same Python executable, and the harness verifies
that `benchmark_development.py` and `development_fixtures.py` are byte-identical
after line-ending normalization in both implementations.

The blocks run sequentially: **baseline, current, current, baseline**. Each block
has nine warmups and 15 measured cycles per setup across nine Lord cases. This
gives 270 measured cycles and 18 warmups per implementation. Input generation,
process startup, git extraction, export and exact-result hashing are outside the
measured intervals. All inputs and all 90 opening/operation results and snapshots
produce identical exact hashes in both implementations. No policy is embedded
in either engine.

Accepted Windows 11 AMD64, CPython 3.14.7, one worker:

| Phase | Accepted baseline mean | Optimized mean |
| --- | --- | --- |
| Opening | 1.92 ms | 1.66 ms |
| Upkeep and choices | 11.10 ms | 4.39 ms |
| Submission and lock | 4.26 ms | 1.19 ms |
| Development | 3.03 ms | 0.74 ms |
| Entire partial cycle | **20.31 ms** | **7.98 ms** |

That is **2.54× the measured throughput, or 60.71% less wall time**. Each
implementation ran 270 measured cycles and 18 warmups on the same Windows
machine. All four timing workers and both separate profiling workers agreed on
the exact inputs and results. Independent inspection verified the source hashes,
unchanged timing/fixture sources, block counts and weighted aggregate arithmetic.
The [accepted record](evidence/U13_PYSIM_COPYING_88ef438.json) retains every block
and profile; the profile durations are excluded from the speed comparison.

Earlier local Linux x86_64 diagnostic, CPython 3.12.14, one worker:

| Phase | Accepted baseline mean | Optimized mean |
| --- | --- | --- |
| Opening | 2.80 ms | 2.23 ms |
| Upkeep and choices | 19.97 ms | 5.48 ms |
| Submission and lock | 7.81 ms | 1.42 ms |
| Development | 5.44 ms | 0.95 ms |
| Entire partial cycle | **36.02 ms** | **10.08 ms** |

That is **3.57× the measured throughput, or 72.02% less wall time** for this
slice. These numbers compare both versions on the same local runtime/hardware;
they do not compare Linux performance with the user's earlier Windows result.
The raw [comparison and separate profiles](evidence/U13_PYSIM_COPYING_LOCAL.json)
pin both source fingerprints. The optimized source fingerprint is
`88547dc7c9c86c9265ca4a4a50007af1ab319c081492ef0186be7516e097b859`;
the record describes pre-commit changes based on `1fc29d7`.

Block medians and p95 values are preserved individually; combined means are
weighted by cycle count. The harness does not average percentiles or report an
invented combined p95. Separate instrumented profiles include preparation and
warmup and are explicitly excluded from the throughput comparison. In that
profile, complete snapshot calls fell from 360 to 216 for the same operation
sequence. Use uninstrumented wall time for the performance result.

**Full-round and full-match speed remain unknown.** No artillery, combat,
Marching, late Lord effects, victory or doctrine evaluation runs in the timing
slice. The report leaves full-match games/second and 50,000-match duration null.
The [policy/performance gates](U13_PYSIM_POLICY_AND_PERFORMANCE_2026-09-15.md)
still require an early spatial spike and the first supported full-match timing.

## Correctness gate

The focused gate combines the existing planning and Development fixtures because
both use the optimized transaction path:

- 27 Python tests: the existing 20 plus seven ownership/rollback regressions.
- 429 planning Godot checks and 497 Development Godot checks.
- 321 complete match snapshots and 303 exact game operations, including the
  planning corpus's 140 rejected operations.
- 21 economy and 217 Guard/Work component operations, plus 52 standalone cursor
  operations, with their original isolated-fixture scope.
- 25 deliberate evidence corruptions, all rejected by the unchanged comparators.

New regressions cover float/type/alias preservation, read-only previews, failed
second-player lock and deployment, nested world/presentation/event rollback,
clock rollback after an exception, and snapshot/player-view independence after
later mutations. These checks supplement complete differential snapshots;
they do not substitute for Godot parity. Local 4.5.1 is diagnostic only.

All checks above passed on Windows Godot 4.7.2 at clean `88ef438`, with zero
failures or script errors. Independent Python replay of both uploaded exact
exports reproduced the complete Windows verifier summaries, including all 25
rejected evidence corruptions, without a diagnostic override. This replay uses
the uploaded Windows reference; it does not claim a local Godot 4.7.2 run.

The earlier local checks also passed. The
[diagnostic parity record](evidence/U13_PYSIM_COPYING_PARITY_LOCAL.json) retains
both complete verifier summaries and exact export hashes at the same optimized
source fingerprint as the timing report. No Godot source or fixture was edited.

## Windows acceptance

Accepted archive:
`u13-pysim-copying-8WDQ0g-2026-09-15_00-05-58-kwtTlA.zip`.

- SHA-256: `82a081475ea1e806f2aa60b91349cf6ee8bd62711d27e9ae7c3957dc7bcb6c3e`.
- Source revision: `88ef43870e736bd0a1ad5df5ee06d714367276c3`.
- Source fingerprint: `88547dc7c9c86c9265ca4a4a50007af1ab319c081492ef0186be7516e097b859`.
- Runtime: `4.7.2.stable.official.ed1daf0bf`, Windows; Python 3.14.7.
- Empty working diff, exit status 0, 16 unique archive members and valid CRCs.
- 926 Godot checks, 27 Python tests, 321 complete snapshots and all 25 corruption
  probes passed. Scope remains the existing planning and Development suites.

The [acceptance record](evidence/U13_PYSIM_COPYING_88ef438.json) preserves both
verifier summaries, trace identities, case coverage, independent replay result,
full timing/profile report and the SHA-256/size of every archive member.

The copying gate re-exports both existing short suites at the new source identity,
then measures baseline and optimized code on the same Windows machine. The
baseline is a pinned ancestor already available after pulling. No dependencies
beyond Git, Python 3.10+ and the acceptance Godot runtime are needed. The command
below is retained for reproduction; this documentation update needs no rerun.

```bash
cd /c/Users/jerem/OneDrive/Documents/Corruptor-U13-Perf &&
git pull --ff-only origin u13-basic-doctrine &&
bash Scripts/Sim/run_u13_pysim_copying.sh \
  'C:/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
```

Each stage has the existing 180-second watchdog and heartbeat. Comparison child
processes have a 120-second timeout. One `u13-pysim-copying-*.zip` in Downloads
contains both Godot exports, parity summaries, unit log, source/runtime identity,
working diff and `copying-comparison.json` with separate profiles. No 100-game
campaign is part of this gate. Preserve the exact 4.7.2 acceptance requirement.

Next, continue ordinary resolution with artillery/commitment/
combat interfaces, then run the early Marching performance spike before finishing
the spatial/Lord-effect port. Common Smart Core, Lord doctrines, serious balance
and roguelite work retain their later positions in the roadmap.
