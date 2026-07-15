class_name BotDevelopmentDoctrine
extends RefCounted


const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)

const BotDoctrineData = preload(
	"res://Scripts/Sim/BotDoctrine.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const BotSelectorData = preload(
	"res://Scripts/Sim/BotSelector.gd"
)


const PASS_SCORE: float = 0.0
const UNAVAILABLE_SCORE: float = -1000.0


static func repair_choices(
	game,
	rules: RuleConfig,
	random_source = null,
	policy = null
) -> Dictionary:
	assert(
		game != null,
		"Bot Repair doctrine requires a GameState."
	)

	assert(
		rules != null,
		"Bot Repair doctrine requires RuleConfig."
	)

	var effective_policy = _policy_or_default(
		policy
	)

	var decisions: Dictionary = {}

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		var candidates: Array = (
			evaluate_repair_candidates(
				game,
				player_id,
				rules
			)
		)

		var selection: Dictionary = (
			BotSelectorData.choose(
				candidates,
				random_source,
				effective_policy
			)
		)

		var payload = selection.get(
			"payload",
			{
				"pass": true,
			}
		)

		if typeof(
			payload
		) != TYPE_DICTIONARY:
			payload = {
				"pass": true,
			}

		var decision: Dictionary = payload

		decisions[player_id] = decision.duplicate(
			true
		)

	return decisions


static func evaluate_repair_candidates(
	game,
	player_id: int,
	_rules: RuleConfig
) -> Array:
	var player = game.get_player(
		player_id
	)

	assert(
		player != null,
		"Repair evaluator player does not exist."
	)

	var candidates: Array = [
		{
			"id": "repair_pass",
			"score": PASS_SCORE,
			"degraded_score": PASS_SCORE,
			"tie_rank": 0,
			"payload": {
				"pass": true,
			},
		},
	]

	if player.ruined_castles.is_empty():
		return candidates

	var priority: Array = _castle_priority(
		String(
			player.lord
		)
	)

	var available_total: int = (
		_card_total(
			player.hand
		)
		+ _card_total(
			player.garrison
		)
	)

	for castle_name_value in player.ruined_castles:
		var castle_name: String = String(
			castle_name_value
		)

		if not RoundEngineData.CASTLE_REPAIR_COSTS.has(
			castle_name
		):
			continue

		var use_token: bool = (
			player.repair_token > 0
		)

		var cost: int = repair_cost(
			game,
			player,
			castle_name,
			use_token
		)

		if available_total < cost:
			continue

		var payment_cards: Array = (
			_select_low_payment(
				_combined_payment_zone(
					player
				),
				cost
			)
		)

		if _card_total(
			payment_cards
		) < cost:
			continue

		var priority_index: int = priority.find(
			castle_name
		)

		if priority_index < 0:
			priority_index = priority.size()

		var score: float = (
			20.0
			- float(
				priority_index
			) * 2.0
			- float(
				cost
			) * 0.01
		)

		var degraded_score: float = (
			2.0
			- float(
				cost
			) * 0.05
		)

		candidates.append({
			"id": (
				"repair_%s"
				% castle_name
			),
			"score": score,
			"degraded_score": degraded_score,
			"tie_rank": -priority_index,
			"payload": {
				"castle": castle_name,
				"use_token": use_token,
				"payment": _card_ids(
					payment_cards
				),
			},
		})

	return candidates


static func repair_cost(
	game,
	player,
	castle_name: String,
	use_token: bool
) -> int:
	var cost: int = int(
		RoundEngineData.CASTLE_REPAIR_COSTS.get(
			castle_name,
			0
		)
	)

	if use_token:
		cost -= (
			RoundEngineData
			.REPAIR_TOKEN_DISCOUNT
		)

	if (
		player.lord == "Kalligan"
		and player.alive
	):
		if player.kalligan_repair_used:
			cost -= (
				RoundEngineData
				.KALLIGAN_LATER_REPAIR_DISCOUNT
			)
		else:
			cost -= (
				RoundEngineData
				.KALLIGAN_FIRST_REPAIR_DISCOUNT
			)

	if game.breach == "Kalligan":
		cost -= (
			RoundEngineData
			.KALLIGAN_BREACH_REPAIR_DISCOUNT
		)

	return max(
		1,
		cost
	)


static func summon_choices(
	game,
	rules: RuleConfig,
	random_source = null,
	policy = null
) -> Dictionary:
	assert(
		game != null,
		"Bot Summon doctrine requires a GameState."
	)

	assert(
		rules != null,
		"Bot Summon doctrine requires RuleConfig."
	)

	var effective_policy = _policy_or_default(
		policy
	)

	var decisions: Dictionary = {}

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		var candidates: Array = (
			evaluate_summon_candidates(
				game,
				player_id,
				rules
			)
		)

		var selection: Dictionary = (
			BotSelectorData.choose(
				candidates,
				random_source,
				effective_policy
			)
		)

		var payload = selection.get(
			"payload",
			{
				"pass": true,
			}
		)

		if typeof(
			payload
		) != TYPE_DICTIONARY:
			payload = {
				"pass": true,
			}

		var decision: Dictionary = payload

		decisions[player_id] = decision.duplicate(
			true
		)

	return decisions


static func evaluate_summon_candidates(
	game,
	player_id: int,
	rules: RuleConfig
) -> Array:
	var player = game.get_player(
		player_id
	)

	var opponent = game.get_opponent(
		player_id
	)

	assert(
		player != null,
		"Summon evaluator player does not exist."
	)

	assert(
		opponent != null,
		"Summon evaluator opponent does not exist."
	)

	if player.alive:
		return [
			{
				"id": "summon_pass",
				"score": PASS_SCORE,
				"degraded_score": PASS_SCORE,
				"tie_rank": 0,
				"payload": {
					"pass": true,
				},
			},
		]

	var candidates: Array = [
		{
			"id": "summon_pass",
			"score": UNAVAILABLE_SCORE,
			"degraded_score": UNAVAILABLE_SCORE,
			"tie_rank": -1000,
			"payload": {
				"pass": true,
			},
		},
	]

	var hand_total: int = _card_total(
		player.hand
	)

	for pool_index: int in range(
		player.lord_pool.size()
	):
		var lord_name: String = String(
			player.lord_pool[
				pool_index
			]
		)

		if not GameSetupData.LORD_CONTENT.has(
			lord_name
		):
			continue

		var cost: int = summon_cost(
			game,
			player,
			rules,
			lord_name
		)

		if hand_total < cost:
			continue

		var payment_cards: Array = (
			_select_low_payment(
				player.hand,
				cost
			)
		)

		if _card_total(
			payment_cards
		) < cost:
			continue

		var score: float = _summon_score(
			game,
			player,
			opponent,
			lord_name,
			cost
		)

		var degraded_score: float = (
			1.0
			- float(
				cost
			) * 0.05
		)

		candidates.append({
			"id": (
				"summon_%s"
				% lord_name
			),
			"score": score,
			"degraded_score": degraded_score,
			"tie_rank": -pool_index,
			"payload": {
				"lord": lord_name,
				"payment": _card_ids(
					payment_cards
				),
			},
		})

	return candidates


static func summon_cost(
	game,
	player,
	rules: RuleConfig,
	lord_name: String
) -> int:
	var lord_data: Dictionary = (
		GameSetupData.LORD_CONTENT.get(
			lord_name,
			{}
		)
	)

	var cost: int = int(
		lord_data.get(
			"summon_cost",
			0
		)
	)

	if (
		lord_name == "Deimos"
		and rules.deimos_summon_cost > 0
	):
		cost = rules.deimos_summon_cost

	if (
		lord_name == "Gremory"
		and rules.gremory_summon_cost > 0
	):
		cost = rules.gremory_summon_cost

	if player.castles.has(
		"SummoningCircle"
	):
		cost -= 2

	if game.breach == lord_name:
		cost += 3

	return max(
		0,
		cost
	)


static func _summon_score(
	game,
	player,
	opponent,
	lord_name: String,
	cost: int
) -> float:
	var score: float = 0.0

	match lord_name:
		"Orias":
			score += (
				1.5
				if (
					opponent.alive
					and opponent.threat >= 1
				)
				else 0.8
			)

		"Deimos":
			score += (
				1.2
				if opponent.castles.size() >= 2
				else 0.6
			)

		"Gremory":
			score += 0.8

			if (
				not player.ruined_castles.is_empty()
				or not opponent.ruined_castles.is_empty()
			):
				score += 0.4

		"Kroni":
			score += (
				0.6
				+ player.kroni_hunger * 0.3
			)

		"Valak":
			score += (
				0.9
				if (
					opponent.alive
					and opponent.lord_guards.size() >= 2
				)
				else 0.5
			)

		"Kalligan":
			score += (
				0.7
				if not player.ruined_castles.is_empty()
				else 0.3
			)

		"Odradek":
			score += (
				0.8
				if (
					opponent.alive
					and opponent.threat >= 2
				)
				else 0.5
			)

		"Kanifous":
			score += 0.7

		"Humbaba":
			score += (
				0.7
				+ player.castles.size() * 0.08
			)

	if player.vessel_offered_lord == lord_name:
		score += 0.4

	if game.breach == lord_name:
		score -= 0.5
		score -= 1.5

	score -= float(
		cost
	) * 0.05

	return score


static func _castle_priority(
	lord_name: String
) -> Array:
	var raw_priority = (
		BotDoctrineData.CASTLE_PRIORITIES.get(
			lord_name,
			BotDoctrineData.DEFAULT_CASTLE_PRIORITY
		)
	)

	if typeof(
		raw_priority
	) != TYPE_ARRAY:
		return (
			BotDoctrineData
			.DEFAULT_CASTLE_PRIORITY
		)

	return raw_priority


static func _combined_payment_zone(
	player
) -> Array:
	var cards: Array = []

	cards.append_array(
		player.hand
	)

	cards.append_array(
		player.garrison
	)

	return cards


static func _select_low_payment(
	cards: Array,
	required_total: int
) -> Array:
	if required_total <= 0:
		return []

	var ordered_cards: Array = (
		_stable_sorted_cards(
			cards,
			false
		)
	)

	var selected_cards: Array = []
	var selected_total: int = 0

	for card in ordered_cards:
		if selected_total >= required_total:
			break

		selected_cards.append(
			card
		)

		selected_total += int(
			card.value
		)

	return selected_cards


static func _stable_sorted_cards(
	cards: Array,
	descending: bool
) -> Array:
	var entries: Array[Dictionary] = []

	for index: int in range(
		cards.size()
	):
		entries.append({
			"card": cards[index],
			"index": index,
			"value": int(
				cards[index].value
			),
		})

	entries.sort_custom(
		func(
			entry_a: Dictionary,
			entry_b: Dictionary
		) -> bool:
			var value_a: int = int(
				entry_a.get(
					"value",
					0
				)
			)

			var value_b: int = int(
				entry_b.get(
					"value",
					0
				)
			)

			if value_a != value_b:
				if descending:
					return value_a > value_b

				return value_a < value_b

			return int(
				entry_a.get(
					"index",
					0
				)
			) < int(
				entry_b.get(
					"index",
					0
				)
			)
	)

	var result: Array = []

	for entry: Dictionary in entries:
		result.append(
			entry.get(
				"card"
			)
		)

	return result


static func _card_total(
	cards: Array
) -> int:
	var total: int = 0

	for card in cards:
		total += int(
			card.value
		)

	return total


static func _card_ids(
	cards: Array
) -> Array[String]:
	var result: Array[String] = []

	for card in cards:
		result.append(
			_card_id(
				card
			)
		)

	return result


static func _card_id(
	card
) -> String:
	if card == null:
		return ""

	if card.has_method(
		"card_id"
	):
		return String(
			card.card_id()
		)

	return "%s:%d" % [
		String(
			card.get(
				"suit"
			)
		),
		int(
			card.get(
				"value"
			)
		),
	]


static func _policy_or_default(
	policy
):
	if policy == null:
		return BotPolicyData.golden_core()

	return policy
