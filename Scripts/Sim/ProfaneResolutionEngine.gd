class_name ProfaneResolutionEngine
extends RefCounted


const ACTION_PROFANE: String = "Profane"
const ZONE_CASTLE: String = "Castle"

const SIGIL_FRESH: String = "fresh"

const CastleIntegrityRulesData = preload(
	"res://Scripts/Sim/CastleIntegrityRules.gd"
)


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

	# PLAYABLE_PROFANE_RETARGET_AND_NO_REFLEX_RESERVE_V1
	var requested_castle: String = target_castle
	var target_reevaluated: bool = false

	# A bot Profane target can become illegal after Commitment if an earlier
	# Siege damages/removes that Castle. Re-evaluate at the exact action boundary.
	if (
		bool(
			options.get(
				"reevaluate_target",
				false
			)
		)
		and not _profane_castle_eligible(
			player,
			target_castle,
			rules
		)
	):
		target_castle = _fallback_profanable_castle(
			player,
			rules
		)
		target_reevaluated = (
			target_castle
			!= requested_castle
		)

		if target_castle.is_empty():
			player.pending_profane = ""
			return {
				"action": "profane",
				"reason": "no_eligible_castle_after_reevaluation",
				"player_id": player_id,
				"opponent_id": int(
					opponent.pid
				),
				"target_castle": "",
				"requested_castle": requested_castle,
				"target_reevaluated": true,
				"blocked": false,
				"blocking_zone": "",
				"profaned": false,
				"tear_pending": false,
				"tear_gain": 0,
				"veil_after": int(
					game.calculate_veil_total()
				),
			}

	var blocking_zone: String = _fresh_sigil_zone(
		opponent
	)

	# FIX B removes Fresh-Sigil Profane denial.  The sigil still exists as a
	# defensive combat layer; it simply no longer vetoes a different action.
	if not rules.fix_b and not blocking_zone.is_empty():
		player.pending_profane = ""

		return {
			"action": "profane",
			"reason": "blocked_by_fresh_sigil",
			"player_id": player_id,
			"opponent_id": int(
				opponent.pid
			),
			"target_castle": target_castle,
			"requested_castle": requested_castle,
			"target_reevaluated": target_reevaluated,
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

	if rules.profane_requires_full_integrity and rules.castle_integrity:
		var maximum: int = CastleIntegrityRulesData.max_integrity(target_castle)
		var integrity: int = int(player.castle_integrity.get(target_castle, maximum))
		if integrity < maximum:
			return _invalid_result(
				player_id,
				"profane_requires_full_integrity",
				target_castle
			)

	player.castles.erase(
		target_castle
	)

	if rules.castle_integrity:
		player.castle_integrity[target_castle] = 0
		player.castle_construction_progress.erase(target_castle)

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
		"requested_castle": requested_castle,
		"target_reevaluated": target_reevaluated,
		"blocked": false,
		"blocking_zone": "",
		"profaned": true,
		"tear_pending": true,
		"tear_gain": 0,
		"veil_after": int(
			game.calculate_veil_total()
		),
	}


static func _profane_castle_eligible(
	player,
	castle_name: String,
	rules: RuleConfig
) -> bool:
	if (
		castle_name.is_empty()
		or not player.castles.has(
			castle_name
		)
	):
		return false

	if (
		rules.profane_requires_full_integrity
		and rules.castle_integrity
	):
		var maximum: int = (
			CastleIntegrityRulesData.max_integrity(
				castle_name
			)
		)
		return int(
			player.castle_integrity.get(
				castle_name,
				maximum
			)
		) >= maximum

	return true


static func _fallback_profanable_castle(
	player,
	rules: RuleConfig
) -> String:
	var priority: Array[String] = (
		CastleIntegrityRulesData.priority_for(
			String(
				player.lord
			)
		)
	)

	# Profane sacrifices the lowest-priority Castle first.
	for index: int in range(
		priority.size() - 1,
		-1,
		-1
	):
		var castle_name: String = priority[index]
		if _profane_castle_eligible(
			player,
			castle_name,
			rules
		):
			return castle_name

	for raw_castle_name in player.castles:
		var castle_name: String = String(
			raw_castle_name
		)
		if _profane_castle_eligible(
			player,
			castle_name,
			rules
		):
			return castle_name

	return ""


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
