# Marcher self-defense and Kanifous Resurrection

Accepted 2026-09-17 during playable UI testing. This changes game rules and the
matching Python simulator. Earlier full-match evidence describes earlier rules.

- Newly recruited Marchers hold their position until next round unless attacked.
  A surviving ranged or melee hit releases that unit's movement hold, including
  a hit absorbed entirely by Armor. Other new recruits keep holding. Normal
  speed, targeting, lane boundaries, and ranged/melee attack rates still apply.
- Resurrection targets a whole marching lane through a field selection overlay.
  It revives the caster's Marchers killed there in the current round, after
  Marching finishes. This replaces the earlier Guard-card restoration rule.
- Revived Marchers return near their death locations with printed HP/Armor,
  fresh identities, and next-round movement readiness. Old identities remain
  retired. Temporary buffs and wounds are not copied.
- Explicit death events supply the casualty record: combat, killing hazards,
  devouring, gravity, Lamp rejection, Deathwish, and the Blood Price. Spent
  Hunt/Siege support, Guard cards, enemy casualties, and previous-round losses
  are excluded. Banishment must remain separate from death.
- A successful Resurrection creates one normal delayed Price. No eligible
  casualties means zero revived units and no Price. Aftermath reports the count
  and lane.

The changed firing hook changes the rules signature: start a new match. Existing
save files are untouched and remain associated with their earlier rules.

Validation: diagnostic Godot 4.5.1 playable-interaction, doctrine-coverage, and
Kanifous-board checks passed, including both player orientations and field
selection. Focused assertions cover fresh identities, full HP/Armor, wrong-lane
and previous-round exclusions. Python Marching/power tests passed (23 tests).
Exact Godot/Python comparison matched 176 operations across Resurrection,
Deathwish, Gravity Orb, Lamp rejection, and Kroni/Breach scenarios. The full
Windows Godot 4.7.2 acceptance suite remains to be rerun for these rules.
