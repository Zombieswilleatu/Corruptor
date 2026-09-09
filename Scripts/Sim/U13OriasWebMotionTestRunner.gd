extends "res://Scripts/Sim/U13OriasWebTestRunner.gd"

const Auras = preload("res://Scripts/Sim/U13LaneAuras.gd")


func _run() -> void:
	var active: Dictionary = _active()
	var compiled: Dictionary = Content.Fields.compile([active], 1)
	var at_center: Dictionary = {"lane": "Lord", "x_fp": 1200, "y_fp": 300}
	_check(Content.Fields.slowed(compiled.lanes, 1, at_center), "enemy_inside_web_slowed")
	_check(not Content.Fields.slowed(compiled.lanes, 0, at_center), "web_current_allies_immune")
	_check(
		Content.Fields.slowed(Content.Fields.compile([active], 2).lanes, 1, at_center),
		"fading_web_still_slows"
	)
	_check(
		Content.Fields.compile([active], 3).lanes.is_empty(), "expired_web_has_no_motion_modifier"
	)
	var total: int = 0
	for clock in range(16):
		total += Auras.speed(3, 25, true, clock, true)
	_check(total == 15, "web_breath_and_rout_compose_before_rounding")
	var world: Dictionary = Scenario.world()
	var actor_id: String = _add(world, 0, 1, "Lord", 1500, 300)
	var ids = Ids.new()
	ids.restore(world.entities)
	var actor: Dictionary = ids.get_entity(actor_id)
	actor.attributes.step_fp = 4
	ids.update(actor_id, 1, actor.attributes)
	world.entities = ids.snapshot()
	var before: Dictionary = world.duplicate(true)
	var ordinary: Dictionary = Marching.resolve(
		_context(world, Timeline.MARCHING), Callable(self, "_reaction")
	)
	var slowed: Dictionary = Marching.resolve(
		_context(world, Timeline.MARCHING, 1, [active]), Callable(self, "_reaction")
	)
	if _check(
		ordinary.action == "resolved" and slowed.action == "resolved", "web_real_marching_runs"
	):
		_check(_entity(ordinary.world, actor_id).attributes.x_fp == 700, "web_baseline_travel")
		# Eight full-speed ticks reach 1468, then 192 half-speed ticks reach1084.
		_check(
			_entity(slowed.world, actor_id).attributes.x_fp == 1084,
			"web_entering_actor_slows_at_actual_position"
		)
		_check(
			_entity(slowed.world, actor_id).attributes.hp == 5,
			"web_entry_does_not_repeat_fresh_damage"
		)
		var replay: Dictionary = Marching.resolve(
			_context(
				Content.Data.copy_data(JSON.parse_string(JSON.stringify(world))),
				Timeline.MARCHING,
				1,
				[active]
			),
			Callable(self, "_reaction")
		)
		_check(replay == slowed, "web_marching_json_replay_exact")
	_check(world == before, "web_motion_leaves_input_untouched")
	at_center.x_fp = 929
	_check(
		not Content.Fields.slowed(compiled.lanes, 1, at_center),
		"leaving_web_removes_slow_immediately"
	)
	print("U13 Orias Web motion failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _reaction(world: Dictionary, _event: Dictionary, _seed: String, _order: Array) -> Dictionary:
	return {"action": "resolved", "world": world, "events": []}
