extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

# Experimental assertions: run only in a kurchin10_mitigation1 project.
func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output = FileAccess.open(args[0], FileAccess.WRITE) if not args.is_empty() else null
	for pid in [0, 1]:
		for attack in [["Muno", 0], ["Muno", 3], ["Beam", 3], ["Ambush", 5], ["Kopita", 1], ["Poison", 1]]:
			for bypass in [false, true]:
				var w: Dictionary = phase_world()
				var tank: Dictionary = put(w, "Kurchin", pid, 1200, {"hp": 10, "max_hp": 10})
				var enemy: Dictionary = put(w, "Butcher", 1-pid, 1260)
				var c: Dictionary = context(w)
				var ids = Marching.Buffer.new(); ids.restore(w.entities)
				var hit: Dictionary = {"source": enemy, "target": tank.id, "amount": attack[1], "bypass": bypass, "ability": attack[0]}
				var input: Dictionary = {"world": w.duplicate(true), "hit": hit.duplicate(true), "context": c.duplicate(true)}
				var r: Dictionary = MonsterFX.damage(w, ids, hit, c, 0, Callable(Game.Content.new(), "react"))
				var facts_hit: Array = facts(r, "MONSTER_ATTACK")
				var reduced: int = 1 if attack[1] > 1 else 0
				var damage: int = int(attack[1])-reduced
				var after: Dictionary = ids.get_entity(tank.id).attributes
				check(facts_hit.size() == 1 and facts_hit[0].damage_reduced == reduced, "ability prevention is separate: " + attack[0])
				check(after.hp == 10-(damage if bypass else 0) and after.armor == 6-(0 if bypass else damage), "reduce before Armor; preserve bypass and zero/one floor")
				if output != null:
					input["result"] = r
					output.store_line(Codec.encode(input).text)
	if output != null: output.close()
	print("U13 Kurchin mitigation failures: ", failures)
	quit(1 if failures else 0)
