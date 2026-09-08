# Board runner timeout follow-up

The local wrapper reported U13Board exit 124 at 30 seconds after the responsiveness
change. Only the timeout footer was supplied, so the exact last stage and whether
the run was still progressing are not established.

## Harness changes

- Headless board runners cap their scene loop at 60 FPS. Without display pacing,
  uncapped frame polling can compete with the worker being measured. This affects
  only these test processes, not game settings or fixed simulation ticks.
  See [Godot Engine.max_fps](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-max-fps).
- The existing 48-Marcher integration checks move into U13DenseBoard, a separate
  runner. U13Board retains art, manual submission, replay, movement and normal UI
  interaction checks. All dense assertions remain, including exact worker/reference
  state and events, restart, rejected jobs and duplicate submissions.
- Each runner still has the same default 30-second hard watchdog. The full suite
  now contains 15 runners; no assertions were dropped to get under a timer.
- Named stages and worker-wait elapsed times show whether a timeout occurs in
  setup, normal UI, dense simulation, replay comparison or restart. A worker deadline
  stops subsequent assertions instead of cascading into further waits.
- On failure, the wrapper preserves the captured logs in a uniquely named
  `u13-foundation-failure-*.log` under Downloads and prints the exact path. It retains
  the temporary directory if saving fails. `U13_TEST_LOG_DIR` can override the destination.

## Focused rerun

```bash
bash Scripts/Sim/run_u13_foundation_tests.sh "$u13_godot" --board
```

This runs the existing dependency preflight, then only U13Board and U13DenseBoard.
Success is explicitly labelled `U13 board runners passed: 2/2`; it is not a claim
that the full foundation suite ran. A normal invocation still runs all 15 suites.

Grammar and shell syntax were checked here. A fake-engine wrapper check covers
the selected runners, paths containing spaces, error output with exit zero,
missing success footers, watchdog expiry and failure-log preservation. These are
harness checks; Godot 4.7.2 execution and the actual timeout outcome remain local gates.
