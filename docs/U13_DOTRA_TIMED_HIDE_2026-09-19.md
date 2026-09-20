# Dotra's guaranteed concealment — V16

Historical comparison: [V17 adds five seconds of untargetability after emergence](U13_DOTRA_SHROUD_2026-09-20.md).

Interpretation correction: actual commitments summon normal marchers **plus** their chosen monster. Recipe comparisons below are artificial replacement benchmarks, not a gameplay resource tradeoff. The continuous simulations already use additive spawning.

Dotra now hides **once per summon, after his first 15 seconds on the field**, replacing the 25% concealment roll. The delay is 200 simulation ticks and begins on his first eligible field tick. Protected staging and the birth hold do not consume it. Playback speed scales those 15 game seconds normally.

After hiding, he keeps moving at full speed until an enemy enters his 240 ambush radius. He then delivers the existing 5-damage ambush and exposes nearby enemies within 360 to +1 incoming damage per hit, before Armor, for one full round. He does not roll for another hide after emerging. The timer and spent concealment survive save/load; a mid-round activation still waits a full 200 ticks.

Both engines use `U13_MONSTERS_V16_DOTRA_TIMED_HIDE`. `dotra_hide_delay_ticks: 200` replaces the probability setting. The arena and launcher identify this build as **Dotra timed hide V16**. The [V15 exposure report](U13_DOTRA_EXPOSURE_2026-09-19.md) documents the unchanged ambush, exposure, and visual rules.

## Matched balance comparison

The same **576 fights** cover 18 Dotra scenarios, 16 seeds and both reflected seats. All **288 seat pairs** matched outcome, goals, surviving forces and duration. The fights resolved **1,594 intervals**, with no round-cap outcomes. Each row below is 32 fights from Dotra's side.

| Scenario | V15 wins / losses | V16 wins / losses |
|---|---:|---:|
| Dotra versus ordinary units from his recipe cards | 2 / 30 | 4 / 28 |
| Same-card comparison with support on both sides | 0 / 32 | 4 / 28 |
| Supported versus six Butchers | 0 / 32 | 0 / 32 |
| Supported versus three Penitents and three Vultures | 0 / 32 | 0 / 32 |
| Supported versus mixed army | 12 / 20 | 22 / 10 |

Support is one of each ordinary marcher. The mixed opponent has that core plus two additional Butchers. These paired experiments have 16 independent seeds per scenario; the improved mixed-army result does not establish general balance.

Every Dotra in the controlled batch survived long enough to deliver his one ambush: **576 ambush/exposure pulses**, compared with **264 in V15**. Pulses affected **910 enemy instances**, up from **446**. This guarantees the timer, not survival: enemies can still kill Dotra before it expires. Damage contributed by exposed targets taking stronger allied hits is credited to the allies.

## Continuous runs

Eight native continuous games ran 30 intervals each (**240 total**), using both screenshot seeds plus `monster-mixed:2` and `monster-mixed:3`, each with swapped seats. All four seat pairs mirrored their complete final session totals.

| Dotra measure | V15 | V16 |
|---|---:|---:|
| Summons | 18 | 18 |
| Ambush/exposure pulses | 8 | 16 |
| Affected-enemy instances | 44 | 100 |
| Own recorded HP damage | 164 | 214 |
| Kills credited to Dotra | 26 | 24 |

All **16 deployed Dotras** hid on their saved deadline and delivered exactly one ambush; all 16 pulses affected multiple enemies. The other two summons were still in staging at the final interval, so their timers had not started. Increased damage and exposure did not increase Dotra's own kill count in this small sample.

Final normal-seat goals were `[0, 15]`, `[2, 39]`, `[25, 15]` and `[19, 48]` in the seed order above; swapped seats reversed each result.

## Verification

- **923 native assertions passed:** 196 timing, 648 general monster, and 79 exposure checks.
- Timing coverage includes both seats, different seeds, the complete visible first interval, delayed staging release, birth hold, save/load, exact mid-round expiry, continued stalking, one ambush/exposure pulse, no subsequent concealment, playback timing, and concealment preceding enemy target selection in the same tick.
- **148 complete native/Python phase comparisons passed**, covering **29,600 ticks** and complete resulting worlds/events: 43 timing phases, 84 general monster phases, three exposure phases, two controlled samples and 16 continuous samples.
- **17 complete native/Python damage-adapter cases passed**, retaining the existing exposure behavior across attack types, blocks, evasion and secondary damage.
- Launcher syntax and patch whitespace checks passed.

Tests used Godot 4.5.1 Linux headless and PyPy 3.11 v7.3.20. The Windows launcher still requires Godot 4.7.2 stable; Windows visual acceptance was not performed here.

The [evidence folder](evidence/U13_DOTRA_TIMED_HIDE_2026-09-19/) contains matched fight summaries, replay samples, parity logs, and source hashes. Audit summaries identify the starting commit in their inherited `revision` field; the source manifest identifies the tested V16 files.

## Runner

From Windows Git Bash in the project folder:

```bash
git pull --ff-only origin u13-basic-doctrine
bash Scripts/Sim/run_u13_vulture_balance.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

Check for **Dotra timed hide V16** in the launcher and **timed hide V16** in the arena title.
