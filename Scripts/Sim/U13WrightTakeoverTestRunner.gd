extends "res://Scripts/Sim/U13WrightRepairTestRunner.gd"

func abandoned(pid: int, site: int, hp: int = 3, departed: bool = false) -> Dictionary:
	var fixture: Dictionary = guarded(pid, site, hp)
	var ids = Work.Ids.new(); ids.restore(fixture.world.entities)
	if departed:
		var a: Dictionary = fixture.builder.attributes.duplicate(true)
		a.wright_released = true
		a.x_fp = 1800 if pid == 0 else 600
		ids.update(fixture.builder.id, pid, a)
	else: ids.retire(fixture.builder.id)
	fixture.world.entities = ids.snapshot()
	return fixture

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	for pid in [0, 1]:
		for site in [0, 2]:
			for departed in [false, true]:
				var f: Dictionary = abandoned(pid, site, 3, departed)
				var fresh: Dictionary = put(f.world, "Wright", pid, 0 if pid == 0 else 2400, {}, 20)
				var result: Dictionary = phase("takeover_arrival_%d_%d_%s" % [pid, site, departed], f.world, "wright-takeover")
				var a: Dictionary = Kanifous._entity(result.world, fresh.id).attributes
				var repaired: Array = facts(result, "WRIGHT_STRUCTURE_REPAIRED")
				check(facts(result, "WRIGHT_REPAIR_ASSIGNED").size() == 1 and a.wright_guard_target == Fort.rows(f.world)[0].id, "fresh Wright adopts a damaged structure after its builder dies or departs")
				check(repaired.size() == 3 and repaired[0].tick > 0 and Fort.rows(result.world)[0].attributes.hp == 6, "approaching Wright starts repairs within range and repeats to full HP")
				check(a.wright_arrived and a.wright_guard_until > 600 and not a.wright_released, "minimum guard time starts at arrival")
				check(Fort.rows(result.world)[0].attributes.builder_id == f.builder.id and Fort.rows(result.world)[0].attributes.armor == 0, "takeover preserves construction identity and never restores Armor")
				check(facts(result, "WRIGHT_STRUCTURE_BUILT").is_empty(), "repair duty does not create a duplicate structure")
				var saved: Dictionary = Codec.decode(Codec.encode(result.world).text).value
				check(saved == result.world and Marching.valid(saved), "takeover assignment survives exact save transport")
				result = phase("takeover_guard_%d_%d_%s" % [pid, site, departed], saved, "wright-takeover", 3)
				check(Fort.rows(result.world)[0].attributes.hp == 6 and Kanifous._entity(result.world, fresh.id).attributes.wright_released, "fully repaired replacement leaves only after the minimum guard period")
				result = phase("takeover_release_%d_%d_%s" % [pid, site, departed], result.world, "wright-takeover", 4)
				check(Fort.rows(result.world)[0].attributes.hp == 6 and Kanifous._entity(result.world, fresh.id).attributes.wright_released, "replacement marches on after full repair and minimum guard time")
				check(Ledger.describe("WRIGHT_REPAIR_ASSIGNED", facts(phase("takeover_ledger_%d_%d_%s" % [pid, site, departed], f.world, "wright-takeover"), "WRIGHT_REPAIR_ASSIGNED")[0]).contains("taking over"), "takeover appears in aftermath ledger")
		var f: Dictionary = abandoned(pid, 0)
		var home: Dictionary = Fort.anchor(pid, 0)
		var one: Dictionary = put(f.world, "Wright", pid, home.x_fp, {"y_fp": home.y_fp}, 20)
		var two: Dictionary = put(f.world, "Wright", pid, home.x_fp, {"y_fp": home.y_fp}, 21)
		var events: Array = raw_step(f.world, 2, 7)
		check(events.filter(func(r): return r.event.type == "WRIGHT_REPAIR_ASSIGNED").size() == 1 and Fort.rows(f.world)[0].attributes.hp == 5, "one guard is assigned while both nearby Wrights contribute repairs")
		var actor: Dictionary = f.world.entities.entities.filter(func(u): return u.attributes.has("wright_guard_target"))[0]
		var duplicate: Dictionary = actor.duplicate(true); duplicate.id = two.id if actor.id == one.id else one.id
		var ids = Work.Ids.new(); ids.restore(f.world.entities)
		ids.update(duplicate.id, pid, duplicate.attributes)
		var invalid: Dictionary = f.world.duplicate(true); invalid.entities = ids.snapshot()
		check(not Fort.valid(invalid), "save validation rejects duplicate guards")
		ids.restore(f.world.entities); ids.retire(actor.id); ids.retire(two.id if actor.id == one.id else one.id); f.world.entities = ids.snapshot()
		put(f.world, "Wright", pid, home.x_fp, {"y_fp": home.y_fp}, 22)
		events = raw_step(f.world, 2, 8)
		check(events.filter(func(r): return r.event.type == "WRIGHT_STRUCTURE_REPAIRED").size() == 1 and Fort.rows(f.world)[0].attributes.hp == 6, "a different arriving Wright contributes its own repair without overhealing")
		f = guarded(pid, 0)
		put(f.world, "Wright", pid, home.x_fp, {"y_fp": home.y_fp}, 20)
		events = raw_step(f.world, 2)
		check(not events.any(func(r): return r.event.type == "WRIGHT_REPAIR_ASSIGNED"), "living guard retains its post")
		f = abandoned(pid, 0)
		var fresh: Dictionary = put(f.world, "Wright", 1-pid, home.x_fp, {"y_fp": home.y_fp}, 20)
		events = raw_step(f.world, 2)
		check(not events.any(func(r): return r.event.type == "WRIGHT_REPAIR_ASSIGNED"), "enemy structure cannot be adopted")
		f = abandoned(pid, 0)
		fresh = put(f.world, "Wright", pid, home.x_fp, {"y_fp": home.y_fp, "lane": "Castle"}, 20)
		events = raw_step(f.world, 2)
		check(not events.any(func(r): return r.event.type == "WRIGHT_REPAIR_ASSIGNED"), "another lane cannot be repaired remotely")
		f = abandoned(pid, 0)
		fresh = put(f.world, "Wright", pid, 0 if pid == 0 else 2400, {}, 20)
		raw_step(f.world, 2, 1)
		f.world.data.field_structures = []
		raw_step(f.world, 2, 2)
		check(Kanifous._entity(f.world, fresh.id).attributes.wright_released, "destroyed takeover target releases the approaching guard")
		for bad in ["", 3, null]:
			var a: Dictionary = Kanifous._entity(f.world, fresh.id).attributes.duplicate(true)
			a.wright_guard_target = bad
			check(not Fort.valid_unit(a), "invalid guard target is rejected")
	if phase_output != null: phase_output.close()
	print("U13 Wright takeover failures: ", failures)
	quit(1 if failures else 0)
