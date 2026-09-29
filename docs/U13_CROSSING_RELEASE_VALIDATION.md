# Crossing accepted release — 2026-09-29

Ships the finite Gate/Lamp encounter, calibrated opposition, player reinforcements, original game visuals, and player-only Lemek/Muno price adjustment.

Player prices: Lemek 6 power, Muno 7 power; both retain 3 capacity. Enemy expedition weights and seeded schedules are unchanged. Campaign aftermath remains preview-only.

Validation on Godot 4.5.1 Linux against repository base f4b4c187a0e9099680f304022ba74e33bba2cffd plus this release:

| Suite | Passed | Failed |
| --- | ---: | ---: |
| Encounter and replay | 163 | 0 |
| Crossing monster opt-in and combat | 269 | 0 |
| Player reinforcements | 233 | 0 |
| Finite opposition profiles | 204 | 0 |
| Forecast-aware tactical policy | 29 | 0 |
| Visual projection and hourglass | 22 | 0 |
| Total | 920 | 0 |

Before assembly, 72 seeded Gate/Lamp/difficulty comparisons verified that player repricing preserved complete enemy orders, positions, budgets and spending. OpenGL preview inspected at 1440×810. Windows Godot 4.7.2 was not available here. No new win-rate calibration is claimed after repricing.

Launch: `bash Scripts/Sim/run_u13_encounter.sh "$godot_exe"`. The dev setup menu also exposes THE CROSSING. For the encounter suite, append `--test`; other suites are the U13Crossing*TestRunner scripts listed above.
