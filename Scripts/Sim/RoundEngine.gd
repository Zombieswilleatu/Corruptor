class_name RoundEngine
extends RefCounted


const BASE_DRAW_COUNT: int = 5
const STOCKPILE_DRAW_BONUS: int = 1

const REPAIR_TOKEN_DISCOUNT: int = 3
const KALLIGAN_FIRST_REPAIR_DISCOUNT: int = 7
const KALLIGAN_LATER_REPAIR_DISCOUNT: int = 5
const KALLIGAN_BREACH_REPAIR_DISCOUNT: int = 1

const SIGIL_ZONES: Array[String] = ["Lord", "Castle"]

const CASTLE_REPAIR_COSTS: Dictionary = {
	"Keep": 13,
	"Bastion": 11,
	"SummoningCircle": 9,
	"Stockpile": 8,
	"SiegeEngine": 7,
}


static func advance_to_round_draw(
	game,
	round_number: int,
	rules: RuleConfig
) -> void:
	begin_round(game, round_number)
	_update_sigils(game, rules)
	_apply_veil_drift(game, rules)
	_run_draw_step(game, rules)
	game.refresh_derived_values()


static func advance_to_round_market(
	game,
	round_number: int,
	rules: RuleConfig,
	market_choices: Dictionary
) -> Array[Dictionary]:
	advance_to_round_draw(
		game,
		round_number,
		rules
	)

	var results: Array[Dictionary] = resolve_market(
		game,
		market_choices
	)

	game.refresh_derived_values()
	return results


static func advance_to_round_repair(
	game,
	round_number: int,
	rules: RuleConfig,
	market_choices: Dictionary,
	repair_choices: Dictionary
) -> Array[Dictionary]:
	advance_to_round_market(
		game,
		round_number,
		rules,
		market_choices
	)

	var results: Array[Dictionary] = resolve_repairs(
		game,
		rules,
		repair_choices
	)

	game.refresh_derived_values()
	return results


static func begin_round(
	game,
	round_number: int
) -> void:
	assert(
		game != null,
		"RoundEngine requires a GameState."
	)

	assert(
		round_number >= 1,
		"Round number must be at least 1."
	)

	game.round = round_number
	game.reflex_winner = -1

	for player in game.players:
		player.reset_round_state()

	game.refresh_derived_values()


static func resolve_market(
	game,
	market_choices: Dictionary
) -> Array[Dictionary]:
	assert(
		game != null,
		"Market resolution requires a GameState."
	)

	assert(
		not game.players.is_empty(),
		"Market resolution requires players."
	)

	assert(
		game.first_player >= 0
		and game.first_player < game.players.size(),
		"First player is outside the valid player range."
	)

	var results: Array[Dictionary] = []

	for offset: int in range(
		game.players.size()
	):
		var player_id: int = (
			game.first_player + offset
		) % game.players.size()

		var player = game.get_player(
			player_id
		)

		assert(
			player != null,
			"Market player %d does not exist."
			% player_id
		)

		var decision: Dictionary = (
			_decision_for_player(
				market_choices,
				player_id
			)
		)

		if _market_decision_is_pass(
			decision
		):
			results.append({
				"player_id": player_id,
				"action": "pass",
				"take": "",
				"give": "",
			})

			continue

		var take_card_id := String(
			decision.get(
				"take",
				""
			)
		)

		var give_card_id := String(
			decision.get(
				"give",
				""
			)
		)

		var market_index := _find_card_index(
			game.market,
			take_card_id
		)

		var hand_index := _find_card_index(
			player.hand,
			give_card_id
		)

		assert(
			market_index >= 0,
			"Player %d attempted to take missing Market card %s."
			% [
				player_id,
				take_card_id,
			]
		)

		assert(
			hand_index >= 0,
			"Player %d attempted to give missing hand card %s."
			% [
				player_id,
				give_card_id,
			]
		)

		var market_card = game.market[
			market_index
		]

		var hand_card = player.hand[
			hand_index
		]

		game.market.remove_at(
			market_index
		)

		player.hand.remove_at(
			hand_index
		)

		player.hand.append(
			market_card
		)

		game.market.append(
			hand_card
		)

		results.append({
			"player_id": player_id,
			"action": "swap",
			"take": _card_id(
				market_card
			),
			"give": _card_id(
				hand_card
			),
		})

	return results


static func resolve_repairs(
	game,
	rules: RuleConfig,
	repair_choices: Dictionary
) -> Array[Dictionary]:
	assert(
		game != null,
		"Repair resolution requires a GameState."
	)

	assert(
		rules != null,
		"Repair resolution requires RuleConfig."
	)

	var results: Array[Dictionary] = []

	for player in game.players:
		var decision := _decision_for_player(
			repair_choices,
			int(player.pid)
		)

		results.append(
			_resolve_player_repair(
				game,
				player,
				rules,
				decision
			)
		)

	return results


static func _resolve_player_repair(
	game,
	player,
	_rules: RuleConfig,
	decision: Dictionary
) -> Dictionary:
	var player_id := int(
		player.pid
	)

	if _repair_decision_is_pass(
		decision
	):
		var pass_reason := "pass"

		if player.ruined_castles.is_empty():
			pass_reason = "no_ruins"

		return {
			"player_id": player_id,
			"action": "pass",
			"reason": pass_reason,
			"castle": "",
			"cost": 0,
			"paid_total": 0,
			"paid_cards": [],
			"used_token": false,
		}

	var castle_name := String(
		decision.get(
			"castle",
			""
		)
	)

	if not CASTLE_REPAIR_COSTS.has(
		castle_name
	):
		return _invalid_repair_result(
			player_id,
			castle_name,
			"unknown_castle"
		)

	if not player.ruined_castles.has(
		castle_name
	):
		return _invalid_repair_result(
			player_id,
			castle_name,
			"castle_not_ruined"
		)

	var use_token := bool(
		decision.get(
			"use_token",
			false
		)
	)

	if (
		use_token
		and player.repair_token <= 0
	):
		return _invalid_repair_result(
			player_id,
			castle_name,
			"repair_token_unavailable"
		)

	var repair_cost := int(
		CASTLE_REPAIR_COSTS[
			castle_name
		]
	)

	if use_token:
		repair_cost -= (
			REPAIR_TOKEN_DISCOUNT
		)

	if (
		player.lord == "Kalligan"
		and player.alive
	):
		if player.kalligan_repair_used:
			repair_cost -= (
				KALLIGAN_LATER_REPAIR_DISCOUNT
			)
		else:
			repair_cost -= (
				KALLIGAN_FIRST_REPAIR_DISCOUNT
			)

	if game.breach == "Kalligan":
		repair_cost -= (
			KALLIGAN_BREACH_REPAIR_DISCOUNT
		)

	repair_cost = max(
		1,
		repair_cost
	)

	var raw_payment = decision.get(
		"payment",
		[]
	)

	if typeof(raw_payment) != TYPE_ARRAY:
		return _invalid_repair_result(
			player_id,
			castle_name,
			"payment_must_be_array",
			repair_cost,
			use_token
		)

	var payment_ids: Array = raw_payment

	var selection := _select_payment_cards(
		player,
		payment_ids,
		repair_cost
	)

	if not bool(
		selection.get(
			"valid",
			false
		)
	):
		return _invalid_repair_result(
			player_id,
			castle_name,
			String(
				selection.get(
					"reason",
					"invalid_payment"
				)
			),
			repair_cost,
			use_token
		)

	var selected_cards: Array = (
		selection.get(
			"cards",
			[]
		)
	)

	var paid_total := int(
		selection.get(
			"paid_total",
			0
		)
	)

	if use_token:
		player.repair_token = 0

	for card in selected_cards:
		if player.hand.has(
			card
		):
			player.hand.erase(
				card
			)
		elif player.garrison.has(
			card
		):
			player.garrison.erase(
				card
			)
		else:
			assert(
				false,
				"Repair payment card left all payment zones."
			)

		game.discard.append(
			card
		)

	player.ruined_castles.erase(
		castle_name
	)

	if not player.castles.has(
		castle_name
	):
		player.castles.append(
			castle_name
		)

	player.repaired_this_round = true
	player.repair_token_used_this_repair = use_token

	if (
		player.lord == "Kalligan"
		and player.alive
	):
		player.kalligan_repair_used = true

		var opponent = game.get_opponent(
			player_id
		)

		if opponent != null:
			game.persist_scorch_pid = int(
				opponent.pid
			)

			game.persist_scorch_type = "Lord"

	return {
		"player_id": player_id,
		"action": "repair",
		"reason": "",
		"castle": castle_name,
		"cost": repair_cost,
		"paid_total": paid_total,
		"paid_cards": _card_ids(
			selected_cards
		),
		"used_token": use_token,
	}


static func _select_payment_cards(
	player,
	payment_ids: Array,
	repair_cost: int
) -> Dictionary:
	var selected_cards: Array = []
	var paid_total: int = 0

	for raw_card_id in payment_ids:
		if paid_total >= repair_cost:
			break

		var card_identifier := String(
			raw_card_id
		)

		var selected_card = (
			_find_unselected_card(
				player.hand,
				card_identifier,
				selected_cards
			)
		)

		if selected_card == null:
			selected_card = (
				_find_unselected_card(
					player.garrison,
					card_identifier,
					selected_cards
				)
			)

		if selected_card == null:
			return {
				"valid": false,
				"reason": (
					"payment_card_missing_%s"
					% card_identifier
				),
				"cards": [],
				"paid_total": 0,
			}

		selected_cards.append(
			selected_card
		)

		paid_total += int(
			selected_card.value
		)

	if paid_total < repair_cost:
		return {
			"valid": false,
			"reason": "insufficient_payment",
			"cards": [],
			"paid_total": 0,
		}

	return {
		"valid": true,
		"reason": "",
		"cards": selected_cards,
		"paid_total": paid_total,
	}


static func _find_unselected_card(
	cards: Array,
	card_identifier: String,
	selected_cards: Array
):
	for card in cards:
		if (
			not selected_cards.has(card)
			and _card_id(card) == card_identifier
		):
			return card

	return null


static func _invalid_repair_result(
	player_id: int,
	castle_name: String,
	reason: String,
	repair_cost: int = 0,
	use_token: bool = false
) -> Dictionary:
	return {
		"player_id": player_id,
		"action": "invalid",
		"reason": reason,
		"castle": castle_name,
		"cost": repair_cost,
		"paid_total": 0,
		"paid_cards": [],
		"used_token": use_token,
	}


static func _update_sigils(
	game,
	rules: RuleConfig
) -> void:
	for player in game.players:
		var preserved_zone: String = ""

		if (
			rules.humbaba_patient
			and player.humbaba_patient
		):
			player.humbaba_patient = false

			if _sigil_state(
				player,
				"Lord"
			) == "fresh":
				preserved_zone = "Lord"
			elif _sigil_state(
				player,
				"Castle"
			) == "fresh":
				preserved_zone = "Castle"
			elif _sigil_state(
				player,
				"Lord"
			) == "flipped":
				preserved_zone = "Lord"
			elif _sigil_state(
				player,
				"Castle"
			) == "flipped":
				preserved_zone = "Castle"

		for zone: String in SIGIL_ZONES:
			if zone == preserved_zone:
				continue

			var state := _sigil_state(
				player,
				zone
			)

			if state == "flipped":
				player.sigils[zone] = ""
			elif state == "fresh":
				player.sigils[zone] = "flipped"


static func _apply_veil_drift(
	game,
	rules: RuleConfig
) -> void:
	if (
		rules.veil_drift <= 0
		or game.round <= 1
	):
		return

	if (
		game.round
		% rules.veil_drift
		!= 0
	):
		return

	game.neutral_tears += 1
	game.refresh_derived_values()


static func _run_draw_step(
	game,
	rules: RuleConfig
) -> void:
	for player in game.players:
		var draw_count: int = (
			BASE_DRAW_COUNT
		)

		if player.castles.has(
			"Stockpile"
		):
			draw_count += (
				STOCKPILE_DRAW_BONUS
			)

		for _draw_index: int in range(
			draw_count
		):
			_draw_to_hand(
				game,
				player,
				rules.hand_limit
			)


static func _draw_to_hand(
	game,
	player,
	hand_limit: int
) -> bool:
	if player.hand.size() >= hand_limit:
		return false

	var card = _draw_top_card(
		game
	)

	if card == null:
		return false

	player.hand.append(
		card
	)

	return true


static func _draw_top_card(
	game
):
	# Current deterministic checkpoints do not exhaust the deck.
	# Seeded discard recycling arrives with the engine RNG.
	if game.deck.is_empty():
		return null

	return game.deck.pop_back()


static func _decision_for_player(
	decisions: Dictionary,
	player_id: int
) -> Dictionary:
	var raw_decision = decisions.get(
		player_id,
		null
	)

	if raw_decision == null:
		raw_decision = decisions.get(
			str(player_id),
			{}
		)

	if typeof(raw_decision) != TYPE_DICTIONARY:
		return {}

	return raw_decision


static func _market_decision_is_pass(
	decision: Dictionary
) -> bool:
	if (
		decision.is_empty()
		or bool(
			decision.get(
				"pass",
				false
			)
		)
	):
		return true

	return (
		String(
			decision.get(
				"take",
				""
			)
		).is_empty()
		or String(
			decision.get(
				"give",
				""
			)
		).is_empty()
	)


static func _repair_decision_is_pass(
	decision: Dictionary
) -> bool:
	if (
		decision.is_empty()
		or bool(
			decision.get(
				"pass",
				false
			)
		)
	):
		return true

	return String(
		decision.get(
			"castle",
			""
		)
	).is_empty()


static func _find_card_index(
	cards: Array,
	card_identifier: String
) -> int:
	for index: int in range(
		cards.size()
	):
		if _card_id(
			cards[index]
		) == card_identifier:
			return index

	return -1


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


static func _sigil_state(
	player,
	zone: String
) -> String:
	return String(
		player.sigils.get(
			zone,
			""
		)
	)
