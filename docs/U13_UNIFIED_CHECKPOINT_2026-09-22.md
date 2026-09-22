# Unified playable checkpoint — 2026-09-22

Combines Windows checkpoint `23cc2613fdb37ee38ae0ac9f04d0571748b67bca`
with the validated Kroni release `0390f25ed868413d38bcdc8378d4a403fb990a7b`.
The working branch remains `u13-basic-doctrine`.

## Preserved work

- Full Kroni kit, neutral bouncing Consume, eleven-enemy Ravenous reward,
  and V29 Hunger-aware Hunt valuation.
- Split Ward, current performance changes, monster tuning and targeting.
- Staging capacity 15, birth hold, same-round release of the selected cohort,
  overflow handling and legacy queued-command compatibility.
- Opening march and playback, continuous effect clocks and round-aware Rout.
- Wright pair work split: five construction / three repair.
- Grimoire wording, modal sizing and the previously untracked hand recipe hints.

Resolved 26 conflicted paths individually. Combined the newer opening-phase
monster timing with lazy target-list materialization; removed one duplicate
Monsters declaration introduced by Git's otherwise automatic merge. Retained
the executable bit on the lane balance launcher.

## Validation

- 71 focused Python tests passed (Ward, doctrine, Kroni and development).
- Seven native playable-tempo release suites passed.
- Four exact paired Python/Godot cases passed, including worlds, events and
  native snapshot restoration.
- Native four-round staging replay: 134 assertions, zero failures; independent
  Python replay matched all 95 operations, world, events and clocks; rule hashes
  matched as well.
- Native GuardWork, GuardConsume, Kroni and KroniBoard suites passed.
- Shared playable planner: 23 cases / 253 checks, zero failures.
- Godot 4.7.2 project import completed on retry with two CPU cores after an
  initial asset-import crash. No generated import metadata is committed.
- git diff --check passed.

The earlier 128-game balance screen belongs to its recorded source, before the
newer local opening-march changes. It is preserved as historical evidence, not
claimed as a new balance study of this combined build.

## Consolidation scope

The supplied active checkout and remaining active source file are integrated.
The supplied backup directories are rollback copies, preserved locally and
ignored by Git. The supplied older U13 worktree commit tips are already ancestors
of the validated release. Historical main contains old sprite-asset commits;
those branches and their alternative assets are not deleted or blindly merged.
Uncommitted changes inside other Windows worktrees were not included in the
upload and cannot be certified from this package.

The repair installer completes the existing merge with this exact tested tree,
then pushes `u13-basic-doctrine` without force. If the remote has advanced
incompatibly, the push fails safely and the local merge remains saved.
