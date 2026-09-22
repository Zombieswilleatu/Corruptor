# Kroni: eleven-enemy Ravenous reward

Implemented locally on top of the promoted Ward/round-20 tempo rules.

Ravenous now requires at least **11 enemy marcher bodies consumed in one use**
for its once-per-use reward: one Soul, one Hunger and one Neutral Tear. Friendly
bodies still get eaten but do not advance the reward. Enemy monsters count as
bodies. Twenty-two enemy meals still pay only one reward. Breach actors never
pay. Movement, footprint, chomp timing and targeting are unchanged.

Python and Godot actors now retain an enemy consumption counter alongside the
existing total. Reward events and the aftermath display expose the enemy count.
Playable Lord rules explain the new requirement. The doctrine's uncertain
route-reward estimate now uses eleven enemy intersections instead of six;
intersections are still not promised kills. Native snapshot validation checks
that the counter is an integer between zero and total consumption, and zero for
Breach actors. Older snapshots lacking the field remain readable; unknown past
kills are not retrospectively credited. Legacy reward events retain a total-unit
label in the ledger.

## Where Kroni's other Souls came from

An exact replay of archived `kroni_odradek_00_tempo` under its frozen pre-nerf
rules reproduced its final-state hash. Kroni reached 12 Souls in round 9:

| Round | Source | Souls gained | Running balance |
|---|---|---:|---:|
| 3 | Siege castle destruction, also defeated a guard | 3 | 3 |
| 4 | Siege castle destruction, also defeated guards | 3 | 6 |
| 6 | Siege castle destruction, no guards defeated | 2 | 8 |
| 9 | Siege castle destruction, also defeated a guard | 3 | 11 |
| 9 | Ravenous, 16 enemy bodies and no friendly bodies | 1 | 12 |

Thus 11 Souls came from Siege and one from Ravenous. Current Siege rules award
2 Souls per castle destroyed, or 3 if the Siege also defeated a guard. This is
an illustrative game's exact attribution, not a full-roster income breakdown.
No Hunt, artillery, Ward or round-20 bonus supplied Souls in this game.

That particular Ravenous would still meet the new requirement. This does not
prove the whole game remains identical after the change: doctrine decisions
can change. No newly planned full game was run for this patch.

## Focused validation

- Nine Python tests passed: reward threshold, actual bite ownership, reward
  cap, Breach exclusion and existing Kroni doctrine tests.
- Native Kroni suite: 973/973 assertions passed, including 10-versus-11 enemy
  boundaries, friendly padding, 22-enemy cap, already-paid actors, snapshot
  validation, integrated consumption and JSON replay.
- Native launch/visual suite: 89 checks, zero failures; all 16 exported actor
  cases matched Python exactly.
- Native playable Kroni board suite: zero failures.

Soul audit evidence: `docs/evidence/U13_KRONI_SOUL_AUDIT_2026-09-22.json`.
No attack-bonus timing, monster price, Lord stat or seat-order change is included.
