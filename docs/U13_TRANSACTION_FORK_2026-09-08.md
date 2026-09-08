# U13 internal transaction copying

## Measured problem

Two local Godot 4.7.2 debug profiles confirmed increasing match-history cost on an i7-1165G7. Board planning through Marching reached 8.06 and 8.46 seconds in round 3. With six travel Marchers, round-3 restore validation took 567 and 584 ms; non-Marching hooks and submissions totaled 9.32 and 10.56 seconds.

Every internal preview/hook cloned the match by calling `restore(snapshot())`. That repeatedly copied, normalized and validated the complete historical event payload, including prior movement tapes. Serialized history grew by approximately 0.5 MB per round in the six-Marcher travel fixture.

## Change

`U13Match._clone()` now copies its already-owned state directly:

- World, presentation world, submissions and combat orders are deep copies.
- Runtime cursor/log, pending effects, persistent effects, cooldowns and entity registries use private `_fork()` methods. Mutable records, nested declarations and spent-ID dictionaries are copied; scalar clocks and reentrancy state are retained.
- Event logs copy their private outer row array. Historical rows are immutable under the event-log API: `append()` copies incoming data, public reads return deep copies, and `restore()` replaces the row list. Forks can append independently while sharing immutable historical payloads.
- Live `_consistent()` checks remain in the internal clone path. Incoming declarations, returned world transforms and new events still take their existing validation paths.
- External `restore()` is unchanged, including version, numeric, world, component, historical-event and cross-component validation. There is no unchecked restore option accepting caller-supplied dictionaries.
- Commit still adopts the successful candidate only after hook execution; failed candidates are discarded.

This is a copying optimization, not a rules/timing/RNG or save-schema change. Pure content callbacks retain the same ownership model as before. Event row sharing assumes no future method mutates an existing private row; such an operation would need an isolated replacement.

The outer event row array still takes O(history rows) reference copying. The fix removes repeated traversal of every nested historical tick payload; it does not claim constant-time cloning at unlimited match lengths.

## Regression coverage

The existing match runner now compares internal forks with validated restored state across three rounds and each hook boundary, exercising submissions, pending/hidden outcomes, active persistent effects, cooldowns, runtime and identity state. It probes nested mutable-state isolation and event append/read/restore isolation. Existing later-resolver-failure rollback and retry checks remain active.

The foundation suite remains 14 runners. No watchdog increase or validation bypass was added. U12 and main scenes are unchanged.

The performance runner adds `internal_transaction_clone` alongside snapshot/restore costs at each history checkpoint. External restore timing is expected to remain similar: the optimization removes restore from routine internal transactions rather than weakening save validation. Compare owner/board round timings and the new clone metric against history size.

Workspace verification: grammar parsing, audit of copied state fields, and source comparison confirming external restore logic unchanged. Godot 4.7.2 correctness tests and measured speedup remain local verification; no post-fix runtime numbers are claimed.

Run the normal foundation wrapper, then the same standalone performance wrapper. Compare the new log with the two baseline runs; the density-only Marching cases were not optimized in this change and showed variability between baseline runs.
