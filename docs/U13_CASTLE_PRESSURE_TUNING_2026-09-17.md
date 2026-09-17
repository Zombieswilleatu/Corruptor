# Castle pressure tuning — 2026-09-17

Goal: sustained, sufficiently strong pressure should break one castle in roughly 3–5 rounds. Guard placement should compete with offensive commitment without also restoring so much integrity that attacks make no lasting progress.

**Follow-up:** Penitent-pair protection was subsequently reduced to +3 and Butcher pairs increased to two kills. The tables below preserve this initial tuning pass; current pair rules and updated pressure results are in [Guard work](U13_GUARD_WORK_2026-09-14.md#september-17-pair-balance-validation).

## Playtest rules

| Rule | Previous | This pass |
| --- | ---: | ---: |
| Base castle maximum integrity | 21 | 17 |
| Fresh Wright-pair Work bonus | +5 | +3 |
| Kalligan's ordinary Forge repair, per damaged eligible castle per round | +2 | +1 |
| Gremory's Inevitable Ruin sets integrity to | 14 | 8 |
| Kanifous's Longevity repairs up to | 14 | 8 |

Each new Guard still provides one Work. A pair of Wrights therefore provides five total Work on placement: two base Work plus the three-point bonus. Surviving Guards do not repeat that placement benefit. Uncommissioned construction still gains three passive Work per round. The operational threshold remains seven; existing repair locks still apply after a castle falls below it.

Ruin still costs two cards and fires at the start of the following round. It only targets a commissioned enemy castle above eight; it rechecks at firing and cannot heal or destroy the target. From a full 17-integrity castle, it now removes nine integrity, so this is an offensive buff, not merely proportional scaling. Longevity accepts eligible owned castles below eight, repairs to eight or the lower maximum, and charges a Price only for actual healing. Breach Longevity shares that ceiling and keeps its existing heavier Price.

The requested Forge reduction applies to ordinary Forge. Kalligan's separate Rapid Construction breach remains +2 for exposed players. Deimos's breach still reduces castle maximum by five, giving a 12-integrity ceiling under the new baseline. Siege Engine damage remains two. Gremory's preceding reduction to two Predator Vultures remains in effect; movement and gate-arrival rules are unchanged.

## Controlled native-engine pressure checks

`U13CastlePressureTestRunner.gd` uses the actual Work, Forge and Siege resolvers. A full-health Bastion is attacked directly, so there is one building to break. Each round supplies a fixed attack and two fresh rank-three Castle Guards. Replacements repair that same castle before combat. No Ward, Sigil, artillery, marching support or declared powers are included. These are guaranteed-resource stress cases, not simulated card draws or predictions for complete matches.

| Attack each round | Replacement Guards | Forge | Destroyed in round |
| ---: | --- | --- | ---: |
| 12 | Mixed suits | No | 4 |
| 12 | Mixed suits | Yes | 4 |
| 12 | Wright pair | No | 7 |
| 12 | Wright pair | Yes | No destruction in 12 rounds; stabilizes at 11 HP |
| 14 | Wright pair | No | 3 |
| 14 | Wright pair | Yes | 4 |
| 12 | Penitent pair | No | No destruction in 12 rounds; stabilizes at 16 HP |
| 16 | Penitent pair | No | 5 |
| 16 | Penitent pair | Yes | 6 |
| 17 | Penitent pair | Yes | 4 |

The ordinary 12-strength case now meets the target, including Forge. Replenishing a valuable pair every round can still defeat a modest attack indefinitely; sufficiently larger commitments overcome it. Real draws constrain the ability to keep replacing that exact pair. Reaching a different castle through an intact Bastion also requires breaking that additional building, so the 3–5-round target should be evaluated per building, not for the entire defensive line.

If real games still stall after this pass, examine the combination of Guard protection and the automatic one Work per placement before repeatedly lowering castle HP. Fresh Penitent pairs remain another strong defensive layer. The current ten cases deliberately expose these limits rather than asserting that every repeated Siege must succeed.

## Implementation and validation

- Updated native Godot rules, independent Python rules, Kanifous doctrine targeting, UI explanations and the castle damage preview. Historical U12 rules and old save evidence remain unchanged.
- Bumped the Guard/Work policy to `U13_GUARD_WORK_V3` and updated the full power-rules fingerprint. Start a new match; old snapshots must not silently continue under changed balance.
- Passed the ten native pressure cases and focused checks for Work, Forge, both threshold powers, monster interactions, opening economy, castle screening, construction, duplicate Engines, Deimos, Humbaba and the playable UI. Python: 27 development/power/planning tests passed.
- Current full Python `PowerMatch` matched Godot at 298 exact boundaries across nine opening/development games and eleven components. The older partial Development mirror predates permanent Veil advancement; the current full engine was used for this comparison.
- Testing used Godot 4.5.1 as a diagnostic runtime. The production 4.7.2 requirement is unchanged; interactive Windows review remains. The legacy loadout-scene runner stops at that runtime guard in this environment; the current playable-board checks passed.

Pressure curves and validation metadata: [U13_CASTLE_PRESSURE_TUNING_2026-09-17.json](evidence/U13_CASTLE_PRESSURE_TUNING_2026-09-17.json).
