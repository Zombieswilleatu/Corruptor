extends SceneTree

const Sim = preload("res://Scripts/Sim/U13LaneSandbox.gd")
const Scene = preload("res://Prototype/U13/U13VulturePreview.tscn")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, copy: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + copy)

func run() -> void:
	var current = Sim.new("preview-check")
	check(Sim.Marching.Ranged.vulture_range(current.world) == 400 and Sim.Marching.Ranged.tower_range(current.world) == 600 and not Sim.Marching.Ranged.goal_advance_enabled(current.world), "ordinary sandbox retains its current rules")
	for owner in [0, 1]:
		for advance in [false, true]:
			var sim = Sim.new("preview-check", true, advance)
			var vulture: String = sim.spawn("Vulture", owner).ids[0]
			var target: String = sim.spawn("Butcher", 1 - owner).ids[0]
			var ids = Sim.Ids.new(); ids.restore(sim.world.entities)
			for id in [vulture, target]:
				var row: Dictionary = ids.get_entity(id)
				row.attributes.x_fp = (1600 if id == vulture else 1200) if owner == 0 else (800 if id == vulture else 1200)
				row.attributes.y_fp = 300
				row.attributes.hp = 1000; row.attributes.max_hp = 1000
				row.attributes.armor = 0; row.attributes.regen = 0
				if id == target: row.attributes.step_fp = 0
				ids.update(id, row.owner, row.attributes)
			sim.world.entities = ids.snapshot()
			for number in [1, 2]:
				var result: Dictionary = Sim.resolve_round(sim.world, sim.seed_value, number)
				check(result.action == "resolved", "side %d, advance %s, interval %d resolves" % [owner, advance, number])
				sim.finish(result)
			check(sim.totals[owner].reached_goal == (1 if advance else 0), "side %d records the goal only when advancing" % owner)
			check(sim.units().any(func(r): return r.id == vulture) != advance, "side %d: goal advance retires the camper; toggle off preserves it" % owner)
			check(Sim.Marching.Ranged.goal_advance_enabled(sim.world) == advance and Sim.Marching.Ranged.vulture_range(sim.world) == 900, "preview settings survive both round boundaries")
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	var arena = Scene.instantiate()
	check(arena.balance_preview and arena.standalone, "runner scene opens the standalone range preview")
	arena.standalone = false
	root.add_child(arena)
	await process_frame
	check(arena.goal_advance_toggle.button_pressed and Sim.Marching.Ranged.goal_advance_enabled(arena.sim.world), "goal-distance advance starts enabled")
	check(arena.spawn_buttons.Vulture.tooltip_text.contains("900") and Sim.Marching.Ranged.tower_range(arena.sim.world) == 1125, "visible preview and simulation use the proposed ranges")
	var preview_title: bool = false
	for node in arena.find_children("*", "Label", true, false):
		if node.text == "VULTURE PREVIEW · range 900 · tower 1125": preview_title = true
	check(preview_title, "range label identifies this build at a glance")
	arena.seed_entry.text = "lane-f881e7ec-e3aebe70"
	arena.reset()
	var decks: Array = [arena.sim.spawners[0].deck.duplicate(true), arena.sim.spawners[1].deck.duplicate(true)]
	arena.request_spawn("Vulture")
	arena.goal_advance_toggle.button_pressed = false
	check(arena.sim.units().is_empty() and arena.sim.round_number == 1 and arena.sim.seed_value == "lane-f881e7ec-e3aebe70", "toggling resets units and round with the entered seed")
	check(decks == [arena.sim.spawners[0].deck, arena.sim.spawners[1].deck] and not Sim.Marching.Ranged.goal_advance_enabled(arena.sim.world), "toggle comparison preserves both deterministic opening decks")
	arena.new_random_arena()
	check(arena.sim.seed_value != "lane-f881e7ec-e3aebe70" and not Sim.Marching.Ranged.goal_advance_enabled(arena.sim.world), "new random arena keeps the selected behavior")
	arena.goal_advance_toggle.button_pressed = true
	arena.request_spawn("Vulture")
	arena.start()
	check(arena.goal_advance_toggle.disabled and arena.job != null, "settings cannot race the simulation worker")
	var deadline: int = Time.get_ticks_msec() + 15000
	while arena.job != null and Time.get_ticks_msec() < deadline: await process_frame
	check(arena.active and not arena.goal_advance_toggle.disabled, "worker installs playback and releases settings")
	arena.pause()
	arena.goal_advance_toggle.button_pressed = false
	check(not arena.active and not arena.running and arena.pending.is_empty() and arena.sim.units().is_empty(), "changing behavior clears old playback and queued spawns")
	await process_frame
	var bounds := Rect2(Vector2.ZERO, arena.size)
	check(bounds.encloses(arena.field.get_global_rect()) and bounds.encloses(arena.run_button.get_global_rect()) and bounds.encloses(arena.goal_advance_toggle.get_global_rect()), "preview controls and lane fit the runner viewport")
	arena.dismiss()
	await process_frame
	print("U13 Vulture preview: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
