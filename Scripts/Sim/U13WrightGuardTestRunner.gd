extends "res://Scripts/Sim/U13WrightRepairTestRunner.gd"

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	for pid in [0, 1]:
		for site in [0, 2]:
			for reach in [400, 401]:
				var f: Dictionary = guarded(pid, site, 6, 9999)
				var home: Dictionary = Fort.anchor(pid, site)
				put(f.world, "Butcher", 1-pid, home.x_fp + reach * (1 if pid == 0 else -1), {"y_fp": home.y_fp, "step_fp": 0, "hp": 100, "max_hp": 100, "armor": 0, "attack": 1})
				var r: Dictionary = phase("guard_range_%d_%d_%d" % [pid, site, reach], f.world)
				var shots: Array = facts(r, "MARCHER_RANGED_ATTACK").filter(func(h): return h.attacker.id == f.builder.id)
				check(shots.size() == (4 if reach == 400 else 0), "defending Wright fires every 50 ticks within 400 range, excluding 401")
				check(shots.all(func(h): return h.damage_dealt == 1), "defensive arrows use ordinary Wright damage without the Vulture-versus-Butcher bonus")
				check(not facts(r, "MARCHER_MELEE_ATTACK").any(func(h): return h.attacker.id == f.builder.id), "ranged guard never double-attacks with melee")
				var after: Dictionary = Kanifous._entity(r.world, f.builder.id)
				check(Fort.distance(after.attributes, home) == 0, "ranged guard remains behind the fortification")
		var f: Dictionary = guarded(pid, 0, 6, 400)
		var home: Dictionary = Fort.anchor(pid, 0)
		put(f.world, "Butcher", 1-pid, home.x_fp + 500*(1 if pid == 0 else -1), {"y_fp": home.y_fp, "step_fp": 0, "hp": 100, "max_hp": 100})
		var r: Dictionary = phase("guard_alert_%d" % pid, f.world)
		check(not Kanifous._entity(r.world, f.builder.id).attributes.wright_released and Fort.distance(Kanifous._entity(r.world, f.builder.id).attributes, home) == 0, "nearby threat keeps a full-health post guarded after the minimum guard period")
		f = guarded(pid, 0, 6, 9999)
		put(f.world, "Butcher", 1-pid, home.x_fp + 60*(1 if pid == 0 else -1), {"y_fp": home.y_fp, "step_fp": 0, "hp": 100, "max_hp": 100, "attack": 1, "armor": 0})
		r = phase("guard_point_blank_%d" % pid, f.world)
		check(facts(r, "MARCHER_RANGED_ATTACK").filter(func(h): return h.attacker.id == f.builder.id).size() == 4 and not facts(r, "MARCHER_MELEE_ATTACK").any(func(h): return h.attacker.id == f.builder.id), "guard stance has one attack cadence even at point blank")
		for distance_fp in [60, 300]:
			var w: Dictionary = phase_world()
			var actor: Dictionary = put(w, "Wright", pid, 1200, {"step_fp": 0, "hp": 100, "max_hp": 100})
			put(w, "Butcher", 1-pid, 1200 + distance_fp*(1 if pid == 0 else -1), {"step_fp": 0, "hp": 100, "max_hp": 100, "attack": 1, "armor": 0})
			r = phase("field_wright_%d_%d" % [pid, distance_fp], w)
			check(not facts(r, "MARCHER_RANGED_ATTACK").any(func(h): return h.attacker.id == actor.id), "ordinary field Wright has no ranged attack")
			check(facts(r, "MARCHER_MELEE_ATTACK").filter(func(h): return h.attacker.id == actor.id).size() == (6 if distance_fp == 60 else 0), "field Wright keeps ordinary melee reach and cooldown")
		f = guarded(pid, 0, 6, 9999)
		f.world.data.field_structures = []
		put(f.world, "Butcher", 1-pid, home.x_fp + 300*(1 if pid == 0 else -1), {"y_fp": home.y_fp, "step_fp": 0, "hp": 100, "max_hp": 100, "attack": 1})
		r = phase("guard_structure_lost_%d" % pid, f.world)
		check(not facts(r, "MARCHER_RANGED_ATTACK").any(func(h): return h.attacker.id == f.builder.id), "destroying the post removes the ranged stance")
	if phase_output != null: phase_output.close()
	print("U13 Wright ranged guard failures: ", failures)
	quit(1 if failures else 0)
