# U13 PySim — reduce full-match rollback copying

Status: implemented; local CPython tests, exact replay and matched timing pass.
The changed code's Windows CPython/PyPy acceptance and sustained comparison are
pending. The accepted `d059b95` CPython/PyPy results remain historical controls.

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
rejections. This is Linux CPython replay against the accepted Windows oracle.
The changed code has not yet been executed on Windows or under PyPy.

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
It does not establish the combined gain with PyPy or steady-state throughput.
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

Keep parity gates under both runtimes on later changes. After this comparison,
use the remaining measured cost to choose the next optimization. The 50 ms
suggestion and full-roster doctrine throughput remain unpassed targets.
