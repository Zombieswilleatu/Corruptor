# U13 PySim — reduce full-match rollback copying

Status: **Windows CPython and PyPy acceptance passed at clean `c228d85`.** Both
runtimes passed all 63 tests and the exact two-game replay, including 13 deliberate
corruption rejections. The sustained comparison measured 12.92 → 2.71 seconds
under CPython (4.78×) and 7.83 → 1.45 under PyPy (5.40×). The accepted `d059b95`
source remains the control; this optimization does not extend rules coverage.

## Change and ownership contract

`PlanningMatch.apply()` previously called the public `snapshot()` before every
operation, recursively copying all retained semantic rows/views and the
presentation world. The cost grew with the match's history.

Rollback now has separate storage, `RollbackSnapshot`. The audited built-in
`FullMatch` path deep-copies mutable state, copies the history's list of row
references, and shares its existing rows and presentation world with the backup.
These subtrees are detached from mutable authority: built-in dispatch only
appends new rows and replaces the presentation world. Failure restores the
original prefix, world, ledgers, orders, persistent IDs and clock. No event is
discarded, and no hook or transaction is skipped.

This is scoped structural sharing, not a general copy-on-write object model:

- Public `snapshot()` still returns completely detached plain data. The generic
  copier and its alias/cycle memo are unchanged.
- Internal handlers use `_state`. Reading or assigning the compatibility `state`
  property marks live state as exposed. During a transaction it first upgrades
  the backup to a full detached copy; later transactions stay fully copied
  because external references may have been retained.
- Subclasses and replaced match handlers use full backups. Earlier Planning,
  Development and Resolution adapters also retain full backups.
- Policy observation/input-generation helpers read internal storage but return
  detached permitted views to the injected policy. Their generated reference
  decisions still match the accepted input manifest exactly.
- Future hooks that edit old history/presentation or introduce aliases between
  these subtrees and mutable authority must revisit the sharing contract.
  Private `_state` is internal; extensions can use the conservative live-state
  property or detached public observations.

No further Lords or powers are ported, and mechanics, U12 and automatic Python
selection are unchanged.

## Exact verification and retained oracle

The 63-test full-match suite preserves all prior tests and adds failures after
native event/reservation work, live-state access during a hook, retained
references with aliases across world/presentation/history, custom private hooks
and successful edits without corrupting retained public snapshots. Gate tests
reject changed native sources, an incorrect stream and a wrong final digest
even when Python is launched with `-O`.

`verify-full-match-copying` reuses only the exact accepted Windows Godot 4.7.2
stream, with these pinned identities:

- Reference revision: `d059b9560a95c32779597260d99829f9f1534f22`.
- Reference source: `b25bdf65d1f1689f7e0b5e35cee748e810bd1bf409f2084ee55b0b280ad7358e`.
- Input hash: `c811aa29dd34c2e8c6cf7cc710693483340c067415aaae0b94c55cc8f8fb3865`.
- Stream SHA-256: `81318a197145163bbd0d282c16a2b1ccc19d92c8ad7f68b1c6c8ac3f2f697b72`.

It checks the historical source archive against that fingerprint and requires
every current `Scripts/Sim` Godot source and the explicit inputs to match. A
native change requires a new Godot export; there is no diagnostic bypass. The
existing exact verifier and all 13 corruption probes execute the candidate
against the old oracle. Reports separately identify the candidate source/runtime
and historical reference; the old stream is not relabeled as a new export.

Local replay matched two complete games, 30 rounds, 767 operations, four terminal
rejections, eight settlement components, the 200-tick probe and all 13 corruption
rejections. The subsequent Windows CPython and PyPy runs also matched these
checks; each entire `reference_verification` summary equals the original accepted
`d059b95` summary, including every event count and both final digests.

## Accepted Windows sustained comparison

Evidence: `u13-pysim-full-copying-RE3M9k-2026-09-15_11-34-28-lmRCI2.zip`
(26,606 bytes; SHA-256
`9c168cf969652aaddddc630eb843fa06a26fdd73ae54d9127d553c09583cd4b7`).
All 21 members were inspected, archive CRC checks passed, `exit_status=0`, and
`worktree.diff` is empty. The [accepted evidence record](evidence/U13_PYSIM_FULL_MATCH_COPYING_c228d85.json)
retains member hashes, exact parity, both runtime identities and all 80 timing
samples. The standalone sample files match the embedded comparison blocks;
counts, ordering, digests and statistics were independently checked.

Candidate revision: `c228d85d449b19cfb3cd929479b0255c7e49bfc1`.
Candidate source SHA-256:
`e34ef7c6e3aeb39040ad413159feb6b2cef5e15e19adbe6accf777339613854f`.
Both runs verified the same inputs and pinned native stream above, plus all 386
unchanged native source files. The existing Windows Godot 4.7.2 export was reused;
this was not a new Godot run. Unit tests passed 63/63 under CPython 3.14.7
(10.493 seconds) and PyPy 7.3.23 / Python 3.11.15 (11.246 seconds).

Each implementation/runtime ran 20 alternating games in one process: ten samples
of each of the two accepted games, with initial games included. All 80 timed
final digests matched. CPython ran baseline then candidate; PyPy ran candidate
then baseline. All blocks were sequential on the user's Windows machine.

| Runtime | Original `d059b95` mean | Optimized `c228d85` mean | Copying speedup |
| --- | ---: | ---: | ---: |
| CPython 3.14.7 | 12.9229 s | 2.7060 s | 4.78× |
| PyPy 7.3.23 | 7.8286 s | 1.4486 s | 5.40× |

PyPy's optimized first ten average 1.6623 seconds and final ten 1.2350 seconds.
Within the final ten, the 13-round game averages 0.9665 seconds and the 17-round
game 1.5035 seconds. This decline is consistent with warmup but does not isolate
JIT behavior or establish steady state. All 20 samples remain in the headline
means. CPython's optimized first/later halves average 2.6660 / 2.7461 seconds.

The current CPython baseline divided by the current optimized PyPy mean gives
**8.92× combined observed speedup**. Use these same-upload controls: the older
15.21-second CPython and 5.13-second PyPy means used a different sampling protocol.
In particular, this PyPy baseline is slower than its earlier archive; these
reports do not isolate the cause, so the old 2.96× runtime gain is not multiplied
into the new copying gain.

Arithmetic from the optimized PyPy mean gives about 2,485 repetitions/hour, or
2,915 using the final-ten subset. Repeating these same workloads 50,000 times
would take about 20.12 or 17.15 hours respectively on one worker. These are
extrapolations, not measured campaign capacity: policy selection is excluded,
the corpus still contains only two ordinary games, and memory/worker scaling
are unmeasured. The 50 ms whole-match target remains unmet.

## Local matched timing

On Linux CPython 3.12.14, four alternating games per implementation were measured
in separate sequential baseline/candidate processes, two samples per case. Every
final digest matched. Initial games are included; no profiler ran in the timers.

| Reference game | Original `d059b95` | Candidate |
| --- | ---: | ---: |
| bones_endurance, 13 rounds | 9.12 s | 2.08 s |
| spoils_rekindle, 17 rounds | 16.01 s | 3.42 s |
| Equal-weight mean | 12.57 s | 2.75 s |

This bounded diagnostic measured **4.57× speedup / 78.11% less wall time**. It
uses its own matched control, not the older Windows or Linux timing denominator.
It does not itself establish the combined gain with PyPy or steady-state throughput;
the subsequent Windows comparison above supplies the two-runtime observation.
The [local evidence record](evidence/U13_PYSIM_FULL_MATCH_COPYING_LOCAL_2026-09-15.json)
retains actual source identity, complete replay, tests and raw comparison data.

## Sustained comparison and Windows command

`benchmark-full-match-copying` loads the original implementation from pinned Git
commit `d059b95`. Both implementations execute the identical worker and unchanged
`benchmark_full_match.play()`/input manifest. Each worker runs **20 alternating
complete games in one process** by default, checking every final digest/outcome
outside its timer. Reports retain chronological samples, the initial pair,
first/later halves, per-case statistics, executable/runtime identity, selected
PyPy environment settings and interpreter flags.

Setup, decisions, all hooks, rollback and full semantic history are included;
imports, policy selection, comparison snapshots/digests, export and profiling
are excluded. Memory and worker scaling remain unmeasured. Early/later sample
differences do not establish steady-state JIT or population throughput.

From the candidate checkout:

```bash
bash Scripts/Sim/run_u13_pysim_full_match_copying.sh \
  "$HOME/Downloads/u13-pysim-full-match-5KQlDr/full-match.exact.jsonl" \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

The optional third argument selects CPython explicitly. The runner tests and
replays under both runtimes, then measures baseline → candidate for CPython and
candidate → baseline for PyPy. This uses two sequential workers per runtime,
not interleaved within-runtime blocks: 80 timed repetitions of the two fixed
games, with no new matchup corpus or Godot campaign. Each timing worker has a
15-minute watchdog. Reports are packaged into a new Downloads ZIP.

The previous PyPy upload already had ten samples per case in one process. Its
early decline was consistent with warmup, not proof that all longer campaigns
will be faster. The old 76–78% copying fractions were CPython profiles; PyPy's
separate profiles showed 59% / 71%. Runtime and algorithm gains can overlap,
so the combined speed is measured rather than predicted by multiplying 3× by
a hypothetical copying multiplier.

Keep parity gates under both runtimes on later changes. This comparison is now
accepted. Profile the optimized implementation separately from timing to choose
the next optimization; the pre-change copying fractions cannot identify its new
dominant cost. Preserve rollback, detached views and exact events. The 50 ms
suggestion and full-roster doctrine throughput remain unpassed targets.

The [focused optimized-profile capture](U13_PYSIM_OPTIMIZED_PROFILE_2026-09-15.md)
is accepted at clean `76e80fd`, retaining this engine fingerprint. All 64 repeated
final digests matched. PyPy's new 20-game mean is 1.439 seconds (final ten 1.263),
consistent with this comparison. CPython's mean rose to 5.566 seconds with the
same timed worker; digesting remains excluded and the variation has no identified
cause. Caller data identifies movement and unnecessary reaction-registry
restoration as bounded candidates; normalization overlaps the latter. Another
quick 2–3× is not established. See the capture record for scope and attribution.
