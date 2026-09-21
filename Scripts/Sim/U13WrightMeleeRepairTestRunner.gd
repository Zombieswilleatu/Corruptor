extends "res://Scripts/Sim/U13WrightRepairTestRunner.gd"

func other_wall(f: Dictionary, pid: int, hp: int = 3) -> Dictionary:
	var p: Dictionary = Fort.site_point(pid, 1)
	var builder: Dictionary = put(f.world, "Wright", pid, p.x_fp, {"y_fp": p.y_fp}, 30)
	var ids = Work.Ids.new(); ids.restore(f.world.entities); ids.retire(builder.id); f.world.entities = ids.snapshot()
	var wall: Dictionary = {"id": Work.Data.instance_id("wright_structure", builder.id, "1"), "kind": "fortification", "owner": pid, "attributes": {"structure": "Wall", "site": 1, "lane": "Lord", "x_fp": p.x_fp, "y_fp": p.y_fp, "hp": hp, "max_hp": 6, "armor": 0, "max_armor": 2, "attack": 0, "ranged_next_tick": 0, "builder_id": builder.id}}
	f.world.data.field_structures.append(wall)
	return wall

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	for pid in [0, 1]:
		for site in [0, 2]:
			for reach in [90, 91]:
				var f: Dictionary = guarded(pid, site, 3, 9999)
				var wall: Dictionary = Fort.rows(f.world)[0]
				var a: Dictionary = f.builder.attributes.duplicate(true)
				a.x_fp = wall.attributes.x_fp - (reach + (24 if site == 0 else 0)) * (1 if pid == 0 else -1)
				var ids = Work.Ids.new(); ids.restore(f.world.entities); ids.update(f.builder.id, pid, a); f.world.entities = ids.snapshot()
				var events: Array = raw_step(f.world, 2)
				check(events.filter(func(e): return e.event.type == "WRIGHT_STRUCTURE_REPAIRED").size() == (1 if reach == 90 else 0), "wall/tower repair includes melee reach 90 and excludes 91")
		for probe in [[0, 42, true], [0, 43, false], [80, 30, false], [45, 21, true]]:
			var f: Dictionary = guarded(pid, 0, 3, 9999)
			var wall: Dictionary = Fort.rows(f.world)[0]
			var a: Dictionary = f.builder.attributes.duplicate(true)
			a.x_fp = wall.attributes.x_fp - (24 + probe[0]) * (1 if pid == 0 else -1)
			a.y_fp = wall.attributes.y_fp + 150 + probe[1]
			var ids = Work.Ids.new(); ids.restore(f.world.entities); ids.update(f.builder.id, pid, a); f.world.entities = ids.snapshot()
			var events: Array = raw_step(f.world, 2)
			check(events.filter(func(e): return e.event.type == "WRIGHT_STRUCTURE_REPAIRED").size() == (1 if probe[2] else 0), "repairs obey lateral and diagonal melee contact, not a circular radius")
		var f: Dictionary = guarded(pid, 0, 6, 9999)
		var wall: Dictionary = other_wall(f, pid)
		check(not Fort.in_melee(f.builder, wall), "opposite wall is outside melee repair range from the home post")
		check(raw_step(f.world, 2).is_empty() and wall.attributes.hp == 3, "guard cannot remotely repair the other wall")
		check(Fort.goal(f.builder, Fort.rows(f.world), 400, {}) == Fort.anchor(pid, 1), "guard walks to the other damaged wall when its own wall is healthy")
		var r: Dictionary = phase("wright_walk_to_other_wall_%d" % pid, f.world)
		var repairs: Array = facts(r, "WRIGHT_STRUCTURE_REPAIRED")
		check(repairs.size() == 3 and repairs[0].tick > 0, "repairs start after walking and repeat until full")
		var frame: Dictionary = facts(r, "MARCHING_TICK")[repairs[0].tick - 1]
		var actor: Dictionary = frame.units.filter(func(u): return u.id == f.builder.id)[0]
		check(Fort.in_melee(actor, wall), "first repair occurs only after the Wright reaches melee contact")
		check(Fort.find(Fort.rows(r.world), pid, "Lord", 1).attributes.hp == 6, "other wall is repaired fully")
		var after: Dictionary = Kanifous._entity(r.world, f.builder.id)
		check(Fort.distance(after.attributes, Fort.anchor(pid, 0)) <= 16*16, "helper returns to its guard post after repairs")
		check(Fort.ranged_guard(after, Fort.rows(r.world), 2), "returned guard retains its ranged defensive stance")
		f = guarded(pid, 0, 3, 9999)
		wall = other_wall(f, pid)
		check(Fort.goal(f.builder, Fort.rows(f.world), 400, {}) == Fort.anchor(pid, 0), "damage to its own structure has repair priority")
		# Cooperative work still applies when both helpers are physically in contact.
		var home: Dictionary = Fort.anchor(pid, 0)
		put(f.world, "Wright", pid, home.x_fp, {"y_fp": home.y_fp}, 31)
		raw_step(f.world, 2)
		check(Fort.find(Fort.rows(f.world), pid, "Lord", 0).attributes.hp == 5 and wall.attributes.hp == 3, "two local Wrights cooperate without healing the distant wall")
	if phase_output != null: phase_output.close()
	print("U13 Wright melee repair failures: ", failures)
	quit(1 if failures else 0)
