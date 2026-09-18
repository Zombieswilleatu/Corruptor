# Wright structure repair — 2026-09-18

Wrights keep the existing construction and local defense behavior. Once built,
the assigned Wright restores **1 HP at the start of each Marching round** and
stays on guard while the structure is damaged. It leaves only when the structure
has full HP and its original 200-tick minimum guard period has elapsed.

Repairs affect HP, not Armor. Repairing the final missing HP can release the
Wright immediately if its minimum guard period is complete. A full structure
still consumes that round's repair opportunity, so later damage cannot grant a
second repair through save/reload. Inactive, routed, hidden, waiting or fleeing
Wrights do not repair. A destroyed structure releases its builder; the builder
does not repair a replacement belonging to another Wright. Once released, it
does not return to later damage or repair remotely.

The aftermath ledger records the repair, and playback displays the updated HP.
Save validation covers repair-round and release state. The native and independent
Python rules both use `U13_VULTURE_RANGED_V9_WRIGHT_REPAIR`; start a fresh game
after updating because earlier rules fingerprints are incompatible.

Verification passed in the Godot 4.5.1 Linux diagnostic runtime:

- Directed repair, guarding, movement, allegiance, save/load and HP-cap checks.
- Existing construction, wall/tower combat, destruction and passage checks.
- Native/Python equality across 62 complete phases and 12,400 visual ticks,
  including every event and final world.
- All 19 Python marching regression tests.

Godot 4.7.2 Windows acceptance has not been run. Reproduce using
`U13WrightRepairTestRunner.gd` and `U13FieldCombatTestRunner.gd`, passing each an
output JSONL path, then run `python -m u13_pysim.verify_monsters FILE` with
`PYTHONPATH=Scripts/Sim`. [Verification counts and source hashes](evidence/U13_WRIGHT_REPAIR_2026-09-18.json).

The earlier monster/formation balance archives were measured before Wright
repair. Their reports retain those rules and should not be presented as measurements
of this updated Wright behavior.

This update also includes the previously verified Tumler pursuit correction:
he commits through enemy clusters while still avoiding slowing pools. Existing
hunt evasion and landed-melee retargeting remain in place. Permanent evasion,
monster HP changes, Kurchin mitigation and Penitent-led formation remain isolated
[balance experiments](https://github.com/Zombieswilleatu/Corruptor/blob/7c26052041bc0a9a8212bd10f07dcaad2c9717cd/docs/U13_MONSTER_PAIR_BALANCE_2026-09-18.md).
