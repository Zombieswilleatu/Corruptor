extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

# Focused resolver fixtures. Compare identities, keyed Price timing and the
# complete world/events for normal and Breach resurrection, twice per body.
func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output = FileAccess.open(args[0], FileAccess.WRITE) if not args.is_empty() else null
	if not args.is_empty() and output == null:
		check(false, "resurrection export opens")
		quit(1)
		return
	var handler = Kanifous.new()
	for power_name in ["WishResurrection", "BreachWishResurrection"]:
		for turret in [false, true]:
			var world: Dictionary = phase_world()
			var lost: Dictionary = put(world, "Sooge", 0, 900, {
				"sprite_form": "turret" if turret else "mobile", "step_fp": 0 if turret else 4,
				"attack": 3 if turret else 1, "armor": 0, "max_armor": 6 if turret else 2,
				"sooge_root_attempts": 4, "sooge_root_round": 2})
			var revived_ids: Array = []
			var price_ids: Array = []
			for attempt in range(2):
				var ids = Work.Ids.new()
				ids.restore(world.entities); ids.retire(lost.id); world.entities = ids.snapshot()
				world.data.kanifous_losses = [lost]
				var name: String = "%s_%s_%d" % [power_name, "turret" if turret else "mobile", attempt]
				var source: Dictionary = {"power_id": power_name, "player_id": 0,
					"target": {"lane": "Lord"}, "parameters": {}, "declaration_id": "resurrection:" + name}
				var c: Dictionary = {"world": world.duplicate(true), "round": 2, "seed": "resurrection-parity"}
				var result: Dictionary = handler.resolve({"declaration": source}, c)
				check(result.action == "resolved" and result == handler.resolve({"declaration": source}, c), name + " repeats exactly")
				var bodies: Array = result.world.entities.entities.filter(func(r): return r.attributes.get("monster_id") == "Sooge")
				check(bodies.size() == 1, name + " restores one Sooge")
				if bodies.size() != 1:
					quit(1)
					return
				lost = bodies[0].duplicate(true)
				var expected = Work.Ids.new()
				var expected_id: String = expected.create("marcher", source.declaration_id, 0, 0, lost.attributes).entity.id
				check(lost.id == expected_id and lost.id not in revived_ids, name + " owns a fresh declaration-derived identity")
				revived_ids.append(lost.id)
				var debt: Dictionary = result.world.data.kanifous_prices.back()
				check(debt.id == Kanifous.Data.instance_id("price", source.declaration_id, "main") and debt.id not in price_ids, name + " owns a separate Price")
				price_ids.append(debt.id)
				check(debt.get("breach", false) == power_name.begins_with("Breach"), name + " preserves Price origin")
				check(lost.attributes.sooge_root_attempts == 4 and lost.attributes.sooge_root_round == 2 and lost.attributes.sprite_form == ("turret" if turret else "mobile"), name + " preserves rooting progress and form")
				if output != null:
					var encoded: Dictionary = Codec.encode({"name": name, "source": source, "context": c, "result": result})
					check(encoded.has("text"), name + " exports exact data")
					if encoded.has("text"):
						output.store_line(encoded.text)
						output.flush()
				world = result.world
	if output != null: output.close()
	print("U13 monster resurrection failures: ", failures)
	quit(1 if failures else 0)
