# Current victory baseline: 15 Souls / 7 personal Tears

Adopted by Jeremiah on 2026-09-23, until explicitly changed.

- Ritual: at least 15 Souls and a living Lord.
- Dominion: at least 7 personal Tears, strictly more than the opponent, and total Veil at least 12. No living Lord required.
- Existing victory precedence, tempo round-25 settlement, and legacy Final Collapse remain unchanged.
- Godot authority: Scripts/Sim/U13Victory.gd. Python authority: Scripts/Sim/u13_pysim/lifecycle.py.
- New Lord surveys record these requirements in their manifest. Start a fresh run from the updated checkout. Resuming an old frozen run intentionally retains its old rules.

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

This commit changes victory requirements on the current remote branch. That branch still has the commitment suit penalty and attack thresholds 13/17/21. Preserve the separate local printed-value and 15/19/23 patches when assembling the next balance build; do not overwrite newer work with the frozen test snapshot.

## Verification

From the repository root:

```bash
PYTHONPATH=Scripts/Sim python -m unittest u13_pysim.test_victory_baseline u13_doctrine.test_closing u13_doctrine.test_rites
```

Native boundary and UI fixtures updated: U13VictoryTestRunner, U13VeilWheelTestRunner, U13UIFeedbackTestRunner. Godot execution requires a local Godot installation.
