# U13 spatial-query optimization

Follow-up to the measured 1.20-second 48-Marcher contact phase after the phase-buffer optimization.

## Changes

- Friendly center checks use 128-unit spatial cells; enemy contact checks use 256-unit cells. Each query visits nine neighboring cells, then uses the existing exact squared-distance comparison. The cell widths exceed their respective 84/180-unit radii, so no possible collision is excluded.
- Friendly grids are updated after each accepted movement in the same immutable-ID order as before. They reflect already-accepted positions, while targeting still reads the fixed tick-start positions.
- Queued, waiting, held and active-duel units do not perform unnecessary long-range target searches. Mobile opponents share each pair-distance calculation; nearest-target ties retain the original ID ordering.
- Contact candidates are sorted back into immutable-ID order before keyed selection. Bucket iteration order cannot change encounter RNG results.
- Stationary units with an unchanged contact ticket do not repeat identical buffer writes.

The grids are ephemeral query data. Vector2i cell keys never enter world state, saves, event records or RNG keys. Movement speed, positions, damage, queue ordering, tick count and event formats are unchanged.

## Verification

The frozen pre-optimization reference remains untouched. Exact world/event comparison now also includes 48 Marchers, in addition to 6/24, across travel/contact and two rounds. Query-edge checks cover both radii across 128/256-unit boundaries and field edges.

Workspace grammar checks pass. Local Godot equivalence tests and the existing performance profile determine correctness and actual speedup. No runtime improvement is claimed before that measurement. The added dense reference cases do increase spatial-test workload; they are not production code.

## Fifteen-second action window

The user's intended 15-second Marching window provides room for future incremental calculation. This change keeps atomic whole-phase resolution and does not alter the preview's existing playback duration. Moving simulation work across frames would require a private in-progress transaction, cancellation/restart handling, and fixed-tick results independent of frame rate. Simply stretching playback would not remove synchronous calculation latency. Reassess that option after measuring this pass.
