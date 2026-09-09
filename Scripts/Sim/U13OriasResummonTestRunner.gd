extends "res://Scripts/Sim/U13OriasMarkTestRunner.gd"


func _run() -> void:
	var owner = _banish(3)
	if owner != null:
		_return_marked(owner)
	_absent_threat()
	_circle_shortfall()
	_finish("Orias resummon")


func _return_marked(owner) -> void:
	while not owner.next_hook().is_empty():
		if not _ok(owner.run_next_hook(), "mark_finish_banish_round"):
			return
	if (
		not _ok(owner.begin_next_round([0, 1]), "mark_begin_return_round")
		or not _drive(owner, Timeline.SUBMISSION_LOCK)
	):
		return
	var before: Dictionary = owner.snapshot()
	var cards: Array = owner.player_view(1).world.hand
	var order: Dictionary = {"summon": {"card_ids": cards}}
	var quote: Dictionary = Content.Resummon.quote(before.world, 1, cards)
	if not _ok(quote, "marked_return_payment_available"):
		return
	_check(quote.return_threat == 1 and quote.marked, "marked_full_payment_returns_plus_one")
	var doubled: Dictionary = order.duplicate(true)
	doubled["guard_moves"] = [{"card_id": cards[0], "lane": "Lord", "slot": 0}]
	_check(
		owner.preview_submission(1, [], doubled).action == "invalid" and owner.snapshot() == before,
		"summon_guard_double_spend_rejected"
	)
	var duplicate: Dictionary = {"summon": {"card_ids": [cards[0], cards[0]]}}
	_check(
		owner.preview_submission(1, [], duplicate).action == "invalid",
		"summon_duplicate_card_rejected"
	)
	var options: Dictionary = Scenario.enumerate(owner, 1)
	var found: bool = false
	for candidate in options.orders:
		found = found or candidate.has("summon")
	_check(found, "bot_has_resummon_candidate")
	var replay = Content.new().create_combat_match()
	if not _ok(replay.restore(JSON.parse_string(JSON.stringify(before))), "summon_prelock_json"):
		return
	for current in [owner, replay]:
		if (
			not _ok(current.submit(0, [], {}), "summon_other_pass")
			or not _ok(current.submit(1, [], order), "summon_sealed")
		):
			return
	for hook in [Timeline.SUBMISSION_LOCK, Timeline.DEVELOPMENT]:
		if (
			not _ok(owner.run_next_hook(), "summon_owner_" + hook)
			or not _ok(replay.run_next_hook(), "summon_replay_" + hook)
		):
			return
		_check(owner.snapshot() == replay.snapshot(), "summon_replay_exact_" + hook)
		_json(owner, "summon_json_" + hook)
		if hook == Timeline.SUBMISSION_LOCK:
			_check(
				not Content.Resummon.lord(owner.snapshot().world, 1).attributes.alive,
				"summon_waits_for_development"
			)
	var final: Dictionary = owner.snapshot().world
	var actor: Dictionary = Content.Resummon.lord(final, 1)
	_check(
		actor.id == before.world.players[1].lord_entity_id and actor.attributes.alive,
		"same_marked_lord_returns"
	)
	_check(actor.attributes.threat == 1, "marked_return_threat_applied_once")
	_check(final.data.orias_marks == before.world.data.orias_marks, "mark_survives_return")
	_check(
		final.data.neutral_tears == before.world.data.neutral_tears + 1,
		"resummon_addendum_one_neutral_tear"
	)
	_check(final.data.summon_counts[1] == 2, "resummon_count_once")
	while not owner.next_hook().is_empty():
		if not _ok(owner.run_next_hook(), "summon_complete_round"):
			return
	_json(owner, "summon_aftermath_json")


func _absent_threat() -> void:
	var world: Dictionary = _world("Humbaba")
	_patch(world, world.players[1].lord_entity_id, {"alive": false})
	_check(
		Content.Resummon.quote(world, 1, []).action == "invalid", "humbaba_cannot_pay_absent_threat"
	)
	var full: Dictionary = Content.Resummon.quote(world, 1, world.data.card_zones.hands[1])
	_check(full.action == "legal", "humbaba_can_pay_cards")
	_check(
		not Content.Resummon.lord(world, 1).attributes.has("threat"), "humbaba_threat_stays_absent"
	)


func _circle_shortfall() -> void:
	var world: Dictionary = _world()
	_patch(world, world.players[1].lord_entity_id, {"alive": false})
	var circle_id: String = ""
	for entity in world.entities.entities:
		if (
			entity.kind == "castle"
			and entity.owner == 1
			and entity.attributes.castle_type == "SummoningCircle"
		):
			circle_id = entity.id
	if not _check(not circle_id.is_empty(), "circle_fixture_exists"):
		return
	_patch(world, circle_id, {"integrity": 7, "status": "standing", "construction_state": "active"})
	var owner = _ready(world)
	if owner == null:
		return
	var quote: Dictionary = Content.Resummon.quote(owner.snapshot().world, 1, [])
	if not _ok(quote, "circle_makes_zero_card_return_affordable"):
		return
	_check(
		quote.circle_id == circle_id and quote.return_threat == 3,
		"circle_discount_then_threat_shortfall"
	)
	for malformed in [
		{"summon": {"card_ids": []}, "castle_action": 1},
		{"summon": {"card_ids": []}, "guard_moves": 1}
	]:
		_check(
			owner.preview_submission(1, [], malformed).action == "invalid",
			"summon_malformed_extras_rejected"
		)
	if (
		not _ok(owner.submit(0, [], {}), "circle_other_pass")
		or not _ok(owner.submit(1, [], {"summon": {"card_ids": []}}), "circle_return_sealed")
	):
		return
	for hook in [Timeline.SUBMISSION_LOCK, Timeline.DEVELOPMENT]:
		if not _ok(owner.run_next_hook(), "circle_return_" + hook):
			return
		_json(owner, "circle_return_json_" + hook)
	var final: Dictionary = owner.snapshot().world
	_check(
		(
			_entity(final, circle_id).attributes.integrity == 4
			and _entity(final, circle_id).attributes.status == "standing"
		),
		"circle_blood_offering_spends_integrity_once"
	)
	_check(
		Content.Resummon.lord(final, 1).attributes.threat == 3,
		"unmarked_return_uses_payment_shortfall"
	)
