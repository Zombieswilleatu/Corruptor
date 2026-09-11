# U13 restore performance — 2026-09-11

The ZenBook profile completed in 65.297 seconds, including 19.218 seconds in
checkpoint round trips, 15.091 in restore validation, and 7.844 in the
angle-gradient section. Angle-gradient includes 512 individual assertion prints;
Windows console output is a suspected contributor, not isolated by that trace.

## Changes

U13Match.restore already recursively validates and normalizes/deep-copies the
entire external checkpoint. U13EventLog now accepts exclusive ownership of that
validated, normalized event subtree through a private internal method. It still
checks schema, event shapes and both player views before atomically installing
history. This removes duplicate recursive validation and copying. Standalone
EventLog.restore keeps its external recursive validation and canonical copy.
No caller-owned payload is retained, and all exported history remains copied.

Kroni still executes every assertion, but defaults to section summaries and a
passed/checked total. Failures always print immediately. Pass-by-pass output is
available with --verbose-checks on U13KroniTestRunner.gd. --profile retains phase
measurements and now emits the final canonical checkpoint SHA-256.
No gameplay rules, test deadlines, or production runtime gates changed.

## Measurements

Sequential headless runs on local Linux/Godot 4.5.1 stable. The reference run used
the old Match/EventLog implementation with the same new quiet test runner as the
optimized run. Only the old implementation was temporarily restored for that
comparison; the committed code is optimized.

| Phase | Old restore, quiet runner | Optimized, quiet runner |
|---|---:|---:|
| Full suite | 18.447 s | 16.649 s |
| Checkpoint round trips | 6.512 s | 4.321 s |
| Restore validation/install | 5.144 s | 2.912 s |

Approximately 10% less full-suite time, 34% less checkpoint time, and 43% less
restore validation/install time in this comparison. Single runs are subject to
host scheduling noise. An initial run with both old code and verbose assertion
output took 19.664 seconds; Linux output was inexpensive (angle-gradient 0.026 s).
Do not extrapolate that logging result to the user's Windows 4.7.2 machine.

Reference and optimized full-match canonical snapshot hashes both:
4614b5dddc8ece0f8ac33eac6519d27a2e8745a5e8af92fb6c3347618d3e1a7d

## Verification

Kroni: 1016/1016 assertions. Match foundation, determinism/identity, Kanifous rules,
and Kanifous board suites: zero failures, no engine/script errors. The board suite
used its explicit headless compatibility-check flag. New regressions compare
legacy append-based event restore against optimized restore, including both player
projections, integer normalization, caller mutation isolation and atomic rejection
of malformed late rows, fractional fixed-point numbers, NaN/Inf and invalid keys.
Existing full-match tests compare internal forks to validated checkpoint restores.

## Windows follow-up

After pulling u13-lord-overhaul, run the same run_u13_kroni_profile.sh command.
The profiler no longer prints every successful assertion. Compare suite time,
restore_validate and angle_gradient to u13-kroni-profile-kFKbpu.log. The performance
issue is improved locally; completion on the original 30-second Windows deadline
is not yet established. Production timeout policy remains unchanged.
