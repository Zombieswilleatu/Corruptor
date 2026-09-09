extends "res://Scripts/Sim/U13GuardDeploymentTestRunner.gd"


func _replay_round(round_number: int) -> void:
	var owner = _owner(_world())
	if owner == null:
		return
	for prior in range(1, round_number):
		if not _round(owner, prior):
			return
		if not _ok(owner.begin_next_round([0, 1]), "snare_next_round"):
			return
	var replay = Content.new().create_combat_match()
	if not _ok(
		replay.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))),
		"snare_replay_start_json"
	):
		return
	while not owner.next_hook().is_empty():
		var hook: String = owner.next_hook()
		if hook == Timeline.SUBMISSION_LOCK:
			var cards: Array = owner.player_view(1).world.hand
			var order: Dictionary = {"guard_moves": [_move(cards[0], "Lord", round_number - 1)]}
			var extra: Array = order.guard_moves.duplicate(true)
			extra.append(_move(cards[1], "Castle"))
			_check(
				(
					(owner.preview_submission(1, [], {"guard_moves": extra}).action != "invalid")
					== (round_number != 2)
				),
				"snare_two_guard_legality_round_" + str(round_number)
			)
			_check(
				(
					owner.player_view(1).world.guard_placement_limits[1]
					== (1 if round_number == 2 else 6)
				),
				"snare_public_limit_round_" + str(round_number)
			)
			for current in [owner, replay]:
				if not _submit_round(current, round_number, order):
					return
		if (
			not _ok(owner.run_next_hook(), "snare_owner_" + hook)
			or not _ok(replay.run_next_hook(), "snare_replay_" + hook)
		):
			return
		_check(owner.snapshot() == replay.snapshot(), "snare_exact_state_" + hook)
		if (
			hook
			in [
				Timeline.ROUND_START_SCHEDULED,
				Timeline.SUBMISSION_LOCK,
				Timeline.DEVELOPMENT,
				Timeline.AFTERMATH
			]
		):
			_json(owner, "snare_json_" + hook)
		if hook == Timeline.ROUND_START_SCHEDULED:
			_check(
				owner.snapshot().pending.pending.is_empty(), "snare_pending_consumed_at_round_start"
			)
		if hook == Timeline.DEVELOPMENT:
			var record: Dictionary = owner.snapshot().world.data.guard_orders[1]
			var card: Dictionary = _entity(owner.snapshot().world, record.moves[0].card_id)
			_check(card.attributes.get("role") == "guard", "snare_allowed_guard_deployed")
	var lord_id: String = owner.snapshot().world.players[0].lord_entity_id
	_check(
		_entity(owner.snapshot().world, lord_id).attributes.threat == 1,
		"snare_threat_paid_once_across_rounds"
	)


func _round(owner, round_number: int) -> bool:
	while not owner.next_hook().is_empty():
		if owner.next_hook() == Timeline.SUBMISSION_LOCK:
			var hand: Array = owner.player_view(1).world.hand
			if not _submit_round(
				owner, round_number, {"guard_moves": [_move(hand[0], "Lord", round_number - 1)]}
			):
				return false
		var result: Dictionary = owner.run_next_hook()
		if result.action == "invalid":
			return _ok(result, "snare_warmup_hook")
	return true


func _submit_round(owner, round_number: int, order: Dictionary) -> bool:
	var powers: Array = [Candidates.snare_source(0, 1)] if round_number == 1 else []
	return (
		_ok(owner.submit(0, powers, {}), "snare_round_source_submission")
		and _ok(owner.submit(1, [], order), "snare_round_guard_submission")
	)
