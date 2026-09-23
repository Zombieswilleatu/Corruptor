# Shared opponent memory

The live game and Python simulation now use the same history-aware CommonSmartCore. This changes doctrine only. The 15-Soul / 7-Tear baseline, marching recruitment, Lord abilities, and return-round victory rules are unchanged.

## What it learns

The trusted observation boundary projects the last six completed rounds of the opponent's public combat commitments: action, lane, card count, printed strength, and Ward strength. It omits card identities, targets, recipes, private hands, current sealed orders, and simulation RNG. Split attack/Ward reveals are merged into one record per round. No-action rounds dilute the history.

Only previously revealed events count. Loading an existing save reconstructs the window from its event log; restarting the Python worker does not erase it. Nothing is learned across matches. Both seats use the same projection.

At least two large commitments (four or more cards, at least 12 printed strength) are required. They must represent at least half the recency-weighted window. Recent rounds weigh more; three quiet rounds after a sustained rush disable the response. The name “aggression” describes observed commitments, not knowledge of whether the opponent used their entire hidden hand.

Historical lane weights keep a nonzero prior in both lanes. Learned strength probes use the recent attack average, bounded to 9–30 printed strength, with a three-point margin either side. Current public Supplicants and Veil attack bonuses are added separately, so past bonuses are not counted twice.

## What changes in planning

Repeated heavy attacks add a defensive risk score for castle damage/destruction, Guard losses, Pillage, and banishment. Banishment includes the existing return-Lord utility; castle loss includes a utility allowance for the opponent's two-Soul reward. This is a bounded heuristic, not an exact win-probability model.

Useful Guard and Ward candidates receive a ranking allowance so they survive early pruning. That allowance is removed before complete-plan scoring to avoid duplicate credit. Up to four existing Ward candidates get reserved complete-plan slots. The same 32-plan / eight-preview limits still apply. Split Ward plus attack remains available; there is no forced Ward or hard prohibition on attacking.

The existing fixed defensive scenarios remain as a fallback. Unmodeled resummon/sacrifice/terminal projections retain their existing handling. Artillery, enemy powers, movement and current hidden commitments are not simulated by these defensive stress cases.

`CommonSmartCore(opponent_memory_enabled=False)` disables the learned response for paired comparison, while retaining the same observation and game rules.

## Verification

- Five focused Python tests: visibility boundary, quiet-round decay, persistence, deterministic bounded selection, and actual legal combat in which the adaptive defense prevents banishment.
- Native/Python projection parity: 72 checks, including both perspectives across all 12 rounds of the supplied saved match.
- Native restoration of that match preserves the same six-round memory after another save/restore.
- Native worker receives the history and admits a legal plan.
- Native diagnostic runtime here: Godot 4.5.1. The production launcher remains pinned to 4.7.2; verification on that Windows runtime remains outstanding.
- The existing common/defensive/split-Ward suite ran 43 tests. Three historical assertion failures reproduce identically on the untouched parent: one old Dominion threshold fixture and two historical defensive replay subcases rejected before planning. They are not silently skipped or counted as passing.

## Exploratory full-game screen

Regular full-game rules, including marching, against an attacker that allocates all available combat cards to Hunt/Siege, deploys no Guards, uses no Ward or Lord powers, and delays resummoning until Ritual is funded. Both arms use identical seeds and seats. This is a scripted stress test, not a replay of the human match.

| Defender | Wins without memory | Wins with memory |
|---|---:|---:|
| Gremory | 0/2 | 1/2 |
| Humbaba | 1/2 | 1/2 |
| Valak | 2/2 | 1/2 |
| Orias | 1/2 | 2/2 |
| Kroni | 1/2 | 1/2 |
| Total | 5/10 | 6/10 |

Ward rounds increased from 32 to 52; recorded Ward saves from 16 to 18. Attack rounds remained frequent (115 versus 107). This confirms adaptation, with mixed match outcomes. One seed per Lord cannot establish a reliable win-rate improvement; Valak regressed on one seat and Kroni's winning seat changed. Do not tune Lord balance from this sample.

Supplicant-sourced Tears were eight without memory and nine with it. This small difference does not establish that reducing attack recruitment would help. Test recruitment separately if pursuing that rule change.

The round-of-return Ritual finish remains possible. This doctrine change does not close that rules interaction.

## Local commands

From the current project folder, run the focused Python checks:

```bash
python Scripts/Sim/run_u13_opponent_memory_checks.py
```

Add native parity using the installed Windows executable:

```bash
python Scripts/Sim/run_u13_opponent_memory_checks.py --godot "C:/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

Run 12 games (three Lords, both seats, memory on/off), using three workers:

```bash
python Scripts/Sim/run_u13_aggression_probe.py --workers 3 --output "$HOME/Downloads/Corruptor-Balance/opponent-memory-$(date +%Y%m%d-%H%M%S)"
```

For a larger all-Lord screen, add `--lords Gremory Deimos Humbaba Kalligan Orias Odradek Kroni Valak Kanifous --repeats 3` (108 games). Use a new output folder; existing results are never overwritten. Per-game files include the selected plan, observed history and defensive scoring. The final `summary.json` reports wins and mean rounds.
