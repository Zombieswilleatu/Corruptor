extends "res://Scripts/Sim/U13WrightRepairTestRunner.gd"

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var output = FileAccess.open(args[0], FileAccess.WRITE)
	for guards in [0, 1, 2]:
		for attackers in [1, 2]:
			for index in range(8):
				var f: Dictionary = guarded(0, 0, 6, 600)
				var w: Dictionary = f.world
				Fort.rows(w)[0].attributes.merge({"hp": Fort.WALL_HP, "max_hp": Fort.WALL_HP, "armor": Fort.WALL_ARMOR, "max_armor": Fort.WALL_ARMOR}, true)
				if guards == 0:
					var ids = Work.Ids.new(); ids.restore(w.entities); ids.retire(f.builder.id); w.entities = ids.snapshot()
				if guards == 2:
					var home: Dictionary = Fort.anchor(0, 1)
					var builder: Dictionary = put(w, "Wright", 0, home.x_fp, {"y_fp": home.y_fp, "wright_site": 1, "wright_owner": 0, "wright_progress": 32, "wright_built": true, "wright_guard_until": 600, "wright_repair_round": 1, "wright_released": false}, 1)
					var p: Dictionary = Fort.site_point(0, 1)
					w.data.field_structures.append({"id": Work.Data.instance_id("wright_structure", builder.id, "1"), "kind": "fortification", "owner": 0, "attributes": {"structure": "Wall", "site": 1, "lane": "Lord", "x_fp": p.x_fp, "y_fp": p.y_fp, "hp": Fort.WALL_HP, "max_hp": Fort.WALL_HP, "armor": Fort.WALL_ARMOR, "max_armor": Fort.WALL_ARMOR, "attack": 0, "ranged_next_tick": 0, "builder_id": builder.id}})
				var opponents: Array = []
				for i in range(attackers):
					put(w, "Butcher", 1, 754 + (index % 4) * 60, {"y_fp": 120 + i * 30 + floori(float(index) / 4.0) * 30}, i)
					opponents.append("Butcher")
				var allies: Array = []
				for i in range(guards): allies.append("Wright")
				var arena = preload("res://Scripts/Sim/U13LaneSandbox.gd").new("guard-audit:%d" % index, true, true)
				var ids = Work.Ids.new(); ids.restore(w.entities)
				for entity in w.entities.entities:
					if entity.kind != "marcher": ids.retire(entity.id)
				arena.world.entities = ids.snapshot()
				arena.world.data["field_structures"] = Fort.rows(w).duplicate(true)
				w = arena.world
				assert(Marching.valid(w))
				for reflected in [false, true]:
					var record: Dictionary = {"case": "guard%d:butcher%d" % [guards, attackers], "group": "wright_guard", "focus": "Wright", "teams": [allies, opponents], "recipe_hand": [], "seed": "guard-audit:%d" % index, "seed_index": index, "reflected": reflected, "round": 2, "world": preload("res://Scripts/Sim/U13LaneSandbox.gd").mirror(w) if reflected else w}
					var encoded: Dictionary = Codec.encode(record)
					if encoded.action != "encoded":
						bad_data(record, "record")
						quit(1)
						return
					output.store_line(encoded.text)
	output.close()
	print("EXPORTED 96 guarded-wall fixtures; second guard occupies the other wall post and can cover the attacked wall.")
	quit(0)
