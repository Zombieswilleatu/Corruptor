extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

const Melee = preload("res://Scripts/Sim/U13FieldMelee.gd")
const Ranged = preload("res://Scripts/Sim/U13RangedMarching.gd")
const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")

# Use an isolated cadence project. High HP prevents deaths from hiding extra hits.
func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	for kind in ["melee", "vulture", "tower"]:
		var w: Dictionary = phase_world()
		var actor: Dictionary
		var attack_type: String = "MARCHER_MELEE_ATTACK" if kind == "melee" else "MARCHER_RANGED_ATTACK"
		var interval: int = Melee.INTERVAL if kind == "melee" else Ranged.RANGED_INTERVAL_TICKS
		var extra: Dictionary = {"hp": 10000, "max_hp": 10000, "armor": 0, "step_fp": 0, "regen": 0}
		if kind == "tower":
			var builder: Dictionary = put(w, "Wright", 0, 0, {"movement_ready_round": 10})
			var p: Dictionary = Fort.site_point(0, 2)
			actor = {"id": Work.Data.instance_id("wright_structure", builder.id, "2"), "kind": "fortification", "owner": 0, "attributes": {"structure": "Tower", "site": 2, "lane": "Lord", "x_fp": p.x_fp, "y_fp": p.y_fp, "hp": 6, "max_hp": 6, "armor": 4, "max_armor": 4, "attack": 1, "ranged_next_tick": 0, "builder_id": builder.id}}
			w.data["field_structures"] = [actor]
			put(w, "Butcher", 1, int(p.x_fp)+300, extra)
		else:
			actor = put(w, "Butcher" if kind == "melee" else "Vulture", 0, 900, extra)
			put(w, "Butcher" if kind == "melee" else "Vulture", 1, 960 if kind == "melee" else 1200, extra)
		var next_tick: int = 400
		for number in range(2, 6):
			var expected: Array = []
			while next_tick < (number+1)*200:
				expected.append(next_tick-number*200)
				next_tick += interval
			var r: Dictionary = phase("cadence_%s_%d" % [kind, number], w, "cadence-boundary", number)
			var attacks: Array = facts(r, attack_type).filter(func(hit): return hit.attacker.id == actor.id)
			check(attacks.map(func(hit): return hit.tick) == expected, "%s round %d obeys cooldown and carries it across rounds" % [kind, number])
			w = r.world
	if phase_output != null: phase_output.close()
	print("U13 cadence failures: ", failures)
	quit(1 if failures else 0)
