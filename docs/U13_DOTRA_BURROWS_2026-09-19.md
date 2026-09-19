# Dotra's three-hole burrow — V14

Dotra now creates three visible, fixed exits when he hides, then emerges from the usable exit nearest the most isolated visible enemy. The behavior works in both simulation engines and both lane views. This first pass **does not fix his weak army matchups**: some results improve, others worsen.

## Behavior

- The existing **25% hide chance per active round** opens three holes: one near Dotra and two farther along the lane, spread laterally. The forward offsets are 360 and 600. Positions stay inside the field and remain distinct near the goals.
- Dotra waits underground for **24 simulation ticks**. The three holes are public; neither seat sees his body underground. Exits remain fixed while enemies move.
- At emergence, isolation means **fewest visible allies within 400** of the enemy. Ties favor greater distance to the enemy's nearest ally, then proximity to a usable exit, then stable identity. Only enemy marchers in the same lane qualify. Hidden units do not contribute information to this choice; protected staging is outside the field.
- Dotra takes the closest usable exit to that enemy. A blocked hole first searches nearby free footprints. Fully blocked holes are skipped; if all three are obstructed, he retries the same exits on subsequent ticks. He can tunnel beneath walls, but cannot surface inside a wall or another unit.
- He becomes visible on emergence and closes at his normal movement speed for **one 5-damage ambush within 240**, subject to Armor and evasion. Walls block the strike, and local Kurchin taunts still apply. This replaces V13's persistent concealment until the strike.
- A dead, charmed, hidden, or navigation-rejected victim is replaced. If a queued victim dies before the hit resolves, Dotra retains the prepared strike. No enemies means taking the forward exit and marching, with the strike still available.
- Hole markers disappear on emergence, death, removal, or reset. A brief dirt burst marks emergence. Playback does not slide the hidden body toward its future exit or show an incoming projectile before emergence.

The 24-tick wind-up is roughly 1.8 seconds of marching on the 15-second sandbox clock; playback also includes its entrance animation. Speed settings scale the presentation normally. Both engines identify this as `U13_MONSTERS_V14_DOTRA_BURROWS`.

## Focused balance results

**576 controlled fights**, across all 18 Dotra scenarios, 16 seeds and both reflected seats, resolved **1,650 intervals** with no round-cap outcomes. Every one of the **288 seat pairs** agreed on winner, goals, duration, and cap status. The baseline is the matching subset of [V13](U13_MONSTER_SUPPORT_BALANCE_2026-09-19.md).

Each row below contains 32 fights. Results are from Dotra's side; supported means one of each ordinary marcher alongside him.

| Scenario | V13 wins / losses / draws | V14 wins / losses / draws |
|---|---:|---:|
| Dotra versus the ordinary units his recipe cards produce | 0 / 32 / 0 | 0 / 30 / 2 |
| Same-card comparison, with support on both sides | 0 / 32 / 0 | 0 / 32 / 0 |
| Supported versus six Butchers | 0 / 32 / 0 | 0 / 32 / 0 |
| Supported versus three Penitents and three Vultures | 0 / 32 / 0 | 4 / 28 / 0 |
| Supported versus mixed army | 10 / 22 / 0 | 2 / 30 / 0 |

The mixed opponent is one of each ordinary marcher plus two additional Butchers. Controlled runs recorded **242 ambushes**. These scenarios establish that the burrow works, but provide no basis for calling Dotra balanced or overpowered.

Eight native continuous games ran **240 intervals**, using both supplied screenshot seeds plus `monster-mixed:2` and `monster-mixed:3`, each with seats swapped. All four pairs produced mirrored final session totals. This batch produced **18 Dotra summons, 10 burrows, 10 successful emergences, and 6 ambushes**. Eight emergences used the forwardmost hole and two used the middle hole. The matching V13 games had 18 summons and 10 ambushes. Dotra's recorded HP damage fell from 190 to 90 in this small continuous sample; the burrow is not a demonstrated strength increase.

## Verification

- **1,127 native assertions passed**: 621 general monster, 104 dedicated burrow, 110 targeting/charm, 234 support/hunt, and 58 responsive Kopita pulse checks.
- **243 complete native/Python phase comparisons passed**, covering **48,600 ticks** and complete resulting worlds/events: 135 directed phases, 90 preview/navigation regressions, two controlled samples, and 16 continuous samples.
- **40 Python unit tests passed**. The launcher passes Bash syntax validation.
- Dedicated checks cover both seats, edge placement, isolation, enemy movement before emergence, occupied and fully obstructed exits, walls, target replacement, saved deadlines, cross-round timing, birth hold, one strike per hide, both lane drawings, death/reset cleanup, and teleport/projectile replay timing.

Tests ran with **Godot 4.5.1 Linux headless** and **PyPy 3.11 v7.3.20**. The Windows runner still requires **Godot 4.7.2 stable**. Native behavior, replay geometry, and drawing calls were exercised; Windows visual acceptance was not performed here.

The [evidence folder](evidence/U13_DOTRA_BURROWS_2026-09-19/) contains battle summaries, native check logs, exact parity inputs/hashes, recorded continuous burrow events, and `verification.json` with source SHA-256 hashes. The reports' inherited `revision` field names the starting V13 commit; the source manifest identifies the tested V14 files.

## Runner

Pull the branch and launch from Windows Git Bash:

```bash
git pull --ff-only origin u13-basic-doctrine
bash Scripts/Sim/run_u13_vulture_balance.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The launcher prints **Dotra burrows V14** and the arena title includes **burrows V14**. The existing unit chooser can spawn Dotra directly for inspection.
