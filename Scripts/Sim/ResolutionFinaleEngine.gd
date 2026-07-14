class_name ResolutionFinaleEngine
extends RefCounted


const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
)


const ACTION_HUNT: String = "Hunt"
const ACTION_SIEGE: String = "Siege"
const ACTION_WARD: String = "Ward"

const ZONE_LORD: String = "Lord"
const ZONE_CASTLE: String = "Castle"

const RECONFIG_META_KEY: String = (
	"odradek_reconfig_tokens"
)


static func resolve(
	game,
	rules: RuleConfig
) -> Dictionary:
	assert(
		game != null,
		"Resolution Finale requires a GameState."
	)

	assert(
		rules != null,
		"Resolution Finale requires RuleConfig."
	)

	var decay_events: Array[Dictionary] = []
	var fallback_events: Array[Dictionary] = []
	var breach_events: Array[Dictionary] = []
	var reconfiguration_events: Array[Dictionary] = []
	var state_events: Array[Dictionary] = []

	if rules.kroni_hunger_decay:
		for player in game.players:
			var decay_event: Dictionary = (
				_apply_kroni_decay(
					player
				)
			)

			if bool(
				decay_event.get(
					"applied",
					false
				)
			):
				decay_events.append(
					decay_event
				)

	for player in game.players:
		var fallback_event: Dictionary = (
			_resolve_kroni_fallback(
				game,
				player
			)
		)

		if bool(
			fallback_event.get(
				"triggered",
				false
			)
		):
			fallback_events.append(
				fallback_event
			)

			if _check_win(
				game,
				rules
			):
				game.refresh_derived_values()

				return _result(
					game,
					decay_events,
					fallback_events,
					breach_events,
					reconfiguration_events,
					state_events,
					true
				)

	if game.breach == "Kroni":
		for player in game.players:
			var breach_event: Dictionary = (
				_resolve_kroni_breach(
					game,
					player
				)
			)

			if bool(
				breach_event.get(
					"triggered",
					false
				)
			):
				breach_events.append(
					breach_event
				)

	for player in game.players:
		if (
			player.lord != "Odradek"
			or not player.alive
		):
			continue

		var reconfiguration_event: Dictionary = (
			_resolve_odradek_reconfiguration(
				game,
				player,
				rules
			)
		)

		reconfiguration_events.append(
			reconfiguration_event
		)

		if bool(
			reconfiguration_event.get(
				"won",
				false
			)
		):
			game.refresh_derived_values()

			return _result(
				game,
				decay_events,
				fallback_events,
				breach_events,
				reconfiguration_events,
				state_events,
				true
			)

	for player in game.players:
		var previous_ward_before: String = String(
			player.prev_ward_target
		)

		if player.action == ACTION_WARD:
			player.prev_ward_target = String(
				player.ward_target
			)
		else:
			player.prev_ward_target = ""

		var patient_before: bool = bool(
			player.humbaba_patient
		)

		if (
			player.lord == "Humbaba"
			and player.alive
			and rules.humbaba_patient
		):
			player.humbaba_patient = not [
				ACTION_HUNT,
				ACTION_SIEGE,
			].has(
				String(
					player.action
				)
			)

		state_events.append({
			"player_id": int(
				player.pid
			),
			"previous_ward_before": (
				previous_ward_before
			),
			"previous_ward_after": String(
				player.prev_ward_target
			),
			"patient_before": patient_before,
			"patient_after": bool(
				player.humbaba_patient
			),
		})

	game.refresh_derived_values()

	return _result(
		game,
		decay_events,
		fallback_events,
		breach_events,
		reconfiguration_events,
		state_events,
		false
	)


static func _apply_kroni_decay(
	player
) -> Dictionary:
	if (
		player.lord != "Kroni"
		or not player.alive
		or [
			ACTION_HUNT,
			ACTION_SIEGE,
		].has(
			String(
				player.action
			)
		)
	):
		return {
			"applied": false,
			"player_id": int(
				player.pid
			),
			"hunger_before": int(
				player.kroni_hunger
			),
			"hunger_after": int(
				player.kroni_hunger
			),
		}

	var hunger_before: int = int(
		player.kroni_hunger
	)

	player.kroni_hunger = max(
		0,
		hunger_before - 1
	)

	return {
		"applied": true,
		"player_id": int(
			player.pid
		),
		"hunger_before": hunger_before,
		"hunger_after": int(
			player.kroni_hunger
		),
	}


static func _resolve_kroni_fallback(
	game,
	player
) -> Dictionary:
	if (
		player.lord != "Kroni"
		or not player.alive
		or player.kroni_consume_done
	):
		return _empty_fallback_event(
			player,
			"not_eligible"
		)

	var selected_entry: Dictionary = (
		_lowest_guard_entry(
			player
		)
	)

	if selected_entry.is_empty():
		selected_entry = _lowest_garrison_entry(
			player
		)

	if selected_entry.is_empty():
		return _empty_fallback_event(
			player,
			"no_subject_available"
		)

	var selected_card = selected_entry.get(
		"card"
	)

	var selected_zone: String = String(
		selected_entry.get(
			"zone",
			""
		)
	)

	_remove_card_from_zone(
		player,
		selected_card,
		selected_zone
	)

	game.discard.append(
		selected_card
	)

	_mark_destruction(
		game
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

	return {
		"triggered": true,
		"reason": "",
		"player_id": int(
			player.pid
		),
		"zone": selected_zone,
		"discarded_card": _card_id(
			selected_card
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
	}


static func _resolve_kroni_breach(
	game,
	player
) -> Dictionary:
	var selected_entry: Dictionary = (
		_lowest_guard_entry(
			player
		)
	)

	if selected_entry.is_empty():
		return {
			"triggered": false,
			"player_id": int(
				player.pid
			),
			"zone": "",
			"discarded_card": "",
		}

	var selected_card = selected_entry.get(
		"card"
	)

	var selected_zone: String = String(
		selected_entry.get(
			"zone",
			""
		)
	)

	_remove_card_from_zone(
		player,
		selected_card,
		selected_zone
	)

	game.discard.append(
		selected_card
	)

	_mark_destruction(
		game
	)

	return {
		"triggered": true,
		"player_id": int(
			player.pid
		),
		"zone": selected_zone,
		"discarded_card": _card_id(
			selected_card
		),
	}


static func _resolve_odradek_reconfiguration(
	game,
	player,
	rules: RuleConfig
) -> Dictionary:
	var denial_threshold: int = (
		1
		if rules.reconfig_strict
		else 2
	)

	var defeated_count: int = int(
		player.odradek_guards_defeated
	)

	var tokens_before: int = int(
		game.get_meta(
			RECONFIG_META_KEY,
			0
		)
	)

	if defeated_count >= denial_threshold:
		return {
			"eligible": true,
			"blocked": true,
			"player_id": int(
				player.pid
			),
			"guards_defeated": defeated_count,
			"denial_threshold": denial_threshold,
			"tokens_before": tokens_before,
			"tokens_after": tokens_before,
			"personal_tear_gain": 0,
			"neutral_tear_gain": 0,
			"harvested_card": "",
			"harvested_by": -1,
			"won": false,
		}

	var tokens_after: int = (
		tokens_before + 1
	)

	var personal_tear_gain: int = 0
	var neutral_tear_gain: int = 0

	var harvested_card: String = ""
	var harvested_by: int = -1

	if tokens_after >= rules.reconfig_tokens_needed:
		tokens_after -= (
			rules.reconfig_tokens_needed
		)

		var tear_event: Dictionary = {}

		if rules.reconfig_neutral:
			tear_event = _gain_neutral_tear(
				game
			)

			neutral_tear_gain = 1
		else:
			tear_event = _gain_personal_tear(
				game,
				player
			)

			personal_tear_gain = 1

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

	game.set_meta(
		RECONFIG_META_KEY,
		tokens_after
	)

	var won: bool = _check_win(
		game,
		rules
	)

	return {
		"eligible": true,
		"blocked": false,
		"player_id": int(
			player.pid
		),
		"guards_defeated": defeated_count,
		"denial_threshold": denial_threshold,
		"tokens_before": tokens_before,
		"tokens_after": tokens_after,
		"personal_tear_gain": personal_tear_gain,
		"neutral_tear_gain": neutral_tear_gain,
		"harvested_card": harvested_card,
		"harvested_by": harvested_by,
		"won": won,
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


static func _lowest_guard_entry(
	player
) -> Dictionary:
	var selected_card = null
	var selected_zone: String = ""
	var selected_value: int = 1000000
	var selected_order: int = 1000000

	var order_index: int = 0

	for card in player.lord_guards:
		var card_value: int = int(
			card.value
		)

		if (
			card_value < selected_value
			or (
				card_value == selected_value
				and order_index < selected_order
			)
		):
			selected_card = card
			selected_zone = ZONE_LORD
			selected_value = card_value
			selected_order = order_index

		order_index += 1

	for card in player.castle_guards:
		var card_value: int = int(
			card.value
		)

		if (
			card_value < selected_value
			or (
				card_value == selected_value
				and order_index < selected_order
			)
		):
			selected_card = card
			selected_zone = ZONE_CASTLE
			selected_value = card_value
			selected_order = order_index

		order_index += 1

	if selected_card == null:
		return {}

	return {
		"card": selected_card,
		"zone": selected_zone,
	}


static func _lowest_garrison_entry(
	player
) -> Dictionary:
	if player.garrison.is_empty():
		return {}

	var selected_index: int = 0
	var selected_value: int = int(
		player.garrison[0].value
	)

	for index in range(
		1,
		player.garrison.size()
	):
		var card_value: int = int(
			player.garrison[index].value
		)

		if card_value < selected_value:
			selected_index = index
			selected_value = card_value

	return {
		"card": player.garrison[
			selected_index
		],
		"zone": "Garrison",
	}


static func _remove_card_from_zone(
	player,
	card,
	zone: String
) -> void:
	if zone == ZONE_LORD:
		assert(
			player.lord_guards.has(
				card
			),
			"Expected Lord Guard was missing."
		)

		player.lord_guards.erase(
			card
		)

		return

	if zone == ZONE_CASTLE:
		assert(
			player.castle_guards.has(
				card
			),
			"Expected Castle Guard was missing."
		)

		player.castle_guards.erase(
			card
		)

		return

	if zone == "Garrison":
		assert(
			player.garrison.has(
				card
			),
			"Expected Garrison card was missing."
		)

		player.garrison.erase(
			card
		)

		return

	assert(
		false,
		"Unknown Finale card zone: %s"
		% zone
	)


static func _mark_destruction(
	game
) -> void:
	game.set_meta(
		"any_destruction_round",
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


static func _empty_fallback_event(
	player,
	reason: String
) -> Dictionary:
	return {
		"triggered": false,
		"reason": reason,
		"player_id": (
			-1
			if player == null
			else int(
				player.pid
			)
		),
		"zone": "",
		"discarded_card": "",
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
	}


static func _result(
	game,
	decay_events: Array[Dictionary],
	fallback_events: Array[Dictionary],
	breach_events: Array[Dictionary],
	reconfiguration_events: Array[Dictionary],
	state_events: Array[Dictionary],
	stopped_on_win: bool
) -> Dictionary:
	return {
		"action": "resolution_finale",
		"decay_events": decay_events,
		"fallback_events": fallback_events,
		"breach_events": breach_events,
		"reconfiguration_events": (
			reconfiguration_events
		),
		"state_events": state_events,
		"stopped_on_win": stopped_on_win,
		"winner": int(
			game.winner
		),
		"win_by": String(
			game.win_by
		),
	}


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
