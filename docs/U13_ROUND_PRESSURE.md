# U13 automatic neutral Tear pressure

User rule, 2026-09-13:

| Round completed | Neutral Tears added |
| --- | ---: |
| 1-12 | 0 |
| 13-20 | 1 |
| 21 onward | 2 |

Apply once in Aftermath, after ordinary round effects and Vacant Throne rewards,
before the existing victory evaluation. Personal Tears are unchanged. Emit one
`NEUTRAL_TEAR_CREATED` event with source `RoundPressure` and the correct amount.
Veil threshold penalties remain disabled. The drift metadata and playable
help text describe the newly active rule.

The existing victory thresholds and precedence are unchanged: Ritual at 12
Souls with a living Lord, then Final Collapse at 26 total Tears, then Dominion
at total Veil 12 with at least five personal Tears and a lead over the opponent.
Starting with zero Tears and gaining none from other sources, automatic pressure
alone reaches eight at round 20 and 26 at round 29. Consequently a fresh game
must finish by the end of round 29 under the current nondecreasing neutral-Tear
rules. Ordinary play can end it earlier.

## Compatibility

Victory policy is now `U13_VICTORY_V2_ROUND_PRESSURE`. This deliberately changes
the match policy ID: older saves/checkpoints are rejected instead of silently
combining a pre-pressure history with the new rule. Start fresh matches. The
42 completed old-rule results remain useful old-rule evidence; do not combine
them with the new campaign as one ruleset.

The existing checked-round ledger prevents duplicate Aftermath calls from
adding pressure again. The new tears and the terminal result are included in
the ordinary atomic hook and save/replay path.

## Verification

`U13RoundPressureTestRunner.gd` plays 29 actual rounds with both players passing
combat/development and with no offensive Castle effects. It checks exact
cumulative neutral Tears every round, unchanged personal Tears, one event per
eligible round, and no premature win. It verifies planning and settled saves,
exact replay and duplicate rejection at rounds 12, 13, 20, 21 and 29. A separate
case checks that a new neutral Tear can trigger Dominion at the same Aftermath.

Local Godot 4.5.1 diagnostic: all 227 round-pressure checks and all 226
basic-doctrine checks passed, including explicit rejection of an old no-pressure
policy snapshot. The fresh
Kanifous/Kalligan seed 35 finished at round 21 by Final Collapse, winner Kalligan,
without errors (single-conductor legality). The older-rule continuation had
ended in round 39 with Kanifous winning by Dominion; this is a rule change, not
a same-policy performance comparison.

The doctrine preflight now includes the pressure suite (six suites total):

```bash
U13_DOCTRINE_FIXTURES_ONLY=1 bash Scripts/Sim/run_u13_doctrine.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

Reports are packaged as a fresh ZIP directly in Downloads. Windows acceptance
of the new rule is pending.
