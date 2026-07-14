class_name ProfaneResolutionEngine
extends RefCounted


const ACTION_PROFANE: String = "Profane"
const ZONE_CASTLE: String = "Castle"

const SIGIL_FRESH: String = "fresh"


static func resolve(
	game,
	rules: RuleConfig,
	player_id: int,
	options: Dictionary = {}
) -> Dictionary:
	assert(
		game != null,
		"Profane Resolution requires a GameState."
	)

	assert(
		rules != null,
		"Profane Resolution requires RuleConfig."
	)

	var player = game.get_player(
		player_id
	)

	if player == null:
		return _invalid_result(
			player_id,
			"player_missing"
		)

	if player.action != ACTION_PROFANE:
		return _invalid_result(
			player_id,
			"player_not_profaning"
		)

	if int(
		player.tgt_pid
	) != player_id:
		return _invalid_result(
			player_id,
			"profane_must_target_self"
		)

	if String(
		player.tgt_type
	) != ZONE_CASTLE:
		return _invalid_result(
			player_id,
			"profane_target_type_invalid"
		)

	var opponent = game.get_opponent(
		player_id
	)

	if opponent == null:
		return _invalid_result(
			player_id,
			"opponent_missing"
		)

	var target_castle: String = String(
		options.get(
			"target_castle",
			player.pending_profane
		)
	)

	var blocking_zone: String = _fresh_sigil_zone(
		opponent
	)

	if not blocking_zone.is_empty():
		player.pending_profane = ""

		return {
			"action": "profane",
			"reason": "blocked_by_fresh_sigil",
			"player_id": player_id,
			"opponent_id": int(
				opponent.pid
			),
			"target_castle": target_castle,
			"blocked": true,
			"blocking_zone": blocking_zone,
			"profaned": false,
			"tear_pending": false,
			"tear_gain": 0,
			"veil_after": int(
				game.calculate_veil_total()
			),
		}

	if target_castle.is_empty():
		return _invalid_result(
			player_id,
			"target_castle_required"
		)

	if not player.castles.has(
		target_castle
	):
		return _invalid_result(
			player_id,
			"target_castle_not_active",
			target_castle
		)

	player.castles.erase(
		target_castle
	)

	if not player.profaned_castles.has(
		target_castle
	):
		player.profaned_castles.append(
			target_castle
		)

	player.pending_profane = target_castle
	player.profane_this_round = true

	game.refresh_derived_values()

	return {
		"action": "profane",
		"reason": "",
		"player_id": player_id,
		"opponent_id": int(
			opponent.pid
		),
		"target_castle": target_castle,
		"blocked": false,
		"blocking_zone": "",
		"profaned": true,
		"tear_pending": true,
		"tear_gain": 0,
		"veil_after": int(
			game.calculate_veil_total()
		),
	}


static func _fresh_sigil_zone(
	player
) -> String:
	if String(
		player.sigils.get(
			"Lord",
			""
		)
	) == SIGIL_FRESH:
		return "Lord"

	if String(
		player.sigils.get(
			"Castle",
			""
		)
	) == SIGIL_FRESH:
		return "Castle"

	return ""


static func _invalid_result(
	player_id: int,
	reason: String,
	target_castle: String = ""
) -> Dictionary:
	return {
		"action": "invalid",
		"reason": reason,
		"player_id": player_id,
		"opponent_id": -1,
		"target_castle": target_castle,
		"blocked": false,
		"blocking_zone": "",
		"profaned": false,
		"tear_pending": false,
		"tear_gain": 0,
		"veil_after": 0,
	}
