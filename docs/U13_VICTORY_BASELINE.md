# Current victory baseline: 15 Souls / 7 personal Tears

Adopted by Jeremiah on 2026-09-23, until explicitly changed.

- Ritual: at least 15 Souls and a living Lord.
- Dominion: at least 7 personal Tears, strictly more than the opponent, and total Veil at least 12. No living Lord required.
- Existing victory precedence, tempo round-25 settlement, and legacy Final Collapse remain unchanged.
- Godot authority: Scripts/Sim/U13Victory.gd. Python authority: Scripts/Sim/u13_pysim/lifecycle.py.
- Fresh Lord balance runs explicitly enable the tested split-Ward/tempo setup, and record these requirements and shared balance values in their manifest. Start a fresh run from the updated checkout. Resuming an old frozen run intentionally retains its old rules.

## Evidence

Uploaded local run: u13-s15-d678-20260922-230113.zip.
243 games completed successfully; record checksums and all 2,823 source hashes verified.
Same 81 ordered Lord matchups and seeds per setting, one seed per matchup.

| Souls | Tears | Mean rounds | Median | Ritual | Dominion | Round-limit decisions |
|---|---|---|---|---|---|---|
| 15 | 6 | 15.1605 | 14 | 28 | 52 | 1 |
| 15 | 7 | 17.0494 | 17 | 44 | 35 | 2 |
| 15 | 8 | 18.3086 | 18 | 55 | 21 | 5 |

At 15/7, 28/81 games continued after both sides had no nonruined castles, ending a mean 5.43 rounds later. Deimos rebuilding can interrupt castlelessness. Assess late-game enjoyment in human playtests.

Evidence used frozen V29 doctrine, printed commitment values, Veil attack bonuses 15/19/23, and Dominion Veil gate 12. It does not certify subsequent Lord tuning.

The shared balance baseline also uses full printed card values for Hunt, Siege and Ward, with no commitment suit penalty or pair bonus in GuardWork games. Tempo attack bonuses are +1/+2/+3 at Veil 15/19/23. Breach arrivals and their protection thresholds remain separate and unchanged. Existing split Ward, Ward recruitment at 2:1 without monster summons, castle/pair rules, round-20 decisive Souls and round-25 settlement already match the tested source. Individual Lord tuning is preserved separately; this integration does not revert newer doctrine to the frozen V29 snapshot.

## Verification

From the repository root:

```bash
PYTHONPATH=Scripts/Sim python -m unittest u13_pysim.test_victory_baseline u13_pysim.test_shared_balance u13_doctrine.test_closing u13_doctrine.test_rites
```

Native boundary and UI fixtures updated: U13VictoryTestRunner, U13VeilWheelTestRunner, U13UIFeedbackTestRunner. Godot execution requires a local Godot installation.

Shared-balance integration validation: 60 local Python tests passed, including all four suits at values 1–5 through real Hunt/Siege/Ward resolution and bot payments, pair-bonus removal, victory and tempo boundaries, Lord-runner setup flags, and existing Orias/closing/rite regressions. Godot execution was unavailable; native printed-commitment and Veil-wheel tests are supplied. No new full balance games were run for this integration.
