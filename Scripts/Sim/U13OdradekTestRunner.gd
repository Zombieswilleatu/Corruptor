extends "res://Scripts/Sim/U13OriasWebTestRunner.gd"

const Odradek = preload("res://Scripts/Sim/U13Odradek.gd")
const OdradekScenario = preload("res://Scripts/Sim/U13OdradekScenario.gd")
const Session = preload("res://Scripts/Sim/U13LoadoutBoardSession.gd")


func _run() -> void:
	_redirect()
	_interrupted_duel()
	_resource_queue()
	_banishment()
	_roster()
	print("U13 Odradek failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _redirect() -> void:
	var world: Dictionary = OdradekScenario.world()
	var own: String = _add(world, 0, 0, "Lord", 1200, 300, 7, 3)
	var enemy: String = _add(world, 1, 1, "Lord", 1500, 300)
	var outside: String = _add(world, 2, 1, "Lord", 1501, 300)
	var other: String = _add(world, 3, 0, "Castle", 1200, 300)
	var before: Dictionary = world.duplicate(true)
	var source: Dictionary = OdradekScenario.source(0, 1, _target())
	var pending = Pending.new()
	var record: Dictionary = pending.schedule(source).effect
	var content = Odradek.new()
	var result: Dictionary = content.resolve(
		record, _context(world, Timeline.POST_RESOLUTION_POSITION)
	)
	if not _check(result.action == "resolved", "redirect_fires"):
		return
	_check(world == before, "redirect_does_not_mutate_input")
	for id in [own, enemy]:
		var expected: Dictionary = _entity(world, id).duplicate(true)
		expected.attributes.lane = "Castle"
		_check(
			_entity(result.world, id) == expected,
			"redirect_both_owners_only_lane_changes_including_boundary"
		)
	_check(
		(
			_entity(result.world, outside) == _entity(world, outside)
			and _entity(result.world, other) == _entity(world, other)
		),
		"redirect_excludes_outside_and_other_lane"
	)
	_check(
		(
			result
			== content.resolve(
				record,
				_context(
					JSON.parse_string(JSON.stringify(world)), Timeline.POST_RESOLUTION_POSITION
				)
			)
		),
		"redirect_json_exact_replay"
	)
	var second: Dictionary = OdradekScenario.source(
		0, 1, {"lane": "Castle", "field_position": _target().field_position}, 1
	)
	var twice: Dictionary = content.resolve(
		pending.schedule(second).effect, _context(result.world, Timeline.POST_RESOLUTION_POSITION)
	)
	_check(
		(
			_entity(twice.world, own).attributes.lane == "Lord"
			and _entity(twice.world, other).attributes.lane == "Lord"
		),
		"later_redirect_recaptures_prior_moves"
	)
	var wrong: Dictionary = record.duplicate(true)
	wrong.fire_hook = Timeline.MARCHING
	_check(
		content.resolve(wrong, _context(world, Timeline.MARCHING)).action == "invalid",
		"redirect_rejects_live_marching_hook"
	)


func _advance(owner, hook: String) -> bool:
	var limit: int = 30
	while owner.next_hook() != hook and not owner.next_hook().is_empty() and limit > 0:
		var result: Dictionary = owner.run_next_hook()
		if result.action == "invalid":
			print(result)
			_check(false, "odradek_hook_advance")
			return false
		limit -= 1
	return owner.next_hook() == hook


func _resource_queue() -> void:
	var owner = Odradek.new().create_combat_match()
	var world: Dictionary = OdradekScenario.world()
	_check(world.players[0].resources.reconfiguration == 0, "reconfiguration_starts_zero")
	var started: Dictionary = owner.start("odradek-resource", world, [0, 1])
	if not _check(started.action != "invalid", "odradek_match_starts"):
		print(started)
		return
	for round_number in range(1, 6):
		if not _advance(owner, Timeline.SUBMISSION_LOCK):
			return
		_check(
			owner.snapshot().world.players[0].resources.reconfiguration == mini(round_number, 4),
			"gain_one_per_round_cap_four"
		)
		if round_number < 5:
			owner.submit(0, [], {})
			owner.submit(1, [], {})
			owner.run_next_hook()
			if not _advance(owner, Timeline.AFTERMATH):
				return
			owner.run_next_hook()
			owner.begin_next_round([0, 1])
	var draft: Array = []
	for index in range(4):
		draft.append(OdradekScenario.source(0, 5, _target(), index))
	var before: Dictionary = owner.snapshot()
	_check(
		owner.preview_submission(0, draft, {}).action != "invalid", "four_redirects_legal_at_four"
	)
	var too_many: Array = draft.duplicate(true)
	too_many.append(OdradekScenario.source(0, 5, _target(), 4))
	_check(owner.preview_submission(0, too_many, {}).action == "invalid", "fifth_redirect_rejected")
	_check(owner.snapshot() == before, "rejected_and_preview_drafts_preserve_bank")
	var plan: Dictionary = RandomLegal.plan(owner, 0, Callable(OdradekScenario, "enumerate"))
	_check(
		plan.action != "invalid" and not plan.powers.is_empty(), "odradek_bot_uses_shared_legality"
	)
	owner.submit(0, draft, {})
	owner.submit(1, [], {})
	var lock: Dictionary = owner.run_next_hook()
	if not _check(lock.action != "invalid", "repeatable_queue_locks"):
		print(lock)
		return
	_check(owner.snapshot().world.players[0].resources.reconfiguration == 0, "queue_pays_at_lock")
	var restored = Odradek.new().create_combat_match()
	var loaded: Dictionary = restored.restore(JSON.parse_string(JSON.stringify(owner.snapshot())))
	if not _check(loaded.action != "invalid", "paid_queue_json_restore"):
		print(loaded)
		return
	var bad: Dictionary = owner.snapshot()
	bad.world.players[0].resources.reconfiguration = 1
	_check(
		Odradek.new().create_combat_match().restore(bad).action == "invalid",
		"snapshot_cannot_refund_locked_cost"
	)
	if (
		not _advance(owner, Timeline.MARCHING_START)
		or not _advance(restored, Timeline.MARCHING_START)
	):
		return
	_check(owner.snapshot() == restored.snapshot(), "queued_effects_replay_exactly")
	var events: Array = owner.player_view(0).events.filter(
		func(e: Dictionary) -> bool: return e.type == "REDIRECT_RESOLVED"
	)
	_check(events.size() == 4, "all_repeated_redirects_fire")
	for index in range(events.size()):
		_check(
			events[index].data.declaration_id == draft[index].declaration_id,
			"redirects_preserve_queue_order"
		)


func _banishment() -> void:
	var world: Dictionary = OdradekScenario.world()
	world.players[0].resources.reconfiguration = 4
	var hit: Dictionary = Content.Battle.apply(
		world,
		{
			"command_id": "banish-test",
			"kind": "banish_lord",
			"target_id": world.players[0].lord_entity_id
		},
		1,
		Timeline.COMBAT_RESOLUTION
	)
	var content = Odradek.new()
	var result: Dictionary = content.react(hit.world, hit.event, "banish-test", [0, 1])
	_check(
		result.action != "invalid" and result.world.players[0].resources.reconfiguration == 0,
		"banishment_immediately_resets_bank"
	)
	var owner = content.create_combat_match()
	if not _check(
		owner.start("banished", result.world, [0, 1]).action != "invalid", "banished_odradek_valid"
	):
		return
	if not _advance(owner, Timeline.SUBMISSION_LOCK):
		return
	_check(
		owner.snapshot().world.players[0].resources.reconfiguration == 0,
		"banished_lord_gains_nothing"
	)
	_check(
		(
			owner.preview_submission(0, [OdradekScenario.source(0, 1, _target())], {}).action
			== "invalid"
		),
		"banished_lord_cannot_declare"
	)
	var record: Dictionary = Pending.new().schedule(OdradekScenario.source(0, 1, _target())).effect
	_check(
		(
			(
				content
				. resolve(record, _context(result.world, Timeline.POST_RESOLUTION_POSITION))
				. action
			)
			== "resolved"
		),
		"armed_redirect_survives_banishment"
	)


func _roster() -> void:
	for opponent in ["Gremory", "Deimos", "Humbaba", "Kalligan", "Orias", "Odradek"]:
		var session = Session.new()
		var result: Dictionary = session.configure(
			["Odradek", opponent], [Session.Slots.TYPES, Session.Slots.TYPES], true
		)
		if not _check(result.action != "invalid", "odradek_setup_vs_" + opponent):
			print(result)
			continue
		var saved: Dictionary = session.checkpoint()
		_check(
			(
				Session.new().restore_checkpoint(JSON.parse_string(JSON.stringify(saved))).action
				!= "invalid"
			),
			"odradek_board_checkpoint_restores"
		)


func _interrupted_duel() -> void:
	var world: Dictionary = OdradekScenario.world()
	var left: String = _add(world, 0, 0, "Lord", 1200, 300)
	var right: String = _add(world, 1, 1, "Lord", 1200, 300)
	var waiter: String = _add(world, 2, 0, "Lord", 2400, 300)
	var ids = Ids.new()
	ids.restore(world.entities)
	for id in [left, right]:
		var unit: Dictionary = ids.get_entity(id)
		unit.attributes.hp = 500
		unit.attributes.max_hp = 500
		unit.attributes.attack = 1
		ids.update(id, unit.owner, unit.attributes)
	var waiting: Dictionary = ids.get_entity(waiter)
	waiting.attributes.waiting = true
	waiting.attributes.waiting_since_round = 1
	ids.update(waiter, 0, waiting.attributes)
	world.entities = ids.snapshot()
	var content = Odradek.new()
	var fought: Dictionary = Marching.resolve(
		_context(world, Timeline.MARCHING), Callable(content, "react")
	)
	if not _check(
		fought.action == "resolved" and not fought.world.data.marching_duels.is_empty(),
		"redirect_fixture_has_unfinished_duel"
	):
		return
	var record: Dictionary = Pending.new().schedule(OdradekScenario.source(0, 2, _target())).effect
	var moved: Dictionary = content.resolve(
		record, _context(fought.world, Timeline.POST_RESOLUTION_POSITION, 2)
	)
	if not _check(moved.action == "resolved", "redirect_moves_fighting_marchers"):
		return
	_check(
		moved.world.data.marching_duels.is_empty() and Marching.valid(moved.world),
		"redirect_invalidates_old_lane_encounter"
	)
	var resumed: Dictionary = Marching.resolve(
		_context(moved.world, Timeline.MARCHING, 2), Callable(content, "react")
	)
	_check(resumed.action == "resolved", "redirected_combat_resumes_on_new_lane")
	var gate_record: Dictionary = (
		Pending
		. new()
		. schedule(
			OdradekScenario.source(
				0, 2, {"lane": "Lord", "field_position": {"x_fp": 2400, "y_fp": 300}}, 1
			)
		)
		. effect
	)
	var gate: Dictionary = content.resolve(
		gate_record, _context(moved.world, Timeline.POST_RESOLUTION_POSITION, 2)
	)
	var expected: Dictionary = _entity(moved.world, waiter).duplicate(true)
	expected.attributes.lane = "Castle"
	_check(
		_entity(gate.world, waiter) == expected and Marching.valid(gate.world),
		"redirect_waiter_keeps_progress_and_waiting_state_on_new_lane"
	)
