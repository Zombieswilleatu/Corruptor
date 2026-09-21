extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")
const Melee = preload("res://Scripts/Sim/U13FieldMelee.gd")

func clear_units(w: Dictionary) -> void:
	var ids = Work.Ids.new(); ids.restore(w.entities)
	for unit in w.entities.entities:
		if unit.kind == "marcher": ids.retire(unit.id)
	w.entities = ids.snapshot()

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	var w: Dictionary = phase_world()
	for pid in [0, 1]:
		for i in range(2): put(w, "Butcher", pid, 1000 + pid * 80, {"y_fp": 100 + i * 400, "hp": 3, "armor": 0, "step_fp": 0}, i)
	var r: Dictionary = phase("independent_simultaneous_melee", w)
	var strikes: Array = facts(r, "MARCHER_MELEE_ATTACK")
	check(strikes.size() == 4 and strikes.all(func(f): return f.tick == 0), "two separate fights strike on the same tick")
	check(facts(r, "MARCHER_DEFEATED").size() == 4, "reciprocal lethal hits all land exactly once")
	check(r.world.data.marching_duels.is_empty(), "current combat stores no exclusive lane duels")
	w = phase_world()
	for i in range(2): put(w, "Butcher", 0, 1000, {"y_fp": 280 + 40 * i, "hp": 100, "max_hp": 100, "armor": 0, "attack": 1, "step_fp": 0}, i)
	put(w, "Penitent", 1, 1060, {"hp": 100, "max_hp": 100, "armor": 0, "step_fp": 0})
	r = phase("several_attack_one_enemy", w)
	var first: Array = facts(r, "MARCHER_MELEE_ATTACK").filter(func(f): return f.tick == 0)
	check(first.size() == 3 and first.filter(func(f): return f.attacker.owner == 0).size() == 2, "several allies can hit one enemy without waiting for a duel slot")
	for pid in [0, 1]:
		for boundary in [[90, 0, true], [91, 0, false], [0, 42, true], [0, 43, false], [60, 30, true], [70, 30, false]]:
			w = phase_world()
			put(w, "Penitent", pid, 1200, {"hp": 100, "max_hp": 100, "step_fp": 0})
			put(w, "Butcher", 1 - pid, 1200 + int(boundary[0]), {"y_fp": 300 + int(boundary[1]), "hp": 100, "max_hp": 100, "step_fp": 0})
			r = phase("melee_boundary_%d_%d_%d" % [pid, boundary[0], boundary[1]], w)
			check(not facts(r, "MARCHER_MELEE_ATTACK").is_empty() == bool(boundary[2]), "owner %d melee footprint accepts only %d forward / %d sideways" % [pid, boundary[0], boundary[1]])
	for pid in [0, 1]:
		w = phase_world()
		for i in range(3): put(w, "Wright", pid, 400 if pid == 0 else 2000, {"y_fp": [100, 500, 300][i]}, i)
		r = phase("wright_first_builds_%d" % pid, w)
		var built: Array = facts(r, "WRIGHT_STRUCTURE_BUILT")
		check(built.size() >= 2 and built[0].structure.attributes.site < 2 and built[1].structure.attributes.site < 2, "both walls complete before a tower can be constructed")
		w = r.world
		var loaded: Dictionary = Codec.decode(Codec.encode(w).text).value
		check(loaded == w and Marching.valid(loaded), "construction, HP, cooldown and guard time survive exact save transport")
		r = phase("wright_tower_and_departure_%d" % pid, loaded, "monster-check", 3)
		w = r.world
		check(Fort.rows(w).size() == 3 and Fort.rows(w).filter(func(s): return s.attributes.structure == "Tower").size() == 1, "each side has exactly two walls and one tower")
		var builders: Array = w.entities.entities.filter(func(u): return u.kind == "marcher")
		check(builders.all(func(u): return u.attributes.get("wright_built", false) and u.attributes.attack == 1), "every Wright builds once and uses the reduced offensive profile")
		check(builders.any(func(u): return Fort.distance(u.attributes, Fort.anchor(pid, u.attributes.wright_site)) > 16 * 16), "finished Wrights leave their posts after one complete round")
		var before: Array = Fort.rows(w).duplicate(true)
		clear_units(w)
		put(w, "Butcher", 1 - pid, 1050 if pid == 0 else 1350, {"step_fp": 0, "hp": 100, "max_hp": 100, "armor": 0})
		r = phase("tower_fires_beyond_vulture_range_%d" % pid, w, "monster-check", 4)
		var shots: Array = facts(r, "MARCHER_RANGED_ATTACK")
		check(not shots.is_empty() and shots.all(func(f): return f.attacker.kind == "fortification" and f.attacker.attributes.structure == "Tower"), "tower independently attacks beyond Vulture range")
		check(shots.size() <= 4 and shots[0].damage_dealt == 1, "tower uses one damage and the Vulture's 50-tick cadence")
		check(Fort.rows(r.world).all(func(s): return s.attributes.hp == s.attributes.max_hp and s.attributes.armor == s.attributes.max_armor), "structures are unaffected by distant enemy melee")
		var bad: Dictionary = w.duplicate(true); bad.data.field_structures.append(before[0])
		check(not Marching.valid(bad), "save validation rejects duplicate occupied sites")
		# Leave a completed wall in the way of a ground attacker.
		clear_units(w)
		var enemy: Dictionary = put(w, "Butcher", 1 - pid, 900 if pid == 0 else 1500, {"y_fp": 150, "attack": 6, "hp": 100, "max_hp": 100}, 1)
		r = phase("walls_block_and_break_%d" % pid, w, "monster-check", 4)
		var destroyed: Array = facts(r, "WRIGHT_STRUCTURE_DESTROYED").filter(func(f): return f.structure.attributes.site == 0)
		check(destroyed.size() == 1, "strong attacker breaks the wall to advance through its section")
		var blocked: bool = true
		if not destroyed.is_empty():
			for tick in facts(r, "MARCHING_TICK"):
				if tick.tick >= destroyed[0].tick: break
				for unit in tick.units:
					if unit.id == enemy.id: blocked = blocked and (int(unit.attributes.x_fp) > 640 if pid == 0 else int(unit.attributes.x_fp) < 1760)
		check(blocked, "no ground unit crosses an intact hostile wall")
		check(facts(r, "MARCHER_DEFEATED").is_empty(), "destroying structures never triggers marcher death rewards")
		var broken: Dictionary = r.world.duplicate(true)
		# Isolate rebuilding: damaged surviving posts have repair priority.
		clear_units(broken)
		for structure in Fort.rows(broken): structure.attributes.hp = structure.attributes.max_hp
		put(broken, "Wright", pid, 560 if pid == 0 else 1840, {"y_fp": 150}, 3)
		var rebuilt: Dictionary = phase("replace_destroyed_wall_%d" % pid, broken, "monster-check", 5)
		check(not Fort.find(Fort.rows(rebuilt.world), pid, "Lord", 0).is_empty() and Fort.rows(rebuilt.world).size() <= 3, "a later Wright rebuilds a destroyed wall without adding extra sites")
		# Allies pass through the same intact structure; no automatic healing.
		clear_units(w)
		var ally: Dictionary = put(w, "Butcher", pid, 400 if pid == 0 else 2000, {"y_fp": 150}, 2)
		w.data.field_structures[0].attributes.hp = 3
		r = phase("friendly_passage_%d" % pid, w, "monster-check", 4)
		var survivor: Dictionary = Kanifous._entity(r.world, ally.id)
		check(survivor.attributes.x_fp > 640 if pid == 0 else survivor.attributes.x_fp < 1760, "allies pass their own wall without being queued")
		check(r.world.data.field_structures[0].attributes.hp == 3, "structures do not regenerate for free")
		clear_units(w)
		put(w, "Butcher", 1 - pid, 1081 if pid == 0 else 1319, {"step_fp": 0, "hp": 100, "max_hp": 100}, 4)
		r = phase("tower_range_excludes_601_%d" % pid, w, "monster-check", 4)
		check(facts(r, "MARCHER_RANGED_ATTACK").is_empty(), "tower cannot fire beyond its actual range")
		clear_units(w)
		var flyer: Dictionary = put(w, "Fyra", 1 - pid, 900 if pid == 0 else 1500, {"y_fp": 150, "hp": 100, "max_hp": 100})
		r = phase("flying_over_walls_%d" % pid, w, "monster-check", 4)
		var flying_after: Dictionary = Kanifous._entity(r.world, flyer.id)
		check(not flying_after.is_empty() and (flying_after.attributes.x_fp < 640 if pid == 0 else flying_after.attributes.x_fp > 1760), "flying monsters pass over ground walls")
		# A tower build cannot finish after either required wall is lost.
		clear_units(w)
		w.data.field_structures = Fort.rows(w).filter(func(s): return s.attributes.site == 1)
		put(w, "Wright", pid, 400 if pid == 0 else 2000, {"wright_site": 2, "wright_owner": pid, "wright_progress": 31}, 5)
		r = phase("tower_prerequisite_destroyed_%d" % pid, w, "monster-check", 4)
		check(Fort.find(Fort.rows(r.world), pid, "Lord", 2).is_empty() and not Fort.find(Fort.rows(r.world), pid, "Lord", 0).is_empty(), "Wright abandons an ineligible tower and rebuilds the missing wall")
	w = phase_world()
	var builder: Dictionary = put(w, "Wright", 0, 560, {"y_fp": 150})
	put(w, "Butcher", 1, 560, {"y_fp": 180, "attack": 100, "step_fp": 0})
	r = phase("builder_killed_before_completion", w)
	check(Kanifous._entity(r.world, builder.id).is_empty() and Fort.rows(r.world).is_empty(), "killing a builder prevents its structure completing")
	clear_units(r.world)
	put(r.world, "Wright", 0, 560, {"y_fp": 150}, 1)
	r = phase("dead_builder_releases_site", r.world, "monster-check", 3)
	check(Fort.rows(r.world).size() == 1 and Fort.rows(r.world)[0].attributes.site == 0, "another Wright can claim the dead builder's site")
	var charmed: Dictionary = phase_world()
	put(charmed, "Wright", 1, 1840, {"y_fp": 150, "wright_site": 0, "wright_owner": 0, "wright_progress": 31})
	put(charmed, "Wright", 1, 1840, {"y_fp": 450, "wright_site": 0, "wright_owner": 1, "wright_progress": 1}, 1)
	check(Marching.valid(charmed), "owner change releases stale reservations before the next tick")
	var redirected: Dictionary = phase("charmed_builder_reassigns_site", charmed)
	check(Fort.rows(redirected.world).size() == 2, "charmed builder takes a free site instead of duplicating an existing claim")
	# Beam damage must include structures, without unit death or block rolls.
	w = r.world
	clear_units(w)
	put(w, "Sooge", 1, 2000, {"sprite_form": "turret", "step_fp": 0, "y_fp": 150})
	r = phase("sooge_hits_fortifications", w, "monster-check", 4)
	check(facts(r, "MONSTER_ATTACK").any(func(f): return f.target.kind == "fortification" and f.ability == "Beam" and f.damage_dealt == 0) and Fort.rows(r.world)[0].attributes.armor == Fort.WALL_ARMOR - 3, "Sooge's delayed beam spends wall Armor before HP")
	var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	check(playback.build(r.events.map(func(e): return e.event)) and not playback.sample(playback.duration).field_structures.is_empty(), "playback retains persistent structures in its final picture")
	var display = preload("res://Prototype/U13/U13SandboxLaneView.gd").new()
	root.add_child(display)
	display.size = Vector2(760, 880)
	display.show_frame(playback.sample(playback.duration), 4)
	await process_frame
	check(display.field_structures.size() == Fort.rows(r.world).size(), "sandbox receives the authoritative structure picture")
	var position: Dictionary = {"x_fp": 1200, "y_fp": 300, "lane": "Lord"}
	check(display._monster_point(position) == display.projectile_visual.point(display.travel_rect("Lord"), position), "unit feet and projectile impacts use identical screen coordinates")
	display.free()
	friendly_passage_checks()
	if phase_output != null: phase_output.close()
	print("U13 field combat failures: %d" % failures)
	quit(1 if failures else 0)

func friendly_passage_checks() -> void:
	for pid in [0, 1]:
		var w: Dictionary = phase_world()
		var guard: Dictionary = put(w, "Wright", pid, 560 if pid == 0 else 1840, {"y_fp":450,"wright_site":1,"wright_owner":pid,"wright_progress":32,"wright_built":true,"wright_guard_until":999})
		w.data["field_structures"] = [{"id": Work.Data.instance_id("wright_structure",guard.id,"1"),"kind":"fortification","owner":pid,"attributes":{"site":1,"lane":"Lord","structure":"Wall","x_fp":640 if pid == 0 else 1760,"y_fp":450,"hp":6,"max_hp":6,"armor":2,"max_armor":2,"attack":0,"ranged_next_tick":0,"builder_id":guard.id}}]
		var passers: Array = []
		for i in range(2): passers.append(put(w,"Vulture",pid,450 if pid == 0 else 1950,{"y_fp":450 + i*90},i))
		put(w,"Butcher",1-pid,900 if pid == 0 else 1500,{"y_fp":0,"step_fp":0,"hp":100,"max_hp":100})
		var r: Dictionary = phase("diagonal_guard_passage_%d" % pid,w)
		for passer in passers:
			check(facts(r,"MARCHER_RANGED_ATTACK").any(func(f): return f.attacker.id == passer.id), "both marchers push past stationary guard and reach firing range")
		var after_guard: Dictionary = Kanifous._entity(r.world,guard.id)
		check(after_guard.attributes.x_fp == guard.attributes.x_fp and after_guard.attributes.y_fp == 450, "defending Wright keeps its post while allies pass")
		var crossed: bool = false
		for frame in facts(r,"MARCHING_TICK"):
			for unit in frame.units:
				if unit.id == passers[0].id: crossed = crossed or Fort.distance(unit.attributes,guard.attributes) < 84*84
		check(crossed,"friendly spacing yields instead of repeatedly sidestepping")
