extends "res://Scripts/Sim/U13DotraExposureTestRunner.gd"

const Shroud = preload("res://Scripts/Sim/U13DotraShroud.gd")
const ShroudVisuals = preload("res://Prototype/U13/U13DotraShroudVisuals.gd")

func protected(extra: Dictionary = {}) -> Dictionary:
	return {"hp": 100, "max_hp": 100, "armor": 0, "step_fp": 0, "dotra_concealment_round": 1, "dotra_shroud_from_tick": 400, "dotra_shroud_until_tick": 467}.merged(extra, true)

func fight_checks() -> void:
	for pid in [0, 1]:
		var direction: int = 1 if pid == 0 else -1
		var start: int = 1000 if pid == 0 else 1400
		var w: Dictionary = phase_world()
		var actor: Dictionary = put(w, "Dotra", pid, start, {"hidden": true, "hp": 100, "max_hp": 100, "armor": 0, "step_fp": 0})
		var ally: Dictionary = put(w, "Butcher", pid, start, {"y_fp": 342, "hp": 100, "max_hp": 100, "armor": 0, "step_fp": 0})
		var melee: Dictionary = put(w, "Butcher", 1-pid, start+direction*40, {"y_fp": 320, "hp": 100, "max_hp": 100, "armor": 0, "step_fp": 0})
		put(w, "Vulture", 1-pid, start+direction*300, {"hp": 100, "max_hp": 100, "step_fp": 0})
		var result: Dictionary = phase("shroud_fight_%d" % pid, w)
		var ambush: Dictionary = facts(result, "MONSTER_ATTACK").filter(func(d): return d.ability == "Ambush")[0]
		check(not ambush.attacker.attributes.hidden and ambush.attacker.attributes.dotra_shroud_from_tick == 400 and ambush.attacker.attributes.dotra_shroud_until_tick == 467, "ambush reveals Dotra and immediately starts 67 ticks of untargetability")
		var strikes: Array = facts(result, "MARCHER_MELEE_ATTACK") + facts(result, "MARCHER_RANGED_ATTACK")
		check(strikes.any(func(d): return d.attacker.id == actor.id and d.tick < 67), "Dotra keeps fighting while untargetable")
		check(not strikes.any(func(d): return d.target.id == actor.id and d.tick < 67), "both melee and ranged enemies leave Dotra alone throughout the window")
		check(strikes.any(func(d): return d.target.id == ally.id and d.attacker.id == melee.id and d.tick < 67) and facts(result, "MARCHER_RANGED_ATTACK").any(func(d): return d.target.id == ally.id and d.tick < 67), "his ally draws both melee attacks and ranged fire")
		check(strikes.any(func(d): return d.target.id == actor.id and d.tick >= 67), "enemies can acquire Dotra again after the window ends")
		check(facts(result, "MONSTER_EXPOSURE_PULSE").size() == 1, "shroud preserves the emergence exposure pulse")
		var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
		check(playback.build(result.events.map(func(e): return e.event)), "shroud playback builds")
		var frame: Dictionary = playback.sample(playback.tick_time(0) + 0.0001)
		check(frame.units.any(func(u): return u.id == actor.id and not u.attributes.hidden and ShroudVisuals.active(u)), "visible Dotra has an untargetability marker immediately after emergence")
		check(playback.sample(playback.tick_time(67)-0.0001).units.any(func(u): return u.id == actor.id and ShroudVisuals.active(u)) and not playback.sample(playback.tick_time(67)+0.0001).units.any(func(u): return u.id == actor.id and ShroudVisuals.active(u)), "the marker expires on the exact recorded tick")
		for View in [preload("res://Prototype/U13/U13BoardLanes.gd"), preload("res://Prototype/U13/U13SandboxLaneView.gd")]:
			var view = View.new(); view.display_settings_path = ""; root.add_child(view); view.size = Vector2(640, 900)
			view.show_frame(frame, 2); await process_frame
			check(view._units.any(func(u): return u.id == actor.id and ShroudVisuals.active(u)), "both lane views draw the shroud for either seat")
			view.reset_effects(); check(view._units.is_empty(), "reset clears shroud feedback"); view.free()

func expiry_checks() -> void:
	for pid in [0, 1]:
		var w: Dictionary = phase_world()
		var start: int = 1000 if pid == 0 else 1400
		var actor: Dictionary = put(w, "Dotra", pid, start, protected({"dotra_shroud_from_tick": 590, "dotra_shroud_until_tick": 657}))
		put(w, "Vulture", 1-pid, start+(400 if pid == 0 else -400), {"step_fp": 0})
		var saved: Dictionary = JSON.parse_string(Game.encode_snapshot(w))
		var loaded: Dictionary = bytes_to_var(Marshalls.base64_to_raw(saved.payload))
		check(loaded == w and Marching.valid(loaded), "save/load retains a shroud that crosses an interval boundary")
		var result: Dictionary = phase("shroud_boundary_%d" % pid, loaded, "shroud-expiry", 3)
		var shots: Array = facts(result, "MARCHER_RANGED_ATTACK")
		check(not shots.is_empty() and shots[0].tick == 57 and shots[0].target.id == actor.id, "a waiting shooter acquires Dotra exactly when his remaining 57 ticks expire")
		var a: Dictionary = Kanifous._entity(result.world, actor.id).attributes
		check(a.dotra_shroud_from_tick == 0 and a.dotra_shroud_until_tick == 0, "expiry clears both saved counters for replay deltas")

func targeting_checks() -> void:
	for pid in [0, 1]:
		var direction: int = 1 if pid == 0 else -1
		var start: int = 1000 if pid == 0 else 1400
		for kind in ["Muno", "Sinodek", "Sooge", "Tumler"]:
			var w: Dictionary = phase_world()
			var actor: Dictionary = put(w, "Dotra", pid, start, protected())
			var ally: Dictionary = put(w, "Vulture", pid, start-direction*20, {"y_fp": 430, "hp": 100, "max_hp": 100, "step_fp": 0})
			var extra: Dictionary = {"hp": 100, "max_hp": 100, "step_fp": 0, "hunt_target": actor.id}
			if kind == "Sooge": extra.merge({"sprite_form": "turret", "armor": 6, "max_armor": 6, "attack": 3})
			var enemy: Dictionary = put(w, kind, 1-pid, start+direction*400, extra)
			var result: Dictionary = phase("shroud_target_%d_%s" % [pid, kind], w, selected_seed(enemy.id, "PORTAL", 25))
			check(not facts(result, "MONSTER_ATTACK").any(func(d): return d.ability == "Muno" and d.target.id == actor.id and d.tick < 67), "Muno cannot directly hit shrouded Dotra")
			check(not facts(result, "MONSTER_FIELD_CREATED").any(func(d): return d.field.get("target_id") == actor.id and d.tick < 67) and not facts(result, "MONSTER_BEAM_FIRED").any(func(d): return d.target.id == actor.id and d.tick < 67), "portal and beam acquisition skip shrouded Dotra")
			var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new(); playback.build(result.events.map(func(e): return e.event))
			if kind == "Tumler": check(playback.sample(playback.tick_time(0)+0.0001).units.any(func(u): return u.id == enemy.id and u.attributes.hunt_target == ally.id), "Tumler drops a previously marked Dotra and hunts his ally")
		# Retained movement must not keep chasing the unavailable body.
		var w: Dictionary = phase_world()
		var actor: Dictionary = put(w, "Dotra", pid, start, protected())
		var enemy: Dictionary = put(w, "Butcher", 1-pid, start+direction*60, {"navigation": {"target": actor.id, "path": [{"x_fp": start, "y_fp": 330}]}})
		check(Marching.Navigation.retained(enemy, [actor]).is_empty(), "retained navigation releases a shrouded target")
		var proposed: Dictionary = {"x_fp": enemy.attributes.x_fp, "y_fp": 304}
		var moved: Dictionary = Marching.Navigation.steer(enemy, proposed, {"x_fp": start-direction*100, "y_fp": 400}, "ally", [actor, enemy], [], 4, 410)
		check(moved.x_fp != enemy.attributes.x_fp or moved.y_fp != enemy.attributes.y_fp, "contact with an untargetable body does not freeze an enemy's movement")

func tower_checks() -> void:
	for pid in [0, 1]:
		var w: Dictionary = phase_world(); var owner: int = 1-pid
		var p: Dictionary = Marching.Fort.site_point(owner, 2)
		var builder: Dictionary = put(w, "Wright", owner, p.x_fp)
		var ids = Work.Ids.new(); ids.restore(w.entities); ids.retire(builder.id); w.entities = ids.snapshot()
		w.data["field_structures"] = [{"id": Marching.Fort.Data.instance_id("wright_structure", builder.id, "2"), "kind": "fortification", "owner": owner, "attributes": {"structure": "Tower", "site": 2, "lane": "Lord", "x_fp": p.x_fp, "y_fp": p.y_fp, "hp": 6, "max_hp": 6, "armor": 4, "max_armor": 4, "attack": 1, "ranged_next_tick": 0, "builder_id": builder.id}}]
		var direction: int = 1 if owner == 0 else -1
		var actor: Dictionary = put(w, "Dotra", pid, p.x_fp+direction*300, protected())
		var ally: Dictionary = put(w, "Butcher", pid, p.x_fp+direction*400, {"hp": 100, "max_hp": 100, "step_fp": 0})
		var result: Dictionary = phase("shroud_tower_%d" % pid, w)
		var shots: Array = facts(result, "MARCHER_RANGED_ATTACK")
		check(shots.any(func(d): return d.target.id == ally.id and d.tick < 67) and not shots.any(func(d): return d.target.id == actor.id and d.tick < 67), "towers redirect fire to an available ally")
		check(shots.any(func(d): return d.target.id == actor.id and d.tick >= 67), "towers can resume targeting Dotra after expiry")

func exception_checks() -> void:
	for ability in ["Poison", "Kopita", "Beam", "Muno", "Ambush"]:
		var w: Dictionary = phase_world()
		var target: Dictionary = put(w, "Dotra", 0, 1000, protected())
		var source: Dictionary = put(w, "Muno", 1, 1200)
		var hit: Dictionary = {"source": source, "target": target.id, "amount": 2, "bypass": ability == "Poison", "ability": ability}
		var result: Dictionary = direct("shroud_damage_" + ability, "packet", w, {"hit": hit, "tick": 10})
		check(Kanifous._entity(result.world, target.id).attributes.hp == (100 if ability in ["Muno", "Ambush"] else 98), "shroud rejects aimed " + ability + " or preserves its area/poison damage")
	var w: Dictionary = phase_world()
	var actor: Dictionary = put(w, "Dotra", 0, 1000, protected({"hp": 9, "max_hp": 10}))
	put(w, "Kopita", 0, 1100, {"step_fp": 0})
	var result: Dictionary = phase("shroud_allied_healing", w)
	check(facts(result, "MONSTER_PULSE")[0].healed.any(func(u): return u.id == actor.id), "allied healing still reaches shrouded Dotra")
	for key in ["dotra_shroud_from_tick", "dotra_shroud_until_tick"]:
		for value in [-1, 0.5, true, "1", null]:
			var a: Dictionary = actor.attributes.duplicate(true); a[key] = value
			check(not Monsters.valid_unit(a), "invalid shroud counter rejected: " + key)
	check(not Shroud.valid({"dotra_shroud_from_tick": 500, "dotra_shroud_until_tick": 400}), "reversed shroud interval is invalid")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0: phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	if args.size() > 1: packet_output = FileAccess.open(args[1], FileAccess.WRITE)
	await fight_checks()
	expiry_checks()
	targeting_checks()
	tower_checks()
	exception_checks()
	if phase_output != null: phase_output.close()
	if packet_output != null: packet_output.close()
	print("U13 Dotra shroud failures: ", failures)
	quit(0 if failures == 0 else 1)
