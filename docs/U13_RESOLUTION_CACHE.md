# Reusing unchanged-world validation

This performance-only patch follows 217565b on `u13-basic-doctrine`.
It does not change the doctrine, information policy, rules, or save format.

## Finding and change

A round-15 checkpoint microprofile separated copying from validation. The native
world copy took about 0.36 ms; a fully validated match clone took about 45 ms,
almost all of it consistency checks. Reinstalling the same world took about
41 ms. Content hooks returning an unchanged world paid the latter cost again.

The GameContent factory now opts into retaining the last successfully validated
world as lossless canonical Variant bytes, plus an isolated entity registry.
An identical install with the same validator reuses that acceptance. Different
state still goes through the original complete world validation. The raw data
boundary always runs first. The key preserves types, including booleans versus
integers; differing dictionary insertion order can only cause a cache miss.

The cache holds one world, never event history or a growing set of prior worlds.
Forks share its private, immutable entry; mutable worlds and registries are
separate copies. Successful validation replaces the entire entry. Custom match
owners default to uncached validation because their validators need not be pure.
External restore starts a fresh transaction and validates its supplied worlds;
it cannot inherit a previous live owner's acceptance. Identical presentation
and authoritative worlds may reuse validation within that fresh transaction.

Temporal consistency checks still run at every hook. Sealed loadouts, retired
entity resurrection, identity history, event projections, and authoritative
submission checks retain their original boundaries. No hidden guard information
is added to bot inputs. Cache state and timing counters are never serialized.

## Local diagnostic results

Godot 4.5.1 Linux, one engine process, compared against the frozen 217565b world
installer using identical plans and states. These are execution-only resolution
times; planning, state comparison, and save work are outside the timed interval.
They are not Windows 4.7.2 acceptance results or whole-campaign speedup claims.

| Sample | Original | Cached | Less resolution time |
| --- | ---: | ---: | ---: |
| Nine opening pairs, summed | 16.428 s | 14.582 s | 11.2% |
| Uploaded game-079 round 15, median of three | 3.078 s | 2.658 s | 13.6% |
| Uploaded game-039 round 25, median of three | 3.061 s | 2.739 s | 10.5% |

The complete 15-case sample took 34.975 s originally and 31.206 s with caching,
10.8% less resolution time. It exercised 240 hooks, with 105 cached installs and
175 full validations. Execution order alternated for the checkpoint repeats.
One noisy repeat showed a smaller gain; treat these as bounded local evidence.

The directed suite passed 451 checks before report-file checks: exact plans and
read-only previews, accepted submissions, state and acknowledgement equality
after every hook, final saves and outcomes, and both player histories. Malformed
input probes cover numeric types, non-string keys, fixed-point fractions,
duplicate/missing entities, and invalid card zones. Other probes cover cache
isolation, validator replacement, failed-restore atomicity, identity history,
and private event projections. The existing 220-check doctrine suite and
27-check committed-Hunt suite also passed, including concealed-guard input/plan
invariance and Hunt while the acting player's Lord is banished.

## Focused Windows gate

After the current campaign finishes, fetch this branch in the doctrine worktree
and run `Scripts/Sim/run_u13_resolution_perf.sh` with the usual Godot 4.7.2 stable
executable. The script compares all nine opening pairs against the old installer,
checks rejection/isolation fixtures, and writes `resolution.json` and
`resolution.log` under the printed Downloads report directory. It does not start
another full campaign. The watchdog is 600 seconds; timing differences themselves
are reported rather than used as a flaky pass/fail threshold.

For additional saved-state diagnostics, invoke `U13ResolutionCacheTestRunner.gd`
directly with `--output=/path/to/report.json` and one or more
`--checkpoint=/path/to/game-NNN-checkpoint.json` arguments. Each checkpoint is
tested three times and must contain the normal `save_json` envelope field.

Campaign hook timing rows now include `world_cache_hits` and `world_validations`.
These count world-install attempts during that hook's dispatch, not other
consistency checks or time. Remaining resolution cost includes those consistency
checks and actual content execution. This patch does not justify expecting
multi-fold overall speedups.
