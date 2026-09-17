extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

# Python's flat slots can change during a monster death callback. Native IDs
# and pre-tick movement readiness remain the authority for the later Orb step.
func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 1:
		phase_output = FileAccess.open(args[0], FileAccess.WRITE)
		check(phase_output != null, "gravity evidence opens")
		if phase_output == null:
			quit(1)
			return
	for lethal in [true, false]:
		for reverse in [false, true]:
			var world: Dictionary = phase_world()
			put(world, "Muno", 0, 700)
			var victim: Dictionary = put(world, "Wright", 1, 1000, {
				"hp": 1 if lethal else 5, "max_hp": 5, "armor": 0 if lethal else 3,
				"birth_round": 2, "movement_ready_round": 3})
			put(world, "Penitent", 1, 1400, {"y_fp": 200})
			world.data["valak_orbs"] = [{"id": "monster-gravity", "owner": 1,
				"target": {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}},
				"round": 2, "consumed": 0, "rewarded": false}]
			if reverse: world.entities.entities.reverse()
			var name: String = "monster_gravity_%s_%s" % ["lethal" if lethal else "wake", "reverse" if reverse else "ordered"]
			var result: Dictionary = phase(name, world)
			if result.action == "invalid": continue
			var first_tick: Dictionary = {}
			var first_attack: Dictionary = {}
			for row in result.events:
				if row.event.type == "MONSTER_ATTACK" and first_attack.is_empty(): first_attack = row.event.data
				if row.event.type == "MARCHING_TICK" and row.event.data.tick == 0: first_tick = row.event.data
			check(not first_attack.is_empty() and first_attack.target.id == victim.id, name + " monster hits before gravity")
			if not lethal:
				var found: Array = first_tick.get("units", []).filter(func(u): return u.id == victim.id)
				check(found.size() == 1 and found[0].attributes.x_fp == 1000 - victim.attributes.step_fp, name + " newly awakened unit moves but does not get pre-ready pull")
	if phase_output != null: phase_output.close()
	print("U13 Monster Gravity failures: ", failures)
	quit(1 if failures else 0)
