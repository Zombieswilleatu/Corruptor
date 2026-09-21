# Nine-Lord integration audit at CommonSmartCore V26

The playable opponent and the Python comparison runner use different planners. `U13PlayableSession.gd` calls native `U13BasicDoctrine.gd`, version `U13_BASIC_DOCTRINE_V8_PUBLIC_GUARDS`. The recent Lord-specific work runs in Python `CommonSmartCore`, version `U13_COMMON_SMART_CORE_ALPHA_V26_ODRADEK_FIELD`. Publishing those Python changes did not install V26 as the playable opponent.

This checkpoint adds a bounded integration replay, fixes three stale integration expectations, and corrects the full-game setup explanation. It does not port the planner, change tactics, tune power strength or establish a win-rate improvement.

## Concrete fixes

- Python's saved `rules_hash` still identified an older declared-power roster. An exact comparison of all native and Python rule dictionaries found no content difference. The pin is now `8466e29e676ea503c6e7f848a3fc9ed264c48b3111e773f9fd8768ba4fbe42b0`, with a regression that derives the fingerprint from the independently maintained Python roster. Native replay also compares the complete dictionaries. A roster fingerprint does not identify every rule implementation.
- The native public-Guard fixture indexed the pre-draw opening hand, which is now empty. GDScript raised an index error and skipped Guard checks even though the runner printed zero assertion failures. The fixture explicitly draws two real cards before deploying them and checks each draw. `--fixtures-only` now runs the directed native checks without repeating nine opening resolutions.
- The playable worker retires completed animation samples after playback. Its reference fixture retained those samples, producing a full-state mismatch. Both paths now cross the same retirement boundary before strict comparison. Semantic events, resources and the rest of the snapshot are still compared; the fixture also verifies that samples were actually retired.
- Full-game setup text now describes free starting Lords, the normal first-round draw without an extra setup hand, and enabled permanent Breach arrivals. No gameplay configuration changes accompany the text.

Existing Python snapshots retain their recorded identities; they are not rewritten. This fixes newly created snapshot metadata. The nine saved defense replay tests still pass unchanged.

## Bounded checks

57 Python tests passed, covering opening identity, all-Lord legal/deterministic planning, closing preference, actual Dominion settlement, Invocation, defense and power/plan coordination. All nine saved defense expectations pass. The native directed checks pass with no script errors: 94 Basic Doctrine assertions, 17 playable-session assertions and 30 history/retirement/Supplicant assertions.

The new `run_u13_integration_smoke.py` runs nine cyclic Lord pairs for four rounds each. Every Lord appears once in each seat. It checks action admission, preview rejection, generation/retention/complete-plan/preview budgets and selection of an available resilient closing plan. It can export exact typed inputs, operation results, opening snapshots and full round-end snapshots for `U13IntegrationReplayTestRunner.gd`.

| Pair | Rounds | Decisions | Operations |
|---|---:|---:|---:|
| Gremory / Deimos | 4 | 8 | 102 |
| Deimos / Humbaba | 4 | 8 | 103 |
| Humbaba / Kalligan | 4 | 8 | 102 |
| Kalligan / Orias | 4 | 8 | 103 |
| Orias / Odradek | 4 | 8 | 100 |
| Odradek / Kroni | 4 | 8 | 103 |
| Kroni / Valak | 4 | 8 | 102 |
| Valak / Kanifous | 4 | 8 | 103 |
| Kanifous / Gremory | 4 | 8 | 103 |
| Total | 36 | 72 | 921 |

The Python run had zero invalid operations or rejected previews, and 44 casts spanning 16 power types. The initial run took 64.24 seconds; rerunning after the metadata correction took 93.12 seconds while other verification was active. Per-pair reports, actions, cast counts and budget counters were identical before and after the correction.

Native exact replay passed all nine cases: 921 operation results, nine opening snapshots, 36 complete round-end snapshots/outcomes and the declared-power roster, totaling 1,003 exact comparisons. There were no rule-resolution differences in this scope.

One intermediate trace file was incomplete; the replay correctly rejected it instead of reporting success. The final trace was rebuilt by replaying the original 921 explicit inputs through the current Python engine. Every operation result and complete checkpoint matched the original run after the declared-rule identity correction. The complete 941-record stream then passed Godot replay. The exporter now writes to a temporary file and publishes the final path only after the finish record, preserving any previous trace if generation fails.

Native checks use local Godot 4.5.1 headless. They do not establish rendered Windows 4.7.2 acceptance. Explicit-input parity checks rule resolution; they do not mean native Basic Doctrine selects the Python plans. The existing playable-session fixture separately checks the animated production adapter against the native conductor.

## Behavior observations and limits

No smoke decision reached the 32-complete-plan or eight-preview ceiling. The four retained combat candidates were filled in all 72 decisions, and several specialized generators reached their own limits. This shows that pruning is active, not that a better plan was discarded. The directed closing and coordination regressions remain the evidence that specific important options survive those limits; the short smoke cannot prove exhaustive tactical coverage.

Odradek actually resolved two Allegiance Shifts; five Guards were devoured, and both Ravenous casts earned rewards. Two Gravity Orbs produced 117 damage events and three core kills. Projection and several less common powers were not exercised by these opening games, so their existing directed fixtures retain that scope. Cast frequency alone is not a reason to force a power or buff it.

The main remaining integration gap is the native planner. For example, native Orb scoring still uses cluster counts, native Projection proposes enemy Guards only, and native Consume lacks V24's mandatory opposite-attack-lane selection. These are visible source differences, not conclusions inferred from short-game win counts.

The next implementation milestone should be a native CommonSmartCore adapter with shared public-observation and decision fixtures, preserving hidden-information boundaries and the existing deterministic work limits. First reproduce selected complete plans on the same public states; then switch the playable opponent. Avoid a mixture of copied Lord scorers atop the old greedy planner: V26 depends on complete-plan coordination, candidate reservations and closing priorities as well as individual power scores.

## Reproduce

From the repository root:

```bash
PYTHONPATH=Scripts/Sim python -m unittest u13_pysim.test_opening u13_doctrine.test_common u13_doctrine.test_coordination u13_doctrine.test_closing u13_doctrine.test_rites u13_doctrine.test_defensive_plans
python Scripts/Sim/run_u13_integration_smoke.py --trace /tmp/u13-integration.exact.jsonl
"$GODOT_BIN" --headless --path . --script Scripts/Sim/U13IntegrationReplayTestRunner.gd -- /tmp/u13-integration.exact.jsonl
"$GODOT_BIN" --headless --path . --script Scripts/Sim/U13BasicDoctrineTestRunner.gd -- --fixtures-only
"$GODOT_BIN" --headless --path . --script Scripts/Sim/U13PlayableSessionTestRunner.gd -- --fixtures-only
"$GODOT_BIN" --headless --path . --script Scripts/Sim/U13SupplicantHistoryTestRunner.gd
```

Set `GODOT_BIN` to the installed Godot executable. Check both the final success summary and absence of `SCRIPT ERROR`/`ERROR:` output: a Godot zero exit status alone did not detect the original Guard fixture error. These are bounded correctness checks, not the long balance comparison runner.
