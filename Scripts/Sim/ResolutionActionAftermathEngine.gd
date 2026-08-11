class_name ResolutionActionAftermathEngine
extends RefCounted


const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
)

const DrawEngineData = preload(
	"res://Scripts/Sim/DrawEngine.gd"
)


const ACTION_HUNT: String = "hunt"
const ACTION_SIEGE: String = "siege"

const SUIT_VULTURE: String = "Vulture"
const SUIT_WRIGHT: String = "Wright"


static func resolve(
	game,
	rules: RuleConfig,
	acting_player_id: int,
	action_result: Dictionary = {},
	vessel_decision: Dictionary = {},
	random_source = null
) -> Dictionary:
	assert(
		game != null,
		"Resolution Action Aftermath requires a GameState."
	)

	assert(
		rules != null,
		"Resolution Action Aftermath requires RuleConfig."
	)

	var acting_player = game.get_player(
		acting_player_id
	)

	if acting_player == null:
		return _invalid_result(
			acting_player_id,
			"acting_player_missing"
		)

	# Validate the cached Vessel decision before aftermath mutation.
	var vessel_validation: Dictionary = {
		"valid": true,
		"reason": "",
		"offer": false,
	}

	# Doctrine-marked Vessel decisions are validated after reevaluation. The
	# playable prototype may also ask a human at this exact boundary.
	var post_action_choice: bool = bool(
		vessel_decision.get(
			"post_action",
			false
		)
	)

	if not bool(
		vessel_decision.get(
			"reevaluate_after_action",
			false
		)
	) and not post_action_choice:
		vessel_validation = (
			_validate_vessel_decision(
				game,
				acting_player,
				vessel_decision
			)
		)

		if not bool(
			vessel_validation.get(
				"valid",
				false
			)
		):
			return _invalid_result(
				acting_player_id,
				String(
					vessel_validation.get(
						"reason",
						"invalid_vessel_decision"
					)
				)
			)

	# Explicit cached Vessel decisions cannot reopen an existing victory.
	if (
		int(game.winner) >= 0
		and not bool(
			vessel_decision.get(
				"reevaluate_after_action",
				false
			)
		)
		and not post_action_choice
	):
		var stale_vessel_event: Dictionary = (
			_resolve_vessel(
				game,
				acting_player,
				vessel_validation,
				rules,
				random_source
			)
		)

		return {
			"action": "resolution_action_aftermath",
			"reason": "",
			"player_id": acting_player_id,
			"destruction_recorded": false,
			"kroni_events": [],
			"vessel_event": stale_vessel_event,
			"vulture_draw": "",
			"wright_token_gained": false,
			"momentum_refunded": [],
			"discarded_committed": [],
			"stopped_on_win": true,
			"winner": int(
				game.winner
			),
			"win_by": String(
				game.win_by
			),
		}

	var destruction_recorded: bool = (
		_action_caused_destruction(
			action_result
		)
	)

	if destruction_recorded:
		game.set_meta(
			"any_destruction_round",
			int(
				game.round
			)
		)

	# Consume and Gorge evaluate in Resolution Finale, after every primary
	# and Reflex action has had a chance to establish the round state.
	var kroni_events: Array[Dictionary] = []

	var effective_vessel_decision: Dictionary = (
		vessel_decision
	)

	if bool(
		vessel_decision.get(
			"reevaluate_after_action",
			false
		)
	):
		effective_vessel_decision = (
			_post_action_vessel_decision(
				game,
				acting_player,
				rules
			)
		)

		# Python reevaluates Vessel after action aftermath, before the next
		# victory checkpoint.
		if (
			bool(
				effective_vessel_decision.get(
					"offer",
					false
				)
			)
			and int(
				game.winner
			) >= 0
			and String(
				game.win_by
			) == "Ritual"
		):
			game.winner = -1
			game.win_by = ""

		# Revalidate the refreshed doctrine result before resolving it.
		vessel_validation = (
			_validate_vessel_decision(
				game,
				acting_player,
				effective_vessel_decision
			)
		)

		if not bool(
			vessel_validation.get(
				"valid",
				false
			)
		):
			return _invalid_result(
				acting_player_id,
				String(
					vessel_validation.get(
						"reason",
						"invalid_vessel_decision"
					)
				)
			)
	elif post_action_choice:
		# A real post-action Vessel choice can replace a provisional Ritual
		# victory, while Final Collapse and Dominion remain authoritative.
		if (
			bool(vessel_decision.get("offer", false))
			and int(game.winner) >= 0
			and String(game.win_by) == "Ritual"
		):
			game.winner = -1
			game.win_by = ""

		vessel_validation = _validate_vessel_decision(
			game,
			acting_player,
			vessel_decision
		)
		if not bool(vessel_validation.get("valid", false)):
			return _invalid_result(
				acting_player_id,
				String(vessel_validation.get("reason", "invalid_vessel_decision"))
			)

	var vessel_event: Dictionary = (
		_resolve_vessel(
			game,
			acting_player,
			vessel_validation,
			rules,
			random_source
		)
	)

	var won_after_vessel: bool = _check_win(
		game,
		rules
	)

	if won_after_vessel:
		game.refresh_derived_values()

		return {
			"action": "resolution_action_aftermath",
			"reason": "",
			"player_id": acting_player_id,
			"destruction_recorded": destruction_recorded,
			"kroni_events": kroni_events,
			"vessel_event": vessel_event,
			"vulture_draw": "",
			"wright_token_gained": false,
			"momentum_refunded": [],
			"discarded_committed": [],
			"stopped_on_win": true,
			"winner": int(
				game.winner
			),
			"win_by": String(
				game.win_by
			),
		}

	var vulture_draw = null

	if _suit_count(
		acting_player.committed,
		SUIT_VULTURE
	) >= 2:
		vulture_draw = _draw_outside_development(
			game,
			acting_player,
			rules,
			random_source
		)

	var wright_token_gained: bool = false

	if _suit_count(
		acting_player.committed,
		SUIT_WRIGHT
	) >= 2:
		acting_player.repair_token = 1
		wright_token_gained = true

	var momentum_refunded: Array = []
	var refund_count: int = min(
		int(acting_player.momentum_refund_due),
		acting_player.committed.size()
	)

	for _refund_index: int in range(refund_count):
		var highest_index: int = _highest_card_index(acting_player.committed)
		if highest_index < 0:
			break

		var refunded_card = acting_player.committed[highest_index]
		acting_player.committed.remove_at(highest_index)
		if acting_player.hand.size() < rules.hand_limit:
			acting_player.hand.append(refunded_card)
		else:
			game.discard.append(refunded_card)
		momentum_refunded.append(refunded_card)

	acting_player.momentum_refund_due = 0

	var preserve_frontline_ward: bool = (
		rules.ward_frontline
		and String(acting_player.action) == "Ward"
	)
	var discarded_committed: Array = []
	if not preserve_frontline_ward:
		discarded_committed = acting_player.committed.duplicate()
		for card in discarded_committed:
			game.discard.append(card)
		acting_player.committed.clear()

	game.refresh_derived_values()

	var won: bool = _check_win(
		game,
		rules
	)

	return {
		"action": "resolution_action_aftermath",
		"reason": "",
		"player_id": acting_player_id,
		"destruction_recorded": destruction_recorded,
		"kroni_events": kroni_events,
		"vessel_event": vessel_event,
		"vulture_draw": (
			""
			if vulture_draw == null
			else _card_id(
				vulture_draw
			)
		),
		"wright_token_gained": (
			wright_token_gained
		),
		"momentum_refunded": _card_ids(momentum_refunded),
		"discarded_committed": _card_ids(
			discarded_committed
		),
		"stopped_on_win": won,
		"winner": int(
			game.winner
		),
		"win_by": String(
			game.win_by
		),
	}


static func _post_action_vessel_decision(
	game,
	player,
	rules: RuleConfig
) -> Dictionary:
	if (
		player.vessel_used
		or not player.alive
	):
		return {
			"pass": true,
		}

	# A non-Ritual victory is already authoritative. Ritual is provisional
	# here because the golden sequence evaluates Vessel first.
	if (
		int(
			game.winner
		) >= 0
		and String(
			game.win_by
		) != "Ritual"
	):
		return {
			"pass": true,
		}

	var opponent = game.get_opponent(
		int(
			player.pid
		)
	)

	if opponent == null:
		return {
			"pass": true,
		}

	# Vessel gives the opponent one Soul before victory is checked.
	if opponent.souls + 1 >= rules.win_souls:
		return {
			"pass": true,
		}

	var veil_after: int = (
		game.calculate_veil_total()
		+ 1
	)

	if (
		veil_after < rules.dominion_track
		or veil_after
		>= rules.final_collapse_threshold
	):
		return {
			"pass": true,
		}

	var personal_after: int = (
		player.tears + 1
	)

	if personal_after <= opponent.tears:
		return {
			"pass": true,
		}

	var player_summaries: Array = []

	for candidate in game.players:
		player_summaries.append({
			"lord": String(
				candidate.lord
			),
			"alive": (
				false
				if int(
					candidate.pid
				) == int(
					player.pid
				)
				else bool(
					candidate.alive
				)
			),
		})

	var requirement: int = (
		LordMathData.dominion_requirement(
			player_summaries,
			rules
		)
	)

	if personal_after < requirement:
		return {
			"pass": true,
		}

	return {
		"offer": true,
	}


static func _validate_vessel_decision(
	game,
	player,
	decision: Dictionary
) -> Dictionary:
	if _decision_is_pass(
		decision
	):
		return {
			"valid": true,
			"reason": "",
			"offer": false,
		}

	if not bool(
		decision.get(
			"offer",
			false
		)
	):
		return {
			"valid": true,
			"reason": "",
			"offer": false,
		}

	# Vessel choices are generated before committed actions resolve.
	# If that action has already won, the cached offer is stale and must
	# become a harmless pass, matching the golden runtime policy.
	if int(
		game.winner
	) >= 0:
		return {
			"valid": true,
			"reason": "",
			"offer": false,
		}

	if player.vessel_used:
		return {
			"valid": false,
			"reason": "vessel_already_used",
			"offer": false,
		}

	if not player.alive:
		return {
			"valid": false,
			"reason": "vessel_requires_living_lord",
			"offer": false,
		}

	var opponent = game.get_opponent(
		int(
			player.pid
		)
	)

	if opponent == null:
		return {
			"valid": false,
			"reason": "opponent_missing",
			"offer": false,
		}

	return {
		"valid": true,
		"reason": "",
		"offer": true,
	}


static func _resolve_vessel(
	game,
	player,
	validation: Dictionary,
	rules: RuleConfig,
	random_source = null
) -> Dictionary:
	if not bool(
		validation.get(
			"offer",
			false
		)
	):
		return {
			"action": "pass",
			"reason": "pass",
			"player_id": int(
				player.pid
			),
			"opponent_id": -1,
			"offered_lord": "",
			"opponent_soul_gain": 0,
			"discarded_lord_guards": [],
			"gremory_guard_trigger": (
				_empty_gremory_guard_trigger()
			),
			"personal_tear_gain": 0,
			"harvested_card": "",
			"harvested_by": -1,
		}

	var opponent = game.get_opponent(
		int(
			player.pid
		)
	)

	assert(
		opponent != null,
		"Validated Vessel opponent disappeared."
	)

	var discarded_lord_guards: Array = (
		player.lord_guards.duplicate()
	)

	var offered_lord: String = String(
		player.lord
	)

	player.vessel_used = true
	player.vessel_offered_lord = offered_lord

	opponent.souls += 1

	for guard in discarded_lord_guards:
		game.discard.append(
			guard
		)

	player.lord_guards.clear()
	player.alive = false
	player.derived_lord_def = 0

	var gremory_guard_trigger: Dictionary = (
		_empty_gremory_guard_trigger()
	)

	if not discarded_lord_guards.is_empty():
		gremory_guard_trigger = (
			_trigger_gremory_lord_guard(
				game,
				rules,
				random_source
			)
		)

	var tear_event: Dictionary = (
		_gain_personal_tear(
			game,
			player
		)
	)

	return {
		"action": "offer_vessel",
		"reason": "",
		"player_id": int(
			player.pid
		),
		"opponent_id": int(
			opponent.pid
		),
		"offered_lord": offered_lord,
		"opponent_soul_gain": 1,
		"discarded_lord_guards": _card_ids(
			discarded_lord_guards
		),
		"gremory_guard_trigger": (
			gremory_guard_trigger
		),
		"personal_tear_gain": 1,
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
	}


static func _trigger_gremory_lord_guard(
	game,
	rules: RuleConfig,
	random_source = null
) -> Dictionary:
	for player in game.players:
		if (
			player.lord != "Gremory"
			or not player.alive
			or player.gremory_lord_guard_draw_done
		):
			continue

		player.gremory_lord_guard_draw_done = true

		var drawn_card = _draw_outside_development(
			game,
			player,
			rules,
			random_source
		)

		var discarded_card = null

		if not player.hand.is_empty():
			var lowest_index: int = _lowest_card_index(
				player.hand
			)

			discarded_card = player.hand[
				lowest_index
			]

			player.hand.remove_at(
				lowest_index
			)

			game.discard.append(
				discarded_card
			)

		return {
			"triggered": true,
			"player_id": int(
				player.pid
			),
			"drawn_card": (
				""
				if drawn_card == null
				else _card_id(
					drawn_card
				)
			),
			"discarded_card": (
				""
				if discarded_card == null
				else _card_id(
					discarded_card
				)
			),
		}

	return _empty_gremory_guard_trigger()


static func _draw_outside_development(
	game,
	player,
	rules: RuleConfig,
	random_source = null
):
	var draw_result: Dictionary = (
		DrawEngineData.draw_to_hand(
			game,
			player,
			rules,
			random_source,
			true
		)
	)

	if not bool(
		draw_result.get(
			"drawn",
			false
		)
	):
		return null

	return player.hand.back()


static func _action_caused_destruction(
	action_result: Dictionary
) -> bool:
	var raw_guards = action_result.get(
		"guards_defeated",
		[]
	)

	if (
		typeof(
			raw_guards
		) == TYPE_ARRAY
		and not raw_guards.is_empty()
	):
		return true

	if bool(
		action_result.get(
			"banished",
			false
		)
	):
		return true

	if not String(
		action_result.get(
			"siphoned_card",
			""
		)
	).is_empty():
		return true

	var resolved_action: String = String(
		action_result.get(
			"action",
			""
		)
	).to_lower()

	if (
		resolved_action == ACTION_SIEGE
		and bool(
			action_result.get(
				"destroyed",
				false
			)
		)
	):
		return true

	return false


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

		player.gremory_veil_draw_done = true

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
	# Kroni's action can provisionally win before aftermath Soul gains.
	# Re-evaluate so Ritual-first priority can replace that label.
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


static func _suit_count(
	cards: Array,
	suit_name: String
) -> int:
	var count: int = 0

	for card in cards:
		if String(
			card.suit
		) == suit_name:
			count += 1

	return count


static func _highest_card_index(
	cards: Array
) -> int:
	if cards.is_empty():
		return -1

	var selected_index: int = 0
	for index: int in range(1, cards.size()):
		if int(cards[index].value) > int(cards[selected_index].value):
			selected_index = index

	return selected_index


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


static func _empty_gremory_guard_trigger() -> Dictionary:
	return {
		"triggered": false,
		"player_id": -1,
		"drawn_card": "",
		"discarded_card": "",
	}


static func _invalid_result(
	player_id: int,
	reason: String
) -> Dictionary:
	return {
		"action": "invalid",
		"reason": reason,
		"player_id": player_id,
		"destruction_recorded": false,
		"kroni_events": [],
		"vessel_event": {},
		"vulture_draw": "",
		"wright_token_gained": false,
		"momentum_refunded": [],
		"discarded_committed": [],
		"stopped_on_win": false,
		"winner": -1,
		"win_by": "",
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
