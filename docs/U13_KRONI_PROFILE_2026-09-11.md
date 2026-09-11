# Kroni suite phase profile — 2026-09-11

Two sequential headless measurement runs of the complete U13KroniTestRunner on Linux,
Godot 4.5.1 stable. Both reported zero failures. These are diagnostic local
measurements, not acceptance measurements for the pinned Windows 4.7.2 runtime.

| Phase | First run (seconds) | Second run (seconds) |
|---|---:|---:|
| Complete suite | 18.691 | 17.642 |
| Configure/restore seven Lord pairings | 2.435 | 2.299 |
| Four-round match (includes rows below) | 13.070 | 12.208 |
| All round hooks | 4.074 | 3.830 |
| Checkpoint round trips at selected hooks | 6.622 | 6.213 |
| Random legal planning | 1.477 | 1.421 |

In the first run, the four marching hooks totaled 0.329 seconds. They are
included in all round hooks above. The fixture submits powers and empty combat
orders, so this is not a crowded-board stress test or an FPS measurement.

The second run split checkpoint work: owner construction 0.070 seconds,
snapshot copies 0.198, JSON serialization/parsing 0.849, restore/validation 4.919.
These are nested timings, not additional costs. The remaining checkpoint time
includes timing output/loop overhead. Checkpoint costs rise with accumulated
history. U13Match.restore recursively validates and normalizes the full envelope;
U13EventLog.restore then validates and copies its event rows again. This is a
specific optimization candidate, not yet a measured attribution to individual
validation functions. Do not remove validation or test coverage to shorten runs.

The timeout alone does not demonstrate slow marching. No production performance
change or timeout change was made in this profiling pass. Before accepting a
higher deadline, capture the same phase log on the affected machine. Optimization
of validation/copying needs snapshot equivalence, malformed-input rejection,
caller isolation, and before/after measurements.

The final shell-runner verification also passed (21.086 seconds), while repository
inspection/tool work was occurring. This is a functional runner check, not a
controlled additional benchmark.

## Run on the affected machine

```bash
cd ~/OneDrive/Documents/Corruptor-U13 &&
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_kroni_profile.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The runner preserves a log in Downloads, prints runtime/OS/CPU, and checks the
suite success marker and engine errors. It intentionally has no diagnostic
measurement deadline; Ctrl+C cancels. Normal test runner deadlines are unchanged.
Optional `--profile` instrumentation in the test runner preserves all assertions.
Phase timings exclude engine startup and are wall time, not per-function CPU
samples. Output and nested timings add some overhead. Standalone Kroni tests
retain their existing runtime compatibility behavior; no production gate changes.
