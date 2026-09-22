# Six-game worker memory check

Run from the isolated simulation checkout:

```bash
bash Scripts/Sim/run_u13_lord_balance.sh --memory-check
```

The launcher uses the same PyPy discovery as the balance runner. The check
selects six complete cases from the latest completed balance report under
Downloads/Corruptor/Balance; --report accepts an explicit report directory.
It freezes the current source into a new output directory before simulation.

This runs fresh bot decisions, diagnostics, trace recording, checksumming and
compression through the existing survey.run_one path. There are exactly two
workers and six games. pooled_results recreates the pool after four games,
so games five and six run in newly created processes.

The terminal displays pool batch, worker PID, resident memory at game start
and after cleanup, cumulative process peak memory and total game time.
memory-check.json collects those readings, worker PIDs by batch, elapsed
time and verification results. Full records and per-game performance sidecars
are retained. After the workers exit, every completed record is integrity
checked and compared against the archived semantic, decision, trace and
final-state hashes. Failed games or mismatches return a nonzero exit code.

Output goes to Downloads/Corruptor/Performance/sim-memory-check-<timestamp>.
The terminal prints the final ZIP path. Existing balance reports are only
read. This check has no resume mode and creates a new directory each time.

The six cases are Gremory/Humbaba, Kroni/Odradek, Valak/Kalligan and their
reverse seat orders, using repeat 00. This is a memory/process-lifetime check,
not balance evidence or a proof that long-run memory growth is eliminated.
Worker readings do not include the launcher, supervisor or other applications.
Peak memory is cumulative within each worker, not additive across games.
New worker PIDs and fresh start readings expose pool replacement; no automatic
memory threshold is treated as a pass/fail balance gate.

Publication validation: reviewed against the existing freeze, survey,
record-integrity and pooled_results interfaces. The execution environment was
unavailable, so this new wrapper has not been executed before publication.
The earlier tests and three-game replay results apply to the existing engine
and pool implementation, not to a completed six-game check.
