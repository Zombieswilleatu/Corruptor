# U13 PySim — profile the accepted optimized full-match path

Status: observer implemented and checked on Linux CPython; the focused Windows
CPython/PyPy profile is pending. The engine is the accepted `c228d85` source,
unchanged by this observer. User goal: determine whether another 2–3× whole-match
improvement is worth pursuing before expanding rules coverage.

## Run on Windows

From the checkout containing this runner:

```bash
bash Scripts/Sim/run_u13_pysim_full_match_profile.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

An optional second argument selects CPython explicitly. The runner checks the
three observer tests under each runtime, then runs each runtime sequentially:

1. Twenty alternating, unprofiled complete games in one process, using the same
   worker as the accepted copying comparison. Every initial sample is retained.
2. A separate profiling process runs ten alternating warmup games. Its final
   pair collects per-operation/hook wall times with cProfile disabled. These
   timer-instrumented warmups are separate from the throughput samples.
3. One cProfile game per reference case, retaining every function, its callers,
   exclusive/cumulative times, per-file exclusive totals and native `.prof` data.

Every game, including warmups and profiled games, must match the accepted final
digest and outcome. Result snapshots/digests are outside timers and profiles.
There are 64 repetitions of two fixed games across both runtimes, with no old
baseline block. Progress appears every 15 seconds; the results are packaged into
one `u13-pysim-optimized-profile-*.zip` in Downloads. Expected elapsed time is a
few minutes, with generous watchdogs for slower machines.

## Provenance and scope

`profile_u13_pysim_full_match.py` is a separate observer outside the engine
package and main CLI. It records its own source hash separately from the engine
fingerprint. It refuses a changed engine or input manifest before running:

- Accepted engine revision: `c228d85d449b19cfb3cd929479b0255c7e49bfc1`.
- Accepted engine/native-source fingerprint:
  `e34ef7c6e3aeb39040ad413159feb6b2cef5e15e19adbe6accf777339613854f`.
- Input fingerprint:
  `c811aa29dd34c2e8c6cf7cc710693483340c067415aaae0b94c55cc8f8fb3865`.

Both prior runtime replay prerequisites are checked from the
[accepted evidence](evidence/U13_PYSIM_FULL_MATCH_COPYING_c228d85.json). The
engine fingerprint is rechecked after the run. Actual checkout revision,
observer hash, evidence hash, Python executable/version, platform, GC and runtime
options are retained. A different local Python/platform is labeled diagnostic.
This reuses existing acceptance for identical engine source; it does not claim
a fresh Godot export, new full replay, broader rules parity or a new optimization.

## Local diagnostic and decision threshold

The [local evidence](evidence/U13_PYSIM_OPTIMIZED_PROFILE_LOCAL_2026-09-15.json)
records CPython 3.12.14 on Linux with four unprofiled games, two warmups and two
profiles. All eight final digests/outcomes matched. The three observer tests
passed, including real recursive cProfile data: function records and caller
records store total/primitive call counts in opposite orders, which the JSON
export handles explicitly. The runner retains all 267 / 265 profiled functions;
the repository's diagnostic evidence selects the top 25 by cumulative and
exclusive time and retains complete caller data for those selected functions.

Unprofiled means were 2.057 seconds for the 13-round game and 3.306 seconds for
the 17-round game, averaging 2.682 seconds. The separate hook-timed games put
Marching at **78.8% / 82.0%** of total wall time. Within cProfile:

| Function | 13-round cumulative share | 17-round cumulative share |
| --- | ---: | ---: |
| Marching `move` | 37.2% | 37.6% |
| `restore_reactions` | 19.1% | 24.1% |
| `_clone`, all callers | 13.5% | 12.9% |
| Full-match `_rollback_snapshot` | 7.8% | 6.7% |

These cumulative rows overlap and must not be added. Profiles instrumented the
two games to about 6.33 / 9.87 seconds, roughly three times their unprofiled means.
The stage timers independently support Marching's prominence; the instrumented
function fractions are leads, not predictions of the unprofiled PyPy split.

Code inspection identifies two concrete candidates: repeated nearby-unit search
and movement work, and rebuilding/validating the full entity registry when
`restore_reactions` recreates `Columns`. The latter invokes `Entities.restore`
181 / 307 times through reaction restoration alone. Any future fast path must
preserve public validation, callback rollback, stable IDs and explicit contact
ordering. No such fast path is introduced by this observer.

A 2× whole-match improvement requires removing 50% of elapsed time; 3× requires
66.7%. If Marching stays at roughly 80% and all other work is unchanged, those
goals require approximately 2.7× and 6× improvements within Marching respectively.
The local concentration makes investigation worthwhile; neither gain has yet
been demonstrated. Use the Windows/PyPy profile to choose a bounded candidate,
then keep or discard it based on exact parity and matched unprofiled timing.

PyPy supports cProfile with its JIT enabled but warns that instrumentation can
strongly distort results; its guidance favors statistical profiling where
available. This runner uses the already available standard-library profiler and
keeps timing and stage measurements separate. See
[PyPy profiling guidance](https://pypy.org/performance.html) and
[Python's profiler documentation](https://docs.python.org/3/library/profile.html).
Memory use, worker scaling and doctrine-selection cost remain unmeasured here.
