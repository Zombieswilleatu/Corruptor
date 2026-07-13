class_name GoldenSnapshotSerializer
extends RefCounted


static func snapshot_game(game_state, checkpoint: String) -> Dictionary:
	var player_snapshots: Array = []

	for player in game_state.players:
		player_snapshots.append(snapshot_player(player))

	return {
		"checkpoint": checkpoint,
		"round": int(game_state.round),
		"first_player": int(game_state.first_player),
		"breach": _nullable_string(game_state.breach),
		"breach_owner": int(game_state.breach_owner),
		"reflex_winner": _nullable_player_id(game_state.reflex_winner),
		"neutral_tears": int(game_state.neutral_tears),
		"veil_total": int(game_state.calculate_veil_total()),
		"winner": _nullable_player_id(game_state.winner),
		"win_by": str(game_state.win_by),
		"deck": card_list(game_state.deck),
		"discard": card_list(game_state.discard),
		"market": card_list(game_state.market),
		"players": player_snapshots,
	}


static func snapshot_player(player) -> Dictionary:
	return {
		"pid": int(player.pid),
		"lord": str(player.lord),
		"alive": bool(player.alive),

		"souls": int(player.souls),
		"tears": int(player.tears),
		"threat": int(player.threat),
		"kroni_hunger": int(player.kroni_hunger),
		"repair_token": int(player.repair_token),

		"first_summon_done": bool(player.first_summon_done),
		"cataclysmic_used": bool(player.cataclysmic_used),
		"vessel_used": bool(player.vessel_used),
		"vessel_offered_lord": str(player.vessel_offered_lord),
		"kalligan_repair_used": bool(player.kalligan_repair_used),
		"kroni_ravenous_used": bool(player.kroni_ravenous_used),
		"deimos_breach_claimed": bool(player.deimos_breach_claimed),

		"action": str(player.action),
		"tgt_pid": int(player.tgt_pid),
		"tgt_type": str(player.tgt_type),
		"ward_target": str(player.ward_target),
		"prev_ward_target": str(player.prev_ward_target),

		"was_hunted": bool(player.was_hunted),
		"was_sieged": bool(player.was_sieged),
		"was_lord_attacked_prev": bool(player.was_lord_attacked_prev),
		"was_castle_attacked_prev": bool(
			player.was_castle_attacked_prev
		),
		"last_sieged_castle": str(player.last_sieged_castle),

		"pending_profane": str(player.pending_profane),
		"orias_snare_active": bool(player.orias_snare_active),
		"profane_ruins_used_this_round": bool(
			player.profane_ruins_used_this_round
		),
		"profane_this_round": bool(player.profane_this_round),

		"humbaba_patient": bool(player.humbaba_patient),

		"odradek_recoil_done": bool(player.odradek_recoil_done),
		"odradek_guards_defeated": int(
			player.odradek_guards_defeated
		),

		"gremory_ruin_done": bool(player.gremory_ruin_done),
		"gremory_inevitable_ruin_done": bool(
			player.gremory_inevitable_ruin_done
		),
		"gremory_veil_draw_done": bool(
			player.gremory_veil_draw_done
		),
		"gremory_lord_guard_draw_done": bool(
			player.gremory_lord_guard_draw_done
		),

		"kanifous_outside_draws": int(
			player.kanifous_outside_draws
		),
		"kanifous_invoked_suit": str(
			player.kanifous_invoked_suit
		),
		"kanifous_invoked_high": bool(
			player.kanifous_invoked_high
		),
		"kanifous_invokes_this_round": int(
			player.kanifous_invokes_this_round
		),

		"kroni_consume_done": bool(player.kroni_consume_done),
		"kroni_personally_defeated_guard": bool(
			player.kroni_personally_defeated_guard
		),
		"kroni_enemy_destroyed": bool(
			player.kroni_enemy_destroyed
		),
		"kroni_tear_milestone_fired": bool(
			player.kroni_tear_milestone_fired
		),

		"hand": card_multiset(player.hand),
		"garrison": card_multiset(player.garrison),
		"castle_guards": card_multiset(player.castle_guards),
		"lord_guards": card_multiset(player.lord_guards),
		"committed": card_multiset(player.committed),
		"penitent_temp_guards": card_multiset(
			player.penitent_temp_guards
		),

		"castles": sorted_strings(player.castles),
		"ruined_castles": sorted_strings(
			player.ruined_castles
		),
		"profaned_castles": sorted_strings(
			player.profaned_castles
		),

		"lord_pool": string_list(player.lord_pool),
		"sigils": snapshot_sigils(player.sigils),
		"_derived_lord_def": int(player.derived_lord_def),
	}


static func card_id(card) -> String:
	if card == null:
		return ""

	if card.has_method("card_id"):
		return str(card.card_id())

	return "%s:%d" % [
		str(card.get("suit")),
		int(card.get("value")),
	]


static func card_list(cards: Array) -> Array:
	var result: Array = []

	for card in cards:
		result.append(card_id(card))

	return result


static func card_multiset(cards: Array) -> Array:
	var result := card_list(cards)
	result.sort()
	return result


static func string_list(values: Array) -> Array:
	var result: Array = []

	for value in values:
		result.append(str(value))

	return result


static func sorted_strings(values: Array) -> Array:
	var result := string_list(values)
	result.sort()
	return result


static func snapshot_sigils(sigils: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var keys: Array = sigils.keys()
	keys.sort()

	for key in keys:
		result[str(key)] = _canonicalize_json_value(
			sigils[key]
		)

	return result


static func _canonicalize_json_value(value):
	match typeof(value):
		TYPE_NIL:
			return null

		TYPE_BOOL:
			return bool(value)

		TYPE_INT:
			return int(value)

		TYPE_FLOAT:
			return float(value)

		TYPE_STRING, TYPE_STRING_NAME:
			return str(value)

		TYPE_ARRAY:
			var array_result: Array = []

			for entry in value:
				array_result.append(
					_canonicalize_json_value(entry)
				)

			return array_result

		TYPE_DICTIONARY:
			var dictionary_result: Dictionary = {}
			var keys: Array = value.keys()
			keys.sort()

			for key in keys:
				dictionary_result[str(key)] = (
					_canonicalize_json_value(value[key])
				)

			return dictionary_result

		_:
			if value != null and value.has_method("card_id"):
				return card_id(value)

			return str(value)


static func _nullable_string(value):
	if value == null:
		return null

	var text := str(value)

	if text.is_empty():
		return null

	return text


static func _nullable_player_id(value):
	if value == null:
		return null

	var player_id := int(value)

	if player_id < 0:
		return null

	return player_id
