extends "res://Scripts/Sim/U13HumbabaTestRunner.gd"

const Auras = preload("res://Scripts/Sim/U13LaneAuras.gd")
const Persistent = preload("res://Scripts/Sim/U13PersistentEffects.gd")
const Candidates = preload("res://Scripts/Sim/U13HumbabaCandidates.gd")


func _run() -> void:
	_regeneration()
	_movement()
	print("U13 lane auras failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _effects() -> Array:
	var registry = Persistent.new()
	var source: Dictionary = Candidates.source(0, 1, "Lord", Content.BREATH)
	registry.activate(
		source,
		Content.BREATH,
		Content.rules()[Content.BREATH].stages,
		{"lane_aura": Content.rules()[Content.BREATH].lane_aura},
		{},
		1
	)
	return registry.snapshot().active


func _regeneration() -> void:
	var world: Dictionary = Scenario.world()
	var id: String = _add_unit(world, 0, "Penitent", 1)
	var context: Dictionary = _context(world, Timeline.ROUND_START_AUTOMATIC, 2)
	context["persistent_effects"] = _effects()
	var before: Dictionary = world.duplicate(true)
	var result: Dictionary = Marching.regenerate(context)
	if not _check(result.action == "resolved", "aura_regeneration_resolves"):
		return
	_check(_entity(result.world, id).attributes.hp == 4, "aura_adds_one_to_canonical_regen")
	_check(world == before, "aura_regeneration_does_not_mutate_input")
	var repeated: Dictionary = context.duplicate(true)
	repeated.world = result.world
	_check(Marching.regenerate(repeated).action == "invalid", "aura_cannot_add_second_regen_pulse")
	var endurance: Dictionary = Content.endurance(
		_context(result.world, Timeline.END_MARCHING_CHECKS, 2)
	)
	_check(endurance.world.data.neutral_tears == 0, "healed_penitent_no_longer_meets_endurance")
	for condition in ["enemy", "other_lane", "waiter", "capped", "expired", "entered", "banished"]:
		var changed: Dictionary = context.duplicate(true)
		var unit: Dictionary = _entity(changed.world, id)
		var expected: int = 3
		match condition:
			"enemy":
				unit.owner = 1
				unit.attributes.direction = -1
			"other_lane":
				unit.attributes.lane = "Castle"
			"waiter":
				unit.attributes.waiting = true
				unit.attributes.waiting_since_round = 1
				expected = 1
			"capped":
				unit.attributes.hp = 4
				expected = 5
			"expired":
				changed.round = 3
			"entered":
				unit.attributes.lane = "Castle"
				unit.attributes.lane = "Lord"
				expected = 4
			"banished":
				_lord(changed.world, 0).attributes.alive = false
				expected = 4
		var checked: Dictionary = Marching.regenerate(changed)
		_check(
			checked.action == "resolved" and _entity(checked.world, id).attributes.hp == expected,
			"aura_regeneration_" + condition
		)
	var future: Dictionary = _context(world, Timeline.POST_RESOLUTION_MOVEMENT_STATE)
	var source: Dictionary = Candidates.source(0, 1, "Lord", Content.BREATH)
	var fired: Dictionary = Content.new().resolve({"declaration": source}, future)
	_check(
		fired.action == "resolved" and fired.world == world,
		"breath_cast_does_not_invent_healing_pulse"
	)
	_check(Marching.regenerate(future).action == "invalid", "regeneration_only_at_step_three")


func _movement() -> void:
	var world: Dictionary = Scenario.world()
	var id: String = _add_unit(world, 0, "Penitent", 5)
	var effects: Array = _effects()
	var context: Dictionary = _context(world, Timeline.MARCHING, 2)
	context["lane_modifiers"] = Auras.compile(effects, 2)
	for condition in [
		"friendly",
		"other_lane",
		"enemy",
		"recovering",
		"retreating",
		"expired",
		"late_spawn",
		"not_ready"
	]:
		var fixture: Dictionary = world.duplicate(true)
		var unit: Dictionary = _entity(fixture, id)
		unit.attributes.x_fp = 1000
		var expected: int = 750
		var motion: Dictionary = context.duplicate(true)
		match condition:
			"other_lane":
				unit.attributes.lane = "Castle"
				expected = 600
			"enemy":
				unit.owner = 1
				unit.attributes.direction = -1
				expected = -600
			"recovering", "retreating":
				unit.attributes["rout_round"] = 1 if condition == "recovering" else 2
				unit.attributes["rout_effect_id"] = "test-rout"
				expected = 375 if condition == "recovering" else -750
			"expired":
				motion.lane_modifiers = Auras.compile(effects, 3)
				expected = 600
			"late_spawn":
				unit.attributes.birth_round = 2
				unit.attributes.movement_ready_round = 2
			"not_ready":
				unit.attributes.movement_ready_round = 3
				expected = 0
		var entities = Ids.new()
		entities.restore(fixture.entities)
		for tick in range(Marching.TICKS):
			Marching._move(entities, {}, motion, 400 + tick, true)
		var after: Dictionary = entities.get_entity(id).attributes
		_check(after.x_fp == 1000 + expected, "aura_actual_movement_" + condition)
		_check(
			after.step_fp == 3 and not after.has("lane_aura"),
			"aura_never_rewrites_base_or_tags_unit_" + condition
		)
	# Move the same physical body into and out of the lane between ticks.
	var changing = Ids.new()
	changing.restore(world.entities)
	for lane in ["Castle", "Lord", "Castle"]:
		var body: Dictionary = changing.get_entity(id)
		body.attributes.lane = lane
		body.attributes.x_fp = 1000
		changing.update(id, body.owner, body.attributes)
		Marching._move(changing, {}, context, 403, true)
		_check(
			changing.get_entity(id).attributes.x_fp == (1004 if lane == "Lord" else 1003),
			"aura_follows_current_lane_" + lane
		)
	# Exercise the public phase transform too: registry -> compiled modifiers -> ticks.
	context.erase("lane_modifiers")
	context["persistent_effects"] = effects
	var content = Content.new()
	var resolved: Dictionary = Marching.resolve(context, Callable(content, "react"))
	_check(
		resolved.action == "resolved" and _entity(resolved.world, id).attributes.x_fp == 750,
		"marching_phase_consumes_authoritative_aura"
	)
	var recovered_total: int = 0
	var normal_total: int = 0
	for clock in range(200):
		normal_total += Auras.speed(3, 25, false, clock)
		recovered_total += Auras.speed(3, 25, true, clock)
	_check(
		normal_total == 750 and recovered_total == 375, "odd_speed_rout_composes_before_rounding"
	)
