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

	# Doctrine-marked Vessel decisions are validated after reevaluation.
	if not bool(
		vessel_decision.get(
			"reevaluate_after_action",
			false
		)
	):
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
	):
		var stale_vessel_event: Dictionary = (
			_resolve_vessel(
				game,
				acting_player,
				vessel_validation
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

	var kroni_events: Array[Dictionary] = []

	var opponent = game.get_opponent(
		acting_player_id
	)

	var consume_order: Array = [
		acting_player,
		opponent,
	]

	for candidate in consume_order:
		if candidate == null:
			continue

		var kroni_event: Dictionary = (
			_try_kroni_consume(
				game,
				candidate
			)
		)

		if bool(
			kroni_event.get(
				"triggered",
				false
			)
		):
			kroni_events.append(
				kroni_event
			)

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

		# Python reevaluates Vessel after action aftermath and Kroni Consume,
		# before the next victory checkpoint.
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

	var vessel_event: Dictionary = (
		_resolve_vessel(
			game,
			acting_player,
			vessel_validation
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

	var discarded_committed: Array = (
		acting_player.committed.duplicate()
	)

	for card in discarded_committed:
		game.discard.append(
			card
		)

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
	validation: Dictionary
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


static func _try_kroni_consume(
	game,
	player
) -> Dictionary:
	if (
		player.lord != "Kroni"
		or not player.alive
		or player.kroni_consume_done
	):
		return _empty_kroni_event(
			player
		)

	if not _destruction_active_this_round(
		game
	):
		return _empty_kroni_event(
			player
		)

	player.kroni_consume_done = true

	var hunger_before: int = int(
		player.kroni_hunger
	)

	var hunger_event: Dictionary = (
		_gain_kroni_hunger(
			game,
			player
		)
	)

	var gorge_soul_gain: int = 0

	if (
		player.kroni_hunger >= 1
		and player.kroni_personally_defeated_guard
	):
		player.souls += 1
		gorge_soul_gain = 1

	return {
		"triggered": true,
		"player_id": int(
			player.pid
		),
		"hunger_before": hunger_before,
		"hunger_after": int(
			player.kroni_hunger
		),
		"personal_tear_gain": int(
			hunger_event.get(
				"personal_tear_gain",
				0
			)
		),
		"harvested_card": String(
			hunger_event.get(
				"harvested_card",
				""
			)
		),
		"harvested_by": int(
			hunger_event.get(
				"harvested_by",
				-1
			)
		),
		"gorge_soul_gain": gorge_soul_gain,
	}


static func _gain_kroni_hunger(
	game,
	player
) -> Dictionary:
	var was_two: bool = (
		player.kroni_hunger == 2
	)

	player.kroni_hunger += 1

	if (
		was_two
		and not player.kroni_tear_milestone_fired
	):
		player.kroni_tear_milestone_fired = true

		var tear_event: Dictionary = (
			_gain_personal_tear(
				game,
				player
			)
		)

		return {
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

	return {
		"personal_tear_gain": 0,
		"harvested_card": "",
		"harvested_by": -1,
	}


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


static func _destruction_active_this_round(
	game
) -> bool:
	return int(
		game.get_meta(
			"any_destruction_round",
			-1
		)
	) == int(
		game.round
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


static func _empty_kroni_event(
	player
) -> Dictionary:
	return {
		"triggered": false,
		"player_id": (
			-1
			if player == null
			else int(
				player.pid
			)
		),
		"hunger_before": (
			0
			if player == null
			else int(
				player.kroni_hunger
			)
		),
		"hunger_after": (
			0
			if player == null
			else int(
				player.kroni_hunger
			)
		),
		"personal_tear_gain": 0,
		"harvested_card": "",
		"harvested_by": -1,
		"gorge_soul_gain": 0,
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
