extends RefCounted

const Legality = preload("res://Scripts/Sim/U13Legality.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const CASTLE_POLICY: String = "U13_RANDOM_CASTLE_V1"
const VERSION: String = "U13_RANDOM_LEGAL_V1"


# One power name uniformly, then one complete canonical payload uniformly.
# Real doctrine owns the decision when supplied, including an intentional pass.
static func plan(
	owner, player_id: int, candidates: Callable, doctrine: Callable = Callable()
) -> Dictionary:
	if player_id not in [0, 1]:
		return Data.invalid("bot_player_invalid")
	if doctrine.is_valid():
		var decision = doctrine.call(owner.player_view(player_id, 0))
		return _checked(owner, player_id, decision)
	if not candidates.is_valid():
		return Data.invalid("bot_candidate_provider_missing")
	var raw = candidates.call(owner, player_id)
	if typeof(raw) != TYPE_DICTIONARY:
		return Data.invalid("bot_candidate_contract_invalid")
	if raw.get("action") == "invalid":
		return raw
	if typeof(raw.get("powers")) != TYPE_ARRAY or typeof(raw.get("orders")) != TYPE_ARRAY:
		return Data.invalid("bot_candidate_contract_invalid")
	var groups: Array = Legality.legal_power_groups(owner, player_id, raw.powers)
	var powers: Array = []
	if not groups.is_empty():
		var group: Dictionary = groups[_pick(
			owner, player_id, "BOT_POWER_CHOICE", "power", groups.size()
		)]
		powers.append(
			group.candidates[_pick(
				owner, player_id, "BOT_POWER_TARGET", group.power, group.candidates.size()
			)]
		)
	var castle_action: Dictionary = {}
	if raw.has("castle_actions"):
		if typeof(raw.castle_actions) != TYPE_ARRAY:
			return Data.invalid("castle_candidates_invalid")
		var choices: Array = Legality.legal_castle_groups(
			owner, player_id, powers, raw.castle_actions
		)
		if not choices.is_empty():
			var group: Dictionary = choices[_pick(
				owner, player_id, "BOT_CASTLE_ACTION", CASTLE_POLICY, choices.size()
			)]
			castle_action = group.candidates[_pick(
				owner,
				player_id,
				"BOT_CASTLE_PAYMENT",
				CASTLE_POLICY + ":" + group.action,
				group.candidates.size()
			)]
	var orders: Array = Legality.legal_combat_orders(
		owner, player_id, powers, raw.orders, castle_action
	)
	var order: Dictionary = (
		{}
		if orders.is_empty()
		else orders[_pick(owner, player_id, "BOT_COMBAT_CHOICE", "order", orders.size())]
	)
	if orders.is_empty() and not castle_action.is_empty():
		order["castle_action"] = castle_action
	return _checked(owner, player_id, {"powers": powers, "order": order})


static func _checked(owner, player_id: int, decision) -> Dictionary:
	if (
		typeof(decision) != TYPE_DICTIONARY
		or typeof(decision.get("powers")) != TYPE_ARRAY
		or typeof(decision.get("order")) != TYPE_DICTIONARY
	):
		return Data.invalid("bot_doctrine_contract_invalid")
	var checked: Dictionary = owner.preview_submission(player_id, decision.powers, decision.order)
	if checked.action == "invalid":
		return checked
	return {
		"action": "bot_plan",
		"powers": decision.powers.duplicate(true),
		"order": decision.order.duplicate(true)
	}


static func _pick(owner, player_id: int, purpose: String, decision: String, bound: int) -> int:
	var key: String = (
		"%s:round:%d:player:%d:%s" % [VERSION, owner.round_number(), player_id, decision]
	)
	return int(Rng.draw(owner.rng_seed(), key, purpose, 0, bound).value)
