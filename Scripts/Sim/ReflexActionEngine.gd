class_name ReflexActionEngine
extends RefCounted


const HuntResolutionEngineData = preload(
	"res://Scripts/Sim/HuntResolutionEngine.gd"
)

const SiegeResolutionEngineData = preload(
	"res://Scripts/Sim/SiegeResolutionEngine.gd"
)


const ACTION_PASS: String = "Pass"
const ACTION_HUNT: String = "Hunt"
const ACTION_SIEGE: String = "Siege"
const ACTION_WARD: String = "Ward"

const ZONE_LORD: String = "Lord"
const ZONE_CASTLE: String = "Castle"

const SIGIL_FRESH: String = "fresh"


static func resolve(
	game,
	rules: RuleConfig,
	winner_decision: Dictionary,
	breach_decision: Dictionary = {}
) -> Dictionary:
	assert(
		game != null,
		"Reflex Action requires a GameState."
	)

	assert(
		rules != null,
		"Reflex Action requires RuleConfig."
	)

	assert(
		game.players.size() == 2,
		"Reflex Action currently requires two players."
	)

	if int(
		game.winner
	) >= 0:
		return _pass_result(
			int(
				game.reflex_winner
			),
			"game_already_won"
		)

	if int(
		game.get_meta(
			"reflex_action_resolved_round",
			-1
		)
	) == int(
		game.round
	):
		return _invalid_result(
			int(
				game.reflex_winner
			),
			-1,
			"reflex_action_already_resolved"
		)

	var winner_id: int = int(
		game.reflex_winner
	)

	var winner = game.get_player(
		winner_id
	)

	if winner == null:
		return _pass_result(
			winner_id,
			"no_reflex_winner"
		)

	var winner_validation: Dictionary = (
		_validate_decision(
			game,
			rules,
			winner,
			winner_decision
		)
	)

	if not bool(
		winner_validation.get(
			"valid",
			false
		)
	):
		return _invalid_result(
			winner_id,
			winner_id,
			String(
				winner_validation.get(
					"reason",
					"invalid_reflex_action"
				)
			)
		)

	var requested_action: String = String(
		winner_validation.get(
			"action",
			ACTION_PASS
		)
	)

	var winner_selected_cards: Array = (
		winner_validation.get(
			"cards",
			[]
		)
	)

	var winner_selected_card_ids: Array[String] = (
		_card_ids(
			winner_selected_cards
		)
	)

	if requested_action == ACTION_PASS:
		_mark_resolved(
			game
		)

		return {
			"action": "reflex_action",
			"reason": "pass",
			"winner_id": winner_id,
			"requested_action": ACTION_PASS,
			"executed_by": winner_id,
			"executed_action": ACTION_PASS,
			"stolen": false,
			"breach_guess": "",
			"winner_selected_cards": [],
			"winner_discarded_cards": [],
			"executed_cards": [],
			"discarded_after_action": [],
			"action_result": {
				"action": "pass",
				"reason": "pass",
			},
			"won": false,
		}

	var breach_guess: String = ""
	var stolen: bool = false

	var execution_player = winner
	var execution_validation: Dictionary = (
		winner_validation
	)

	var winner_discarded_cards: Array = []

	if game.breach == "Odradek":
		var breach_owner_id: int = int(
			game.breach_owner
		)

		var breach_owner = game.get_player(
			breach_owner_id
		)

		if (
			breach_owner != null
			and breach_owner_id != winner_id
			and not breach_owner.hand.is_empty()
		):
			breach_guess = _canonical_action(
				String(
					breach_decision.get(
						"guess",
						""
					)
				)
			)

			if breach_guess == requested_action:
				var stolen_decision: Dictionary = (
					_nested_stolen_decision(
						breach_decision
					)
				)

				var stolen_validation: Dictionary = (
					_validate_decision(
						game,
						rules,
						breach_owner,
						stolen_decision
					)
				)

				if not bool(
					stolen_validation.get(
						"valid",
						false
					)
				):
					return _invalid_result(
						winner_id,
						breach_owner_id,
						String(
							stolen_validation.get(
								"reason",
								"invalid_stolen_action"
							)
						)
					)

				stolen = true
				execution_player = breach_owner
				execution_validation = (
					stolen_validation
				)

	if stolen:
		winner_discarded_cards = (
			_remove_and_discard(
				game,
				winner,
				winner_selected_cards
			)
		)

	var execution: Dictionary = _execute_validated(
		game,
		rules,
		execution_player,
		execution_validation
	)

	_mark_resolved(
		game
	)

	return {
		"action": "reflex_action",
		"reason": "",
		"winner_id": winner_id,
		"requested_action": requested_action,
		"executed_by": int(
			execution_player.pid
		),
		"executed_action": String(
			execution_validation.get(
				"action",
				ACTION_PASS
			)
		),
		"stolen": stolen,
		"breach_guess": breach_guess,
		"winner_selected_cards": (
			winner_selected_card_ids
		),
		"winner_discarded_cards": _card_ids(
			winner_discarded_cards
		),
		"executed_cards": execution.get(
			"selected_cards",
			[]
		),
		"discarded_after_action": execution.get(
			"discarded_cards",
			[]
		),
		"action_result": execution.get(
			"action_result",
			{}
		),
		"won": int(
			game.winner
		) >= 0,
	}


static func _validate_decision(
	game,
	rules: RuleConfig,
	actor,
	decision: Dictionary
) -> Dictionary:
	if not actor.committed.is_empty():
		return _invalid_validation(
			"actor_committed_not_empty"
		)

	var action: String = _decision_action(
		decision
	)

	if action.is_empty():
		return _invalid_validation(
			"reflex_action_invalid"
		)

	var raw_cards = decision.get(
		"cards",
		[]
	)

	if typeof(
		raw_cards
	) != TYPE_ARRAY:
		return _invalid_validation(
			"cards_must_be_array"
		)

	var card_ids: Array = raw_cards

	var selection: Dictionary = _select_hand_cards(
		actor,
		card_ids
	)

	if not bool(
		selection.get(
			"valid",
			false
		)
	):
		return selection

	var selected_cards: Array = selection.get(
		"cards",
		[]
	)

	if (
		action == ACTION_PASS
		and not selected_cards.is_empty()
	):
		return _invalid_validation(
			"pass_cannot_commit_cards"
		)

	if (
		action == ACTION_WARD
		and not selected_cards.is_empty()
	):
		return _invalid_validation(
			"ward_cannot_commit_cards"
		)

	var opponent = game.get_opponent(
		int(
			actor.pid
		)
	)

	if action == ACTION_HUNT:
		if opponent == null:
			return _invalid_validation(
				"opponent_missing"
			)

		if not opponent.alive:
			return _invalid_validation(
				"hunt_target_banished"
			)

		if actor.threat >= rules.max_threat:
			return _invalid_validation(
				"hunt_threat_cost_unpayable"
			)

		return {
			"valid": true,
			"reason": "",
			"action": action,
			"cards": selected_cards,
			"consume_hunt": bool(
				decision.get(
					"consume_hunt",
					false
				)
			),
		}

	if action == ACTION_SIEGE:
		if opponent == null:
			return _invalid_validation(
				"opponent_missing"
			)

		var target_castle: String = String(
			decision.get(
				"target_castle",
				""
			)
		)

		if target_castle.is_empty():
			return _invalid_validation(
				"target_castle_required"
			)

		if not opponent.castles.has(
			target_castle
		):
			return _invalid_validation(
				"target_castle_not_active"
			)

		return {
			"valid": true,
			"reason": "",
			"action": action,
			"cards": selected_cards,
			"target_castle": target_castle,
			"consume_siege": bool(
				decision.get(
					"consume_siege",
					false
				)
			),
			"use_inferno": bool(
				decision.get(
					"use_inferno",
					true
				)
			),
		}

	if action == ACTION_WARD:
		var ward_target: String = String(
			decision.get(
				"ward_target",
				""
			)
		)

		if not [
			ZONE_LORD,
			ZONE_CASTLE,
		].has(
			ward_target
		):
			return _invalid_validation(
				"ward_target_invalid"
			)

		if (
			ward_target == ZONE_LORD
			and not actor.alive
		):
			return _invalid_validation(
				"banished_player_cannot_ward_lord"
			)

		if (
			ward_target == ZONE_CASTLE
			and actor.castles.is_empty()
		):
			return _invalid_validation(
				"no_castle_to_ward"
			)

		if not String(
			actor.sigils.get(
				ward_target,
				""
			)
		).is_empty():
			return _invalid_validation(
				"ward_zone_already_has_sigil"
			)

		return {
			"valid": true,
			"reason": "",
			"action": action,
			"cards": selected_cards,
			"ward_target": ward_target,
		}

	return {
		"valid": true,
		"reason": "",
		"action": ACTION_PASS,
		"cards": [],
	}


static func _execute_validated(
	game,
	rules: RuleConfig,
	actor,
	validation: Dictionary
) -> Dictionary:
	var action: String = String(
		validation.get(
			"action",
			ACTION_PASS
		)
	)

	var selected_cards: Array = validation.get(
		"cards",
		[]
	)

	var selected_card_ids: Array[String] = _card_ids(
		selected_cards
	)

	for card in selected_cards:
		assert(
			actor.hand.has(
				card
			),
			"Validated Reflex card left the actor's hand."
		)

		actor.hand.erase(
			card
		)

	actor.committed = selected_cards.duplicate()

	var original_action: String = String(
		actor.action
	)

	var original_target_player: int = int(
		actor.tgt_pid
	)

	var original_target_type: String = String(
		actor.tgt_type
	)

	var original_ward_target: String = String(
		actor.ward_target
	)

	var opponent = game.get_opponent(
		int(
			actor.pid
		)
	)

	var action_result: Dictionary = {}

	if action == ACTION_HUNT:
		actor.action = ACTION_HUNT
		actor.tgt_pid = int(
			opponent.pid
		)
		actor.tgt_type = ZONE_LORD
		actor.ward_target = ""

		actor.threat = min(
			rules.max_threat,
			int(
				actor.threat
			) + 1
		)

		action_result = HuntResolutionEngineData.resolve(
			game,
			rules,
			int(
				actor.pid
			),
			{
				"consume_hunt": bool(
					validation.get(
						"consume_hunt",
						false
					)
				),
			}
		)
	elif action == ACTION_SIEGE:
		actor.action = ACTION_SIEGE
		actor.tgt_pid = int(
			opponent.pid
		)
		actor.tgt_type = ZONE_CASTLE
		actor.ward_target = ""

		action_result = SiegeResolutionEngineData.resolve(
			game,
			rules,
			int(
				actor.pid
			),
			{
				"target_castle": String(
					validation.get(
						"target_castle",
						""
					)
				),
				"reflex": true,
				"consume_siege": bool(
					validation.get(
						"consume_siege",
						false
					)
				),
				"use_inferno": bool(
					validation.get(
						"use_inferno",
						true
					)
				),
			}
		)
	elif action == ACTION_WARD:
		actor.action = ACTION_WARD
		actor.tgt_pid = int(
			actor.pid
		)
		actor.tgt_type = String(
			validation.get(
				"ward_target",
				""
			)
		)
		actor.ward_target = actor.tgt_type

		var threat_before: int = int(
			actor.threat
		)

		actor.sigils[
			actor.ward_target
		] = SIGIL_FRESH

		if actor.ward_target == ZONE_LORD:
			actor.threat = max(
				0,
				int(
					actor.threat
				) - 1
			)

		action_result = {
			"action": "ward",
			"reason": "",
			"player_id": int(
				actor.pid
			),
			"ward_target": String(
				actor.ward_target
			),
			"sigil_state": SIGIL_FRESH,
			"threat_before": threat_before,
			"threat_after": int(
				actor.threat
			),
			"won": false,
		}
	else:
		action_result = {
			"action": "pass",
			"reason": "pass",
			"won": false,
		}

	assert(
		String(
			action_result.get(
				"action",
				""
			)
		) != "invalid",
		"Validated Reflex action became invalid during execution."
	)

	var remaining_cards: Array = (
		actor.committed.duplicate()
	)

	for card in remaining_cards:
		game.discard.append(
			card
		)

	actor.committed.clear()

	actor.action = original_action
	actor.tgt_pid = original_target_player
	actor.tgt_type = original_target_type
	actor.ward_target = original_ward_target

	game.refresh_derived_values()

	return {
		"selected_cards": selected_card_ids,
		"discarded_cards": _card_ids(
			remaining_cards
		),
		"action_result": action_result,
	}


static func _remove_and_discard(
	game,
	player,
	cards: Array
) -> Array:
	var discarded_cards: Array = []

	for card in cards:
		assert(
			player.hand.has(
				card
			),
			"Validated stolen Reflex card left the winner's hand."
		)

		player.hand.erase(
			card
		)

		game.discard.append(
			card
		)

		discarded_cards.append(
			card
		)

	return discarded_cards


static func _select_hand_cards(
	player,
	card_ids: Array
) -> Dictionary:
	var selected_cards: Array = []

	for raw_card_id in card_ids:
		var card_identifier: String = String(
			raw_card_id
		)

		var selected_card = _find_unselected_card(
			player.hand,
			card_identifier,
			selected_cards
		)

		if selected_card == null:
			return _invalid_validation(
				"reflex_card_missing_%s"
				% card_identifier
			)

		selected_cards.append(
			selected_card
		)

	return {
		"valid": true,
		"reason": "",
		"cards": selected_cards,
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


static func _decision_action(
	decision: Dictionary
) -> String:
	if (
		decision.is_empty()
		or bool(
			decision.get(
				"pass",
				false
			)
		)
	):
		return ACTION_PASS

	return _canonical_action(
		String(
			decision.get(
				"action",
				""
			)
		)
	)


static func _canonical_action(
	raw_action: String
) -> String:
	var normalized: String = (
		raw_action.strip_edges().to_lower()
	)

	if normalized == "pass":
		return ACTION_PASS

	if normalized == "hunt":
		return ACTION_HUNT

	if normalized == "siege":
		return ACTION_SIEGE

	if normalized == "ward":
		return ACTION_WARD

	return ""


static func _nested_stolen_decision(
	breach_decision: Dictionary
) -> Dictionary:
	var raw_decision = breach_decision.get(
		"stolen_action",
		{}
	)

	if typeof(
		raw_decision
	) != TYPE_DICTIONARY:
		return {
			"pass": true,
		}

	return raw_decision


static func _mark_resolved(
	game
) -> void:
	game.set_meta(
		"reflex_action_resolved_round",
		int(
			game.round
		)
	)


static func _invalid_validation(
	reason: String
) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"action": "",
		"cards": [],
	}


static func _pass_result(
	winner_id: int,
	reason: String
) -> Dictionary:
	return {
		"action": "pass",
		"reason": reason,
		"winner_id": winner_id,
		"requested_action": ACTION_PASS,
		"executed_by": -1,
		"executed_action": ACTION_PASS,
		"stolen": false,
		"breach_guess": "",
		"winner_selected_cards": [],
		"winner_discarded_cards": [],
		"executed_cards": [],
		"discarded_after_action": [],
		"action_result": {},
		"won": false,
	}


static func _invalid_result(
	winner_id: int,
	invalid_actor_id: int,
	reason: String
) -> Dictionary:
	return {
		"action": "invalid",
		"reason": reason,
		"winner_id": winner_id,
		"invalid_actor_id": invalid_actor_id,
		"requested_action": "",
		"executed_by": -1,
		"executed_action": "",
		"stolen": false,
		"breach_guess": "",
		"winner_selected_cards": [],
		"winner_discarded_cards": [],
		"executed_cards": [],
		"discarded_after_action": [],
		"action_result": {},
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
