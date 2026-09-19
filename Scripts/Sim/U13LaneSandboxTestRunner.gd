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
	check(sim.random_waves([1]).action == "spawned", "enemy-only commitment reveals successfully")
	var wave: Dictionary = sim.last_waves[1]
	check(not wave.get("cards", []).is_empty() and Sim.Marching.valid(sim.world), "enemy spawns through actual commitment reveal")
	check(sim.units().all(func(u): return u.attributes.movement_ready_round == 2), "enemy commitments retain the normal birth hold")
	var expected: Dictionary = {}
	for card in wave.cards: expected[card.attributes.suit] = expected.get(card.attributes.suit, 0) + card.attributes.value
	for suit in Sim.Marching.SUITS:
		check(sim.units().filter(func(u): return u.attributes.suit == suit).size() == floori(float(expected.get(suit, 0)) / 3.0), "enemy %s count matches committed printed values" % suit)
	random_sides_checks()
	opening_checks()
	side_symmetry_checks()
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
	await goal_counter_checks()
	print("U13 lane sandbox: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func body_count(cards: Array) -> int:
	var totals_by_suit: Dictionary = {}
	for card in cards:
		totals_by_suit[card.attributes.suit] = totals_by_suit.get(card.attributes.suit, 0) + int(card.attributes.value)
	var count: int = 0
	for total in totals_by_suit.values(): count += floori(float(total) / 3.0)
	return count

func fixed_hand(values: Array):
	var generator = Sim.Enemy.new("opening-floor")
	generator.goal = "Sooge"
	generator.deck = []
	for entry in values + [["Vulture", 1], ["Vulture", 1], ["Vulture", 1]]:
		generator.deck.append({"id": "fixture:%d" % generator.deck.size(), "kind": "card", "attributes": {"suit": entry[0], "value": entry[1]}})
	generator.deck.reverse()
	return generator

func opening_checks() -> void:
	var sim = Sim.new("lane-balance-1")
	check(sim.random_waves([0, 1]).action == "spawned" and sim.totals.all(func(t): return t.spawned > 0), "reported default opening now spawns bodies for both sides in interval one")
	check(sim.units().all(func(u): return u.attributes.birth_round == 1 and u.attributes.movement_ready_round == 2), "both opening waves share the same normal deployment timing")
	for pid in [0, 1]:
		var single = Sim.new("lane-balance-1")
		single.random_waves([pid])
		check(single.last_waves[pid] == sim.last_waves[pid], "enabling the other side cannot change side %d's opening" % pid)
	var generator = fixed_hand([["Butcher", 3], ["Wright", 1], ["Vulture", 1], ["Wright", 1], ["Butcher", 1]])
	var wave: Dictionary = generator.next_wave(1, [])
	check(wave.monster.is_empty() and body_count(wave.cards) > 0 and wave.saved == 1, "an otherwise empty commitment releases a saved card to field a legal marcher")
	check((generator.deck + generator.discard + generator.saved).size() == 8 and wave.cards.size() <= 5, "opening floor conserves the drawn cards and normal commitment limit")
	generator = fixed_hand([["Penitent", 1], ["Penitent", 1], ["Vulture", 1], ["Wright", 1], ["Butcher", 1]])
	for i in range(100):
		generator.seed_value = "defense-floor-%d" % i
		if generator.pick(1, "defense:Penitent", 2) == 0: break
	wave = generator.next_wave(1, [])
	check(generator.pick(1, "defense:Penitent", 2) == 0 and wave.monster == "Lemek" and Sim.Monsters.qualifies(wave.cards, wave.cards.map(func(c): return c.id), "Lemek"), "defensive spending cannot consume the only legal monster when no ordinary body is possible")
	generator = fixed_hand([["Butcher", 1], ["Wright", 1], ["Vulture", 1], ["Penitent", 1], ["Butcher", 1]])
	wave = generator.next_wave(1, [])
	check(body_count(wave.cards) == 0 and wave.monster.is_empty() and (generator.deck + generator.discard + generator.saved).size() == 8, "a genuinely insufficient hand never creates a free unit or draws extra cards")
	# The fallback also stays legal across independent hands and reshuffles.
	for pid in [0, 1]:
		var all_valid: bool = true
		for i in range(32):
			generator = Sim.Enemy.new("opening-probe-%d" % i, pid)
			for n in range(1, 13):
				wave = generator.next_wave(n, [])
				var cards: Array = generator.deck + generator.discard + generator.saved
				var unique: Dictionary = {}
				for card in cards: unique[card.id] = true
				all_valid = all_valid and cards.size() == 60 and unique.size() == 60 and wave.cards.size() <= 5 and wave.saved <= 2
				if not wave.monster.is_empty(): all_valid = all_valid and Sim.Monsters.qualifies(wave.cards, wave.cards.map(func(c): return c.id), wave.monster)
		check(all_valid, "side %d conserves cards and legal recipes across 384 waves" % pid)
	print("OPENING SAMPLE ", JSON.stringify(sim.last_waves))

func mirror(value: Variant) -> Variant:
	if value is Array: return value.map(mirror)
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			if key in ["owner", "charm_owner", "wright_owner", "player_id"] and value[key] in [0, 1]: result[key] = 1 - int(value[key])
			elif key == "x_fp": result[key] = Sim.Marching.LANE_FP - int(value[key])
			elif key == "direction": result[key] = -int(value[key])
			else: result[key] = mirror(value[key])
		return result
	return value

func side_symmetry_checks() -> void:
	# Keep immutable identities and RNG rolls; exchange owners and reflect the
	# complete field, including builders, structures, charm and ability sources.
	var sim = Sim.new("lane-balance-1")
	for n in range(1, 13):
		sim.random_waves([0, 1])
		var original: Dictionary = Sim.resolve_round(sim.world, sim.seed_value, n)
		var swapped: Dictionary = Sim.resolve_round(mirror(sim.world), sim.seed_value, n)
		check(original.action == "resolved" and swapped.action == "resolved" and mirror(original) == swapped, "interval %d has identical events and outcomes with ownership and field positions swapped" % n)
		sim.finish(original)
	print("SIDE AUDIT ", JSON.stringify({"seed": sim.seed_value, "intervals": 12, "totals": sim.totals}))

func random_sides_checks() -> void:
	var sim = Sim.new("two-sided-waves")
	var streams: Array = [Sim.Enemy.new(sim.seed_value, 0), Sim.Enemy.new(sim.seed_value, 1)]
	check(sim.spawners[0].deck != sim.spawners[1].deck, "home and enemy have independent shuffled decks")
	for n in range(1, 5):
		var expected: Array = [streams[0].next_wave(n, sim.units()), streams[1].next_wave(n, sim.units())]
		var spawned_before: int = sim.totals[0].spawned + sim.totals[1].spawned
		var wave: Dictionary = sim.random_waves([0, 1])
		check(wave.action == "spawned" and sim.units().size() <= Sim.LIMIT and Sim.Marching.valid(sim.world), "both sides reveal together into a valid bounded arena")
		for pid in [0, 1]:
			var actual: Dictionary = sim.last_waves[pid]
			check(actual.cards == expected[pid].cards and actual.monster == expected[pid].monster and actual.saved == expected[pid].saved, "side %d keeps independent draws and recipe choices at interval %d" % [pid, n])
			var created: Array = sim.units().filter(func(u): return u.owner == pid and u.attributes.birth_round == n)
			check(created.size() == actual.spawned and created.all(func(u): return u.attributes.movement_ready_round == n + 1), "side %d has correct ownership, counts and next-round deployment" % pid)
			var cards: Array = sim.spawners[pid].deck + sim.spawners[pid].discard + sim.spawners[pid].saved
			var unique: Dictionary = {}
			for card in cards: unique[card.id] = true
			check(cards.size() == 60 and unique.size() == 60, "each side conserves its own sixty-card deck")
		check(sim.totals[0].spawned + sim.totals[1].spawned == spawned_before + wave.spawned and sim.world.entities.entities.all(func(u): return u.kind == "marcher"), "paired waves retire temporary cards and count both armies")
		var result: Dictionary = Sim.resolve_round(sim.world, sim.seed_value, n)
		check(result.action == "resolved", "two automatic armies play a full interval")
		sim.finish(result)
	for pid in [0, 1]:
		for live_owner in [pid, 1 - pid]:
			var generator = Sim.Enemy.new("living-limit", pid)
			generator.goal = "Sooge"
			generator.saved = generator.ingredients(generator.deck, "Sooge")
			for card in generator.saved: generator.deck.erase(card)
			var live: Dictionary = {"id": "existing-sooge", "kind": "marcher", "owner": live_owner, "attributes": Sim.Monsters.profile("Sooge", "Lord", live_owner, 0, 1)}
			var wave: Dictionary = generator.next_wave(1, [live])
			check((wave.monster != "Sooge") if live_owner == pid else (wave.monster == "Sooge"), "side %d applies living-copy limits to its own monsters only" % pid)
	# Near capacity, only one side can reserve room; retry priority rotates.
	sim = Sim.new("capacity")
	for i in range(40): sim.spawn("Butcher", i % 2)
	var blocked_deck: Array = sim.spawners[0].deck.duplicate(true)
	check(sim.random_waves([0, 1]).action == "spawned" and sim.units().size() <= Sim.LIMIT and sim.spawners[0].deck == blocked_deck and sim.last_waves[0].summary.contains("capacity"), "capacity waiting leaves the skipped side's cards untouched")
	var before: Dictionary = sim.world.duplicate(true)
	check(sim.random_waves([0, 1]).action == "invalid" and sim.world == before, "repeated wave request cannot redeploy the same interval")

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
	check(not arena.seed_entry.text.is_empty() and arena.seed_entry.text == arena.sim.seed_value, "a new arena displays the fresh seed used by its simulation")
	var fresh: String = arena.sim.seed_value
	arena.new_arena_button.pressed.emit()
	check(arena.sim.seed_value != fresh and arena.seed_entry.text == arena.sim.seed_value, "new random arena changes the seed and both draw streams")
	arena.seed_entry.text = "lane-balance-1"
	arena.reset_button.pressed.emit()
	var opening_decks: Array = [arena.sim.spawners[0].deck.duplicate(true), arena.sim.spawners[1].deck.duplicate(true)]
	arena.reset_button.pressed.emit()
	check(arena.sim.seed_value == "lane-balance-1" and opening_decks == [arena.sim.spawners[0].deck, arena.sim.spawners[1].deck], "replay applies the entered seed and restores both exact decks")
	check(arena.monster_choice.item_count == 10 and arena.spawn_buttons.size() == 4, "all ten monsters and four regular spawn buttons are available")
	check(not arena.home_toggle.button_pressed and not arena.enemy_toggle.button_pressed, "home and enemy random spawning are independent opt-in toggles")
	await process_frame
	var bounds: Rect2 = Rect2(Vector2.ZERO, arena.size)
	check(bounds.encloses(arena.field.get_global_rect()) and bounds.encloses(arena.run_button.get_global_rect()) and bounds.encloses(arena.new_arena_button.get_global_rect()) and bounds.encloses(arena.reset_button.get_global_rect()) and bounds.encloses(arena.counts.get_global_rect()), "arena, controls and report fit the menu viewport")
	var source: Dictionary = Sim.Monsters.profile("Sooge", "Lord", 0, 0, 1, true)
	source.x_fp = 1700
	var target: Dictionary = source.duplicate(true); target.x_fp = 2000
	var beam: Dictionary = {"source": source, "target": target, "source_id": "eye", "target_id": "target", "source_owner": 0, "target_owner": 1, "range_fp": 1800}
	var ray: PackedVector2Array = arena.field.beam_points(beam)
	check(ray[0].distance_to(ray[1]) > 100 and is_equal_approx(ray[1].y, arena.field.travel_rect("Lord").position.y), "long laser clips at the sandbox gate, not the main-board header")
	# Keep the original direct-field/debug regression separate from the new
	# protected-reserve timing suite (U13LaneStagingTestRunner).
	arena.staging_capacity.select(2)
	arena.reset()
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
	arena.home_toggle.button_pressed = true
	arena.start()
	check(arena.pending.is_empty() and arena.job != null and arena.sim.last_waves[0].has("cards") and arena.sim.last_waves[1].has("cards"), "continuous mode drains manual requests and prepares both automatic waves")
	check(arena.new_arena_button.disabled and arena.reset_button.disabled, "both reset actions are disabled while the worker is preparing a round")
	check(arena.home_wave_note.text == arena.sim.last_waves[0].summary and arena.wave_note.text == arena.sim.last_waves[1].summary, "report shows each side's own commitment")
	deadline = Time.get_ticks_msec() + 15000
	while arena.job != null and Time.get_ticks_msec() < deadline: await process_frame
	arena._process(15)
	check(arena.running and arena.job != null and arena.sim.round_number == 3, "continuous mode automatically starts the next real round")
	deadline = Time.get_ticks_msec() + 15000
	while arena.job != null and Time.get_ticks_msec() < deadline: await process_frame
	arena.reset()
	check(arena.sim.units().is_empty() and arena.sim.round_number == 1 and not arena.running and arena.pending.is_empty(), "reset clears the arena, queue and playback")
	check(arena.home_toggle.button_pressed and arena.enemy_toggle.button_pressed and arena.sim.last_waves == [{}, {}], "reset preserves random-spawn toggles and clears both commitment reports")
	arena.enemy_toggle.button_pressed = false
	arena.start()
	check(arena.running and arena.job != null and arena.sim.last_waves[0].has("cards") and arena.sim.totals[1].spawned == 0, "home-only random spawning starts from an empty arena without manual input")
	deadline = Time.get_ticks_msec() + 15000
	while arena.job != null and Time.get_ticks_msec() < deadline: await process_frame
	arena._process(15)
	check(arena.running and arena.job != null and arena.sim.round_number == 2, "continuous home spawning advances to the next interval")
	deadline = Time.get_ticks_msec() + 15000
	while arena.job != null and Time.get_ticks_msec() < deadline: await process_frame
	arena.reset()
	arena.dismiss()
	await process_frame
	check(picker.lane_sandbox == null and picker._loadout_content.visible and picker.selection() == selection, "returning to main menu preserves the selected Lords and Castles")
	picker.free()

func goal_counter_checks() -> void:
	var arena = UI.new()
	root.add_child(arena)
	await process_frame
	arena.set_process(false)
	for pid in [0, 1]:
		arena.sim = Sim.new("goal-counter:%d" % pid)
		arena.sim.spawn("Butcher", pid)
		var ids = Sim.Ids.new(); ids.restore(arena.sim.world.entities)
		var unit: Dictionary = arena.sim.units()[0]
		unit.attributes.x_fp = 2398 if pid == 0 else 2
		ids.update(unit.id, pid, unit.attributes)
		arena.sim.world.entities = ids.snapshot()
		arena._show_idle()
		check(arena.round_note.text == "ROUND 1" and arena.home_goal_note.text.contains("0 reached") and arena.enemy_goal_note.text.contains("0 reached"), "round and both goal counters start at zero goals in round one")
		arena.start(); arena.pause()
		var deadline: int = Time.get_ticks_msec() + 15000
		while arena.job != null and Time.get_ticks_msec() < deadline:
			await process_frame
			arena._process(0)
		check(arena.active and arena.goal_rows.size() == 1 and arena.goal_rows[0].owner == pid, "actual gate arrival is credited to the side moving toward that goal")
		if not arena.active or arena.goal_rows.size() != 1: arena.free(); return
		var note: Label = arena.home_goal_note if pid == 0 else arena.enemy_goal_note
		var other_note: Label = arena.enemy_goal_note if pid == 0 else arena.home_goal_note
		var arrival_seconds: float = arena.playback.tick_time(arena.goal_rows[0].tick) / arena.playback.duration * UI.INTERVAL
		arena.start(); arena._process(arrival_seconds * 0.9)
		check(note.text.contains("0 reached"), "goal counter does not reveal an arrival ahead of its playback")
		arena.pause(); arena._process(5)
		check(note.text.contains("0 reached"), "paused playback cannot advance a goal counter")
		arena.start(); arena._process(arrival_seconds * 0.2)
		check(note.text.contains("1 reached") and other_note.text.contains("0 reached"), "goal counter advances as the marcher reaches the gate")
		arena._process(3)
		check(note.text.contains("1 reached"), "a marcher waiting at the goal never scores twice")
		var finished: Dictionary = arena.result.duplicate(true)
		var counted = Sim.new("casualty-after-goal")
		var gone = Sim.Ids.new(); gone.restore(finished.world.entities); gone.retire(unit.id)
		finished.world.entities = gone.snapshot()
		# An arrival remains a goal even if that body is gone at round end.
		finished.events.append(finished.events.filter(func(e): return e.event.type == "MARCHER_WAITING")[0])
		counted.finish(finished)
		check(counted.totals[pid].reached_goal == 1 and counted.totals[pid].escaped == 0 and counted.goal_arrivals(finished.events).is_empty(), "arrival accounting survives removal and deduplicates repeated events across rounds")
		arena.speed.select(2)
		arena._process(15)
		check(arena.round_note.text == "ROUND 2" and note.text.contains("1 reached") and arena.sim.totals[pid].reached_goal == 1 and arena.round_goals == [0, 0], "fast playback and the round boundary preserve exactly one cumulative goal")
		arena.speed.select(1)
		await process_frame
		var bounds: Rect2 = Rect2(Vector2.ZERO, arena.size)
		check([arena.round_note, arena.home_goal_note, arena.enemy_goal_note, arena.field, arena.run_button].all(func(control): return bounds.encloses(control.get_global_rect())), "persistent scoreboard and arena fit the menu viewport")
		if pid == 0: arena.reset_button.pressed.emit()
		else: arena.new_arena_button.pressed.emit()
		check(arena.round_note.text == "ROUND 1" and arena.home_goal_note.text.contains("0 reached") and arena.enemy_goal_note.text.contains("0 reached") and arena.goal_rows.is_empty(), "reset clears the round, cumulative goals and pending playback arrivals")
	arena.free()
