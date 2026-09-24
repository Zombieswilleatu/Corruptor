# Deimos doctrine and Rout 85% — 2026-09-24

Selected for the theater build: prioritize building/commissioning the Siege Engine, favor useful Wright work, always include a legal free War Machine when an operational engine has enemy castles to attack, and reduce Rout retreat movement to 85%. Standard castle order stays unchanged. No starting Siege Engine.

Both the Python marching engine and native Godot marching apply the same deterministic tick-based rounding after other movement modifiers. Following-round recovery remains 50%; ordinary movement, Rout cooldown, and damage bonus remain unchanged. The shared playable/balance doctrine forecasts the reduced retreat speed.

## Evidence

32 paired nonmirror matchups per arm, eight opponents in both seats across two seeds from the overnight run:

| Configuration | Deimos wins |
|---|---:|
| Old doctrine reference | 10/32 |
| Engine-first doctrine | 11/32 |
| Engine-first doctrine + Rout 85% (selected) | 13/32 |
| Engine in third slot, Rout 100% | 17/32 |
| Engine in third slot + Rout 85% | 16/32 |

The selected result is a small screening sample, not proof of a stable 40.6% win rate. The starting engine remains an encounter-design option. It is not part of this release.

25 focused Python tests pass for engine-first/War Machine behavior, Rout forecasts, retreat damage, exact unmodified retreat displacement, and unchanged normal/recovery movement. Native Rout movement expectations are updated from 100% to 85%, with aggregate displacement checks for base speeds 1–20. Native tests were not executed here because Godot is unavailable.

Native check on a machine with Godot:

    godot --headless --path . --script res://Scripts/Sim/U13RoutTestRunner.gd

## Next audit

Orias leads the 810-game overnight nonmirror roster at 94/160 (58.8%); Valak follows at 92/160 (57.5%). Orias's wins by opponent (20 games each): Kanifous 15, Deimos 14, Kalligan 14, Odradek 13, Humbaba 11, Kroni 11, Valak 9, Gremory 7. His lead is uneven, not universal dominance. Audit Hunt/Mark pressure and opponent responses before a blanket kit nerf. Deimos has now changed, so these are historical priorities, not a new roster measurement.
