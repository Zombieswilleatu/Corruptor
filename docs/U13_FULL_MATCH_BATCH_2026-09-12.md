# U13 autonomous full-match gate

The 18/18 foundation gate was accepted on Windows at `4232938`. This checkpoint
adds a separate long-running gate; it does not change combat rules, Lord powers,
victory thresholds or the disabled Veil penalties/drift.

## Run

```bash
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_full_matches.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The wrapper requires Windows-compatible Godot 4.7.2 stable, checks planning
against the previous implementation and checks batch/full-history parity,
then runs 100 seeded full games, using **four Godot processes** by default. Each
worker runs one game and takes the next available index when it finishes. Expect
a long run; four workers improve throughput when CPU and memory allow, but do
not guarantee a fourfold speedup.
It prints elapsed time every 15 seconds, completed-round timings, and each game's result. Keep the computer
awake; sleep can consume the watchdog budget.

Expected acceptance: **100/100 won; 0 censored; 0 failed/missing**. A smaller
smoke run is not the 100-game gate. The existing `run_u13_game.sh` stays at 18/18.

Reports go to a stable folder in Downloads. Rerunning the same command reuses
completed, replay-verified reports for the same content revision, tracked diff,
runtime, setup and round limit. In-progress games restart from their deterministic
seed. Logs and the latest round-start snapshot remain available for diagnosis.
An optional second argument selects the report directory. Scheduler/docs-only
updates retain the content identity, so the four-worker update can reuse results
from the preceding serial runner. Worker count does not change seeds or results.
Ctrl-C, a failure or a timeout stops all Godot processes owned by the runner.

| Setting | Default | Meaning |
| --- | --- | --- |
| `U13_BATCH_WORKERS` | 4 | Concurrent Godot processes; 1 for serial, maximum 16 |
| `U13_BATCH_GAMES` | 100 | Number of games, starting at index 0; maximum 1000 |
| `U13_BATCH_ROUND_LIMIT` | 80 | Diagnostic cap per game; maximum 200; never awards a winner |
| `U13_BATCH_TIMEOUT_SECONDS` | 1200 | Wall-clock watchdog per game, including replay |

Engine errors, invalid plans, replay mismatches and timeouts stop the wrapper and
preserve evidence. Round-capped games are recorded as censored; remaining games
continue, and the final gate fails if any game is censored or missing. Increasing
a cap or changing code invalidates matching report reuse as appropriate. Do not
edit simulation code while a batch is running.

## Lossless saves

The initial local batch exposed a save/replay discrepancy with Kroni in game 6,
at round 8. Fractional movement carry in event history did not survive Godot's
JSON float conversion exactly, even with full-precision output. The game state
and event history must both survive; approximate equality is not sufficient.

`U13GameConductor.snapshot_json()` / `restore_json()` now use a versioned JSON
envelope containing a base64-encoded, lossless Godot Variant payload. Decoding
uses `bytes_to_var`, which does not instantiate objects, followed by all existing
plain-data, policy, clock and snapshot validations. The authoritative runtime
remains pinned. Use these APIs for exact persisted saves; `snapshot()` / `restore()`
remain the raw dictionary boundary. Checkpoints include a `save_json` string for
exact reproduction. Human-readable reports retain their setup and diagnostics.

The harness regression reproduces the old precision loss and asserts exact
state equality with the lossless save, plus atomic rejection of an invalid root.
The existing conductor and Random-Legal gates now exercise this save API.

## Schedule and checks

`U13FullMatchBatch.setup(index)` uses seed `u13-full-match-v1:<index>`. The first
81 games cover every ordered pairing of the nine Lords, including mirrors.
The last 19 add repeats with different seeds and Castle arrangements. Castle
loadouts keep Keep first, rotate the other types and include legal duplicates.
All economy and opening payments come from `U13GameConductor.start()`.

Every game has two independently started conductors. Each round:

1. Both resolve draws and Slaver choices using the seeded random-choice API.
2. Both independently generate plans; plans and unchanged planning states must
   match exactly. No illegal plan is replaced with Pass.
3. The replay conductor restores the planning snapshot through JSON.
4. Both submit through the authoritative joint-submission API and resolve the
   whole round. Complete snapshots must agree, including private events, entity
   IDs, resources, pending/persistent effects and clocks.
5. The round-end save must restore. The owner applies its existing queue and
   lifecycle validation; future effects may remain frozen in a finished game.
6. A terminal result must agree with the victory evaluator, restore identically,
   and reject advancing to another round.

Each game report includes its setup, code/runtime identity, elapsed time, plans,
round state hashes, phase timings, action/power/Development/event counts and outcome. Failed and
censored reports also retain snapshots. `summary.json` aggregates outcomes and
observed coverage. Report validation rejects incomplete/stale entries and records
that relabel an unfinished outcome as a victory.

This is a stability and reachability gate. Random observed coverage is not an
exhaustive candidate audit, and win rates here are not balance evidence. The
follow-up is to inspect gaps and then connect the full conductor to playable U13.

## Local verification and acceptance status

- 120 harness checks passed on Linux Godot 4.5.1, including all scheduled
  loadouts, report validation and lossless save regression.
- Existing conductor and three-round Random-Legal suites passed with the new
  save API. The reproduced Kroni checkpoint replayed rounds 8 and 9 exactly.
- The initial diagnostic batch produced a legitimate replayed Dominion win in
  game 5 (Odradek/Gremory), round 12, before it was stopped to address the Kroni
  precision mismatch. This is not a 100-game success claim.
- Actual capped-game reporting, completed-report reuse and incomplete-batch
  summaries were checked. Missing/censored games prevent acceptance.
- **The full 100-game Windows Godot 4.7.2 acceptance run remains pending.**

## Four-worker scheduler verification

The scheduler protocol tests exercised seven jobs with a peak of four workers,
plus failure, timeout and Ctrl-C cleanup with no surviving worker processes.
These used a test double and are not Godot acceptance results. Four actual Linux
Godot 4.5.1 processes also ran independent one-round capped games concurrently;
game 8 reproduced its prior serial plans and complete-state hash. These were
explicitly censored smoke tests, not four completed victories. Windows 100-game
acceptance remains pending.

## Targeted performance pass

The user canceled the slow run and supplied its round-7 checkpoint. The targeted
fix and reproduction are documented in `U13_SIM_PERFORMANCE_2026-09-12.md`.
Batch V2 uses `U13_BATCH_EVENTS_V1`: omit `MARCHING_TICK` and `KRONI_ACTOR_TICK`
position samples, preserving every simulation step and all other events. Exact
replay compares the complete state and retained event history in this profile.
Normal gameplay keeps its full presentation history by default. Old full-trace
saves still restore in full-trace mode. Old V1 batch results cannot satisfy V2.

Each round now records `timings_ms` for checkpointing, reaching planning,
independent bot planning, planning save/restore, submission, resolution/comparison,
and round-end save/hash. These diagnostics are outside authoritative snapshots
and hashes. Planning and resolution timings include both verification conductors.
Completed-round totals also appear in logs, so an interrupted run retains timing
evidence even before its final result is written.

For an overnight run, `U13_BATCH_TIMEOUT_SECONDS=3600` allows an hour per game
while retaining the 80-round censoring cap; this is an explicit watchdog choice,
not a prediction that all 100 games will finish overnight.

This heavy replay batch remains an occasional integration gate. Use targeted
tests for routine changes; defer large-volume throughput work to PySim parity.
