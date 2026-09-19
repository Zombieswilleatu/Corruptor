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
				row.attributes.x_fp = (2100 if id == vulture else 1800) if owner == 0 else (300 if id == vulture else 600)
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
			check(Sim.Marching.Ranged.goal_advance_enabled(sim.world) == advance and Sim.Marching.Ranged.vulture_range(sim.world) == 400, "preview settings survive both round boundaries")
	await seat_checks()
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	var arena = Scene.instantiate()
	check(arena.balance_preview and arena.standalone, "runner scene opens the standalone range preview")
	arena.standalone = false
	root.add_child(arena)
	await process_frame
	check(arena.goal_advance_toggle.button_pressed and Sim.Marching.Ranged.goal_advance_enabled(arena.sim.world), "goal-distance advance starts enabled")
	check(arena.spawn_buttons.Vulture.tooltip_text.contains("400") and arena.spawn_buttons.Vulture.tooltip_text.contains("+1 damage against Butchers") and Sim.Marching.Ranged.tower_range(arena.sim.world) == 600, "visible preview and simulation use restored ranges and the matchup bonus")
	var preview_title: bool = false
	for node in arena.find_children("*", "Label", true, false):
		if node.text == "MARCHER BALANCE · range 400 · tower 600": preview_title = true
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
	check(arena.goal_advance_toggle.disabled and arena.swap_seats_button.disabled and arena.job != null, "settings and seat swap cannot race the simulation worker")
	var deadline: int = Time.get_ticks_msec() + 15000
	while arena.job != null and Time.get_ticks_msec() < deadline: await process_frame
	check(arena.active and not arena.goal_advance_toggle.disabled, "worker installs playback and releases settings")
	arena.pause()
	arena.goal_advance_toggle.button_pressed = false
	check(not arena.active and not arena.running and arena.pending.is_empty() and arena.sim.units().is_empty(), "changing behavior clears old playback and queued spawns")
	arena.owner_choice.select(0)
	arena.request_spawn("Vulture")
	arena.owner_choice.select(1)
	arena.request_spawn("Butcher")
	var opening_world: Dictionary = arena.sim.world.duplicate(true)
	var opening_seed: String = arena.sim.seed_value
	arena.home_toggle.button_pressed = true
	arena.swap_seats_button.pressed.emit()
	check(arena.sim.seats_swapped and arena.sim.seed_value == opening_seed and arena.sim.world == Sim.mirror(opening_world), "button swaps the actual manual opening with unchanged seed, IDs and reflected positions")
	check(not arena.home_toggle.button_pressed and arena.enemy_toggle.button_pressed and arena.manual_opening.size() == 2, "random-spawn selection and manual opening follow their original army")
	arena.swap_seats_button.pressed.emit()
	check(not arena.sim.seats_swapped and arena.sim.world == opening_world and arena.home_toggle.button_pressed and not arena.enemy_toggle.button_pressed, "second click restores the original opening and controls exactly")
	await process_frame
	var bounds := Rect2(Vector2.ZERO, arena.size)
	check(bounds.encloses(arena.field.get_global_rect()) and bounds.encloses(arena.run_button.get_global_rect()) and bounds.encloses(arena.goal_advance_toggle.get_global_rect()) and bounds.encloses(arena.swap_seats_button.get_global_rect()), "preview controls and lane fit the runner viewport")
	arena.dismiss()
	await process_frame
	print("U13 Vulture preview: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func seat_checks() -> void:
	var original = Sim.new("lane-f881e7ec-e3aebe70", true)
	var swapped = Sim.new(original.seed_value, true, true, true)
	for number in range(1, 7):
		check(original.random_waves([0, 1]).action == "spawned" and swapped.random_waves([0, 1]).action == "spawned", "both seat assignments deploy interval %d" % number)
		check(Sim.mirror(original.world) == swapped.world and original.last_waves[0] == swapped.last_waves[1] and original.last_waves[1] == swapped.last_waves[0], "same draws, IDs and reflected spawn positions at interval %d" % number)
		var first: Dictionary = Sim.resolve_round(original.world, original.seed_value, number)
		var second: Dictionary = Sim.resolve_round(swapped.world, swapped.seed_value, number)
		check(first.action == "resolved" and second == Sim.mirror(first), "complete combat mirrors after real seat swap at interval %d" % number)
		original.finish(first); swapped.finish(second)
		check(original.totals[0] == swapped.totals[1] and original.totals[1] == swapped.totals[0], "swapped totals follow the original armies at interval %d" % number)
		await process_frame
