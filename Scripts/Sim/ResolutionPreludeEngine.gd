class_name ResolutionPreludeEngine
extends RefCounted


const ZONE_LORD: String = "Lord"
const ZONE_CASTLE: String = "Castle"

const COLLAPSE_THRESHOLD: int = 7
const WANING_THRESHOLD: int = 9


static func resolve(
	game,
	rules: RuleConfig,
	tie_first_player: int = -1
) -> Dictionary:
	assert(
		game != null,
		"Resolution Prelude requires a GameState."
	)

	assert(
		rules != null,
		"Resolution Prelude requires RuleConfig."
	)

	assert(
		game.players.size() == 2,
		"Resolution Prelude currently requires two players."
	)

	var committed_values: Array[int] = [
		_committed_value(
			game.players[0].committed
		),
		_committed_value(
			game.players[1].committed
		),
	]

	# Order is locked before any pre-resolution effects strip cards.
	var order_result: Dictionary = _resolve_order(
		game,
		committed_values,
		tie_first_player
	)

	var scorch_event: Dictionary = _apply_persistent_scorch(
		game,
		rules
	)

	var collapse_events: Array[Dictionary] = []

	if game.calculate_veil_total() >= COLLAPSE_THRESHOLD:
		for player in game.players:
			collapse_events.append(
				_strip_attacked_zone_guard(
					game,
					player,
					"veil_collapse"
				)
			)

	var waning_events: Array[Dictionary] = []
	var waning_sources: Array[String] = []

	if game.breach == "Valak":
		waning_sources.append(
			"valak_breach"
		)

	if game.calculate_veil_total() >= WANING_THRESHOLD:
		waning_sources.append(
			"veil_waning"
		)

	for player in game.players:
		for source_name: String in waning_sources:
			waning_events.append(
				_strip_attacked_zone_guard(
					game,
					player,
					source_name
				)
			)

	var kroni_events: Array[Dictionary] = (
		_apply_kroni_hungering_aura(
			game
		)
	)

	game.refresh_derived_values()

	return {
		"action": "resolution_prelude",
		"reason": "",
		"committed_values": committed_values,
		"order": order_result.get(
			"order",
			[]
		),
		"tied": bool(
			order_result.get(
				"tied",
				false
			)
		),
		"tie_first_player": int(
			order_result.get(
				"tie_first_player",
				-1
			)
		),
		"tie_source": String(
			order_result.get(
				"tie_source",
				""
			)
		),
		"persistent_scorch": scorch_event,
		"collapse_events": collapse_events,
		"waning_events": waning_events,
		"kroni_events": kroni_events,
	}


static func _resolve_order(
	game,
	committed_values: Array[int],
	requested_tie_first_player: int
) -> Dictionary:
	var player_zero_value: int = committed_values[0]
	var player_one_value: int = committed_values[1]

	if player_zero_value > player_one_value:
		return {
			"order": [
				0,
				1,
			],
			"tied": false,
			"tie_first_player": -1,
			"tie_source": "",
		}

	if player_one_value > player_zero_value:
		return {
			"order": [
				1,
				0,
			],
			"tied": false,
			"tie_first_player": -1,
			"tie_source": "",
		}

	var selected_first_player: int = (
		requested_tie_first_player
	)

	var tie_source: String = "explicit"

	if not _valid_player_id(
		game,
		selected_first_player
	):
		selected_first_player = int(
			game.first_player
		)

		tie_source = "game_first_player"

	if not _valid_player_id(
		game,
		selected_first_player
	):
		selected_first_player = 0
		tie_source = "fallback_zero"

	return {
		"order": [
			selected_first_player,
			1 - selected_first_player,
		],
		"tied": true,
		"tie_first_player": selected_first_player,
		"tie_source": tie_source,
	}


static func _apply_persistent_scorch(
	game,
	rules: RuleConfig
) -> Dictionary:
	var target_player_id: int = int(
		game.persist_scorch_pid
	)

	var target_zone: String = String(
		game.persist_scorch_type
	)

	if (
		not _valid_player_id(
			game,
			target_player_id
		)
		or not [
			ZONE_LORD,
			ZONE_CASTLE,
		].has(
			target_zone
		)
	):
		return {
			"applied": false,
			"player_id": -1,
			"zone": "",
			"discarded_cards": [],
			"gremory_trigger": (
				_empty_gremory_trigger()
			),
		}

	var player = game.get_player(
		target_player_id
	)

	var guard_zone: Array = (
		player.lord_guards
		if target_zone == ZONE_LORD
		else player.castle_guards
	)

	var victims: Array = []

	for guard in guard_zone.duplicate():
		if int(
			guard.value
		) > 2:
			continue

		guard_zone.erase(
			guard
		)

		game.discard.append(
			guard
		)

		victims.append(
			guard
		)

	var gremory_trigger: Dictionary = (
		_empty_gremory_trigger()
	)

	if (
		target_zone == ZONE_LORD
		and not victims.is_empty()
	):
		gremory_trigger = _trigger_gremory_lord_guard(
			game,
			rules
		)

	return {
		"applied": true,
		"player_id": target_player_id,
		"zone": target_zone,
		"discarded_cards": _card_ids(
			victims
		),
		"gremory_trigger": gremory_trigger,
	}


static func _strip_attacked_zone_guard(
	game,
	player,
	source_name: String
) -> Dictionary:
	var selected_zone: String = ""
	var selected_card = null

	if (
		player.was_lord_attacked_prev
		and not player.lord_guards.is_empty()
	):
		selected_zone = ZONE_LORD

		var lowest_index: int = _lowest_card_index(
			player.lord_guards
		)

		selected_card = player.lord_guards[
			lowest_index
		]

		player.lord_guards.remove_at(
			lowest_index
		)
	elif (
		player.was_castle_attacked_prev
		and not player.castle_guards.is_empty()
	):
		selected_zone = ZONE_CASTLE

		var lowest_index: int = _lowest_card_index(
			player.castle_guards
		)

		selected_card = player.castle_guards[
			lowest_index
		]

		player.castle_guards.remove_at(
			lowest_index
		)

	if selected_card == null:
		return {
			"source": source_name,
			"player_id": int(
				player.pid
			),
			"zone": "",
			"discarded_card": "",
		}

	game.discard.append(
		selected_card
	)

	return {
		"source": source_name,
		"player_id": int(
			player.pid
		),
		"zone": selected_zone,
		"discarded_card": _card_id(
			selected_card
		),
	}


static func _apply_kroni_hungering_aura(
	game
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	for player in game.players:
		if (
			player.lord != "Kroni"
			or not player.alive
			or int(
				player.kroni_hunger
			) < 3
		):
			continue

		var opponent = game.get_opponent(
			int(
				player.pid
			)
		)

		if opponent == null:
			continue

		if opponent.committed.is_empty():
			events.append({
				"kroni_player_id": int(
					player.pid
				),
				"target_player_id": int(
					opponent.pid
				),
				"discarded_card": "",
			})

			continue

		var lowest_index: int = _lowest_card_index(
			opponent.committed
		)

		var victim = opponent.committed[
			lowest_index
		]

		opponent.committed.remove_at(
			lowest_index
		)

		game.discard.append(
			victim
		)

		events.append({
			"kroni_player_id": int(
				player.pid
			),
			"target_player_id": int(
				opponent.pid
			),
			"discarded_card": _card_id(
				victim
			),
		})

	return events


static func _trigger_gremory_lord_guard(
	game,
	rules: RuleConfig
) -> Dictionary:
	for player in game.players:
		if (
			player.lord != "Gremory"
			or not player.alive
			or player.gremory_lord_guard_draw_done
		):
			continue

		player.gremory_lord_guard_draw_done = true

		var drawn_card = null

		if (
			player.hand.size() < rules.hand_limit
			and not game.deck.is_empty()
		):
			drawn_card = game.deck.pop_back()

			player.hand.append(
				drawn_card
			)

			if game.breach == "Kanifous":
				player.threat = min(
					rules.max_threat,
					int(
						player.threat
					) + 1
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

	return _empty_gremory_trigger()


static func _empty_gremory_trigger() -> Dictionary:
	return {
		"triggered": false,
		"player_id": -1,
		"drawn_card": "",
		"discarded_card": "",
	}


static func _valid_player_id(
	game,
	player_id: int
) -> bool:
	return (
		player_id >= 0
		and player_id < game.players.size()
	)


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


static func _committed_value(
	cards: Array
) -> int:
	var total: int = 0

	for card in cards:
		total += int(
			card.value
		)

	return total


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
