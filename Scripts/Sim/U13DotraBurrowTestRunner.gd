extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

const Burrows = preload("res://Scripts/Sim/U13DotraBurrows.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")

func selection_checks() -> void:
	for pid in [0, 1]:
		var direction: int = 1 if pid == 0 else -1
		for position in [0, 1200, 2400]:
			for lateral in [0, 100, 500, 600]:
				var a: Dictionary = Monsters.profile("Dotra", "Lord", pid, 0, 1)
				a.x_fp = position; a.y_fp = lateral
				Burrows.begin(a, 400)
				check(a.dotra_holes.size() == 3 and Monsters.valid_unit(a), "three valid exits remain inside the field, including at lane edges")
				check(Burrows.distance(a.dotra_holes[0], a.dotra_holes[1]) >= 80 * 80 and Burrows.distance(a.dotra_holes[0], a.dotra_holes[2]) >= 80 * 80 and Burrows.distance(a.dotra_holes[1], a.dotra_holes[2]) >= 80 * 80, "holes remain spread apart even beside a goal")
		var w: Dictionary = phase_world()
		var actor: Dictionary = put(w, "Dotra", pid, 1200 - direction * 600, {"hidden": true, "hp": 100, "max_hp": 100})
		var crowded: Dictionary = put(w, "Butcher", 1-pid, 1200 - direction * 350, {"step_fp": 0, "hp": 100, "max_hp": 100})
		put(w, "Butcher", 1-pid, 1200 - direction * 280, {"step_fp": 0, "hp": 100, "max_hp": 100}, 1)
		var loner: Dictionary = put(w, "Vulture", 1-pid, 1200 + direction * 150, {"y_fp": 500, "step_fp": 0, "hp": 100, "max_hp": 100})
		put(w, "Butcher", pid, loner.attributes.x_fp, {"y_fp": 550, "step_fp": 0})
		put(w, "Dotra", 1-pid, loner.attributes.x_fp, {"hidden": true, "movement_ready_round": 3}, 1)
		put(w, "Butcher", 1-pid, loner.attributes.x_fp, {"lane": "Castle", "step_fp": 0}, 2)
		var result: Dictionary = phase("dotra_isolated_exit_%d" % pid, w)
		var emerge: Array = facts(result, "MONSTER_BURROW_EMERGED").filter(func(d): return d.source.id == actor.id)
		check(emerge.size() == 1 and emerge[0].target_id == loner.id and emerge[0].hole_index == 2 and emerge[0].tick == 24, "Dotra bypasses the closer cluster to emerge beside the isolated enemy")
		var strikes: Array = facts(result, "MONSTER_ATTACK").filter(func(d): return d.ability == "Ambush" and d.attacker.id == actor.id)
		check(strikes.size() == 1 and strikes[0].target.id == loner.id and strikes[0].damage_dealt + mini(5, int(strikes[0].target.attributes.armor)) == 5 and strikes[0].tick == 24, "one existing five-damage ambush follows emergence within reach")
		var playback = Playback.new()
		check(playback.build(result.events.map(func(r): return r.event)), "burrow events replay successfully")
		var at: float = playback.tick_time(24)
		var before: Dictionary = playback.sample(at - 0.00001)
		var hidden: Dictionary = before.units.filter(func(u): return u.id == actor.id)[0]
		check(hidden.attributes.hidden and hidden.attributes.dotra_holes.size() == 3 and hidden.attributes.visual_x == actor.attributes.x_fp, "replay holds the hidden origin instead of sliding toward the future exit")
		var after: Dictionary = playback.sample(at + 0.00001)
		check(after.units.any(func(u): return u.id == actor.id and not u.attributes.hidden and u.attributes.dotra_holes.is_empty()) and after.monster_attacks.any(func(a): return a.ability == "DotraEmerge"), "exit dust and exposed body appear at the recorded emergence tick")
		for View in [preload("res://Prototype/U13/U13BoardLanes.gd"), preload("res://Prototype/U13/U13SandboxLaneView.gd")]:
			var view = View.new(); view.display_settings_path = ""; root.add_child(view); view.size = Vector2(640, 900)
			view.show_frame(before, 2)
			await process_frame
			check(view.burrow_markers("Lord").filter(func(m): return m.owner == pid).size() == 3, "both lane views show all three exits for either seat")
			view.show_frame(after, 2)
			await process_frame
			check(view.burrow_markers("Lord").filter(func(m): return m.owner == pid).is_empty(), "exit markers clear on emergence")
			view.show_frame(before, 2)
			view.show_deaths([{"unit": hidden}])
			check(view.burrow_markers("Lord").filter(func(m): return m.owner == pid).is_empty(), "a dead burrower leaves no exit markers")
			view.reset_effects()
			view.show_frame({"units": [], "clash": []}, 2)
			check(view.burrow_markers("Lord").is_empty(), "resetting the arena clears all burrow markers")
			view.free()
		# A target may die, switch sides, hide, or become unreachable after selection.
		actor.attributes["dotra_ambush_target"] = loner.id
		var rows: Array = [crowded, loner]
		check(Burrows.prepared_target(actor, rows, 424).id == loner.id, "the chosen live victim remains stable while closing")
		check(Burrows.prepared_target(actor, [crowded], 424).id == crowded.id, "a dead victim is replaced")
		loner.owner = pid
		check(Burrows.prepared_target(actor, rows, 424).id == crowded.id, "a charmed victim is replaced")
		loner.owner = 1-pid; loner.attributes["hidden"] = true
		check(Burrows.prepared_target(actor, rows, 424).id == crowded.id, "a hidden victim is replaced without tracking it")
		loner.attributes.hidden = false
		actor.attributes["navigation"] = {"avoid": {loner.id: 450}}
		check(Burrows.prepared_target(actor, rows, 424).id == crowded.id, "an unreachable victim is replaced during navigation cooldown")

func exit_and_clock_checks() -> void:
	var w: Dictionary = phase_world()
	var actor: Dictionary = put(w, "Dotra", 0, 600, {"hidden": true})
	Burrows.begin(actor.attributes, 400)
	var occupied: Dictionary = put(w, "Butcher", 1, 1200, {"y_fp": 500})
	var points: Array = Burrows.exits(actor, [actor, occupied], [])
	check(points[2] != actor.attributes.dotra_holes[2] and Burrows.distance(points[2], occupied.attributes) >= 42 * 42, "occupied exit uses a nearby free footprint, never exact superimposition")
	var blockers: Array = []
	for x in range(1032, 1370, 42):
		for y in range(332, 669, 42):
			blockers.append({"id": "%d:%d" % [x, y], "kind": "marcher", "owner": 1, "attributes": {"lane": "Lord", "x_fp": x, "y_fp": y}})
	points = Burrows.exits(actor, blockers, [])
	check(points[2].is_empty() and Burrows.choose_exit(actor, points, occupied) in [0, 1], "a completely crowded hole is skipped in favor of another usable exit")
	var wall: Dictionary = {"id": "test-wall", "kind": "fortification", "owner": 1, "attributes": {"lane": "Lord", "structure": "Wall", "x_fp": 1200, "y_fp": 500}}
	points = Burrows.exits(actor, [], [wall])
	check(not points[2].is_empty() and Burrows.clear_exit(actor, points[2], [], [wall]) and not Burrows.clear_exit(actor, {"x_fp": 1200, "y_fp": 500}, [], [wall]), "emergence clears the whole wall footprint")
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	var react: Callable = Callable(Game.Content.new(), "react")
	var c: Dictionary = context(w)
	MonsterFX.step(w, buffer, c, 199, react)
	var holes: Array = buffer.get_entity(actor.id).attributes.dotra_holes.duplicate(true)
	c.round = 3
	MonsterFX.step(w, buffer, c, 0, react)
	check(buffer.get_entity(actor.id).attributes.dotra_holes == holes and buffer.get_entity(actor.id).attributes.hidden, "cross-round wind-up retains the same holes and deadline")
	check(facts(MonsterFX.step(w, buffer, c, 22, react), "MONSTER_BURROW_EMERGED").is_empty(), "cross-round emergence does not fire a tick early")
	check(facts(MonsterFX.step(w, buffer, c, 23, react), "MONSTER_BURROW_EMERGED").size() == 1, "cross-round emergence uses absolute simulation time")
	# Selection is made at emergence, while the three original exits stay fixed.
	w = phase_world()
	actor = put(w, "Dotra", 0, 600, {"hidden": true, "hp": 100, "max_hp": 100})
	var front: Dictionary = put(w, "Butcher", 1, 850, {"step_fp": 0})
	put(w, "Butcher", 1, 920, {"step_fp": 0}, 1)
	var lone: Dictionary = put(w, "Vulture", 1, 1400, {"y_fp": 500, "step_fp": 0})
	buffer.restore(w.entities); c = context(w)
	MonsterFX.step(w, buffer, c, 0, react)
	holes = buffer.get_entity(actor.id).attributes.dotra_holes.duplicate(true)
	front.attributes.x_fp = 1900
	buffer.update(front.id, front.owner, front.attributes)
	lone.attributes.x_fp = 950; lone.attributes.y_fp = 300
	buffer.update(lone.id, lone.owner, lone.attributes)
	MonsterFX.step(w, buffer, c, 23, react)
	check(buffer.get_entity(actor.id).attributes.dotra_holes == holes, "enemy movement never relocates the already visible holes")
	var emerged: Array = facts(MonsterFX.step(w, buffer, c, 24, react), "MONSTER_BURROW_EMERGED")
	check(emerged.size() == 1 and emerged[0].target_id == front.id, "emergence reevaluates isolation after the enemies reposition")
	# All exits temporarily occupied: remain underground, then retry the same holes.
	w = phase_world(); actor = put(w, "Dotra", 0, 600, {"hidden": true})
	buffer.restore(w.entities); c = context(w)
	MonsterFX.step(w, buffer, c, 0, react)
	holes = buffer.get_entity(actor.id).attributes.dotra_holes.duplicate(true)
	for hole in holes:
		w.data["field_structures"] = w.data.get("field_structures", [])
		for delta in [-120, 0, 120]:
			w.data.field_structures.append({"id": str(hole.x_fp) + ":" + str(delta), "kind": "fortification", "owner": 1, "attributes": {"lane": "Lord", "structure": "Wall", "x_fp": int(hole.x_fp) + delta, "y_fp": hole.y_fp}})
	check(facts(MonsterFX.step(w, buffer, c, 24, react), "MONSTER_BURROW_EMERGED").is_empty() and buffer.get_entity(actor.id).attributes.hidden, "fully obstructed exits do not force an illegal emergence")
	w.data.field_structures = []
	check(facts(MonsterFX.step(w, buffer, c, 25, react), "MONSTER_BURROW_EMERGED").size() == 1, "burrow retries promptly when an exit becomes usable")
	for value in [null, {}, [null, null, null], [{"x_fp": 0, "y_fp": 100}, {}, {}]]:
		var forged: Dictionary = actor.attributes.duplicate(true); forged["dotra_holes"] = value
		check(not Monsters.valid_unit(forged), "malformed burrow data is rejected")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	await selection_checks()
	exit_and_clock_checks()
	if phase_output != null: phase_output.close()
	print("U13 Dotra burrow check failures: ", failures)
	quit(0 if failures == 0 else 1)
