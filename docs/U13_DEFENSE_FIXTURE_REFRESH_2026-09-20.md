# Reviewed early-defense expectations

The two deferred fingerprint failures are closed. This refresh changes saved
expectations and documentation only. The game, doctrine, fixture setup, recorded
moves, opposing plans and defense assertions are unchanged.

Current replay: `4c2082c1516173149397333c7c89643e7e78327b`.
Engine source SHA-256: `b8d45302a13f9341e687f6236b86a3279d5bdf4a0aa1e8d754ac7941bdc2db7d`.

## Review performed

The saved prefixes were replayed under the historical source at `e5ef031` and
under current rules. Both historical observations reproduced the old expected
fingerprints. Current observations were compared before updating the pins.

- **kroni_odradek_00:** only `data.monsters.version` changes, from
  `U13_MONSTERS_V11_VOID_CREATOR_IMMUNITY` to `U13_MONSTERS_V17_DOTRA_SHROUD`.
- **kroni_valak_00:** the current replay has six additional surviving friendly
  marchers: Lemek, Kurchin, one Wright and three Penitents. A Wright Wall survives,
  the dead-Lemek pool is absent, positions/armor/navigation differ, and Neutral
  Tears are one rather than two. The recorded second-round plan casts Gravity
  Orb; its redesigned mechanics are among the intervening rule changes. This is
  a reviewed current-rule expectation, not merely a metadata substitution.

The previous hashes and their existing replay/source identity were appended to
`view_sha256_history`. Updated metadata identifies the current replay and explains
the differences. Original setup, prefix, opposing plans, player seat and protected
castle were compared explicitly before and after the edit and are identical.

## Behavior remains the gate

| Replay | Recorded plan: Keep Integrity | Current bot: Keep Integrity | Selected monster |
|---|---:|---:|---|
| Kroni–Odradek | 0 | 1 | Kurchin |
| Kroni–Valak | 0 | 3 | Fyra |

The test still checks exact planning-state identity, legal replay operations,
no mutation during planning, Keep loss under the recorded plan, Keep survival
under the current bot and a selected monster. No assertion was removed, skipped
or relaxed. The recorded opponent's plan is supplied only after the bot chooses.

Verification: **all 9 tests in `u13_doctrine.test_defensive_plans` pass**, including
both cases, in about **1.9 seconds** under CPython. No long campaign was run.

```bash
PYTHONPATH=Scripts/Sim python -m unittest u13_doctrine.test_defensive_plans
```
