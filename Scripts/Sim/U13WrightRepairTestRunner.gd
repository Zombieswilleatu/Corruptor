extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")

func guarded(pid: int, site: int, hp: int = 3, until: int = 500) -> Dictionary:
	var w: Dictionary = phase_world()
	var home: Dictionary = Fort.anchor(pid, site)
	var builder: Dictionary = put(w, "Wright", pid, home.x_fp, {"y_fp": home.y_fp, "wright_site": site, "wright_owner": pid, "wright_progress": 32, "wright_built": true, "wright_guard_until": until, "wright_repair_round": 1, "wright_released": false})
	var p: Dictionary = Fort.site_point(pid, site)
	w.data["field_structures"] = [{"id": Work.Data.instance_id("wright_structure", builder.id, str(site)), "kind": "fortification", "owner": pid, "attributes": {"structure": "Tower" if site == 2 else "Wall", "site": site, "lane": "Lord", "x_fp": p.x_fp, "y_fp": p.y_fp, "hp": hp, "max_hp": 6, "armor": 0, "max_armor": 4 if site == 2 else 2, "attack": 1 if site == 2 else 0, "ranged_next_tick": 0, "builder_id": builder.id}}]
	return {"world": w, "builder": builder}

func raw_step(w: Dictionary, n: int, tick: int = 0, fleeing: Dictionary = {}) -> Array:
	var ids = Marching.Buffer.new(); ids.restore(w.entities)
	var events: Array = Fort.step(w, ids, n, tick, fleeing)
	w.entities = ids.snapshot()
	return events

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	for pid in [0, 1]:
		for site in [0, 2]:
			var fixture: Dictionary = guarded(pid, site, 3, 999)
			var w: Dictionary = fixture.world
			var builder: Dictionary = fixture.builder
			var r: Dictionary = phase("wright_repair_ticks_%d_%d" % [pid, site], w, "wright-repair", 2)
			var repaired: Array = facts(r, "WRIGHT_STRUCTURE_REPAIRED")
			check(repaired.map(func(e): return e.tick) == [0, 27, 54] and Fort.rows(r.world)[0].attributes.hp == 6, "repair repeats every 27 ticks and stops at full HP")
			check(Fort.rows(r.world)[0].attributes.armor == 0, "repair never refills Armor")
			check(not Kanifous._entity(r.world, builder.id).attributes.wright_released, "full HP still respects the minimum guard timer")
			check(Ledger.describe("WRIGHT_STRUCTURE_REPAIRED", repaired[0]).contains("HP"), "repair appears in aftermath ledger")
			var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
			check(playback.build(r.events.map(func(e): return e.event)) and playback.sample(playback.duration).field_structures[0].attributes.hp == 6, "playback displays repaired structure HP")
			w = Codec.decode(Codec.encode(r.world).text).value
			check(w == r.world and Marching.valid(w), "repair deadline survives exact save transport")
			var released: Dictionary = phase("wright_repair_release_%d_%d" % [pid, site], w, "wright-repair", 5)
			var marcher: Dictionary = Kanifous._entity(released.world, builder.id)
			check(marcher.attributes.wright_released and (int(marcher.attributes.x_fp)-int(builder.attributes.x_fp))*int(builder.attributes.direction) == 800, "full repaired post releases Wright to normal marching after its guard timer")
			w = released.world
			w.data.field_structures[0].attributes.hp = 2
			var gone: Dictionary = phase("wright_no_remote_repair_%d_%d" % [pid, site], w, "wright-repair", 6)
			check(facts(gone, "WRIGHT_STRUCTURE_REPAIRED").is_empty() and Fort.rows(gone.world)[0].attributes.hp == 2, "departed Wright does not repair remotely")
		var fixture: Dictionary = guarded(pid, 0, 6, 600)
		var r: Dictionary = phase("wright_full_minimum_guard_%d" % pid, fixture.world)
		check(Fort.distance(Kanifous._entity(r.world, fixture.builder.id).attributes, fixture.builder.attributes) == 0, "full-HP structure still receives the complete initial guard period")
		check(facts(r, "WRIGHT_STRUCTURE_REPAIRED").is_empty(), "full HP never produces an overheal event")
		r = phase("wright_full_timer_release_%d" % pid, r.world, "wright-repair", 3)
		check(Kanifous._entity(r.world, fixture.builder.id).attributes.wright_released, "full structure releases guard exactly at timer boundary")
		fixture = guarded(pid, 0, 1, 999)
		var w: Dictionary = fixture.world
		check(raw_step(w, 2).size() == 1 and Fort.rows(w)[0].attributes.hp == 2, "first repair is recorded")
		w = Codec.decode(Codec.encode(w).text).value
		check(raw_step(w, 2).is_empty() and Fort.rows(w)[0].attributes.hp == 2, "same-round replay cannot repair twice after save/load")
		check(raw_step(w, 2, 26).is_empty(), "repair is not ready one tick before deadline")
		check(raw_step(w, 2, 27).size() == 1 and Fort.rows(w)[0].attributes.hp == 3, "repair is ready exactly at deadline")
		check(raw_step(w, 2, 199).size() == 1 and Fort.rows(w)[0].attributes.hp == 4, "late-round repair sets an absolute deadline")
		w = Codec.decode(Codec.encode(w).text).value
		check(raw_step(w, 3).is_empty(), "new round does not reset a saved cooldown")
		check(raw_step(w, 3, 26).size() == 1 and Fort.rows(w)[0].attributes.hp == 5, "cooldown expires at the correct tick across round boundary")
		fixture = guarded(pid, 0, 6, 999)
		w = fixture.world
		check(raw_step(w, 2).is_empty(), "full structure neither overheals nor spends an unused repair")
		w.data.field_structures[0].attributes.hp = 4
		check(raw_step(w, 2).size() == 1 and Fort.rows(w)[0].attributes.hp == 5, "unused repair can address damage later in the round")
		fixture = guarded(pid, 0)
		w = fixture.world
		w.data.field_structures[0].attributes.builder_id = "replacement-builder"
		check(raw_step(w, 2).size() == 1 and Fort.rows(w)[0].attributes.hp == 4, "nearby Wright can assist a structure even when its original guard assignment no longer matches")
		for state in [{"waiting": true}, {"movement_ready_round": 3}, {"rout_round": 2}, {"hidden": true}]:
			fixture = guarded(pid, 0)
			w = fixture.world
			var ids = Work.Ids.new(); ids.restore(w.entities)
			var a: Dictionary = fixture.builder.attributes.duplicate(true); a.merge(state, true)
			ids.update(fixture.builder.id, pid, a); w.entities = ids.snapshot()
			check(raw_step(w, 2).is_empty() and Fort.rows(w)[0].attributes.hp == 3, "inactive builder cannot repair")
		fixture = guarded(pid, 0)
		check(raw_step(fixture.world, 2, 0, {fixture.builder.id: true}).is_empty(), "fleeing builder cannot repair")
		fixture = guarded(pid, 0)
		w = fixture.world
		var ids = Work.Ids.new(); ids.restore(w.entities); ids.retire(fixture.builder.id); w.entities = ids.snapshot()
		r = phase("wright_dead_no_repair_%d" % pid, w)
		check(facts(r, "WRIGHT_STRUCTURE_REPAIRED").is_empty() and Fort.rows(r.world)[0].attributes.hp == 3, "dead builder leaves persistent damage")
		fixture = guarded(pid, 0)
		w = fixture.world; w.data.field_structures = []
		r = phase("wright_destroyed_structure_release_%d" % pid, w)
		check(Kanifous._entity(r.world, fixture.builder.id).attributes.wright_released and facts(r, "WRIGHT_STRUCTURE_BUILT").is_empty(), "destroyed structure releases Wright without a second construction")
		fixture = guarded(pid, 0)
		w = fixture.world
		ids = Work.Ids.new(); ids.restore(w.entities)
		var a: Dictionary = fixture.builder.attributes.duplicate(true)
		a.direction *= -1; ids.update(fixture.builder.id, 1-pid, a); w.entities = ids.snapshot()
		check(raw_step(w, 2).is_empty() and Fort.rows(w)[0].attributes.hp == 3, "changed allegiance cannot repair the former owner's structure")
		for invalid in [{"wright_repair_next_tick": -1}, {"wright_repair_next_tick": 1.5}, {"wright_repair_round": -1}, {"wright_released": 1}, {"wright_built": false}]:
			a = fixture.builder.attributes.duplicate(true); a.merge(invalid, true)
			check(not Fort.valid_unit(a), "save validation rejects malformed repair or release state")
	if phase_output != null: phase_output.close()
	print("U13 Wright repair failures: ", failures)
	quit(1 if failures else 0)
