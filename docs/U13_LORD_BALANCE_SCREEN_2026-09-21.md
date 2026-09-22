# Combined build, reserve-aware recipes and Lord balance screen

The known 98-file `Corruptor-V26-synced-performance.zip` payload is now carried
forward from `9f790a9` on `u13-basic-doctrine`. It retains the nine Lord doctrines,
V21.1 Tumler behavior, manual staging, balance patches, movement/targeting
optimizations, Kroni artwork proportions and Valak gravity-well rules. This
checkpoint does not introduce new balance values.

## Recipe fix

The authoritative rules already counted staged Sooge and Sinodek against their
living-copy limits. Python recipe scoring and the older native doctrine only
counted field units. Both now include reserves when checking recipe eligibility.
Reserved bodies remain outside battlefield facts, so this does not treat them
as active fighters or targets. Unlimited recipes remain repeatable; charmed
copies still reserve the original owner's slot.

The fix also applies to ingredient-saving goals, recipe attachment and economy
choices that use the shared recipe book. The shared policy now reports
`U13_COMMON_SMART_CORE_ALPHA_V27_RESERVED_RECIPES`.

The playable-session test checks plan validity before accessing powers/orders,
so a rejected driver plan becomes a reported failure rather than a script error
followed by a misleading zero-failure summary. One existing directed recipe
fixture now gives its synthetic enemy marchers the suit, attack and armor fields
required by the installed staging evaluator; its defense assertions are retained.

## Safely update an already patched Windows checkout

The updater accepts only known base, combined-ZIP or target source hashes. It
refuses unknown changes, staged changes and diverging local commits. It shelves
only the known paths affected by this checkpoint, keeps older stashes and local
backup folders, then fast-forwards the current `u13-basic-doctrine` branch. It
does not create another development branch or pop any stash.

```bash
cd ~/OneDrive/Documents/Corruptor-U13-Doctrine &&
git fetch origin u13-basic-doctrine &&
u13_balance_target=$(git rev-parse origin/u13-basic-doctrine) &&
u13_balance_sync=$(mktemp) &&
git show "${u13_balance_target}:Scripts/Sim/sync_u13_combined.py" > "$u13_balance_sync" &&
python "$u13_balance_sync" --target "$u13_balance_target"
```

Append `--check` to the Python command for a read-only compatibility check.
Unknown edits remain untouched for review. After success, use ordinary Git
updates for subsequent compatible changes. Keep existing stashes; the known
combined patches are already incorporated.

## Run the screen locally

```bash
bash Scripts/Sim/run_u13_lord_balance.sh
```

The launcher discovers PyPy 3.10+ on PATH or in a Downloads `pypy*` directory,
including the extra nested folder in Windows ZIP distributions. It prints the
runtime and refuses a silent CPython fallback. Set `PYPY_BIN` or supply an
explicit executable (including `python` to deliberately use CPython):

```bash
bash Scripts/Sim/run_u13_lord_balance.sh /path/to/pypy3.exe --workers 2
```

Default: 81 complete games, two workers, one game for each ordered pair of the
nine Lords. This includes nine mirrors and 72 cross-Lord games. Every Lord has
16 non-mirror observations (eight opponents, both seats). Reversed seats share
a seed; hidden draws are not forced to follow a Lord when it changes seats.
Both sides use the same current shared planner and ordinary five-castle loadout.
Workers restart after each batch of 12 games total and collect completed game
data between games. Use `--worker-batch-size` to change that bound; zero disables
recycling. Progress includes process ID, resident memory and peak memory.
There is a 40-round cap; an over-cap or otherwise failed game is explicitly
listed and excluded from win-rate denominators.

The runner freezes simulation, doctrine, fixture and evidence source into its
own local snapshot before starting workers. The snapshot pins Git HEAD plus
actual file hashes, including locally changed/new source files. Editing the
original checkout cannot change an in-progress run. It verifies the snapshot
before resuming. The snapshot's local Git metadata uses shared objects; the ZIP
includes all frozen source and its revision/hashes, not Git object storage.

Reports default to `~/Downloads/Corruptor/Balance/u13-lord-balance-<timestamp>`.
The terminal prints that directory, progress and the final ZIP path. ZIPs also
package failed/interrupted results when the runner exits normally through its
cleanup path. A forcibly killed process may not produce a ZIP; its atomic game
records remain in the report directory.

Resume the original frozen build (use the same Python/PyPy runtime):

```bash
bash Scripts/Sim/run_u13_lord_balance.sh --resume "/path/to/report-directory"
```

`--workers` can change on resume. Existing failed game records remain visible;
resume does not silently erase and reroll them. `--repeats 2` creates a new
162-game screen; the default remains 81. `--prepare-only` freezes and checks
configuration without playing games; resume that directory to start it later.

## Evidence and interpretation

- `lord-balance.md`: non-mirror Lord results, matchup matrix, power casts,
  staging commands and rejected-preview counts.
- `lord-balance.json`: machine-readable summary, mirrors, seat wins, win methods,
  reserve counts across decisions and explicit failures.
- `summary.json`: existing survey effect diagnostics, timings and game outcomes.
- `games/*.json.gz`: complete choices, detached observations and operation streams.
- `manifest.json`, `frozen-source.json`, `balance-config.json`: reproducibility.
- `run.log`, `run-status.json`: progress and completion status.
- `performance/*.json`: per-game worker memory, CPU time and total wall time
  including recording and cleanup; kept separate from semantic checksums.

For a short engine benchmark against the latest completed report:

```bash
bash Scripts/Sim/run_u13_lord_balance.sh --benchmark
```

This runs three saved games on the old frozen source and the current source,
sequentially with one worker, and requires identical final-state checksums.
It excludes bot planning and trace recording. Use `--report` with a report
folder if it is outside the normal Downloads location. Reports go to
`~/Downloads/Corruptor/Performance`. Resuming an older campaign always retains
its frozen code, including the old worker policy; start a new campaign to use
these performance changes.

Behavior counts include mirror games; win-rate tables exclude them. A matchup
has only two observations in the default screen. These are leads for targeted
follow-up, not reliable matchup rankings or balance verdicts. Identical bots do
not eliminate differences in how well their Lord modules exploit each kit.
The current staging release rule is heuristic; this fix changes copy-limit
eligibility, not the broader tactical treatment of reserve timing.

## Verification

- 40 focused Python methods passed, including both limited monsters, release/
  removal, charm ownership, unlimited recipes, all Lord openings, survey
  coverage and summary denominators.
- 21 native reserved-recipe checks passed.
- The saved round-seven native driver failure now returns an admitted plan
  without mutating the saved state.
- The playable-session fixture passes, including exact independent resolution
  and save/restore comparison.
- Four updater tests cover fast-forward, prior-stash/unrelated-file preservation,
  CRLF source, idempotence, unknown-edit refusal, staged-edit refusal and dry run.
- The launcher prepares the exact 81-game case list without starting a campaign.
- One actual frozen-source Gremory/Deimos case completed in 17 rounds (136.97
  seconds on local CPython), with validated game records, summary generation and
  ZIP packaging. Resume refuses edited snapshot source. This single game is a
  runner check, not balance evidence or a throughput forecast.

Native checks here use Linux Godot 4.5.1. Windows gameplay remains Godot 4.7.2;
this is not a new rendered acceptance test or a measured performance claim.
