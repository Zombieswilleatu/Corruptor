class_name ResolutionCleanupEngine
extends RefCounted


const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
)


static func resolve(
	game,
	rules: RuleConfig,
	gremory_choices: Dictionary = {}
) -> Dictionary:
	assert(
		game != null,
		"Resolution Cleanup requires a GameState."
	)

	assert(
		rules != null,
		"Resolution Cleanup requires RuleConfig."
	)

	var gremory_events: Array[Dictionary] = []
	var penitent_events: Array[Dictionary] = []
	var profane_events: Array[Dictionary] = []

	for player in game.players:
		if player.lord != "Gremory":
			continue

		var decision: Dictionary = _decision_for_player(
			gremory_choices,
			int(
				player.pid
			)
		)

		var gremory_event: Dictionary = (
			_resolve_inevitable_ruin(
				game,
				player,
				rules,
				decision
			)
		)

		gremory_events.append(
			gremory_event
		)

		if bool(
			gremory_event.get(
				"won",
				false
			)
		):
			game.refresh_derived_values()

			return {
				"action": "resolution_cleanup",
				"gremory_events": gremory_events,
				"penitent_events": penitent_events,
				"profane_events": profane_events,
				"stopped_on_win": true,
				"winner": int(
					game.winner
				),
				"win_by": String(
					game.win_by
				),
			}

	for player in game.players:
		var cleanup_event: Dictionary = (
			_cleanup_penitent_guards(
				game,
				player
			)
		)

		if not bool(
			cleanup_event.get(
				"cleaned",
				false
			)
		):
			continue

		penitent_events.append(
			cleanup_event
		)

	for player in game.players:
		if String(
			player.pending_profane
		).is_empty():
			continue

		var profaned_castle: String = String(
			player.pending_profane
		)

		player.pending_profane = ""

		var tear_event: Dictionary = (
			_gain_personal_tear(
				game,
				player
			)
		)

		var won: bool = _check_win(
			game,
			rules
		)

		profane_events.append({
			"player_id": int(
				player.pid
			),
			"castle": profaned_castle,
			"tear_gain": 1,
			"harvested_card": String(
				tear_event.get(
					"harvested_card",
					""
				)
			),
			"harvested_by": int(
				tear_event.get(
					"harvested_by",
					-1
				)
			),
			"won": won,
		})

		if won:
			game.refresh_derived_values()

			return {
				"action": "resolution_cleanup",
				"gremory_events": gremory_events,
				"penitent_events": penitent_events,
				"profane_events": profane_events,
				"stopped_on_win": true,
				"winner": int(
					game.winner
				),
				"win_by": String(
					game.win_by
				),
			}

	game.refresh_derived_values()

	return {
		"action": "resolution_cleanup",
		"gremory_events": gremory_events,
		"penitent_events": penitent_events,
		"profane_events": profane_events,
		"stopped_on_win": false,
		"winner": int(
			game.winner
		),
		"win_by": String(
			game.win_by
		),
	}


static func _resolve_inevitable_ruin(
	game,
	player,
	rules: RuleConfig,
	decision: Dictionary
) -> Dictionary:
	var player_id: int = int(
		player.pid
	)

	if not player.alive:
		return _gremory_pass_result(
			player_id,
			"gremory_not_alive"
		)

	if player.gremory_inevitable_ruin_done:
		return _gremory_pass_result(
			player_id,
			"inevitable_ruin_already_used"
		)

	if _decision_is_pass(
		decision
	):
		return _gremory_pass_result(
			player_id,
			"pass"
		)

	var opponent = game.get_opponent(
		player_id
	)

	if opponent == null:
		return _invalid_gremory_result(
			player_id,
			"opponent_missing"
		)

	var target_castle: String = String(
		opponent.last_sieged_castle
	)

	if (
		not opponent.was_sieged
		or target_castle.is_empty()
		or not opponent.castles.has(
			target_castle
		)
	):
		return _invalid_gremory_result(
			player_id,
			"no_surviving_sieged_castle",
			target_castle
		)

	var raw_payment = decision.get(
		"payment",
		[]
	)

	if typeof(
		raw_payment
	) != TYPE_ARRAY:
		return _invalid_gremory_result(
			player_id,
			"payment_must_be_array",
			target_castle
		)

	var payment_entries: Array = raw_payment

	if payment_entries.size() != 2:
		return _invalid_gremory_result(
			player_id,
			"payment_requires_exactly_two_cards",
			target_castle
		)

	var selection: Dictionary = _select_payment_cards(
		player,
		payment_entries
	)

	if not bool(
		selection.get(
			"valid",
			false
		)
	):
		return _invalid_gremory_result(
			player_id,
			String(
				selection.get(
					"reason",
					"invalid_payment"
				)
			),
			target_castle
		)

	var selected_entries: Array = selection.get(
		"entries",
		[]
	)

	var paid_cards: Array = []

	for selected_entry in selected_entries:
		var entry: Dictionary = selected_entry
		var source: String = String(
			entry.get(
				"source",
				""
			)
		)

		var card = entry.get(
			"card"
		)

		if source == "Hand":
			assert(
				player.hand.has(
					card
				),
				"Inevitable Ruin hand payment disappeared."
			)

			player.hand.erase(
				card
			)
		else:
			assert(
				player.garrison.has(
					card
				),
				"Inevitable Ruin Garrison payment disappeared."
			)

			player.garrison.erase(
				card
			)

		game.discard.append(
			card
		)

		paid_cards.append(
			card
		)

	player.gremory_inevitable_ruin_done = true

	opponent.castles.erase(
		target_castle
	)

	if not opponent.ruined_castles.has(
		target_castle
	):
		opponent.ruined_castles.append(
			target_castle
		)

	game.set_meta(
		"any_destruction_round",
		int(
			game.round
		)
	)

	var neutral_tear_gain: int = 0
	var harvested_card: String = ""
	var harvested_by: int = -1

	if _castle_tear_available(
		game,
		rules
	):
		var tear_event: Dictionary = (
			_gain_neutral_tear(
				game
			)
		)

		neutral_tear_gain = 1

		harvested_card = String(
			tear_event.get(
				"harvested_card",
				""
			)
		)

		harvested_by = int(
			tear_event.get(
				"harvested_by",
				-1
			)
		)

		_mark_castle_tear_used(
			game
		)

	var recovered_card = null

	if not player.gremory_ruin_done:
		if not game.discard.is_empty():
			recovered_card = game.discard.pop_back()

			player.hand.append(
				recovered_card
			)

		player.gremory_ruin_done = true

	var won: bool = _check_win(
		game,
		rules
	)

	return {
		"player_id": player_id,
		"action": "inevitable_ruin",
		"reason": "",
		"target_player_id": int(
			opponent.pid
		),
		"target_castle": target_castle,
		"paid_cards": _card_ids(
			paid_cards
		),
		"neutral_tear_gain": neutral_tear_gain,
		"harvested_card": harvested_card,
		"harvested_by": harvested_by,
		"recovered_card": (
			""
			if recovered_card == null
			else _card_id(
				recovered_card
			)
		),
		"won": won,
	}


static func _cleanup_penitent_guards(
	game,
	player
) -> Dictionary:
	if player.penitent_temp_guards.is_empty():
		return {
			"player_id": int(
				player.pid
			),
			"cleaned": false,
			"cards": [],
			"zones": [],
		}

	var cleaned_cards: Array = []
	var cleaned_zones: Array[String] = []

	for temporary_guard in player.penitent_temp_guards:
		var source_zone: String = "Missing"

		if player.lord_guards.has(
			temporary_guard
		):
			player.lord_guards.erase(
				temporary_guard
			)

			source_zone = "Lord"
		elif player.castle_guards.has(
			temporary_guard
		):
			player.castle_guards.erase(
				temporary_guard
			)

			source_zone = "Castle"

		# A defeated temporary Guard is already in discard.
		if source_zone == "Missing":
			continue

		game.discard.append(
			temporary_guard
		)

		cleaned_cards.append(
			temporary_guard
		)

		cleaned_zones.append(
			source_zone
		)

	player.penitent_temp_guards.clear()

	return {
		"player_id": int(
			player.pid
		),
		"cleaned": true,
		"cards": _card_ids(
			cleaned_cards
		),
		"zones": cleaned_zones,
	}


static func _select_payment_cards(
	player,
	payment_entries: Array
) -> Dictionary:
	var selected_entries: Array[Dictionary] = []
	var selected_cards: Array = []

	for raw_entry in payment_entries:
		if typeof(
			raw_entry
		) != TYPE_DICTIONARY:
			return {
				"valid": false,
				"reason": "payment_entry_must_be_dictionary",
				"entries": [],
			}

		var entry: Dictionary = raw_entry

		var source: String = String(
			entry.get(
				"source",
				""
			)
		).strip_edges().to_lower()

		var canonical_source: String = ""

		if source == "hand":
			canonical_source = "Hand"
		elif source == "garrison":
			canonical_source = "Garrison"
		else:
			return {
				"valid": false,
				"reason": "payment_source_invalid",
				"entries": [],
			}

		var card_identifier: String = String(
			entry.get(
				"card",
				""
			)
		)

		if card_identifier.is_empty():
			return {
				"valid": false,
				"reason": "payment_card_required",
				"entries": [],
			}

		var source_cards: Array = (
			player.hand
			if canonical_source == "Hand"
			else player.garrison
		)

		var selected_card = _find_unselected_card(
			source_cards,
			card_identifier,
			selected_cards
		)

		if selected_card == null:
			return {
				"valid": false,
				"reason": (
					"payment_card_missing_%s_%s"
					% [
						canonical_source,
						card_identifier,
					]
				),
				"entries": [],
			}

		selected_cards.append(
			selected_card
		)

		selected_entries.append({
			"source": canonical_source,
			"card": selected_card,
		})

	return {
		"valid": true,
		"reason": "",
		"entries": selected_entries,
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


static func _castle_tear_available(
	game,
	rules: RuleConfig
) -> bool:
	if rules.castle_tear_uncapped:
		return true

	return int(
		game.get_meta(
			"first_castle_tear_round",
			-1
		)
	) != int(
		game.round
	)


static func _mark_castle_tear_used(
	game
) -> void:
	game.set_meta(
		"first_castle_tear_round",
		int(
			game.round
		)
	)


static func _gain_personal_tear(
	game,
	player
) -> Dictionary:
	player.tears += 1

	var harvest_event: Dictionary = (
		_trigger_gremory_harvest(
			game
		)
	)

	game.refresh_derived_values()

	return harvest_event


static func _gain_neutral_tear(
	game
) -> Dictionary:
	game.neutral_tears += 1

	var harvest_event: Dictionary = (
		_trigger_gremory_harvest(
			game
		)
	)

	game.refresh_derived_values()

	return harvest_event


static func _trigger_gremory_harvest(
	game
) -> Dictionary:
	for player in game.players:
		if (
			player.lord != "Gremory"
			or not player.alive
			or player.gremory_veil_draw_done
		):
			continue

		for index in range(
			game.discard.size() - 1,
			-1,
			-1
		):
			var card = game.discard[
				index
			]

			if int(
				card.value
			) < 4:
				continue

			game.discard.remove_at(
				index
			)

			player.hand.append(
				card
			)

			player.gremory_veil_draw_done = true

			return {
				"harvested_card": _card_id(
					card
				),
				"harvested_by": int(
					player.pid
				),
			}

		break

	return {
		"harvested_card": "",
		"harvested_by": -1,
	}


static func _check_win(
	game,
	rules: RuleConfig
) -> bool:
	if int(
		game.winner
	) >= 0:
		return true

	for player in game.players:
		if (
			player.alive
			and player.souls >= rules.win_souls
		):
			game.winner = int(
				player.pid
			)

			game.win_by = "Ritual"

			return true

	var veil_total: int = int(
		game.calculate_veil_total()
	)

	if veil_total >= rules.final_collapse_threshold:
		var collapse_winner = game.players[0]

		for index in range(
			1,
			game.players.size()
		):
			var candidate = game.players[
				index
			]

			if candidate.souls > collapse_winner.souls:
				collapse_winner = candidate

		game.winner = int(
			collapse_winner.pid
		)

		game.win_by = "FinalCollapse"

		return true

	if veil_total < rules.dominion_track:
		return false

	assert(
		game.players.size() == 2,
		"Dominion victory currently requires two players."
	)

	var dominion_leader = game.players[0]

	if (
		game.players[1].tears
		> dominion_leader.tears
	):
		dominion_leader = game.players[1]

	var other_player = game.get_opponent(
		int(
			dominion_leader.pid
		)
	)

	if other_player == null:
		return false

	var player_summaries: Array = []

	for player in game.players:
		player_summaries.append({
			"lord": String(
				player.lord
			),
			"alive": bool(
				player.alive
			),
		})

	var requirement: int = (
		LordMathData.dominion_requirement(
			player_summaries,
			rules
		)
	)

	if (
		dominion_leader.tears > other_player.tears
		and dominion_leader.tears >= requirement
	):
		game.winner = int(
			dominion_leader.pid
		)

		game.win_by = "Dominion"

		return true

	return false


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

	if typeof(
		raw_decision
	) != TYPE_DICTIONARY:
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


static func _gremory_pass_result(
	player_id: int,
	reason: String
) -> Dictionary:
	return {
		"player_id": player_id,
		"action": "pass",
		"reason": reason,
		"target_player_id": -1,
		"target_castle": "",
		"paid_cards": [],
		"neutral_tear_gain": 0,
		"harvested_card": "",
		"harvested_by": -1,
		"recovered_card": "",
		"won": false,
	}


static func _invalid_gremory_result(
	player_id: int,
	reason: String,
	target_castle: String = ""
) -> Dictionary:
	return {
		"player_id": player_id,
		"action": "invalid",
		"reason": reason,
		"target_player_id": -1,
		"target_castle": target_castle,
		"paid_cards": [],
		"neutral_tear_gain": 0,
		"harvested_card": "",
		"harvested_by": -1,
		"recovered_card": "",
		"won": false,
	}


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
