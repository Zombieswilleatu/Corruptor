# U13 targeted simulation performance pass

The canceled Windows run supplied `game-000-checkpoint.json`, Gremory/Gremory at
the start of round 7, from the `82e5e2cf-e69de29b-r80` archive. The supplied archive
contains this checkpoint, not the separate round-14 game mentioned in chat.

## Findings

The six completed rounds contain 1,200 authoritative `MARCHING_TICK` rows, exactly
200 per round, and six Marching start/finish pairs. Counting strings in the
serialized payload produces 3,600 ticks because each public event is stored as
the authoritative event plus two player views. This is three stored copies, not
three simulation passes. The verification batch independently simulates two
conductors per round for replay; only the primary history is checkpointed.

The event history occupies 10,081,248 bytes; position ticks account for 9,421,500
bytes (93.46%). The live world itself is 51,320 bytes with 88 entities. Growing
full history is repeatedly copied, validated, encoded, restored and compared.

Victory is implemented and checked after Aftermath. Earlier diagnostic matches
reached legitimate Dominion wins; this interrupted match is not victory evidence.
The round-80 limit remains censoring, never an invented win.

## Changes

- Power-domain filtering still stages the authoritative declaration identity,
  cooldown, resource, target and queue checks. It then uses the existing exact
  bulk order predicate for the empty order, avoiding a full temporary order
  transaction per candidate. Missing/malformed adapters retain the old fallback.
  Final complete plans and actual submissions still use full transactions.
- Entity registry restore owns one validated, normalized copy instead of
  repeatedly validating/copying each entity through `create()`. Canonical IDs,
  owners, duplicates, used-ID history and atomic rejection stay checked.
- Batch V2 explicitly opts into `U13_BATCH_EVENTS_V1`, omitting only
  `MARCHING_TICK` and `KRONI_ACTOR_TICK` from recorded history. Movement, contacts,
  combat, arrivals, deaths, artillery and all other state changes still execute.
  The mode is encoded in the policy and survives submission and save/restore.
  Normal conductor startup continues to record presentation samples.
- The batch logs elapsed time and per-round timing breakdowns. Reports include
  those diagnostics separately from deterministic state and hashes.

## Reproduction and evidence

Local diagnostic runtime: Linux Godot 4.5.1, same container/CPU for sequential
before/after measurements. Windows Godot 4.7.2 remains authoritative. These are
single-checkpoint diagnostic measurements, not a hardware-independent benchmark
or a prediction of 100-game completion time.

| Same saved round, full event mode | Before | After planning/registry fixes |
| --- | ---: | ---: |
| Both primary bot plans | 17.76 s | 7.36 s |
| Sum of measured profile phases | 34.99 s | 21.79 s |

The profile generates both primary plans and resolves primary plus restored
replay. The full batch additionally generates the replay plans independently.
The original primary Marching phase was 0.90 s, much smaller than planning.
The final full-state hash and both complete plans match the unoptimized baseline:
`577ae156759d02701eb2ed75c73fe7b98f06845c519314a1f55c791d33881142`.

An additional full/compact comparison produced identical plans and complete
snapshots after removing only the declared profile suffix and two sample event
types. Its gameplay hash is
`eac9a3a336b1fbe23bb3dc449fe3fc6499412ab3ec874d2bb65e2fca1ed3dc5f`.
Both modes independently passed exact save/replay. End-of-round save strings
were 16,710,314 characters full versus 1,448,790 compact (91.33% smaller).
Those two comparison runs shared CPU concurrently, so their elapsed times are
not used in the sequential timing table above.

`U13PlanningPerformanceTestRunner.gd` compares complete power domains and seeded
plans with the old implementation for all nine Lords, malformed candidates and
fallback adapters. It also compares entity restore against the old implementation
on valid, normalized and malformed snapshots and verifies nested-data ownership.
The batch harness compares two rounds in full and compact modes, including exact
save/restore and continued play. Both checks run automatically before workers on
the pinned Windows wrapper. Windows acceptance and the 100-game gate are pending.

Local verification passed 20 diagnostic suites: the 17 simulation suites in the
game foundation gate, Match, Determinism, and PlanningPerformance. The batch
harness also passed. A real one-round compact batch run produced a replay-verified
censored report with phase timings; it is a reporting smoke test, not a victory.

For a short checkpoint diagnostic, run Godot headless with the project path and
`--script Scripts/Sim/U13CheckpointProfileRunner.gd -- --checkpoint=<json-path>
--output=<report-path> --compact-events --compare-reference`.
It resumes one saved round, writes timings after every phase, compares legal
power domains with the prior implementation, and verifies exact save/replay.
Omit `--compare-reference` for timing without the deliberately slow reference.
Omit `--compact-events` to profile unchanged full presentation history. This
explicit diagnostic conversion does not silently alter ordinary restored saves.

Keep targeted regressions as the normal loop. PySim parity remains the future
path for large simulation campaigns; this pass does not add strategic bot doctrine.
