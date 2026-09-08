class_name U13BoardSession
extends "res://Scripts/Sim/U13SmokeSession.gd"

# The board has manual submissions; inherited methods only drive the U13 owner.
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
var _powers: Array = []
var _order: Dictionary = {}
var _opponent: Dictionary = {}


func reset(scenario: int = 0) -> Dictionary:
	_powers = []
	_order = {}
	_opponent = {}
	return super.reset(scenario)


func next_round() -> Dictionary:
	var result: Dictionary = super.next_round()
	if result.action != "invalid":
		_powers = []
		_order = {}
		_opponent = {}
	return result


func choose(powers: Array, order: Dictionary) -> Dictionary:
	if next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("planning_closed")
	var result: Dictionary = _owner.preview_submission(0, powers, order)
	if result.action != "invalid":
		_powers = powers.duplicate(true)
		_order = order.duplicate(true)
	return result


func declaration(
	power: String, index: int, target: Dictionary, cost: Dictionary = {}
) -> Dictionary:
	return _source(0, power, index, target, cost)


func plans() -> Dictionary:
	return {"powers": _powers.duplicate(true), "order": _order.duplicate(true)}


func preview() -> Dictionary:
	return _owner.preview_submission(0, _powers, _order)


func lock_plans() -> Dictionary:
	if next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("planning_closed")
	if _opponent.is_empty():
		_opponent = random_opponent_plan()
	var before: Dictionary = _owner.snapshot()
	for pid in [0, 1]:
		var selected: Dictionary = plans() if pid == 0 else _opponent
		var result: Dictionary = _owner.submit(pid, selected.powers, selected.order)
		if result.action == "invalid":
			_owner.restore(before)
			return result
	var result: Dictionary = _owner.run_next_hook()
	if result.action == "invalid":
		_owner.restore(before)
	return result


# Scoped exercise policy: choose one legal power uniformly by power name,
# then one canonical legal payload uniformly. No pass if a power is available.
# Legality and shared costs are owned exclusively by preview_submission.
# Card order is canonical: payment permutations do not weight the lottery.
func random_opponent_plan() -> Dictionary:
	var public: Dictionary = _owner.player_view(1).world
	var hand: Array = public.hand.duplicate()
	hand.sort()
	var targets: Array = []
	for entity in public.entities:
		if entity.kind == "castle":
			targets.append(entity.id)
	targets.sort()
	var groups: Array = []
	for power in [Gremory.PREDATOR, Gremory.RUIN]:
		var candidates: Array = []
		if power == Gremory.PREDATOR:
			for lane_name in ["Lord", "Castle"]:
				_add_legal(candidates, _source(1, power, 0, {"lane": lane_name}))
		else:
			for target in targets:
				for first in range(hand.size()):
					for second in range(first + 1, hand.size()):
						_add_legal(
							candidates,
							_source(
								1,
								power,
								0,
								{"entity_id": target},
								{"discard_ids": [hand[first], hand[second]]}
							)
						)
		if not candidates.is_empty():
			groups.append({"power": power, "candidates": candidates})
	var powers: Array = []
	if not groups.is_empty():
		var group: Dictionary = groups[_pick("BOT_POWER_CHOICE", "power", groups.size())]
		powers.append(
			group.candidates[_pick("BOT_POWER_TARGET", group.power, group.candidates.size())]
		)
	# The combat exercise policy picks a legal non-pass action if available.
	# It considers single cards and pairs; this is not strategic doctrine.
	var orders: Array = []
	var payments: Array = []
	for first in range(hand.size()):
		payments.append([hand[first]])
		for second in range(first + 1, hand.size()):
			payments.append([hand[first], hand[second]])
	for cards in payments:
		for lane_name in ["Lord", "Castle"]:
			var ward: Dictionary = {"action": "Ward", "lane": lane_name, "card_ids": cards}
			if _owner.preview_submission(1, powers, ward).action != "invalid":
				orders.append(ward)
		for target in targets:
			var siege: Dictionary = {
				"action": "Siege", "lane": "Castle", "target_id": target, "card_ids": cards
			}
			if _owner.preview_submission(1, powers, siege).action != "invalid":
				orders.append(siege)
	var order: Dictionary = (
		{} if orders.is_empty() else orders[_pick("BOT_COMBAT_CHOICE", "order", orders.size())]
	)
	return {"powers": powers, "order": order}


func _add_legal(candidates: Array, source: Dictionary) -> void:
	if _owner.preview_submission(1, [source], {}).action != "invalid":
		candidates.append(source)


func _pick(purpose: String, decision: String, bound: int) -> int:
	var key: String = "board:round:%d:player:1:%s" % [round_number(), decision]
	return int(Rng.draw(SEED, key, purpose, 0, bound).value)
