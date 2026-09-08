# U13 performance profile

Standalone diagnostic for the smoke timeout and the board suite approaching its watchdog. It does not change production rules, skip validation, or extend the foundation suite. Godot 4.7.2 stable is required.

```bash
bash Scripts/Sim/run_u13_perf_profile.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The log is written to `~/Downloads/u13_perf_profile.log`, overwriting that diagnostic file on each run. Set `U13_PERF_LOG` to use a different path. The runner has no 30-second cutoff and prints progress before each measurement. A first full run may take several minutes; its duration has not yet been measured on the target machine.

For a shorter first pass, append `--counts=6,24 --samples=2 --rounds=2`. Counts are total Marchers, evenly split between players; supported even counts are 2–96. Samples and rounds are each 1–10.

## Measurements

- Density fixtures: 6, 24, and 48 Vultures by default. `travel` separates opposing armies into different lanes, retaining the population while exercising friendly spacing. `contact` puts both armies in the Castle lane closer to the center, exercising steering, queues, damage and real Gremory reactions. These are stress fixtures, not estimates of shipping field density.
- `marching_direct`: the actual whole Marching phase, including atomic world copying, movement, combat/reactions and tick generation. This is an inclusive timing, not a measurement of just the steering loop.
- `event_log_append`: validation/canonical copying of the generated events into a fresh event log.
- `playback_build`: reconstruction of the animation tape.
- `playback_sample_360_frames`: total CPU time for 360 samples spread over the animation; divide by 360 for mean sample cost. It excludes drawing, layout and GPU work.
- History fixture: an actual match owner with six travel Marchers, followed through three rounds. Snapshot copying, restore validation, JSON encoding/decoding and player projection are measured at the start and after each round. Event row counts and UTF-8 JSON byte counts expose history growth; byte counts are serialized size, not RAM usage.
- `marching_owner_transaction`: the real owner's Marching hook including transactional cloning/validation and event installation. Other hooks and submissions are timed as a separate aggregate.
- Board fixture: the actual U13BoardSession, its random-legal opponent, and Predator declarations in ready rounds. Measures planning through Marching, board views/checkpoints, playback building, aftermath, and next-round startup. This excludes instantiating/rendering the graphical board.

Repeatable operations use one discarded warm-up followed by the configured number of samples, reporting minimum, median and maximum milliseconds. Stateful round transactions execute once and are explicitly reported with `samples: 1`; no warm-up is applied to these. Total wall time includes fixtures, warm-ups, progress output and diagnostic serialization, so it is not the sum of reported medians.

`PERF` lines are JSON for easy comparison. `PROFILE META` records engine, OS, CPU and configuration. `OK` means the diagnostic completed without its validity/endpoint checks failing; it is **not** a production performance pass. The wrapper also rejects logged Godot errors even when the process exits zero.

Compare direct Marching with owner/board round costs and inspect growth with history before choosing an optimization. Test-suite wall time alone is not player latency. Run under the same machine/build/settings before and after a fix. Separate graphical profiling is still necessary if CPU state handling is fast but the live board stutters.

Workspace checks: GDScript grammar and shell syntax; shell error/footer handling exercised with a stub executable. Runtime timing and Godot compilation remain local verification.
