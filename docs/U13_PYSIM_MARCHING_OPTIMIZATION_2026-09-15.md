# U13 PySim — focused Marching optimization

Status: implemented; local CPython verification is recorded below. Windows
CPython/PyPy acceptance and target-hardware timing are pending. This follows the
[accepted optimized profile](U13_PYSIM_OPTIMIZED_PROFILE_2026-09-15.md) and compares
against the accepted `c228d85` engine, not the much slower original copying path.

**User direction:** this is likely the last optional optimization pass before
doctrine work. Finish the matched Windows comparison, then move the focus to
CommonSmartCore and Lord doctrine. Do not automatically start another profiling
cycle. The mirror's unsupported rules remain explicit; wider doctrine experiments
still require corresponding rules parity, and these two games establish no balance.

## Changes

1. **Publish/rebuild the ranged registry only for death reactions.** Nonlethal
   damage and cooldowns already live in the owned columns. The next real callback
   receives a fresh snapshot including all accumulated changes. Callback results
   still pass through the original validated registry import; events and public
   results remain detached. Melee reactions and transaction rollback are unchanged.
2. **Replace duplicate touching/nearest scans with an exact nearest search.**
   Each tick sorts the opposing lane/team indices by horizontal position. Search
   starts at the insertion position and visits outward until horizontal distance
   alone proves that every remaining point is farther than the best complete
   two-dimensional distance. Equality must still be visited: the smallest stable
   ID wins a distance tie regardless of traversal order. The selected distance
   also supplies the touching test, removing its separate grid query.

The pre-movement position snapshot, sequential allied blocking, movement rounding,
earliest contact arrival and canonical candidate order for keyed contact selection
are preserved. Contact and ranged-target selection are unchanged, including the
native ranged sentinel at squared distance `640001`. Storage remains parallel
lists. The search can still be quadratic in the worst case, such as a dense
vertical front; this is exact pruning, not an O(n log n) worst-case claim.

Native Godot rules, U12, playable presentation and policy selection are unchanged.

## Verification and local timing

The local run uses CPython 3.12 on Linux against the pinned **Windows Godot 4.7.2
official** evidence. This checks the candidate against that authority; it is not
Windows Python acceptance or a fresh Godot export.

- 67 engine tests and three comparison-prerequisite tests pass. New cases cover
  nearest search against exhaustive two-dimensional selection, equal-distance
  pruning boundaries, sparse retired slots and vertical fronts; nonlethal state
  accumulated before callbacks; detached earlier events; and invalid callback
  registry rejection.
- Exact complete-game replay checks the original `d059b95` stream: two games,
  30 rounds, 767 operations, all semantic rows/views, four terminal rejections,
  eight settlement components and the full-world 200-tick probe. All 13 evidence
  corruption checks remain required.
- Isolated replay checks the original `e8cc3f9` stream: 22 cases, 28 phases,
  5,600 ticks, 33 contact probes and all 14 corruption checks. It also compares
  the batch projection with the complete tick stream.

The [local evidence](evidence/U13_PYSIM_MARCHING_OPTIMIZATION_LOCAL_2026-09-15.json)
retains the source identity, raw samples, both orderings and complete verifier
summaries. Four games per block (16 timed games total) measured **2.745 → 2.182
seconds/game**, or **1.258× throughput**. Both orderings favored the candidate
(1.205× and 1.318×), and every final digest matched. These short Linux blocks are
diagnostic; the Windows runner uses 20 games per block. Windows/PyPy improvement
must be measured independently; no 2–3× claim follows from the local result.

## Windows comparison

From the checkout containing this change:

```bash
bash Scripts/Sim/run_u13_pysim_marching_optimization.sh \
  "$HOME/Downloads/u13-pysim-full-match-5KQlDr/full-match.exact.jsonl" \
  "$HOME/Downloads/u13-pysim-marching-zRzlKJ/marching.exact.json" \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

The first two arguments are the existing accepted export files; change only their
paths if the report folders were moved. An optional fourth argument selects
CPython explicitly. The runner authenticates both streams and reuses them.

Under each runtime it runs the 67 engine tests, three comparison tests and both
exact replay gates. It then measures four separate processes in order:
**control → candidate → candidate → control**, each running 20 alternating
complete games consecutively. That is 80 timed repetitions per runtime, 160
across CPython and PyPy, of the same two accepted games. Initial samples remain
included; each block's first/later halves and both ordering comparisons are
retained. No profiler runs during these samples. Result snapshots/digests remain
outside the timer, using the identical accepted copying-comparison worker.

The control archive must match `c228d85` source fingerprint
`e34ef7c6e3aeb39040ad413159feb6b2cef5e15e19adbe6accf777339613854f`.
Current native sources and the shared timed workload must match that control;
the existing full-game verifier separately authenticates the `d059b95` oracle.
The full and isolated input fingerprints and the isolated trace bytes are also
pinned. The report keeps actual candidate revision/source, observer hash,
runtime/executable/options and prior evidence hash separately. A runtime that
does not match the previously accepted Windows version/platform is diagnostic.

Reports, test logs and status are packaged into
`Downloads/u13-pysim-marching-optimization-*.zip`. The reference streams are not
duplicated in this ZIP. Each worker has a 15-minute watchdog; stage progress is
printed every 15 seconds. A passing correctness gate does not by itself establish
a speedup: inspect both matched orderings before accepting the performance result.
Memory, policy-selection cost, worker scaling and full-roster campaign throughput
remain unmeasured.
