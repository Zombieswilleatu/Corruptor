# Focused shared-legality regressions, with strict preview as the oracle.
extends "res://Scripts/Sim/U13ConstructionTestRunner.gd"


func _run() -> void:
	_screen_equivalence()
	_batch_boundaries()
	print("U13 planning legality failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _batch_boundaries() -> void:
	var owner = _ready_owner(Core.construction_world())
	if owner == null:
		return
	var hand: Array = owner.player_view(1, 0).world.hand
	var power: Dictionary = GremoryCandidates._source(
		1, 1, Gremory.RUIN, {"entity_id": Opening._castle_id(0)}, {"discard_ids": hand.slice(0, 2)}
	)
	var orders: Array = [
		{},
		{"castle_action": _choice("Construct", _engine(1))},
		{"action": "Ward", "lane": "Castle", "card_ids": [hand[0]]},
		{"action": "Ward", "lane": "Castle", "card_ids": [hand[2]]},
		{"action": "Hunt", "lane": "Lord", "target_id": "missing", "card_ids": []},
		{"castle_action": null},
		{"action": "unsupported"},
		7
	]
	var before: Dictionary = owner.snapshot()
	var expected: Array = []
	for order in orders:
		if (
			typeof(order) == TYPE_DICTIONARY
			and owner.preview_submission(1, [power], order).action != "invalid"
		):
			expected.append(order)
	_check(
		owner.legal_order_candidates(1, [power], orders) == expected,
		"batch_payment_and_malformed_domain"
	)
	_check(
		owner.legal_order_candidates(1, [power, power], orders).is_empty(),
		"batch_rejects_duplicate_power_prefix"
	)
	_check(
		owner.legal_order_candidates(0, [power], orders).is_empty(),
		"batch_rejects_wrong_player_prefix"
	)
	var validator: Callable = owner._order_validator
	owner._order_validator = Callable(self, "_bad_batch_validator")
	_check(
		owner.legal_order_candidates(1, [power], orders) == expected,
		"batch_malformed_validator_uses_full_transactions"
	)
	owner._order_validator = validator
	_check(owner.snapshot() == before, "batch_does_not_mutate_world_or_queues")
	_check(owner.submit(1, [power], {}).action != "invalid", "batch_seals_plan")
	_check(owner.legal_order_candidates(1, [], orders).is_empty(), "batch_rejects_locked_player")
	_check(owner.legal_power_candidates(1, [power]).is_empty(), "batch_power_rejects_locked_player")


func _bad_batch_validator(_context: Dictionary) -> Dictionary:
	return {"action": "legal_orders", "indices": [0, 0]}
