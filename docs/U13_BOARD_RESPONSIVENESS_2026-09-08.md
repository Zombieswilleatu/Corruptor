# U13 board responsiveness

The dense-field visual check exposed a visible hitch every round, even after the
field thinned. Passing a 30-second test watchdog is not a frame-time guarantee.

## Sources addressed

The board previously ran planning-to-Marching, event processing and playback
construction synchronously on the scene thread. It also requested whole replay
snapshots just to read the round number, copied all historical events before every
hook, and copied the full history for UI/status reads that only needed recent text.

- The round number is now a scalar read.
- The board requests only its last 15 visible history entries. The default full
  player-view API and authoritative saves retain all events.
- Marching capture uses an internal event cursor and copies only newly emitted
  player-visible events. Other hooks no longer project the whole world/history
  just to discover whether new Marching events exist.
- Submission rollback uses the existing trusted owner fork rather than a full
  serialized snapshot/restore.

## Worker boundary

`U13BoardJob` takes an independent mutable session fork. On one worker it validates
the chosen order, resolves through Marching and builds the playback tape. Aftermath
and next-round preparation also use this boundary. The board polls completion and
publishes the candidate only after the thread has finished successfully.

The worker creates no Nodes, textures or rendering resources. Past event rows and
stateless content callbacks are shared read-only, as in existing hook transactions;
mutable match/session containers are forked. UI requests cannot access or change the
worker's candidate. Invalid results preserve the old authoritative state. Repeated
resolution clicks are ignored. Restart during work discards the result after completion;
normal exit waits responsively for completion before closing. External scene destruction
joins the worker so no running thread outlives its owner.

The displayed board stays intact during preparation, with an animated preparation
label. There is still a preparation wait: this change does not make the calculation
instantaneous or implement streaming results into the proposed 15-second production
Marching window. The existing six-second preview playback remains unchanged.

Threading follows Godot's [thread-safe API guidance](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)
and [thread completion contract](https://docs.godotengine.org/en/stable/classes/class_thread.html).
Thread safety checks remain enabled; no project/rendering settings are changed.

## Black-flash report and logging

A separate intermittent flash to black was reported. No cause is confirmed. The
current board/lanes redraw path was inspected; this patch does not claim a graphics
driver or hardware diagnosis or a confirmed black-flash fix.

The board prints submission, worker and result-install times, plus frame gaps above
100 ms tagged with preparation/playback/idle state. These measure CPU-side frame
delivery gaps; they cannot detect a GPU/display black frame directly. Headless test
pauses and an unfocused window can also produce gap messages.

Capture a dense visual run with:

```bash
bash Scripts/Sim/run_u13_board.sh "$u13_godot" --dense \
  2>&1 | tee "$HOME/Downloads/u13_dense_board.log"
```

Check preparation responsiveness, at least three rounds, restart during preparation,
and any black flash. If a flash remains, report whether only the game or the entire
display went black and attach the log.

## Validation

Added coverage for bounded event reads (hidden views, cursors, defensive copies),
exact worker-versus-synchronous dense state/event equality, no partial publication,
duplicate requests, worker rejection and restart discarding obsolete results.
Existing board interaction tests now await the production worker path.

GDScript grammar and shell syntax checks pass in the workspace. Godot 4.7.2 execution,
15/15 foundation results and in-game frame behavior still require local verification.

The [runner timeout follow-up](U13_BOARD_RUNNER_TIMEOUT_2026-09-08.md) separates
dense integration into its own runner and adds a focused `--board` rerun.
