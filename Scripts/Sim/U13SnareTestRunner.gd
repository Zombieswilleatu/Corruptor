extends "res://Scripts/Sim/U13GuardDeploymentTestRunner.gd"

const Pending = preload("res://Scripts/Sim/U13PendingEffects.gd")


func _run() -> void:
	_limits()
	_cost_and_declaration()
	_prepared_firing()
	_finish("Snare")


func _limits() -> void:
	for opponent in ["Gremory", "Humbaba"]:
		var world: Dictionary = _world(opponent)
		world.data.breach_lord = "Orias"
		_patch(world, world.players[0].lord_entity_id, {"threat": 2})
		if opponent == "Gremory":
			_patch(world, world.players[1].lord_entity_id, {"threat": 2})
		var owner = _ready(world)
		if owner == null:
			return
		var expected: Array = [2, 6 if opponent == "Humbaba" else 2]
		_check(
			owner.player_view(0).world.guard_placement_limits == expected,
			"entanglement_public_caps_" + opponent
		)
		var cards: Array = owner.player_view(0).world.hand
		var two: Array = [_move(cards[0]), _move(cards[1], "Castle")]
		_check(
			owner.preview_submission(0, [], {"guard_moves": two}).action != "invalid",
			"entanglement_allows_two_across_zones_" + opponent
		)
		var three: Array = two.duplicate(true)
		three.append(_move(cards[2], "Lord", 1))
		_check(
			owner.preview_submission(0, [], {"guard_moves": three}).action == "invalid",
			"entanglement_rejects_third_" + opponent
		)
		var capped: Dictionary = owner.snapshot().world
		capped.data.snare_rounds[0] = 1
		_check(Guards.limit_for(capped, 0, 1) == 1, "snare_stricter_than_entanglement")
		_check(Guards.limit_for(capped, 0, 2) == 2, "snare_expires_but_entanglement_remains")


func _cost_and_declaration() -> void:
	var world: Dictionary = _world()
	world.data.breach_lord = "Orias"
	_patch(world, world.players[0].lord_entity_id, {"threat": 1})
	var owner = _ready(world)
	if owner == null:
		return
	var source: Dictionary = Candidates.snare_source(0, 1)
	var cards: Array = owner.player_view(0).world.hand
	var order: Dictionary = {
		"guard_moves": [_move(cards[0]), _move(cards[1], "Lord", 1), _move(cards[2], "Castle")]
	}
	var before: Dictionary = owner.snapshot()
	_check(
		(
			owner.preview_submission(0, [source], order).action != "invalid"
			and owner.snapshot() == before
		),
		"snare_preview_does_not_pay_threat"
	)
	for condition in ["self", "early", "payload", "duplicate"]:
		var bad: Dictionary = source.duplicate(true)
		if condition == "self":
			bad.target.player_id = 0
		elif condition == "early":
			bad.fire_round = 1
		elif condition == "payload":
			bad.parameters["guard_limit"] = 9
		var powers: Array = [bad]
		if condition == "duplicate":
			powers.append(Candidates.snare_source(0, 1, 1))
		_check(
			owner.submit(0, powers, {}).action == "invalid" and owner.snapshot() == before,
			"snare_invalid_declaration_atomic_" + condition
		)
	if not _ok(owner.submit(0, [source], order), "snare_sealed"):
		return
	_check(
		_entity(owner.snapshot().world, world.players[0].lord_entity_id).attributes.threat == 1,
		"snare_cost_waits_for_joint_lock"
	)
	if (
		not _ok(owner.submit(1, [], {}), "snare_opponent_sealed")
		or not _ok(owner.run_next_hook(), "snare_joint_lock")
	):
		return
	var locked: Dictionary = owner.snapshot()
	_check(
		_entity(locked.world, world.players[0].lord_entity_id).attributes.threat == 2,
		"snare_pays_exactly_one_threat"
	)
	_check(
		locked.world.data.guard_public_limits[0] == 6,
		"snare_payment_does_not_retroactively_change_limit"
	)
	_check(
		locked.world.data.snare_rounds == [0, 0] and locked.pending.pending.size() == 1,
		"snare_armed_not_yet_active"
	)
	_check(owner.player_view(1).pending.size() > 0, "snare_prepared_notice_is_public")
	_json(owner, "snare_cost_checkpoint_json")
	for condition in ["paid", "threat", "due", "hook"]:
		var bad: Dictionary = locked.duplicate(true)
		if condition == "paid":
			bad.world.data.snare_paid_rounds[0] = 0
		elif condition == "threat":
			_patch(bad.world, world.players[0].lord_entity_id, {"threat": 1})
		elif condition == "due":
			bad.pending.pending[0].fire_round = 3
		else:
			bad.pending.pending[0].fire_hook = Timeline.DEVELOPMENT
		_check(
			owner.restore(bad).action == "invalid" and owner.snapshot() == locked,
			"snare_cost_restore_atomic_" + condition
		)
	if not _ok(owner.run_next_hook(), "snare_paid_round_deployment"):
		return
	_check(
		owner.player_view(0).world.hand.size() == cards.size() - 3,
		"three_preaccepted_guards_still_deploy"
	)


func _prepared_firing() -> void:
	var world: Dictionary = _world()
	_patch(world, world.players[0].lord_entity_id, {"alive": false, "threat": 1})
	var pending = Pending.new()
	var source: Dictionary = Candidates.snare_source(0, 1)
	var scheduled: Dictionary = pending.schedule(source)
	if not _ok(scheduled, "prepared_snare_fixture_schedules"):
		return
	var context: Dictionary = {"world": world, "round": 2}
	var content = Content.new()
	_check(
		content.validate(source, world, "firing").legal,
		"prepared_snare_does_not_recheck_caster_alive"
	)
	var fired: Dictionary = content.resolve(scheduled.effect, context)
	if not _ok(fired, "prepared_snare_fires_after_caster_banishment"):
		return
	_check(
		fired.world.data.snare_rounds == [0, 2] and world.data.snare_rounds == [0, 0],
		"prepared_snare_sets_only_target_round_without_mutating_input"
	)
	_check(
		_entity(fired.world, world.players[0].lord_entity_id).attributes.threat == 1,
		"prepared_snare_does_not_pay_twice"
	)
	Guards.capture_limits(fired.world, 2)
	_check(fired.world.data.guard_public_limits == [6, 1], "prepared_snare_cap_before_submission")
	Guards.capture_limits(fired.world, 3)
	_check(
		fired.world.data.guard_public_limits == [6, 6], "prepared_snare_limit_lasts_one_development"
	)
