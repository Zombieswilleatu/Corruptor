# U13 PySim Development — Guard deployment, Work and stable pairs

Windows Godot 4.7.2 acceptance **passed** at clean revision
`108fc1579bb9cf71fc905e6be06a6db43754fde3` on `u13-basic-doctrine`, built on
`c00d20dd173debc137b1a319ffd3c7edcc90827d`. Local Godot 4.5.1 results remain
diagnostic only. The previously accepted foundation and planning gates keep
their original revisions and evidence.

Accepted archive:
`u13-pysim-development-VR6vYW-2026-09-14_23-35-02-zLQs81.zip`.
Its SHA-256 is `c5e254ce81212d2b3a0b97f1f7efd85b319e1e9d0bc7e55c2b3dae02b2dd4c18`.
The archive reports Godot `4.7.2.stable.official.ed1daf0bf`, Python 3.14.7,
an empty working diff, exit status zero and no script errors. All 12 members
passed CRC checks. The full exact trace was independently replayed in Python,
including all 14 deliberate evidence corruptions. See the
[accepted evidence and timing report](evidence/U13_PYSIM_DEVELOPMENT_108fc15.json).

## Implemented boundary

`u13_pysim/development.py` extends the independent fresh-game adapter through
the sixth hook, Development. It consumes explicit, power-free submissions from
the accepted planning implementation. It resolves empty Rites/Resummon ledgers,
the construction clock, physical Guard placement, Work and pair formation in
Godot's existing order. It stops before `post_repair_artillery`; the original
`PlanningMatch` still stops before Development.

The isolated subsystem mirror also covers later Guard/Work lifecycle calls:

- Each newly deployed Guard contributes one Work. A fresh Wright pair adds five
  once. Existing Guards and surviving Wright pairs do not pay again.
- An unfinished target receives three passive Work each Development. Active
  damaged Castles receive no passive repair. Inclusive repair locks block active
  repairs; protected building/reconstruction clears the lock.
- Targets persist, can be changed or explicitly cleared, clear on completion or
  invalidation, and clamp to maximum integrity. Activation and Work event order
  and payloads match Godot, including nominal Work when a lock prevents gain.
- Every suit forms public pairs in both zones, with the two lowest fresh slots
  paired when three matching Guards arrive. A broken bond remains inactive if
  its original card returns or a replacement is placed beside a survivor.
- Intact Vulture pairs draw once per later round. The public gain event omits
  the drawn identity. Directed deck exhaustion checks the pair-specific RNG key
  through discard recycling. Reconciliation occurs even on duplicate-clock calls.
- Ruined ordinary Castles remain irreparable. Only a live Deimos can reconstruct
  his own ruined Siege Engine, preserving its physical entity ID.
- Failed second-player deployment rolls back the first player's changes; the
  entity retirement ledger preserves retired pair identities.

The component fixtures explicitly prepare reservations, transfer physical cards,
damage or retire entities, and call one subsystem at a time. These operations
are labeled `fixture_*`; they are **not** gameplay commands, round progression,
or proof of later Lord-hook integration. Expected Godot worlds are never loaded
into the Python engine. Python independently creates each initial world and
replays the explicit fixture operations.

Still outside this slice: paid Rites and Resummon, artillery, combat and the
Penitent/Butcher pair combat effects, Supplicant consumption, Marching, later
Lord effects/upkeep, victory, arbitrary saved-game restoration, full rounds and
full matches. Missing game boundaries raise `Unsupported`, distinct from a
supported Godot legality rejection.

## Focused validation

The new Godot exporter is `U13PySimDevelopmentTestRunner.gd`, with
`U13_PYSIM_DEVELOPMENT_SUITE_V1`, `U13_DEVELOPMENT_TRACE_V1` and
`U13_PYSIM_DEVELOPMENT_EXPORT_V1`. The Python mirror is
`U13_PYSIM_DEVELOPMENT_V1`.

Accepted Windows Godot 4.7.2 results (also previously green in local 4.5.1
diagnostics):

| Check | Result |
| --- | --- |
| Godot directed checks and independent export replay | 497 passed |
| Fresh-game cases | 9; every Lord in both seats |
| Complete match snapshots | 90, including nine openings |
| Exact game operations | 81, covering the first six hooks |
| Isolated lifecycle cases | 11; 217 operations, including 106 explicit fixture preparations |
| Component rejections with unchanged state | 7 |
| Python foundation + planning + Development unit tests | 20 passed |
| Deliberately corrupted evidence rejected at the changed field | 14 |

The [local diagnostic record](evidence/U13_PYSIM_DEVELOPMENT_LOCAL.json) pins
the pre-commit source fingerprint and local exact export SHA-256. It remains
separate from the [clean Windows acceptance](evidence/U13_PYSIM_DEVELOPMENT_108fc15.json),
whose source fingerprint is
`73072edd9ea35c3d50edef2cdcc85adaafbf48490f9801a959bf973679c8d089`.

Comparison includes all snapshot fields, ordered event payloads and player
views, private piles, presentation baseline, exact number types, physical IDs,
used-ID history, Guard slots/bonds, reservations and clocks. The existing exact
transport and batch visual-sample exclusions are unchanged. Corruption probes
cover provenance, missing Development, pair identity/slots/activity, clock and
target state, deployment slots, Work results, public views, Vulture hand order,
broken-bond resurrection and the retirement ledger.

## Partial speed measurement

`benchmark-development` times 270 fresh opening-through-first-Development cycles
across the same nine directed setups, after nine warmups. It preselects all
explicit inputs outside timing. Engine transactions, event handling and opening
RNG remain inside; Godot, trace export, external snapshot comparisons and
doctrine selection are excluded. Phase timings separate opening, upkeep/choices,
submission/lock and Development. This is a single-process measurement.

The accepted Windows run at `108fc15` measured **31.35 ms mean, 26.65 ms median,
52.74 ms p95** per partial cycle. Its 270 measured cycles took 8.4635 seconds
of wall time. Runtime was CPython 3.14.7 on Windows 11, AMD64; the machine
reported eight logical CPUs and the probe used one worker.

| Timed phase | Mean wall time |
| --- | --- |
| Opening | 2.96 ms |
| Upkeep and choices | 17.08 ms |
| Submission and lock | 6.59 ms |
| Development | 4.72 ms |

The CPU-time summary includes a zero minimum and coarse percentile values;
retain those reported statistics and use the wall-clock distribution for
fine-grained comparisons. The [accepted evidence](evidence/U13_PYSIM_DEVELOPMENT_108fc15.json)
retains the complete timing report and hardware/runtime identifiers. This is a
baseline on the user's machine, not a measured optimization over the Linux run.

The initial Linux x86_64 CPython 3.12.14 diagnostic measured **37.59 ms mean,
35.63 ms median, 48.19 ms p95** per partial cycle. Mean phase times were 2.90 ms
opening, 20.83 ms upkeep/choices, 8.19 ms submission/lock, and 5.67 ms Development.
The container reported nine logical CPUs; the probe used one worker. The raw
measurement is retained in
[`evidence/U13_PYSIM_DEVELOPMENT_TIMING_LOCAL.json`](evidence/U13_PYSIM_DEVELOPMENT_TIMING_LOCAL.json),
including the exact source fingerprint. It describes the pre-commit source
based on `c00d20d`, not an accepted clean Windows revision.

These numbers **do not estimate full-match throughput**. Both reports deliberately
leave full-match games/second and 50,000-match duration null. See the
[policy and performance gates](U13_PYSIM_POLICY_AND_PERFORMANCE_2026-09-15.md)
before extending the performance claims or starting doctrine sweeps.

## Windows acceptance command

This gate has passed; no rerun is needed for the documentation update. Retain
the command for later implementation changes requiring this focused gate.

Run from Windows Git Bash, with Python 3.10+ installed; no pip dependencies:

```bash
cd /c/Users/jerem/OneDrive/Documents/Corruptor-U13-Perf &&
git pull --ff-only origin u13-basic-doctrine &&
bash Scripts/Sim/run_u13_pysim_development.sh \
  'C:/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
```

The runner enforces Godot 4.7.2 stable, records runtime/source identity and the
working diff, runs the 20 Python tests, Godot export/replay, independent exact
Python verification and 14 corruptions, then the partial timing probe. Each
stage has a 180-second watchdog and progress heartbeat. It packages one
`u13-pysim-development-*.zip` under Downloads, including `partial-timing.json`.
The verifier rejects non-Windows/4.7.2 traces unless explicitly diagnostic.

No gameplay balance, Godot authority, U12, legacy Python or playable UI changes
are included. The integrated forecast/public Guards and parallel sprite work
remain on the same development line.
