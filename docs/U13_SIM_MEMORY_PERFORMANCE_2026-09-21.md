# Simulation memory and performance

The 810-game balance screen slowed markedly while the user's Windows machine
was at 98% system memory. This patch targets allocation churn and worker
lifetime before changing game balance. It preserves all existing rules,
doctrine weights, recorded decisions and exact-state checksum semantics.

## Measured bottlenecks

A saved 16-round Gremory/Humbaba game was replayed from frozen revision
`f89384d1adbb1004b695fce2abd72363cadd56e5`. Profiling its round-12 Marching
phase found 578,300 column-row materializations. Movement repeatedly rebuilt
the same unit dictionaries, while passive or cooling-down monsters copied
every target row despite having no eligible ability.

The old final-state checksum also held a detached snapshot, a second tagged
tree, JSON text and encoded bytes. On CPython, this single checksum raised
peak memory from approximately 42 MB to 213 MB. On PyPy, a worker exceeded
1.3 GB after one game and retained about 1 GB after explicit collection.
This establishes substantial allocation/retention pressure; it does not prove
an unbounded leak or that every slowdown in the Windows run had one cause.

## Changes

- Reuse the existing movement snapshot within a tick, preserving ordered
  contact updates and the separate accepted-position snapshot.
- Build monster target rows only when the relevant ability can act. Each
  eligible ability still receives fresh rows after preceding mutations.
- Stream the exact transport representation into SHA-256 instead of building
  the complete tagged tree and encoded document. Float bits and output hashes
  remain unchanged.
- Drop completed traces and collect garbage before the next game. Recreate
  the worker pool after each batch of 12 games total. This bounds worker
  lifetime, not maximum memory for an individual game. `--worker-batch-size 0`
  disables recycling; smaller batches trade more cold starts for earlier
  process release.
- Save per-game CPU time, total wall time, process ID, resident memory and
  cumulative process peak memory in separate performance sidecars.
- Detect nested Windows PyPy installations and stop silently falling back to
  CPython. The launcher prints the selected executable and runtime.
- Add `bash Scripts/Sim/run_u13_lord_balance.sh --benchmark`, which compares
  three saved games using the report's frozen engine and the current engine.
  It runs sequentially, validates exact final states, and saves a small report.

Old campaign resumes retain their original source and worker policy. New
campaigns use the updated source. Frozen reports are never patched in place.

## Verification and results

Linux PyPy 7.3.20 / Python 3.11.13, one process per build, same ordered three-game
sequence. Times include replay and final-state hashing; they exclude planner
decisions and trace recording.

| Saved case | Before | After |
|---|---:|---:|
| gremory_humbaba_00 | 39.52 s | 28.99 s |
| kroni_odradek_00 | 39.82 s | 26.01 s |
| valak_kalligan_00 | 29.27 s | 21.17 s |
| Total | 108.61 s | 76.17 s |
| Peak worker memory | 1,678 MB | 903 MB |

That is 29.9% less total time and 46.2% less peak memory in this small sample.
All three complete final-state hashes match the archived campaign, including
event history. A separate fresh Gremory/Humbaba self-play also reproduced the
entire semantic record, every operation and the decision-trace hash; its
recording/cleanup path completed successfully at approximately 798 MB peak.

40 focused tests passed on both CPython and PyPy: exact codec boundaries,
movement, gravity, spawned worker recycling, record integrity, memory sidecars
and legacy resume dispatch. Launcher selection, shell syntax and actual source
freezing were checked. No 810-game campaign was rerun.

These are Linux measurements, not measurements of Windows PyPy 7.3.23 under
the user's other workloads. Pool rotation was validated with lightweight
spawned tasks; long-run throughput remains to be measured. Start the next
campaign with two workers and use the new memory readings before increasing
concurrency. The detailed evidence is in
`docs/evidence/U13_SIM_MEMORY_PERFORMANCE_2026-09-21.json`.
