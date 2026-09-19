# Lane sandbox: prepare the next interval during playback

Continuous mode now prepares one interval ahead by default. Select **Continuous · repeat rounds** and any speed, including 3× or 5×. The **Prepare next interval during playback** checkbox turns this off for comparison. The status line shows whether the next interval is preparing, updating after changed choices, or ready.

The first interval still needs preparation. Later preparation runs during the current replay; when it finishes in time, the next replay starts at the boundary without another preparation wait. An expensive interval or a late input change can still leave a remaining wait. Simulation ticks and the 15-second playback scale are unchanged.

This is sandbox scheduling only. Full-game round flow, marching balance, protected staging, pressure decisions, range, damage and movement rules are unchanged.

## State and input ownership

- A worker owns a separate arena, including both decks, discards, saved cards, monster goals, reshuffle counters, unit-ID serial, totals, goal deduplication and seat orientation.
- It finishes a private copy of the current simulation result, applies the next inputs, resolves the normal engine and builds a private replay. No scene-tree nodes are accessed by the worker.
- The visible arena, staging tray, draw reports and scoreboard advance only at their normal commitment or replay times. Future goal arrivals stay hidden.
- The preparation key includes the arena generation, target interval, ordered manual requests, both random-spawn toggles and both release choices. Speed and display settings do not change the fight.
- Changed next-interval inputs discard the obsolete prepared result. An immediate manual addition while stopped also changes the arena generation, since it changes the base world rather than the queue. Only one speculative worker exists; an obsolete running job finishes before another speculative job starts. The ordinary preparation path handles a boundary cache miss.
- At the boundary, inputs become sealed even if preparation is unfinished. Manual requests and choices made during that wait belong to the following interval. A one-shot March is consumed once at sealing and returns to Hold; later choices survive the handoff.
- Pause stops playback. A worker already running can finish while paused. Reset and seat swap invalidate speculative work by generation without blocking on it. Closing joins the workers.

## Validation

Run from the repository root with a native Godot executable:

```bash
"$GODOT_BIN" --headless --path . --script Scripts/Sim/U13LaneLookaheadTestRunner.gd
"$GODOT_BIN" --headless --path . --script Scripts/Sim/U13LaneLookaheadTestRunner.gd -- --benchmark
```

The focused runner compares threaded and serial commitments, complete engine events and worlds, and every stored replay property across twelve future intervals, including both seat orientations and staging on/off. It also exercises edited inputs, rejected limited-monster requests, one-shot releases, cached and unfinished handoffs, pause/resume, reset, seat swap, shutdown, mode changes and goal visibility. Semaphore-controlled slow workers make boundary races reproducible independently of machine speed.

The benchmark runs the same eight intervals at 5× with preparation ahead off/on and compares the complete arena and simulation signature in every interval. Its timing includes the initial preparation wait. Run it with other test processes stopped for a useful comparison.

Results on 2026-09-19: **117 focused checks, 245 sandbox checks, 60 staging checks, 59 preview checks and 3 benchmark checks passed**, with no script errors. The seeded benchmark used the normal lane sandbox, `lane-f881e7ec-e3aebe70`, 15 protected slots, Auto release and random spawns for both sides. The threaded/serial parity fixtures also cover the balance preview rules:

| Eight intervals at 5× | Preparation ahead off | Preparation ahead on |
| --- | ---: | ---: |
| Total runtime | 33.51 s | 24.29 s |
| Time spent waiting for preparation | 9.97 s | 0.22 s |
| Complete per-interval result signatures | Identical | Identical |

These are measurements from this Linux run, not a fixed speed guarantee. The remaining wait includes initial preparation. Detailed signatures and check counts are saved in [the evidence JSON](evidence/U13_LANE_LOOKAHEAD_2026-09-19.json).

Native checks use the available Linux Godot 4.5.1. The Windows launcher remains pinned to the user's Godot 4.7.2; these checks are not Windows visual acceptance.
