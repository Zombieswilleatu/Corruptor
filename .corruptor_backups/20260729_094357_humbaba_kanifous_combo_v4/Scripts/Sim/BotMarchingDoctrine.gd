class_name BotMarchingDoctrine
extends RefCounted


const ZONE_LORD: String = "Lord"
const ZONE_CASTLE: String = "Castle"

const SUIT_BEATS: Dictionary = {
	"Butcher": "Wright",
	"Wright": "Penitent",
	"Penitent": "Vulture",
	"Vulture": "Butcher",
}


static func march_choice(
	game,
	player_id: int,
	rules: RuleConfig
) -> Dictionary:
	if not rules.marching:
		return {"action": "pass"}

	var player = game.get_player(player_id)
	var opponent = game.get_opponent(player_id)

	if player == null or opponent == null:
		return {"action": "pass"}

	if player.marchers.size() >= rules.march_max_in_flight:
		return {"action": "pass"}

	var enemy_marcher = _threatening_marcher(opponent, rules)
	var candidates: Array[Dictionary] = []

	for source_zone: String in [ZONE_LORD, ZONE_CASTLE]:
		var guards: Array = (
			player.lord_guards
			if source_zone == ZONE_LORD
			else player.castle_guards
		)

		# Marching must create a real board trade rather than empty a door.
		if guards.size() <= 1:
			continue

		for card in guards:
			var score: float = _score_card(
				player,
				card,
				source_zone,
				enemy_marcher,
				rules
			)

			if score <= 0.0:
				continue

			candidates.append({
				"score": score,
				"source_zone": source_zone,
				"card": card,
			})

	if candidates.is_empty():
		return {"action": "pass"}

	candidates.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			var left_score: float = float(left.get("score", 0.0))
			var right_score: float = float(right.get("score", 0.0))
			if left_score != right_score:
				return left_score > right_score
			return _card_id(left.get("card", null)) < _card_id(right.get("card", null))
	)

	var selected: Dictionary = candidates[0]
	var card = selected.get("card", null)
	var source_zone: String = String(selected.get("source_zone", ""))

	return {
		"action": "march",
		"source_zone": source_zone,
		"lane": _choose_lane(card, source_zone, opponent, rules),
		"card": _card_id(card),
	}


static func _score_card(
	player,
	card,
	source_zone: String,
	enemy_marcher,
	rules: RuleConfig
) -> float:
	if card == null:
		return -1000.0

	var value: int = int(card.value)
	var score: float = 0.0

	if value < rules.march_threshold:
		if enemy_marcher == null:
			return -1000.0

		var enemy_card = enemy_marcher.get("card", null)
		var damage: int = rules.march_damage
		if (
			enemy_card != null
			and _suit_advantage(String(card.suit), String(enemy_card.suit))
		):
			damage += rules.march_suit_bonus

		if _is_marshal(enemy_marcher, rules):
			score += 4.0 if _is_spy_card(card, rules) else -5.0
		elif int(enemy_marcher.get("value", 0)) - damage < rules.march_threshold:
			score += 1.6
		else:
			score += 0.2

		score -= float(value) * 0.05
	else:
		if value - rules.march_damage >= rules.march_threshold:
			score += 2.0
		else:
			score += 0.7

		if _is_marshal_card(card, rules):
			score += 3.0

	if source_zone == ZONE_LORD and int(player.threat) >= 2:
		score -= 0.8

	if source_zone == ZONE_CASTLE and player.castles.size() <= 2:
		score -= 0.5

	return score


static func _choose_lane(
	card,
	source_zone: String,
	opponent,
	rules: RuleConfig
) -> String:
	var enemy_lanes: Array[String] = []

	for marcher in opponent.marchers:
		var lane: String = String(marcher.get("lane", ""))
		if not lane.is_empty() and not enemy_lanes.has(lane):
			enemy_lanes.append(lane)

	if enemy_lanes.is_empty():
		return source_zone

	var wants_contact: bool = (
		int(card.value) < rules.march_threshold
		or int(card.value) - rules.march_damage >= rules.march_threshold
	)
	var busy_lane: String = enemy_lanes[0]
	var open_lane: String = (
		ZONE_CASTLE
		if busy_lane == ZONE_LORD
		else ZONE_LORD
	)

	return busy_lane if wants_contact else open_lane


static func _threatening_marcher(opponent, rules: RuleConfig):
	for marcher in opponent.marchers:
		if int(marcher.get("value", 0)) >= rules.march_threshold:
			return marcher
	return null


static func _suit_advantage(
	attacker_suit: String,
	defender_suit: String
) -> bool:
	return String(SUIT_BEATS.get(attacker_suit, "")) == defender_suit


static func _is_marshal(marcher: Dictionary, rules: RuleConfig) -> bool:
	return _is_marshal_card(marcher.get("card", null), rules)


static func _is_marshal_card(card, rules: RuleConfig) -> bool:
	return (
		rules.march_exception_pair
		and card != null
		and String(card.suit) == "Vulture"
		and int(card.value) == 5
	)


static func _is_spy_card(card, rules: RuleConfig) -> bool:
	return (
		rules.march_exception_pair
		and card != null
		and String(card.suit) == "Butcher"
		and int(card.value) == 1
	)


static func _card_id(card) -> String:
	if card == null:
		return ""
	return "%s:%d" % [String(card.suit), int(card.value)]
