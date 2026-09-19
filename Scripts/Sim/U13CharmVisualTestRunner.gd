extends SceneTree

const Sim = preload("res://Scripts/Sim/U13LaneSandbox.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const Charm = preload("res://Prototype/U13/U13CharmVisuals.gd")
const Board = preload("res://Prototype/U13/U13BoardLanes.gd")
const Sandbox = preload("res://Prototype/U13/U13SandboxLaneView.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + description)

func fixture(pid: int, target_name: String) -> Dictionary:
	var sim = Sim.new("charm-feedback", true)
	sim.spawn("Fyra", pid)
	sim.spawn(target_name, 1-pid, false, target_name == "Sooge")
	var source: Dictionary = sim.units().filter(func(u): return u.owner == pid)[0]
	var target: Dictionary = sim.units().filter(func(u): return u.owner != pid)[0]
	var ids = Sim.Ids.new()
	ids.restore(sim.world.entities)
	for unit in [source, target]:
		unit.attributes.hp = 100
		unit.attributes.max_hp = 100
		unit.attributes.step_fp = 0
		unit.attributes.y_fp = 300
		var x: int = 1000 if unit.id == source.id else 1060
		unit.attributes.x_fp = x if pid == 0 else 2400-x
		if unit.id == target.id:
			unit.attributes.attack = 1
			unit.attributes.armor = 0
		ids.update(unit.id, unit.owner, unit.attributes)
	sim.world.entities = ids.snapshot()
	for i in range(1000):
		var seed_value: String = "charm-feedback:%d" % i
		if Sim.Effects.Lamp.draw(seed_value, "%s:1:0:%s" % [source.id, target.id], "CHARM", 100) < 15:
			sim.seed_value = seed_value
			break
	var result: Dictionary = Sim.resolve_round(sim.world, sim.seed_value, 1)
	return {"sim": sim, "result": result, "source": source.id, "target": target.id}

func run() -> void:
	for pid in [0, 1]:
		for target_name in ["Butcher", "Lemek"]:
			var case: Dictionary = fixture(pid, target_name)
			check(case.result.action == "resolved", "charm fixture resolves a valid production combat")
			if case.result.action != "resolved":
				print(case.result)
				continue
			var charms: Array = case.result.events.filter(func(row): return row.event.type == "MONSTER_CHARMED")
			check(charms.size() == 1 and charms[0].event.data.unit_id == case.target, "Fyra actually charms the %s on side %d" % [target_name, 1-pid])
			if charms.is_empty(): continue
			var playback = Playback.new()
			check(playback.build(case.result.events.map(func(row): return row.event)), "actual charm event tape builds")
			var at: float = playback.tick_time(int(charms[0].event.data.tick))
			var before: Dictionary = playback.sample(maxf(0.0, at-0.0001))
			var during: Dictionary = playback.sample(at+0.0001)
			var original: Dictionary = before.units.filter(func(u): return u.id == case.target)[0]
			var charmed: Dictionary = during.units.filter(func(u): return u.id == case.target)[0]
			check(not Charm.active(original) and Charm.active(charmed) and charmed.owner == pid, "hearts and allegiance change at the recorded charm tick, never early")
			for script in [Board, Sandbox]:
				var view = script.new()
				root.add_child(view)
				view.size = Vector2(520, 820)
				if script == Sandbox: view.staging_capacity = 15
				for sprites in [false, true]:
					view.set_display_modes(sprites, sprites)
					view.show_frame({"units": [charmed], "clash": []}, 1)
					var center: Vector2 = view._monster_point(charmed.attributes)
					var height: float = view.unit_sprite_height(charmed) if sprites else view.CHIT_DIAMETER * 0.5
					var ceiling: float = view.travel_rect("Lord").position.y - view.sprite_height + 8.0
					var hearts: Array = view.charm_visuals.particles(charmed, center, height, ceiling)
					check(hearts.size() == 3 and hearts.all(func(h): return h.center.y >= ceiling and h.alpha > 0), "three visible hearts fit above the unit in either display mode")
					check(not Geometry2D.triangulate_polygon(Charm.heart(hearts[0].center, hearts[0].radius)).is_empty(), "heart outline produces a renderable filled polygon")
					check(view._get_tooltip(center).contains("CHARMED") and view._get_tooltip(center).contains("next round"), "hover explains temporary control and its return")
				if script == Sandbox:
					var age: float = view.charm_visuals.age
					view.animation_paused = true
					view._process(1)
					check(view.charm_visuals.age == age, "paused sandbox freezes the floating hearts")
					view.animation_paused = false
					view._process(0.5)
					check(view.charm_visuals.age > age, "resuming animates the hearts")
				view.reset_effects()
				check(view._units.is_empty() and view.charm_visuals.age == 0, "reset clears charm presentation")
				view.free()
			var concealed: Dictionary = charmed.duplicate(true)
			concealed.attributes.hidden = true
			check(not Charm.active(concealed), "hearts cannot reveal a concealed enemy")
			var dead: Dictionary = charmed.duplicate(true)
			dead.attributes.hp = 0
			check(not Charm.active(dead), "dead units cannot retain hearts")
			Sim.Effects.end_round(case.result.world, 1)
			var restored: Dictionary = case.result.world.entities.entities.filter(func(u): return u.id == case.target)[0]
			check(restored.owner == 1-pid and not Charm.active(restored), "restoring original ownership removes the hearts")
	# The sandbox must restore control before its next spawn/release choices.
	for pid in [0, 1]:
		var case: Dictionary = fixture(pid, "Sooge")
		case.sim.finish(case.result)
		var restored: Dictionary = case.sim.units().filter(func(u): return u.id == case.target)[0]
		check(restored.owner == 1-pid and not restored.attributes.has("charm_owner"), "sandbox boundary restores charm before staging decisions")
		check(case.sim.spawn("Sooge", pid).action == "spawned", "an expired charm cannot occupy the next round's living-monster slot")
		# A surviving charmed arrival is removed and scored before restoration.
		case = fixture(pid, "Butcher")
		var ids = Sim.Ids.new()
		ids.restore(case.result.world.entities)
		var arrival: Dictionary = ids.get_entity(case.target)
		arrival.attributes.waiting = true
		arrival.attributes.x_fp = 2400 if pid == 0 else 0
		ids.update(arrival.id, arrival.owner, arrival.attributes)
		case.result.world.entities = ids.snapshot()
		case.result.events.append({"event": {"type": "MARCHER_WAITING", "data": {"entity_id": arrival.id, "x_fp": arrival.attributes.x_fp, "tick": 199}}})
		case.sim.finish(case.result)
		check(case.sim.totals[pid].reached_goal == 1 and case.sim.totals[pid].escaped == 1 and case.sim.totals[1-pid].reached_goal == 0, "charmed arrival scores once for the gate it actually reached")
		check(case.sim.units().all(func(u): return u.id != arrival.id), "charm restoration cannot resurrect or turn around a scored arrival")
	print("CHARM FEEDBACK: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
