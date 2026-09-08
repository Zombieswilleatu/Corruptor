# U13 dense Marching and event recording optimization

## Baseline

After the transaction-fork fix, the local Godot 4.7.2 debug profile measured roughly 1.64–1.66 seconds for a 48-Marcher phase and 392–467 ms for recording its events. Playback sampling remained about 0.22–0.26 ms per sample at that density. These are CPU timings; graphical rendering was not measured.

## Changes

- Marching uses a private phase buffer. Entity snapshots still enter through the existing identity/data validator, including snapshots returned by reactions. The bounded integer movement loop updates owned attributes directly through the buffer instead of recursively normalizing the complete attribute payload for every unit on every tick.
- The buffer maintains stable entity/Marcher ID lists. Tick reads copy only Marchers and do not rebuild/sort the entire registry, copy unrelated cards, or copy spent IDs. Full snapshots remain available at reaction/publication boundaries. Reads and published snapshots are isolated copies.
- Target/contact scans partition the immutable tick snapshot by lane and owner while retaining ID order. Friendly clearance uses independently replaceable row records in the same order. This avoids irrelevant candidates and the linear search to update each accepted position.
- Event logging recognizes identical input objects for public or shared-redacted views. It validates and canonicalizes each distinct payload once, then shares the owned immutable result internally. External inputs never become stored aliases. Public getters and snapshots retain deep-copy isolation; distinct views still receive their own validation.

No speed, contact radius, collision ordering, steering rule, RNG purpose, exchange timing, event format, or save schema changes. Full save validation and per-transform validation remain in place. Serialized event size is unchanged: identical public payloads are still represented in all three snapshot fields, so this does not claim smaller save files.

## Verification

`Reference/U13MarchingBeforeOptimization.gd` is a test-only copy frozen from `cc0939d`; production never loads it. The spatial runner compares the optimized complete world and event tape against that implementation with mixed suits, travel/contact configurations, 6/24 Marchers, reverse registry order and two rounds. Existing contact, spawn, queue, boundary/replay and integration checks remain active.

Event regression cases cover normalization, source mutation, public-view mutation, shared redaction, invalid shared payload rejection, and separate equal payloads. Existing transaction-fork and rollback tests still run.

The foundation suite remains 14 runners, with a direct preflight for the new buffer. Workspace grammar checks and the frozen-source comparison pass. Godot compilation, equivalence checks and speedup measurements remain local verification; no post-change timing is claimed.

Run the normal foundation wrapper, then `run_u13_perf_profile.sh` with the same settings as the baseline. Compare `marching_direct`, `event_log_append` and board/owner costs. Sprite replacement does not change the state-sampling algorithm; animated-sprite drawing/layout/upload costs require separate graphical profiling.
