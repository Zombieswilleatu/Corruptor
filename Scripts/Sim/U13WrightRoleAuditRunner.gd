extends "res://Scripts/Sim/U13MonsterAuditRunner.gd"

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var output = FileAccess.open(args[0], FileAccess.WRITE)
	var count: int = 0
	for wrights in [1, 2, 3]:
		for opposition in ["mixed", "vultures", "butchers"]:
			for index in range(8):
				var seed_value: String = "monster-audit:%d" % index
				var sim = Sim.new(seed_value, true, true, false, 15)
				for i in range(3): assert(sim.spawn("Wright", 0).action == "spawned")
				sim.round_number = 2
				sim.prepare_releases(["March", "March"])
				for n in [2, 3]:
					var result: Dictionary = Sim.resolve_round(sim.world, seed_value, n)
					assert(result.action == "resolved")
					sim.finish(result)
				assert(Sim.Marching.Fort.rows(sim.world).size() == 3)
				var ids = Sim.Ids.new(); ids.restore(sim.world.entities)
				for unit in sim.units(): ids.retire(unit.id)
				sim.world.entities = ids.snapshot()
				for structure in Sim.Marching.Fort.rows(sim.world):
					structure.attributes.hp = 3
					structure.attributes.armor = 0
				var allies: Array = ["Penitent", "Penitent", "Vulture"]
				for i in range(wrights): allies.append("Wright")
				var size: int = allies.size()
				var enemies: Array = []
				if opposition == "mixed":
					for i in range(floori(float(size) / 2.0)): enemies.append("Penitent")
					for i in range(floori(float(size) / 4.0)): enemies.append("Butcher")
					while enemies.size() < size: enemies.append("Vulture")
				else:
					for i in range(size): enemies.append("Vulture" if opposition == "vultures" else "Butcher")
				for name in allies: assert(sim.spawn(name, 0).action == "spawned")
				for name in enemies: assert(sim.spawn(name, 1).action == "spawned")
				sim.round_number = 5
				sim.prepare_releases(["March", "March"])
				assert(Sim.Marching.valid(sim.world))
				for reflected in [false, true]:
					write(output, {"case": "replacement%d:%s" % [wrights, opposition], "group": "wright_takeover", "focus": "Wright", "teams": [allies, enemies], "recipe_hand": [], "seed": seed_value, "seed_index": index, "reflected": reflected, "round": 5, "world": Sim.mirror(sim.world) if reflected else sim.world})
					count += 1
			print("EXPORTED replacements ", wrights, " ", opposition, " · ", count)
	output.close()
	quit(0)
