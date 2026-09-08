class_name U13Legality
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")


# Rules are authoritative content, never supplied by the submission/UI/bot.
# Extra validators are pure (declaration, world, phase) -> {legal: bool, reason: String}.
static func validate_rule(rule: Dictionary) -> bool:
	if not Data.is_data(rule):
		return false
	for key in [
		"lord_id", "fire_hook", "cooldown_on", "target_kind", "target_relation", "visibility"
	]:
		if typeof(rule.get(key)) != TYPE_STRING:
			return false
	if rule.lord_id.is_empty() or not Timeline.is_valid_hook(rule.fire_hook):
		return false
	if (
		rule.cooldown_on not in ["activation", "expiration"]
		or rule.visibility not in ["public", "hidden"]
	):
		return false
	if (
		rule.target_kind not in ["", "lord", "castle", "card", "marcher"]
		or rule.target_relation not in ["any", "own", "enemy"]
	):
		return false
	for key in ["delay_rounds", "cooldown_rounds"]:
		if not Data.is_integer(rule.get(key)) or rule[key] < 0:
			return false
	if (
		rule.delay_rounds == 0
		and Timeline.hook_rank(rule.fire_hook) <= Timeline.hook_rank(Timeline.SUBMISSION_LOCK)
	):
		return false
	if typeof(rule.get("cost")) != TYPE_DICTIONARY or typeof(rule.get("stages")) != TYPE_ARRAY:
		return false
	if not Data.is_integer(rule.get("discard_count", 0)) or rule.get("discard_count", 0) < 0:
		return false
	for stage in rule.stages:
		if typeof(stage) != TYPE_DICTIONARY:
			return false
	for amount in rule.cost.values():
		if not Data.is_integer(amount) or amount < 0:
			return false
	if rule.cooldown_on == "expiration" and rule.stages.is_empty():
		return false
	return true


static func cost_matches(source: Dictionary, rule: Dictionary) -> bool:
	var expected: Dictionary = Data.copy_data(rule.cost)
	var count: int = int(rule.get("discard_count", 0))
	if count > 0:
		var selected = source.cost.get("discard_ids")
		if typeof(selected) != TYPE_ARRAY or selected.size() != count:
			return false
		var seen: Dictionary = {}
		for card_id in selected:
			if typeof(card_id) != TYPE_STRING or card_id.is_empty() or seen.has(card_id):
				return false
			seen[card_id] = true
		expected["discard_ids"] = selected.duplicate()
	return source.cost == expected


static func declaration(
	raw: Dictionary,
	rule: Dictionary,
	world: Dictionary,
	round_number: int,
	cooldowns,
	entities,
	extra: Callable
) -> Dictionary:
	var source: Dictionary = Data.declaration_copy(raw)
	if source.is_empty() or not validate_rule(rule):
		return Data.invalid("declaration_or_rule_invalid")
	if source.declared_round != round_number or source.lord_id != rule.lord_id:
		return Data.invalid("declaration_source_invalid")
	var fire_round: int = source.declared_round if source.fire_round == -1 else source.fire_round
	if fire_round != round_number + int(rule.delay_rounds) or source.fire_hook != rule.fire_hook:
		return Data.invalid("declaration_timing_invalid")
	if source.visibility != rule.visibility or not cost_matches(source, rule):
		return Data.invalid("declaration_terms_invalid")
	var player: Dictionary = world.players[source.player_id]
	var lord: Dictionary = entities.get_entity(player.lord_entity_id)
	if (
		player.lord_id != source.lord_id
		or lord.is_empty()
		or lord.owner != source.player_id
		or not lord.attributes.get("alive", false)
	):
		return Data.invalid("source_unavailable")
	if not cooldowns.is_ready(source.player_id, source.lord_id, source.power_id):
		return Data.invalid("power_not_ready")
	for resource in rule.cost:
		if player.resources.get(resource, 0) < rule.cost[resource]:
			return Data.invalid("insufficient_resources")
	var target_result: Dictionary = _target(source, rule, entities)
	if target_result.action == "invalid":
		return target_result
	return _extra(source, world, "declaration", extra)


static func firing(
	source: Dictionary, rule: Dictionary, world: Dictionary, entities, extra: Callable
) -> Dictionary:
	# No alive/cost/cooldown recheck: an armed power survives source Banishment.
	var target_result: Dictionary = _target(source, rule, entities)
	if target_result.action == "invalid":
		return {"action": "fizzle", "reason": target_result.reason}
	var checked: Dictionary = _extra(source, world, "firing", extra)
	if checked.action == "invalid" and checked.reason == "rule_rejected":
		return {"action": "fizzle", "reason": checked.detail}
	return checked


static func _target(source: Dictionary, rule: Dictionary, entities) -> Dictionary:
	if rule.target_kind.is_empty():
		return {"action": "legal"}
	if typeof(source.target.get("entity_id")) != TYPE_STRING:
		return Data.invalid("target_id_required")
	var target: Dictionary = entities.get_entity(source.target.entity_id)
	if target.is_empty() or target.kind != rule.target_kind:
		return Data.invalid("target_missing_or_wrong_kind")
	if rule.target_relation == "own" and target.owner != source.player_id:
		return Data.invalid("target_not_owned")
	if rule.target_relation == "enemy" and target.owner != 1 - source.player_id:
		return Data.invalid("target_not_enemy")
	return {"action": "legal"}


static func _extra(
	source: Dictionary, world: Dictionary, phase: String, extra: Callable
) -> Dictionary:
	if not extra.is_valid():
		return Data.invalid("validator_missing")
	var result = extra.call(source.duplicate(true), world.duplicate(true), phase)
	if (
		typeof(result) != TYPE_DICTIONARY
		or typeof(result.get("legal")) != TYPE_BOOL
		or typeof(result.get("reason")) != TYPE_STRING
	):
		return Data.invalid("validator_contract_error")
	if not result.legal:
		if result.reason.is_empty():
			return Data.invalid("validator_contract_error")
		return {"action": "invalid", "reason": "rule_rejected", "detail": result.reason}
	return {"action": "legal"}


# Enumeration boundary shared by UI/bot callers. Canonical representations do
# not grant extra lottery weight, and every candidate uses whole-plan preview.
static func legal_power_groups(owner, player_id: int, raw: Array) -> Array:
	var grouped: Dictionary = {}
	for item in raw:
		var source: Dictionary = Data.declaration_copy(item)
		if source.is_empty():
			continue
		if owner.preview_submission(player_id, [source], {}).action == "invalid":
			continue
		if source.cost.has("discard_ids"):
			source.cost.discard_ids.sort()
		if not grouped.has(source.power_id):
			grouped[source.power_id] = {}
		grouped[source.power_id][JSON.stringify(source, "", true)] = source
	var names: Array = grouped.keys()
	names.sort()
	var result: Array = []
	for power in names:
		var keys: Array = grouped[power].keys()
		keys.sort()
		var candidates: Array = []
		for key in keys:
			candidates.append(grouped[power][key])
		result.append({"power": power, "candidates": candidates})
	return result


static func legal_combat_orders(owner, player_id: int, powers: Array, raw: Array) -> Array:
	var unique: Dictionary = {}
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY or not Data.is_data(item):
			continue
		var order: Dictionary = item.duplicate(true)
		if owner.preview_submission(player_id, powers, order).action == "invalid":
			continue
		if typeof(order.get("card_ids")) == TYPE_ARRAY:
			order.card_ids.sort()
		unique[JSON.stringify(order, "", true)] = order
	var keys: Array = unique.keys()
	keys.sort()
	var result: Array = []
	for key in keys:
		result.append(unique[key])
	return result
