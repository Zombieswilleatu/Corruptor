# U13 PySim — profile the accepted optimized full-match path

Status: focused Windows CPython/PyPy capture accepted at clean `76e80fd`.
All 64 repeated-game final digests matched and both runtimes passed the three
observer tests. The engine is the accepted `c228d85` source, unchanged by this
observer. The profile identifies bounded candidates but does not establish
another quick 2–3× whole-match improvement.

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

## Accepted Windows capture — 2026-09-15

Evidence: [audited profile record](evidence/U13_PYSIM_OPTIMIZED_PROFILE_76e80fd.json).
The uploaded `u13-pysim-optimized-profile-UNaYaI-2026-09-15_12-08-29-g9fiXQ.zip`
contains 29 files, 543,162 bytes; SHA-256
`f731fc64e8708d1e6129596e720be658a7299b7227a1dba732350a76bf89797f`.
CRC, all extracted member hashes, duplicate JSON reports, timing statistics,
function/caller metrics, logs and source identities were checked. The worktree
diff is empty and exit status is zero. Three observer tests passed per runtime.
All 40 unprofiled, 20 warmup and four profiled repetitions match the accepted
final digests; the runner also checks outcomes. These repeat the same two
ordinary reference games. This capture reuses the prior exact replay at an
identical engine fingerprint; it is not another full parity run or 63-test run.

The record retains every timing/warmup/stage row and the union of the top 25
functions by exclusive and cumulative time, plus investigation targets, with
complete callers for each selected function. Full JSON/text/binary profiles
remain identified by their archive hashes. No binary profile was deserialized
to perform this audit.

### Separate throughput samples

| Runtime | Earlier same-engine mean | This 20-game mean | This final-ten mean |
| --- | ---: | ---: | ---: |
| CPython 3.14.7 | 2.706 s | 5.566 s | 5.624 s |
| PyPy 7.3.23 / Python 3.11.15 | 1.449 s | 1.439 s | 1.263 s |

All initial samples are retained. Current 13-/17-round means are 4.391 / 6.740
seconds on CPython and 1.193 / 1.685 on PyPy. PyPy's final-ten case means are
0.999 / 1.526 seconds. Its overall result is consistent with the earlier upload;
no steady-state campaign capacity follows from these two repeated games.

**The CPython increase is unresolved, but digesting is not newly included.**
Both runners use the identical imported timing `WORKER`, SHA-256
`8597d4aa93914acfc3ffe4f7adf4d37f484317350fedda75f5e8210357fe6078`.
Both stop wall/CPU timers before calling `digest(game)` and checking outcomes.
Engine, inputs, executable, runtime version and recorded flags/options match
the accepted copying comparison. CPython's separate profiling-process warmups
also vary substantially (the same two cases reach 2.012 / 3.020 seconds before
rising again). CPU mean is 5.477 seconds versus 5.566 wall, so elapsed waiting
alone is not an adequate explanation. Allocation/GC conditions, CPU frequency,
thermal state and competing load were not measured; no cause is assigned.
Do not use this slower CPython block to inflate a claimed PyPy gain. Compare
future changes against a fresh, matched control within each runtime, preferably
with repeated blocks in alternating order.

### What the caller data supports

The separate stage-timed games put Marching at **77.6% / 81.3% on CPython** and
**65.3% / 70.2% on PyPy**. They are one game per case, separate from the 20-game
throughput block. Their faster PyPy wall times of 0.721 / 1.026 seconds are not
replacement throughput estimates.

| PyPy function | 13-round cumulative share | 17-round cumulative share |
| --- | ---: | ---: |
| Marching `move` | 41.8% | 40.2% |
| `restore_reactions` | 11.5% | 12.5% |
| `_clone`, all callers | 10.7% | 11.7% |
| Full-match `_rollback_snapshot` | 6.2% | 6.9% |

Shares use the measured instrumented wall time (3.392 / 4.079 seconds).
Nested cumulative costs overlap and must not be added. In particular:

- `move` runs once per tick: 3,400 calls in the 17-round game. `near` already
  checks a 3×3 spatial-cell neighborhood; its 292,075 calls serve movement,
  allied blocking and contact search. A separate nearest-enemy loop in `move`
  has quadratic worst-case behavior. Nearest movement targets can be outside
  contact range, so a contact-radius-only scan is not a valid replacement.
  Of 858,105 `distance` calls, 403,572 come from allied blocking, 257,745 from
  that nearest-enemy loop and 169,569 from ranged targeting. Distance arithmetic
  itself totals about 1.1% of instrumented wall time; counts alone do not show
  that the grid fails to prune.
- Registry restoration occurs 181 / 307 times, not every one of the 2,600 /
  3,400 ticks. In the longer game, 261 restores follow shot volleys and 46
  follow melee clashes. The volley path restores even when no death triggered
  a reaction. Avoiding those unnecessary reconstructions is a contained
  candidate; retaining columns across real callbacks requires more care.
- `normalize` has 727,866 recursive calls but only 473 outer invocations in
  the longer game. `Entities.restore` accounts for 341 outer calls and about
  96% of normalization's cumulative time. Removing redundant normalization
  largely belongs to the registry-restoration opportunity, not a third
  independent multiplier.
- The 330,190 `_clone` calls span the whole longer match. Of its 0.479 seconds
  cumulative, 0.254 comes through the 433 operation rollback snapshots.
  The 107,632 standard-library `deepcopy` calls have no direct Marching caller:
  their outer callers copy planning clocks, timeline logs/payloads and opening
  registry rows. They are not a generic copy of every Marcher every tick.
  Alias preservation and detached public snapshots still constrain any change.

### Decision

A bounded experiment is justified; another quick 2–3× is not established.
Movement and restoration are distinct paths totaling about 53% of the
instrumented PyPy time. **If both costs were halved**, and these fractions
represented unprofiled execution, the overall gain would be about **1.36×**.
Even eliminating both entirely would imply only about 2.1× under those
assumptions. These are conditional arithmetic examples, not speed predictions.

The first contained candidate is skipping full registry reconstruction for
volleys that invoke no death reaction. Then investigate movement search and
temporary allocations while preserving exact two-dimensional nearest-target
ties, sequential allied blocking, earliest contact arrival and canonical
ID-ordered candidates before keyed selection. Preserve callback validation,
rollback, IDs, aliases, ordered events and detached snapshots. Keep a candidate
only after exact replay under both runtimes and matched unprofiled timing.
No engine optimization or broader game campaign accompanies this record.

## Earlier local diagnostic and decision threshold

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
The local concentration motivated the Windows/PyPy capture above. Neither gain
has been demonstrated; the Windows caller analysis now provides the more
relevant target-runtime evidence for choosing a bounded candidate.

PyPy supports cProfile with its JIT enabled but warns that instrumentation can
strongly distort results; its guidance favors statistical profiling where
available. This runner uses the already available standard-library profiler and
keeps timing and stage measurements separate. See
[PyPy profiling guidance](https://pypy.org/performance.html) and
[Python's profiler documentation](https://docs.python.org/3/library/profile.html).
Memory use, worker scaling and doctrine-selection cost remain unmeasured here.
