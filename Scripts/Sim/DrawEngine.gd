class_name DrawEngine
extends RefCounted


static func draw_to_hand(
	game,
	player,
	rules: RuleConfig,
	random_source = null,
	outside_development: bool = false
) -> Dictionary:
	assert(
		game != null,
		"DrawEngine requires a GameState."
	)

	assert(
		player != null,
		"DrawEngine requires a PlayerState."
	)

	assert(
		rules != null,
		"DrawEngine requires RuleConfig."
	)

	var threat_before: int = int(
		player.threat
	)

	var recycle_result: Dictionary = (
		_prepare_deck(
			game,
			random_source
		)
	)

	var recycled: bool = bool(
		recycle_result.get(
			"recycled",
			false
		)
	)

	if game.deck.is_empty():
		return {
			"action": "draw",
			"drawn": false,
			"reason": "no_cards_available",
			"player_id": int(
				player.pid
			),
			"card": "",
			"outside_development": (
				outside_development
			),
			"recycled": recycled,
			"threat_before": threat_before,
			"threat_after": int(
				player.threat
			),
			"kanifous_breach_triggered": false,
		}

	# Python recycles the discard before checking the hand limit.
	if player.hand.size() >= rules.hand_limit:
		return {
			"action": "draw",
			"drawn": false,
			"reason": "hand_limit",
			"player_id": int(
				player.pid
			),
			"card": "",
			"outside_development": (
				outside_development
			),
			"recycled": recycled,
			"threat_before": threat_before,
			"threat_after": int(
				player.threat
			),
			"kanifous_breach_triggered": false,
		}

	var card = game.deck.pop_back()

	player.hand.append(
		card
	)

	var kanifous_breach_triggered: bool = false

	if outside_development:
		player.kanifous_outside_draws += 1

		if game.breach == "Kanifous":
			player.threat = min(
				rules.max_threat,
				int(
					player.threat
				) + 1
			)

			kanifous_breach_triggered = true

	game.refresh_derived_values()

	return {
		"action": "draw",
		"drawn": true,
		"reason": "",
		"player_id": int(
			player.pid
		),
		"card": _card_id(
			card
		),
		"outside_development": (
			outside_development
		),
		"recycled": recycled,
		"threat_before": threat_before,
		"threat_after": int(
			player.threat
		),
		"kanifous_breach_triggered": (
			kanifous_breach_triggered
		),
	}


static func take_top_card(
	game,
	random_source = null
):
	assert(
		game != null,
		"DrawEngine requires a GameState."
	)

	_prepare_deck(
		game,
		random_source
	)

	if game.deck.is_empty():
		return null

	return game.deck.pop_back()


static func _prepare_deck(
	game,
	random_source
) -> Dictionary:
	if not game.deck.is_empty():
		return {
			"recycled": false,
			"recycled_count": 0,
		}

	if game.discard.is_empty():
		return {
			"recycled": false,
			"recycled_count": 0,
		}

	assert(
		random_source != null,
		"Discard recycling requires a deterministic random source."
	)

	assert(
		random_source.has_method(
			"shuffle"
		),
		"Discard recycling random source must provide shuffle()."
	)

	var recycled_count: int = (
		game.discard.size()
	)

	game.deck = game.discard.duplicate()

	game.discard.clear()

	random_source.shuffle(
		game.deck
	)

	return {
		"recycled": true,
		"recycled_count": recycled_count,
	}


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
