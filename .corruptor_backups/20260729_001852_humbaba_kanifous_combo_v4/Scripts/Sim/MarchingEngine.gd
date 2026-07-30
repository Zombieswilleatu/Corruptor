class_name MarchingEngine
extends RefCounted


const ResolutionFinaleEngineData = preload(
	"res://Scripts/Sim/ResolutionFinaleEngine.gd"
)


const ZONE_LORD: String = "Lord"
const ZONE_CASTLE: String = "Castle"
const LANES: Array[String] = [
	ZONE_LORD,
	ZONE_CASTLE,
]

const SUIT_BEATS: Dictionary = {
	"Butcher": "Wright",
	"Wright": "Penitent",
	"Penitent": "Vulture",
	"Vulture": "Butcher",
}


static func launch(
	game,
	rules: RuleConfig,
	player_id: int,
	decision: Dictionary
) -> Dictionary:
	if not rules.marching:
		return _result(player_id, "pass", "marching_disabled")

	var player = game.get_player(player_id)
	if player == null:
		return _invalid(player_id, "player_missing")

	if _is_pass(decision):
		return _result(player_id, "pass", "pass")

	if player.marchers.size() >= rules.march_max_in_flight:
		return _invalid(player_id, "marcher_limit")

	var source_zone: String = String(decision.get("source_zone", ""))
	var lane: String = String(decision.get("lane", ""))
	var card_id: String = String(decision.get("card", ""))

	if not LANES.has(source_zone):
		return _invalid(player_id, "march_source_zone_invalid")
	if not LANES.has(lane):
		return _invalid(player_id, "march_lane_invalid")

	var guards: Array = (
		player.lord_guards
		if source_zone == ZONE_LORD
		else player.castle_guards
	)
	var card_index: int = _find_card_index(guards, card_id)
	if card_index < 0:
		return _invalid(player_id, "march_card_missing")

	var card = guards[card_index]
	guards.remove_at(card_index)
	player.marchers.append({
		"card": card,
		"value": int(card.value),
		"lane": lane,
		"pos": 0,
	})

	return {
		"action": "march",
		"player_id": player_id,
		"reason": "",
		"source_zone": source_zone,
		"lane": lane,
		"card": _card_id(card),
	}


static func advance(
	game,
	rules: RuleConfig
) -> Dictionary:
	var events: Array[Dictionary] = []

	if not rules.marching:
		return {
			"action": "march_advance",
			"enabled": false,
			"events": events,
			"terminal": false,
		}

	for player in game.players:
		for marcher in player.marchers:
			marcher["pos"] = int(marcher.get("pos", 0)) + 1

	for lane in LANES:
		var first = _marcher_in_lane(game.get_player(0), lane)
		var second = _marcher_in_lane(game.get_player(1), lane)
		if first == null or second == null:
			continue

		var first_marshal: bool = _is_marshal(first, rules)
		var second_marshal: bool = _is_marshal(second, rules)
		if ((first_marshal and _is_spy(second, rules))
				or (second_marshal and _is_spy(first, rules))):
			first["value"] = 0
			second["value"] = 0
			events.append({
				"type": "march_spy",
				"lane": lane,
			})
		elif first_marshal or second_marshal:
			events.append({
				"type": "march_evade",
				"lane": lane,
			})
		else:
			var first_damage: int = rules.march_damage
			var second_damage: int = rules.march_damage
			if _suit_advantage(_card_suit(second), _card_suit(first)):
				first_damage += rules.march_suit_bonus
			if _suit_advantage(_card_suit(first), _card_suit(second)):
				second_damage += rules.march_suit_bonus
			first["value"] = int(first.get("value", 0)) - first_damage
			second["value"] = int(second.get("value", 0)) - second_damage
			events.append({
				"type": "march_clash",
				"lane": lane,
				"first_damage": first_damage,
				"second_damage": second_damage,
			})

	for player in game.players:
		var survivors: Array[Dictionary] = []
		for marcher in player.marchers:
			var card = marcher.get("card", null)
			var value: int = int(marcher.get("value", 0))
			if value <= 0:
				if rules.lane_kill_soul:
					var opponent = game.get_opponent(int(player.pid))
					if opponent != null:
						opponent.souls += 1
				game.discard.append(card)
				events.append({
					"type": "march_destroyed",
					"player_id": int(player.pid),
					"card": _card_id(card),
				})
				continue

			if int(marcher.get("pos", 0)) >= rules.march_steps:
				var scored: bool = value >= rules.march_threshold
				if scored:
					player.tears += 1
				game.discard.append(card)
				events.append({
					"type": "march_arrival",
					"player_id": int(player.pid),
					"card": _card_id(card),
					"scored": scored,
				})
				continue

			survivors.append(marcher)
		player.marchers = survivors

	game.refresh_derived_values()
	var terminal: bool = ResolutionFinaleEngineData.check_win(game, rules)
	return {
		"action": "march_advance",
		"enabled": true,
		"events": events,
		"terminal": terminal,
	}


static func _marcher_in_lane(player, lane: String):
	if player == null:
		return null
	for marcher in player.marchers:
		if String(marcher.get("lane", "")) == lane:
			return marcher
	return null


static func _is_marshal(marcher: Dictionary, rules: RuleConfig) -> bool:
	var card = marcher.get("card", null)
	return (
		rules.march_exception_pair
		and card != null
		and String(card.suit) == "Vulture"
		and int(card.value) == 5
	)


static func _is_spy(marcher: Dictionary, rules: RuleConfig) -> bool:
	var card = marcher.get("card", null)
	return (
		rules.march_exception_pair
		and card != null
		and String(card.suit) == "Butcher"
		and int(card.value) == 1
	)


static func _suit_advantage(attacker_suit: String, defender_suit: String) -> bool:
	return String(SUIT_BEATS.get(attacker_suit, "")) == defender_suit


static func _card_suit(marcher: Dictionary) -> String:
	var card = marcher.get("card", null)
	return "" if card == null else String(card.suit)


static func _find_card_index(cards: Array, card_identifier: String) -> int:
	for index in range(cards.size()):
		if _card_id(cards[index]) == card_identifier:
			return index
	return -1


static func _is_pass(decision: Dictionary) -> bool:
	return String(decision.get("action", "pass")).to_lower() == "pass"


static func _card_id(card) -> String:
	return "" if card == null else "%s:%d" % [String(card.suit), int(card.value)]


static func _result(player_id: int, action: String, reason: String) -> Dictionary:
	return {
		"action": action,
		"player_id": player_id,
		"reason": reason,
		"source_zone": "",
		"lane": "",
		"card": "",
	}


static func _invalid(player_id: int, reason: String) -> Dictionary:
	var result := _result(player_id, "invalid", reason)
	return result
