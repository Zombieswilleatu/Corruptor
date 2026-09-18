extends SceneTree

const Sim = preload("res://Scripts/Sim/U13LaneSandbox.gd")
const UI = preload("res://Prototype/U13/U13LaneSandbox.gd")
const Picker = preload("res://Prototype/U13/U13LoadoutPicker.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, copy: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + copy)

func run() -> void:
	var sim = Sim.new("sandbox-test")
	check(sim.world.entities.entities.is_empty(), "isolated arena has no Lord, Castle, hand or match")
	for pid in [0, 1]:
		for name in Sim.Marching.SUITS:
			check(sim.spawn(name, pid).action == "spawned", "%s spawns for side %d" % [name, pid])
	check(sim.units().filter(func(u): return u.attributes.suit == "Vulture").all(func(u): return u.attributes.attack == Sim.Marching.Ranged.ATTACK), "current ranged Vulture damage is used")
	check(Sim.Marching.valid(sim.world), "regular-unit world passes production validation")
	var input: Dictionary = sim.world.duplicate(true)
	var result: Dictionary = Sim.resolve_round(input, sim.seed_value, 1)
	check(result.action == "resolved" and input == sim.world, "worker resolves without mutating input")
	check(result == Sim.resolve_round(input, sim.seed_value, 1), "seeded round replays exactly")
	var context: Dictionary = {"world": input, "round": 1, "hook": Sim.Marching.Timeline.ROUND_START_AUTOMATIC, "seed": sim.seed_value, "player_order": [0, 1], "persistent_effects": [], "full_roster": true}
	context.world = Sim.Marching.regenerate(context).world
	context.hook = Sim.Marching.Timeline.MARCHING
	check(result == Sim.Marching.resolve(context, Callable(Sim.reaction)), "sandbox result matches the real Marching engine")
	sim.finish(result)
	check(sim.round_number == 2 and Sim.Marching.valid(sim.world), "round boundary preserves a valid lane")
	for name in Sim.Monsters.NAMES:
		sim = Sim.new("monster:" + name)
		var spawned: Dictionary = sim.spawn(name, 0, true, name == "Sooge")
		check(spawned.action == "spawned" and (spawned.count in [3, 4, 5] if name == "Varn" else spawned.count == 1), name + " uses its actual summon size")
		sim.spawn("Butcher", 1, true)
		result = Sim.resolve_round(sim.world, sim.seed_value, 1)
		check(result.action == "resolved" and Sim.Marching.valid(result.world) and Sim.Monsters.valid(result.world), name + " fights with the live monster rules")
		if name == "Sooge":
			check(result.events.any(func(r): return r.event.type == "MONSTER_BEAM_FIRED"), "turret Sooge fires an actual recorded laser")
		if Sim.Monsters.limited(name): check(sim.spawn(name, 0).action == "invalid", name + " enforces one living copy per side")
		sim.finish(result)
		var second: Dictionary = Sim.resolve_round(sim.world, sim.seed_value, 2)
		check(second.action == "resolved", name + " carries correctly into the next interval")
	# Once-active-round rooting, regeneration and the automatic 100% ceiling.
	sim = Sim.new("root-ramp")
	sim.spawn("Sooge", 0, true)
	# Keep the isolated fixture from escaping before its sixth rooting roll.
	var root_ids = Sim.Ids.new(); root_ids.restore(sim.world.entities)
	var root_unit: Dictionary = sim.units()[0]
	root_unit.attributes.step_fp = 0
	root_ids.update(root_unit.id, 0, root_unit.attributes)
	sim.world.entities = root_ids.snapshot()
	for n in range(1, 7):
		result = Sim.resolve_round(sim.world, sim.seed_value, n)
		sim.finish(result)
	check(sim.units()[0].attributes.sprite_form == "turret", "Sooge roots no later than its sixth active interval")
	# Card-driven waves use only qualifying recipes and conserve a trimmed deck.
	var enemy = Sim.Enemy.new("wave-test")
	var replay = Sim.Enemy.new("wave-test")
	var monster_waves: int = 0
	var distribution: Dictionary = {}
	var regular_bodies: int = 0
	for n in range(1, 81):
		var wave: Dictionary = enemy.next_wave(n, [])
		var valid: bool = wave.cards.size() <= 5 and wave.saved <= 2
		if not wave.monster.is_empty():
			monster_waves += 1
			distribution[wave.monster] = distribution.get(wave.monster, 0) + 1
			valid = valid and Sim.Monsters.qualifies(wave.cards, wave.cards.map(func(c): return c.id), wave.monster)
		var all_cards: Array = enemy.deck + enemy.discard + enemy.saved
		for suit in Sim.Marching.SUITS:
			var value: int = 0
			for card in wave.cards:
				if card.attributes.suit == suit: value += card.attributes.value
			regular_bodies += floori(float(value) / 3.0)
		var unique: Dictionary = {}
		for card in all_cards: unique[card.id] = true
		check(valid and all_cards.size() == 60 and unique.size() == 60 and wave == replay.next_wave(n, []), "enemy wave %d is legal, deterministic and conserves its 60-card deck" % n)
	check(monster_waves > 0 and monster_waves < 80, "random waves include ordinary commitments and natural monster recipes")
	print("WAVE SAMPLE ", JSON.stringify({"seed": "wave-test", "intervals": 80, "regular_bodies": regular_bodies, "monster_summons": distribution}))
	sim = Sim.new("actual-commit")
	var wave: Dictionary = sim.enemy_wave()
	check(not wave.get("cards", []).is_empty() and Sim.Marching.valid(sim.world), "enemy spawns through actual commitment reveal")
	check(sim.units().all(func(u): return u.attributes.movement_ready_round == 2), "enemy commitments retain the normal birth hold")
	var expected: Dictionary = {}
	for card in wave.cards: expected[card.attributes.suit] = expected.get(card.attributes.suit, 0) + card.attributes.value
	for suit in Sim.Marching.SUITS:
		check(sim.units().filter(func(u): return u.attributes.suit == suit).size() == floori(float(expected.get(suit, 0)) / 3.0), "enemy %s count matches committed printed values" % suit)
	# An escaping unit is counted and removed, never killed or resurrected.
	sim = Sim.new("escape")
	sim.spawn("Butcher", 0)
	var ids = Sim.Ids.new(); ids.restore(sim.world.entities)
	var unit: Dictionary = sim.units()[0]
	unit.attributes.x_fp = 2398
	ids.update(unit.id, 0, unit.attributes); sim.world.entities = ids.snapshot()
	result = Sim.resolve_round(sim.world, sim.seed_value, 1)
	sim.finish(result)
	check(sim.units().is_empty() and sim.totals[0].escaped == 1 and sim.totals[0].defeated == 0, "gate arrival is a clean escape rather than a death")
	await ui_checks()
	print("U13 lane sandbox: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func ui_checks() -> void:
	# Match the playable board's logical canvas; headless Window defaults to 64px.
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	var picker = Picker.new()
	root.add_child(picker)
	await process_frame
	var selection: Dictionary = picker.selection()
	picker.sandbox_button.pressed.emit()
	await process_frame
	var arena = picker.lane_sandbox
	check(is_instance_valid(arena) and not picker._loadout_content.visible, "main menu opens the isolated lane sandbox")
	check(arena.monster_choice.item_count == 10 and arena.spawn_buttons.size() == 4, "all ten monsters and four regular spawn buttons are available")
	await process_frame
	var bounds: Rect2 = Rect2(Vector2.ZERO, arena.size)
	check(bounds.encloses(arena.field.get_global_rect()) and bounds.encloses(arena.run_button.get_global_rect()) and bounds.encloses(arena.counts.get_global_rect()), "arena, controls and report fit the menu viewport")
	arena.spawn_point.select(1)
	arena.spawn_buttons.Butcher.pressed.emit()
	arena.owner_choice.select(1)
	arena.spawn_buttons.Penitent.pressed.emit()
	check(arena.sim.units().size() == 2 and arena.field._units.size() == 2, "manual buttons immediately display both sides")
	arena.start()
	var deadline: int = Time.get_ticks_msec() + 15000
	while arena.job != null and Time.get_ticks_msec() < deadline: await process_frame
	check(arena.active and arena.running, "worker installs an active playable interval")
	arena.pause()
	var clock: float = arena.elapsed
	arena._process(5)
	check(arena.elapsed == clock and arena.field.animation_paused, "pause freezes combat playback and sprite motion")
	arena.request_spawn("Wright")
	check(arena.pending.size() == 1, "mid-playback spawns wait for the next interval")
	arena.start(); arena._process(15)
	check(not arena.active and not arena.running and arena.sim.round_number == 2, "15-second mode stops at the round boundary")
	arena.mode.select(1)
	arena.enemy_toggle.button_pressed = true
	arena.start()
	check(arena.pending.is_empty() and arena.job != null, "continuous mode drains manual requests and prepares an enemy wave")
	deadline = Time.get_ticks_msec() + 15000
	while arena.job != null and Time.get_ticks_msec() < deadline: await process_frame
	arena._process(15)
	check(arena.running and arena.job != null and arena.sim.round_number == 3, "continuous mode automatically starts the next real round")
	deadline = Time.get_ticks_msec() + 15000
	while arena.job != null and Time.get_ticks_msec() < deadline: await process_frame
	arena.reset()
	check(arena.sim.units().is_empty() and arena.sim.round_number == 1 and not arena.running and arena.pending.is_empty(), "reset clears the arena, queue and playback")
	arena.dismiss()
	await process_frame
	check(picker.lane_sandbox == null and picker._loadout_content.visible and picker.selection() == selection, "returning to main menu preserves the selected Lords and Castles")
	picker.free()
