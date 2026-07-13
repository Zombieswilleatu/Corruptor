class_name RoundEngine
extends RefCounted


const BASE_DRAW_COUNT: int = 5
const STOCKPILE_DRAW_BONUS: int = 1

const SIGIL_ZONES: Array[String] = [
	"Lord",
	"Castle",
]


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
		"Market resolution requires at least one player."
	)

	assert(
		game.first_player >= 0
		and game.first_player < game.players.size(),
		"First player is outside the valid player range."
	)

	var results: Array[Dictionary] = []

	for offset: int in range(game.players.size()):
		var player_id: int = (
			game.first_player + offset
		) % game.players.size()

		var player = game.get_player(player_id)

		assert(
			player != null,
			"Market player %d does not exist."
			% player_id
		)

		var decision: Dictionary = (
			_market_decision_for_player(
				market_choices,
				player_id
			)
		)

		if _decision_is_pass(decision):
			results.append({
				"player_id": player_id,
				"action": "pass",
				"take": "",
				"give": "",
			})

			continue

		var take_card_id: String = String(
			decision.get(
				"take",
				""
			)
		)

		var give_card_id: String = String(
			decision.get(
				"give",
				""
			)
		)

		var market_index: int = _find_card_index(
			game.market,
			take_card_id
		)

		var hand_index: int = _find_card_index(
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

		var market_card = game.market[market_index]
		var hand_card = player.hand[hand_index]

		game.market.remove_at(market_index)
		player.hand.remove_at(hand_index)

		player.hand.append(market_card)
		game.market.append(hand_card)

		results.append({
			"player_id": player_id,
			"action": "swap",
			"take": _card_id(market_card),
			"give": _card_id(hand_card),
		})

	return results


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

			if _sigil_state(player, "Lord") == "fresh":
				preserved_zone = "Lord"
			elif _sigil_state(player, "Castle") == "fresh":
				preserved_zone = "Castle"
			elif _sigil_state(player, "Lord") == "flipped":
				preserved_zone = "Lord"
			elif _sigil_state(player, "Castle") == "flipped":
				preserved_zone = "Castle"

		for zone: String in SIGIL_ZONES:
			if zone == preserved_zone:
				continue

			var state: String = _sigil_state(
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
	if rules.veil_drift <= 0:
		return

	if game.round <= 1:
		return

	if game.round % rules.veil_drift != 0:
		return

	game.neutral_tears += 1
	game.refresh_derived_values()


static func _run_draw_step(
	game,
	rules: RuleConfig
) -> void:
	for player in game.players:
		var draw_count: int = BASE_DRAW_COUNT

		if player.castles.has("Stockpile"):
			draw_count += STOCKPILE_DRAW_BONUS

		for _draw_index: int in range(draw_count):
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

	var card = _draw_top_card(game)

	if card == null:
		return false

	player.hand.append(card)

	return true


static func _draw_top_card(game):
	# The current deterministic checkpoints do not exhaust the deck.
	# Seeded discard recycling will be added with the engine RNG.
	if game.deck.is_empty():
		return null

	return game.deck.pop_back()


static func _market_decision_for_player(
	market_choices: Dictionary,
	player_id: int
) -> Dictionary:
	var raw_decision = market_choices.get(
		player_id,
		null
	)

	if raw_decision == null:
		raw_decision = market_choices.get(
			str(player_id),
			{}
		)

	if typeof(raw_decision) != TYPE_DICTIONARY:
		return {}

	return raw_decision


static func _decision_is_pass(
	decision: Dictionary
) -> bool:
	if decision.is_empty():
		return true

	if bool(
		decision.get(
			"pass",
			false
		)
	):
		return true

	var take_card_id: String = String(
		decision.get(
			"take",
			""
		)
	)

	var give_card_id: String = String(
		decision.get(
			"give",
			""
		)
	)

	return (
		take_card_id.is_empty()
		or give_card_id.is_empty()
	)


static func _find_card_index(
	cards: Array,
	card_identifier: String
) -> int:
	for index: int in range(cards.size()):
		if _card_id(cards[index]) == card_identifier:
			return index

	return -1


static func _card_id(card) -> String:
	if card == null:
		return ""

	if card.has_method("card_id"):
		return String(card.card_id())

	return "%s:%d" % [
		String(card.get("suit")),
		int(card.get("value")),
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
