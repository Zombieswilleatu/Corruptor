class_name SummonEngine
extends RefCounted


const SUMMONING_CIRCLE_DISCOUNT: int = 2
const BREACH_SUMMON_PENALTY: int = 3

const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
)


static func resolve(
	game,
	rules: RuleConfig,
	summon_choices: Dictionary
) -> Array[Dictionary]:
	assert(
		game != null,
		"Summon resolution requires a GameState."
	)

	assert(
		rules != null,
		"Summon resolution requires RuleConfig."
	)

	var results: Array[Dictionary] = []

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		var decision: Dictionary = _decision_for_player(
			summon_choices,
			player_id
		)

		results.append(
			_resolve_player_summon(
				game,
				player,
				rules,
				decision
			)
		)

	game.refresh_derived_values()

	return results


static func _resolve_player_summon(
	game,
	player,
	rules: RuleConfig,
	decision: Dictionary
) -> Dictionary:
	var player_id: int = int(
		player.pid
	)

	if player.alive:
		return _pass_result(
			player_id,
			"already_alive"
		)

	if _decision_is_pass(
		decision
	):
		return _pass_result(
			player_id,
			"pass"
		)

	var chosen_lord: String = String(
		decision.get(
			"lord",
			""
		)
	)

	if chosen_lord.is_empty():
		return _invalid_result(
			player_id,
			chosen_lord,
			"lord_required"
		)

	if not GameSetupData.LORD_CONTENT.has(
		chosen_lord
	):
		return _invalid_result(
			player_id,
			chosen_lord,
			"unknown_lord"
		)

	if not player.lord_pool.has(
		chosen_lord
	):
		return _invalid_result(
			player_id,
			chosen_lord,
			"lord_not_in_pool"
		)

	var summon_cost: int = _summon_cost(
		game,
		player,
		rules,
		chosen_lord
	)

	var raw_payment = decision.get(
		"payment",
		[]
	)

	if typeof(raw_payment) != TYPE_ARRAY:
		return _invalid_result(
			player_id,
			chosen_lord,
			"payment_must_be_array",
			summon_cost
		)

	var payment_ids: Array = raw_payment

	var selection: Dictionary = _select_hand_payment(
		player,
		payment_ids,
		summon_cost
	)

	if not bool(
		selection.get(
			"valid",
			false
		)
	):
		return _invalid_result(
			player_id,
			chosen_lord,
			String(
				selection.get(
					"reason",
					"invalid_payment"
				)
			),
			summon_cost
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
			player.hand.has(
				card
			),
			"Summon payment card left the player's hand."
		)

		player.hand.erase(
			card
		)

		game.discard.append(
			card
		)

	player.lord = chosen_lord
	player.alive = true

	player.threat = _return_threat(
		chosen_lord
	)

	var vessel_applied: bool = false

	if player.vessel_offered_lord == chosen_lord:
		player.threat = 2
		player.vessel_offered_lord = ""
		vessel_applied = true

	var marked_lord: String = String(
		game.get_meta(
			"orias_marked_lord",
			""
		)
	)

	if marked_lord == chosen_lord:
		player.threat = min(
			rules.max_threat,
			int(
				player.threat
			) + 1
		)

	if chosen_lord == "Kroni":
		player.kroni_tear_milestone_fired = false

	player.derived_lord_def = _calculate_lord_defense(
		player,
		rules
	)

	var tear_gain: int = 0
	var harvested_card: String = ""
	var harvested_by: int = -1
	var won: bool = false

	if player.first_summon_done:
		var tear_event: Dictionary = _gain_neutral_tear(
			game
		)

		tear_gain = 1

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

		won = _check_win(
			game,
			rules
		)
	else:
		player.first_summon_done = true

	game.refresh_derived_values()

	return {
		"player_id": player_id,
		"action": "summon",
		"reason": "",
		"lord": chosen_lord,
		"cost": summon_cost,
		"paid_total": paid_total,
		"paid_cards": _card_ids(
			selected_cards
		),
		"threat": int(
			player.threat
		),
		"derived_lord_def": int(
			player.derived_lord_def
		),
		"vessel_applied": vessel_applied,
		"neutral_tear_gain": tear_gain,
		"harvested_card": harvested_card,
		"harvested_by": harvested_by,
		"won": won,
	}


static func _summon_cost(
	game,
	player,
	rules: RuleConfig,
	lord_id: String
) -> int:
	var lord_data: Dictionary = (
		GameSetupData.LORD_CONTENT.get(
			lord_id,
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
		lord_id == "Deimos"
		and rules.deimos_summon_cost > 0
	):
		cost = rules.deimos_summon_cost

	if (
		lord_id == "Gremory"
		and rules.gremory_summon_cost > 0
	):
		cost = rules.gremory_summon_cost

	if player.castles.has(
		"SummoningCircle"
	):
		cost -= SUMMONING_CIRCLE_DISCOUNT

	if game.breach == lord_id:
		cost += BREACH_SUMMON_PENALTY

	return max(
		0,
		cost
	)


static func _return_threat(
	lord_id: String
) -> int:
	var lord_data: Dictionary = (
		GameSetupData.LORD_CONTENT.get(
			lord_id,
			{}
		)
	)

	return int(
		lord_data.get(
			"return_threat",
			0
		)
	)


static func _calculate_lord_defense(
	player,
	rules: RuleConfig
) -> int:
	if player.lord == "Humbaba":
		return LordMathData.lord_base_def(
			"Humbaba",
			player.castles,
			int(
				player.threat
			),
			rules
		)

	var lord_data: Dictionary = (
		GameSetupData.LORD_CONTENT.get(
			player.lord,
			{}
		)
	)

	var defense: int = int(
		lord_data.get(
			"base_defense",
			0
		)
	)

	if player.threat >= 4:
		defense -= 3
	elif player.threat >= 3:
		defense -= 2
	elif player.threat >= 2:
		defense -= 1

	if player.castles.has(
		"Bastion"
	):
		defense += 2

	return max(
		0,
		defense
	)


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
			not selected_cards.has(
				card
			)
			and _card_id(
				card
			) == card_identifier
		):
			return card

	return null


static func _gain_neutral_tear(
	game
) -> Dictionary:
	game.neutral_tears += 1

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

			if int(
				card.value
			) < 4:
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
	# Python re-evaluates victory after each player's summon.
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
		var final_collapse_player = game.players[0]

		for index: int in range(
			1,
			game.players.size()
		):
			var candidate = game.players[
				index
			]

			if (
				candidate.souls
				> final_collapse_player.souls
			):
				final_collapse_player = candidate

		game.winner = int(
			final_collapse_player.pid
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


static func _pass_result(
	player_id: int,
	reason: String
) -> Dictionary:
	return {
		"player_id": player_id,
		"action": "pass",
		"reason": reason,
		"lord": "",
		"cost": 0,
		"paid_total": 0,
		"paid_cards": [],
		"threat": 0,
		"derived_lord_def": 0,
		"vessel_applied": false,
		"neutral_tear_gain": 0,
		"harvested_card": "",
		"harvested_by": -1,
		"won": false,
	}


static func _invalid_result(
	player_id: int,
	lord_id: String,
	reason: String,
	summon_cost: int = 0
) -> Dictionary:
	return {
		"player_id": player_id,
		"action": "invalid",
		"reason": reason,
		"lord": lord_id,
		"cost": summon_cost,
		"paid_total": 0,
		"paid_cards": [],
		"threat": 0,
		"derived_lord_def": 0,
		"vessel_applied": false,
		"neutral_tear_gain": 0,
		"harvested_card": "",
		"harvested_by": -1,
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
