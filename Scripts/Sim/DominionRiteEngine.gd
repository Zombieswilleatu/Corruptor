class_name DominionRiteEngine
extends RefCounted


const INVOCATION_PAYMENT_THRESHOLD: int = 11

const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
)


static func resolve(
	game,
	rules: RuleConfig,
	rite_choices: Dictionary
) -> Array[Dictionary]:
	assert(
		game != null,
		"Dominion Rite resolution requires a GameState."
	)

	assert(
		rules != null,
		"Dominion Rite resolution requires RuleConfig."
	)

	var results: Array[Dictionary] = []

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		var decision: Dictionary = _decision_for_player(
			rite_choices,
			player_id
		)

		results.append(
			_resolve_player_rites(
				game,
				player,
				rules,
				decision
			)
		)

	game.refresh_derived_values()

	return results


static func _resolve_player_rites(
	game,
	player,
	rules: RuleConfig,
	decision: Dictionary
) -> Dictionary:
	var player_id: int = int(
		player.pid
	)

	var actions: Array[Dictionary] = []

	if _decision_is_pass(decision):
		return {
			"player_id": player_id,
			"actions": actions,
			"reason": "pass",
		}

	var invocation_decision: Dictionary = _nested_decision(
		decision,
		"invocation"
	)

	if not _decision_is_pass(
		invocation_decision
	):
		var invocation_result: Dictionary = (
			_resolve_invocation(
				game,
				player,
				rules,
				invocation_decision
			)
		)

		actions.append(
			invocation_result
		)

		if (
			String(
				invocation_result.get(
					"action",
					""
				)
			) == "cataclysmic_invocation"
			and bool(
				invocation_result.get(
					"won",
					false
				)
			)
		):
			return {
				"player_id": player_id,
				"actions": actions,
				"reason": "",
			}

	var profane_decision: Dictionary = _nested_decision(
		decision,
		"profane_ruins"
	)

	if not _decision_is_pass(
		profane_decision
	):
		actions.append(
			_resolve_profane_ruins(
				game,
				player,
				rules,
				profane_decision
			)
		)

	var reason: String = ""

	if actions.is_empty():
		reason = "no_actions"

	return {
		"player_id": player_id,
		"actions": actions,
		"reason": reason,
	}


static func _resolve_invocation(
	game,
	player,
	rules: RuleConfig,
	decision: Dictionary
) -> Dictionary:
	var player_id: int = int(
		player.pid
	)

	if (
		not rules.invocation_repeatable
		and player.cataclysmic_used
	):
		return _invalid_rite_result(
			"invocation",
			"invocation_already_used"
		)

	var veil_before: int = int(
		game.calculate_veil_total()
	)

	if veil_before < rules.invocation_gate:
		return _invalid_rite_result(
			"invocation",
			"veil_below_invocation_gate"
		)

	var raw_payment = decision.get(
		"payment",
		[]
	)

	if typeof(raw_payment) != TYPE_ARRAY:
		return _invalid_rite_result(
			"invocation",
			"payment_must_be_array"
		)

	var payment_ids: Array = raw_payment

	var selection: Dictionary = _select_hand_payment(
		player,
		payment_ids,
		INVOCATION_PAYMENT_THRESHOLD
	)

	if not bool(
		selection.get(
			"valid",
			false
		)
	):
		return _invalid_rite_result(
			"invocation",
			String(
				selection.get(
					"reason",
					"invalid_payment"
				)
			)
		)

	var selected_cards: Array = selection.get(
		"cards",
		[]
	)

	var paid_total: int = int(
		selection.get(
			"paid_total",
			0
		)
	)

	for card in selected_cards:
		assert(
			player.hand.has(card),
			"Invocation payment card left the player's hand."
		)

		player.hand.erase(
			card
		)

		game.discard.append(
			card
		)

	player.cataclysmic_used = true

	var tear_event: Dictionary = _gain_personal_tear(
		game,
		player
	)

	var won: bool = _check_win(
		game,
		rules
	)

	return {
		"player_id": player_id,
		"action": "cataclysmic_invocation",
		"rite": "invocation",
		"reason": "",
		"cost": INVOCATION_PAYMENT_THRESHOLD,
		"paid_total": paid_total,
		"paid_cards": _card_ids(
			selected_cards
		),
		"tear_gain": 1,
		"veil_before": veil_before,
		"veil_after": int(
			game.calculate_veil_total()
		),
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
	}


static func _resolve_profane_ruins(
	game,
	player,
	rules: RuleConfig,
	decision: Dictionary
) -> Dictionary:
	var player_id: int = int(
		player.pid
	)

	if player.profane_ruins_used_this_round:
		return _invalid_rite_result(
			"profane_ruins",
			"profane_ruins_already_used"
		)

	var ruined_count: int = int(
		player.ruined_castles.size()
	)

	if ruined_count < rules.profane_ruins_req:
		return _invalid_rite_result(
			"profane_ruins",
			"insufficient_ruined_castles"
		)

	var castle_name: String = String(
		decision.get(
			"castle",
			""
		)
	)

	if castle_name.is_empty():
		return _invalid_rite_result(
			"profane_ruins",
			"castle_required"
		)

	if not player.ruined_castles.has(
		castle_name
	):
		return _invalid_rite_result(
			"profane_ruins",
			"castle_not_ruined"
		)

	player.ruined_castles.erase(
		castle_name
	)

	if not player.profaned_castles.has(
		castle_name
	):
		player.profaned_castles.append(
			castle_name
		)

	player.profane_ruins_used_this_round = true

	var tear_event: Dictionary = _gain_personal_tear(
		game,
		player
	)

	var won: bool = _check_win(
		game,
		rules
	)

	return {
		"player_id": player_id,
		"action": "profane_ruins",
		"rite": "profane_ruins",
		"reason": "",
		"castle": castle_name,
		"tear_gain": 1,
		"veil_after": int(
			game.calculate_veil_total()
		),
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
	}


static func _gain_personal_tear(
	game,
	player
) -> Dictionary:
	player.tears += 1

	var harvested_card: String = ""
	var harvested_by: int = -1

	for candidate in game.players:
		if (
			candidate.lord != "Gremory"
			or not candidate.alive
			or candidate.gremory_veil_draw_done
		):
			continue

		for index: int in range(
			game.discard.size() - 1,
			-1,
			-1
		):
			var card = game.discard[
				index
			]

			if int(card.value) < 4:
				continue

			game.discard.remove_at(
				index
			)

			candidate.hand.append(
				card
			)

			candidate.gremory_veil_draw_done = true

			harvested_card = _card_id(
				card
			)

			harvested_by = int(
				candidate.pid
			)

			break

		# The oracle assumes only one active Gremory.
		break

	game.refresh_derived_values()

	return {
		"harvested_card": harvested_card,
		"harvested_by": harvested_by,
	}


static func _check_win(
	game,
	rules: RuleConfig
) -> bool:
	if int(game.winner) >= 0:
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
		var best_player = game.players[0]

		for index: int in range(
			1,
			game.players.size()
		):
			var candidate = game.players[
				index
			]

			if candidate.souls > best_player.souls:
				best_player = candidate

		game.winner = int(
			best_player.pid
		)

		game.win_by = "FinalCollapse"

		return true

	if veil_total < rules.dominion_track:
		return false

	assert(
		game.players.size() == 2,
		"Dominion victory currently requires two players."
	)

	var best_player = game.players[0]

	if (
		game.players[1].tears
		> best_player.tears
	):
		best_player = game.players[1]

	var other_player = game.get_opponent(
		int(
			best_player.pid
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
		best_player.tears > other_player.tears
		and best_player.tears >= requirement
	):
		game.winner = int(
			best_player.pid
		)

		game.win_by = "Dominion"

		return true

	return false


static func _select_hand_payment(
	player,
	payment_ids: Array,
	required_total: int
) -> Dictionary:
	var selected_cards: Array = []
	var paid_total: int = 0

	for raw_card_id in payment_ids:
		if paid_total >= required_total:
			break

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

	if paid_total < required_total:
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


static func _nested_decision(
	decision: Dictionary,
	key: String
) -> Dictionary:
	var raw_decision = decision.get(
		key,
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


static func _invalid_rite_result(
	rite_name: String,
	reason: String
) -> Dictionary:
	return {
		"player_id": -1,
		"action": "invalid",
		"rite": rite_name,
		"reason": reason,
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
