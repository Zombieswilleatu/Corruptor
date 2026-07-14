class_name ReflexBidEngine
extends RefCounted


static func resolve(
	game,
	rules: RuleConfig,
	bid_choices: Dictionary
) -> Dictionary:
	assert(
		game != null,
		"Reflex Bid requires a GameState."
	)

	assert(
		rules != null,
		"Reflex Bid requires RuleConfig."
	)

	assert(
		game.players.size() == 2,
		"Reflex Bid currently requires two players."
	)

	game.reflex_winner = -1

	if game.round <= 1:
		return _round_one_skip_result(
			game
		)

	var selected_bids: Array = []
	var bid_totals: Array[int] = []

	for player_index in range(
		game.players.size()
	):
		var player = game.players[
			player_index
		]

		var decision: Dictionary = (
			_decision_for_player(
				bid_choices,
				int(
					player.pid
				)
			)
		)

		var selection: Dictionary = _select_bid(
			player,
			decision
		)

		if not bool(
			selection.get(
				"valid",
				false
			)
		):
			return {
				"action": "invalid",
				"reason": String(
					selection.get(
						"reason",
						"invalid_bid"
					)
				),
				"winner": -1,
				"tie": false,
				"invalid_player_id": int(
					player.pid
				),
				"bid_totals": [],
				"players": [],
			}

		var cards: Array = selection.get(
			"cards",
			[]
		)

		selected_bids.append(
			cards
		)

		bid_totals.append(
			int(
				selection.get(
					"total",
					0
				)
			)
		)

	# Both bids validate before any cards leave either hand.
	for player_index in range(
		game.players.size()
	):
		var player = game.players[
			player_index
		]

		var bid_cards: Array = selected_bids[
			player_index
		]

		for card in bid_cards:
			assert(
				player.hand.has(
					card
				),
				"Validated Reflex card left the player's hand."
			)

			player.hand.erase(
				card
			)

	if bid_totals[0] == bid_totals[1]:
		return _resolve_tie(
			game,
			selected_bids,
			bid_totals
		)

	var winner_id: int = 0

	if bid_totals[1] > bid_totals[0]:
		winner_id = 1

	game.reflex_winner = winner_id

	return _resolve_winner(
		game,
		rules,
		selected_bids,
		bid_totals,
		winner_id
	)


static func _resolve_tie(
	game,
	selected_bids: Array,
	bid_totals: Array[int]
) -> Dictionary:
	var player_results: Array[Dictionary] = []

	for player_index in range(
		game.players.size()
	):
		var player = game.players[
			player_index
		]

		var bid_cards: Array = selected_bids[
			player_index
		]

		var bid_card_ids: Array[String] = _card_ids(
			bid_cards
		)

		for card in bid_cards:
			player.hand.append(
				card
			)

		player_results.append({
			"player_id": int(
				player.pid
			),
			"action": "tie",
			"bid_total": bid_totals[
				player_index
			],
			"bid_cards": bid_card_ids,
			"retrieved_card": "",
			"returned_cards": bid_card_ids.duplicate(),
			"garrisoned_cards": [],
			"discarded_cards": [],
		})

	game.reflex_winner = -1

	return {
		"action": "tie",
		"reason": "equal_bid",
		"winner": -1,
		"tie": true,
		"invalid_player_id": -1,
		"bid_totals": bid_totals.duplicate(),
		"players": player_results,
	}


static func _resolve_winner(
	game,
	rules: RuleConfig,
	selected_bids: Array,
	bid_totals: Array[int],
	winner_id: int
) -> Dictionary:
	var player_results: Array[Dictionary] = []

	for player_index in range(
		game.players.size()
	):
		var player = game.players[
			player_index
		]

		var original_bid: Array = selected_bids[
			player_index
		]

		var original_bid_ids: Array[String] = _card_ids(
			original_bid
		)

		var remaining_cards: Array = original_bid.duplicate()

		var retrieved_card = null

		if not remaining_cards.is_empty():
			var lowest_index: int = _lowest_card_index(
				remaining_cards
			)

			retrieved_card = remaining_cards[
				lowest_index
			]

			remaining_cards.remove_at(
				lowest_index
			)

			player.hand.append(
				retrieved_card
			)

		var garrisoned_cards: Array = []
		var discarded_cards: Array = []

		if player_index == winner_id:
			for card in remaining_cards:
				game.discard.append(
					card
				)

				discarded_cards.append(
					card
				)
		else:
			var garrison_space: int = max(
				0,
				rules.garrison_max
				- player.garrison.size()
			)

			for card in remaining_cards:
				if garrisoned_cards.size() < garrison_space:
					player.garrison.append(
						card
					)

					garrisoned_cards.append(
						card
					)
				else:
					game.discard.append(
						card
					)

					discarded_cards.append(
						card
					)

		var retrieved_card_id: String = ""

		if retrieved_card != null:
			retrieved_card_id = _card_id(
				retrieved_card
			)

		player_results.append({
			"player_id": int(
				player.pid
			),
			"action": (
				"win"
				if player_index == winner_id
				else "lose"
			),
			"bid_total": bid_totals[
				player_index
			],
			"bid_cards": original_bid_ids,
			"retrieved_card": retrieved_card_id,
			"returned_cards": (
				[]
				if retrieved_card_id.is_empty()
				else [
					retrieved_card_id
				]
			),
			"garrisoned_cards": _card_ids(
				garrisoned_cards
			),
			"discarded_cards": _card_ids(
				discarded_cards
			),
		})

	return {
		"action": "resolve",
		"reason": "",
		"winner": winner_id,
		"tie": false,
		"invalid_player_id": -1,
		"bid_totals": bid_totals.duplicate(),
		"players": player_results,
	}


static func _select_bid(
	player,
	decision: Dictionary
) -> Dictionary:
	if _decision_is_pass(
		decision
	):
		return {
			"valid": true,
			"reason": "",
			"cards": [],
			"total": 0,
		}

	var raw_bid = decision.get(
		"bid",
		[]
	)

	if typeof(raw_bid) != TYPE_ARRAY:
		return {
			"valid": false,
			"reason": "bid_must_be_array",
			"cards": [],
			"total": 0,
		}

	var bid_ids: Array = raw_bid
	var selected_cards: Array = []
	var bid_total: int = 0

	for raw_card_id in bid_ids:
		var card_identifier: String = String(
			raw_card_id
		)

		var selected_card = _find_unselected_card(
			player.hand,
			card_identifier,
			selected_cards
		)

		if selected_card == null:
			return {
				"valid": false,
				"reason": (
					"bid_card_missing_%s"
					% card_identifier
				),
				"cards": [],
				"total": 0,
			}

		selected_cards.append(
			selected_card
		)

		bid_total += int(
			selected_card.value
		)

	return {
		"valid": true,
		"reason": "",
		"cards": selected_cards,
		"total": bid_total,
	}


static func _find_unselected_card(
	cards: Array,
	card_identifier: String,
	selected_cards: Array
):
	for card in cards:
		if (
			not selected_cards.has(
				card
			)
			and _card_id(
				card
			) == card_identifier
		):
			return card

	return null


static func _lowest_card_index(
	cards: Array
) -> int:
	if cards.is_empty():
		return -1

	var lowest_index: int = 0
	var lowest_value: int = int(
		cards[0].value
	)

	for index in range(
		1,
		cards.size()
	):
		var current_value: int = int(
			cards[index].value
		)

		if current_value < lowest_value:
			lowest_index = index
			lowest_value = current_value

	return lowest_index


static func _round_one_skip_result(
	game
) -> Dictionary:
	var player_results: Array[Dictionary] = []

	for player in game.players:
		player_results.append({
			"player_id": int(
				player.pid
			),
			"action": "skip",
			"bid_total": 0,
			"bid_cards": [],
			"retrieved_card": "",
			"returned_cards": [],
			"garrisoned_cards": [],
			"discarded_cards": [],
		})

	return {
		"action": "skip",
		"reason": "round_one",
		"winner": -1,
		"tie": false,
		"invalid_player_id": -1,
		"bid_totals": [
			0,
			0,
		],
		"players": player_results,
	}


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
			str(
				player_id
			),
			{}
		)

	if typeof(raw_decision) != TYPE_DICTIONARY:
		return {}

	return raw_decision


static func _decision_is_pass(
	decision: Dictionary
) -> bool:
	return (
		decision.is_empty()
		or bool(
			decision.get(
				"pass",
				false
			)
		)
	)


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
