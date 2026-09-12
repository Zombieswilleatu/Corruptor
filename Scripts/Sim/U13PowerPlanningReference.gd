# Test/profile reference for the pre-optimization power candidate transactions.
extends "res://Scripts/Sim/U13Match.gd"

func legal_power_candidates(player_id: int, sources: Array) -> Array:
	if _seed.is_empty() or player_id not in [0, 1] or next_hook() != Timeline.SUBMISSION_LOCK or _submissions[player_id] != null:
		return []
	var baseline = _clone()
	if baseline == null:
		return []
	var result: Array = []
	for source in sources:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		var candidate = baseline._fork_validated()
		if candidate._accept(player_id, [source], {}).action != "invalid":
			result.append(source)
	return result


static func from_owner(owner):
	var candidate = load("res://Scripts/Sim/U13PowerPlanningReference.gd").new(owner._policy_id, owner._rules, owner._validators, owner._resolvers, owner._projector, owner._hook_handler, owner._context_hook, owner._content_owner, owner._world_validator, owner._order_handler, owner._order_screen, owner._order_validator)
	return candidate if candidate.restore(owner.snapshot()).action != "invalid" else null
