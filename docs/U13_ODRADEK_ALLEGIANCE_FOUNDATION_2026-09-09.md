# Odradek entry slice: Marcher allegiance

This started Milestone 6. The follow-up Redirect slice now makes Odradek selectable with Reconfiguration and repeatable Redirects; see `U13_ODRADEK_REDIRECT_2026-09-09.md`. False Orders, Allegiance Shift, Inversion, Psychic Interlock, Guard transfers, and Paradox Geometry remain pending.

The prerequisite shared `change_marcher_allegiance()` transition is now available through the authoritative `U13BattleEvents` command of the same name. It runs at Post-Resolution Allegiance (Step 10C), before any live Marching buffer exists. A command supplies a stable command ID, target Marcher ID, and new owner. Repeating that command is rejected; two distinct effects may change the same Marcher twice.

A successful transition retains birth identity, position, lane, HP, Armor, attack, regeneration, speed, birth/readiness rounds, and existing Rout state. It changes current ownership and forward direction, clears former-gate waiter/support eligibility and contact tickets, and ends any cached encounter involving the converted Marcher. Both former participants have their contact tickets cleared. Conversion emits a public before/after ownership event, not a death or a spawn.

Current-owner queries, hostility, targeting, aura eligibility, kill credit, and board presentation read the authoritative entity owner. Spatial grids and per-phase movement/field eligibility are rebuilt for the next Marching phase. Future Odradek area effects must capture membership at their firing hook and recapture after earlier effects mutate positions or ownership.

The focused `--allegiance` suite covers both owners at both gates and mid-lane, injured/armored/buffed bodies, exact JSON replay, repeated effects, unfinished combat, later movement and kill credit, and Rout/Web hostility. The aggregate launcher contains 83 suites after this addition. No Odradek ability radii or other unspecified balance values are invented here.

## Gem Dagger preview

Main setup -> Animation Previews -> Gremory · Gem Dagger.

The standalone scene is `res://Prototype/U13/U13GemDaggerPreview.tscn`. It uses the actual Gem Dagger view and real Guard-defeat/reward events from an isolated fixture. It has Replay, Loop, Slow motion, and Back/Exit controls. The Guard fades and both draw messages appear at the same impact event. It needs no hand cards and does not alter the active match.
