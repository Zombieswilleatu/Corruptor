class_name DeployEngine
extends RefCounted


const FRENZY_THRESHOLD: int = 6
const BASE_CASTLE_GUARD_LIMIT: int = 3
const BASE_LORD_GUARD_LIMIT: int = 3


static func resolve(
	game,
	rules: RuleConfig,
	deploy_choices: Dictionary
) -> Array[Dictionary]:
	assert(
		game != null,
		"Deploy resolution requires a GameState."
	)

	assert(
		rules != null,
		"Deploy resolution requires RuleConfig."
	)

	var results: Array[Dictionary] = []

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		var decision: Dictionary = _decision_for_player(
			deploy_choices,
			player_id
		)

		results.append(
			_resolve_player_deploy(
				game,
				player,
				rules,
				decision
			)
		)

	return results


static func _resolve_player_deploy(
	game,
	player,
	rules: RuleConfig,
	decision: Dictionary
) -> Dictionary:
	var player_id: int = int(
		player.pid
	)

	var frenzy_blocked: bool = _frenzy_blocks_garrison(
		game,
		player
	)

	var snare_active: bool = bool(
		player.orias_snare_active
	)

	if _decision_is_pass(
		decision
	):
		return {
			"player_id": player_id,
			"action": "pass",
			"reason": "pass",
			"moves": [],
			"moved_count": 0,
			"invalid_count": 0,
			"frenzy_blocked": frenzy_blocked,
			"snare_active": snare_active,
		}

	var raw_moves = decision.get(
		"moves",
		[]
	)

	if typeof(raw_moves) != TYPE_ARRAY:
		return {
			"player_id": player_id,
			"action": "invalid",
			"reason": "moves_must_be_array",
			"moves": [],
			"moved_count": 0,
			"invalid_count": 1,
			"frenzy_blocked": frenzy_blocked,
			"snare_active": snare_active,
		}

	var requested_moves: Array = raw_moves
	var move_results: Array[Dictionary] = []

	var successful_moves: int = 0
	var garrison_moves: int = 0
	var invalid_moves: int = 0

	for raw_move in requested_moves:
		if typeof(raw_move) != TYPE_DICTIONARY:
			move_results.append(
				_invalid_move(
					"",
					"",
					"",
					"move_must_be_dictionary"
				)
			)

			invalid_moves += 1
			continue

		var move: Dictionary = raw_move

		var move_result: Dictionary = _resolve_move(
			game,
			player,
			rules,
			move,
			successful_moves,
			garrison_moves,
			frenzy_blocked,
			snare_active
		)

		move_results.append(
			move_result
		)

		if String(
			move_result.get(
				"action",
				""
			)
		) == "move":
			successful_moves += 1

			if String(
				move_result.get(
					"source",
					""
				)
			) == "Garrison":
				garrison_moves += 1
		else:
			invalid_moves += 1

	var action_name: String = "deploy"
	var reason: String = ""

	if requested_moves.is_empty():
		action_name = "pass"
		reason = "no_moves"

	return {
		"player_id": player_id,
		"action": action_name,
		"reason": reason,
		"moves": move_results,
		"moved_count": successful_moves,
		"invalid_count": invalid_moves,
		"frenzy_blocked": frenzy_blocked,
		"snare_active": snare_active,
	}


static func _resolve_move(
	_game,
	player,
	rules: RuleConfig,
	move: Dictionary,
	successful_moves: int,
	garrison_moves: int,
	frenzy_blocked: bool,
	snare_active: bool
) -> Dictionary:
	var source_text: String = String(
		move.get(
			"source",
			""
		)
	)

	var target_text: String = String(
		move.get(
			"target",
			""
		)
	)

	var card_identifier: String = String(
		move.get(
			"card",
			""
		)
	)

	var source_index: int = int(
		move.get(
			"source_index",
			-1
		)
	)

	var source_key: String = (
		source_text
		.strip_edges()
		.to_lower()
	)

	var target_key: String = (
		target_text
		.strip_edges()
		.to_lower()
	)

	if (
		source_key != "hand"
		and source_key != "garrison"
	):
		return _invalid_move(
			source_text,
			target_text,
			card_identifier,
			"unknown_source"
		)

	if (
		target_key != "castle"
		and target_key != "lord"
	):
		return _invalid_move(
			source_text,
			target_text,
			card_identifier,
			"unknown_target"
		)

	if card_identifier.is_empty():
		return _invalid_move(
			_display_source(
				source_key
			),
			_display_target(
				target_key
			),
			card_identifier,
			"card_required"
		)

	if (
		snare_active
		and successful_moves >= 1
	):
		return _invalid_move(
			_display_source(
				source_key
			),
			_display_target(
				target_key
			),
			card_identifier,
			"orias_snare_limit"
		)

	if (
		source_key == "hand"
		and player.repaired_this_round
		and not player.repair_token_used_this_repair
	):
		return _invalid_move(
			"Hand",
			_display_target(
				target_key
			),
			card_identifier,
			"hand_deploy_blocked_by_repair"
		)

	if (
		source_key == "garrison"
		and frenzy_blocked
	):
		return _invalid_move(
			"Garrison",
			_display_target(
				target_key
			),
			card_identifier,
			"garrison_deploy_blocked_by_frenzy"
		)

	if (
		source_key == "garrison"
		and garrison_moves >= rules.garrison_max
	):
		return _invalid_move(
			"Garrison",
			_display_target(
				target_key
			),
			card_identifier,
			"garrison_move_limit"
		)

	var target_zone: Array = []

	if target_key == "castle":
		target_zone = player.castle_guards
	else:
		target_zone = player.lord_guards

	var target_limit: int = _target_limit(
		player,
		rules,
		target_key
	)

	if target_zone.size() >= target_limit:
		return _invalid_move(
			_display_source(
				source_key
			),
			_display_target(
				target_key
			),
			card_identifier,
			"target_full"
		)

	var source_zone: Array = []

	if source_key == "hand":
		source_zone = player.hand
	else:
		source_zone = player.garrison

	var selected_card = null

	if source_index >= 0:
		if source_index >= source_zone.size():
			return _invalid_move(
				_display_source(
					source_key
				),
				_display_target(
					target_key
				),
				card_identifier,
				"source_index_out_of_range"
			)

		selected_card = source_zone[
			source_index
		]

		if _card_id(
			selected_card
		) != card_identifier:
			return _invalid_move(
				_display_source(
					source_key
				),
				_display_target(
					target_key
				),
				card_identifier,
				"source_index_card_mismatch"
			)
	else:
		selected_card = _find_card(
			source_zone,
			card_identifier
		)

		if selected_card == null:
			return _invalid_move(
				_display_source(
					source_key
				),
				_display_target(
					target_key
				),
				card_identifier,
				"source_card_missing"
			)

	if source_index >= 0:
		source_zone.remove_at(
			source_index
		)
	else:
		source_zone.erase(
			selected_card
		)

	target_zone.append(
		selected_card
	)

	return {
		"action": "move",
		"reason": "",
		"source": _display_source(
			source_key
		),
		"target": _display_target(
			target_key
		),
		"card": _card_id(
			selected_card
		),
	}


static func _target_limit(
	player,
	rules: RuleConfig,
	target_key: String
) -> int:
	if target_key == "lord":
		return BASE_LORD_GUARD_LIMIT

	if (
		player.lord == "Humbaba"
		and rules.humbaba_gate4
		and player.ruined_castles.is_empty()
	):
		return 4

	return BASE_CASTLE_GUARD_LIMIT


static func _frenzy_blocks_garrison(
	game,
	player
) -> bool:
	var frenzy_active: bool = (
		game.breach == "Orias"
		or (
			int(
				game.calculate_veil_total()
			) >= FRENZY_THRESHOLD
			and int(
				player.tears
			) < FRENZY_THRESHOLD
		)
	)

	return (
		frenzy_active
		and int(
			player.threat
		) >= 3
	)


static func _find_card(
	cards: Array,
	card_identifier: String
):
	for card in cards:
		if _card_id(
			card
		) == card_identifier:
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


static func _invalid_move(
	source_name: String,
	target_name: String,
	card_identifier: String,
	reason: String
) -> Dictionary:
	return {
		"action": "invalid",
		"reason": reason,
		"source": source_name,
		"target": target_name,
		"card": card_identifier,
	}


static func _display_source(
	source_key: String
) -> String:
	if source_key == "garrison":
		return "Garrison"

	return "Hand"


static func _display_target(
	target_key: String
) -> String:
	if target_key == "lord":
		return "Lord"

	return "Castle"


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
