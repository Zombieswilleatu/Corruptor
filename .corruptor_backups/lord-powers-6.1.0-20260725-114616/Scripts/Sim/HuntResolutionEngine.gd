class_name HuntResolutionEngine
extends RefCounted


const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
)


const DrawEngineData = preload(
	"res://Scripts/Sim/DrawEngine.gd"
)


const ACTION_HUNT: String = "Hunt"
const ZONE_LORD: String = "Lord"

const SIGIL_FRESH: String = "fresh"
const SIGIL_FLIPPED: String = "flipped"

const OMEN_THRESHOLD: int = 3


static func resolve(
	game,
	rules: RuleConfig,
	attacker_id: int,
	options: Dictionary = {}
) -> Dictionary:
	assert(
		game != null,
		"Hunt Resolution requires a GameState."
	)

	assert(
		rules != null,
		"Hunt Resolution requires RuleConfig."
	)

	var attacker = game.get_player(
		attacker_id
	)

	if attacker == null:
		return _invalid_result(
			attacker_id,
			-1,
			"attacker_missing"
		)

	if attacker.action != ACTION_HUNT:
		return _invalid_result(
			attacker_id,
			int(
				attacker.tgt_pid
			),
			"attacker_not_hunting"
		)

	if attacker.tgt_type != ZONE_LORD:
		return _invalid_result(
			attacker_id,
			int(
				attacker.tgt_pid
			),
			"hunt_target_type_invalid"
		)

	var defender_id: int = int(
		attacker.tgt_pid
	)

	var defender = game.get_player(
		defender_id
	)

	if defender == null:
		return _invalid_result(
			attacker_id,
			defender_id,
			"defender_missing"
		)

	if defender_id == attacker_id:
		return _invalid_result(
			attacker_id,
			defender_id,
			"hunt_cannot_target_self"
		)

	if not defender.alive:
		return {
			"action": "pass",
			"reason": "target_banished",
			"attacker_id": attacker_id,
			"defender_id": defender_id,
			"strength": 0,
			"lord_defense": 0,
			"sigil_state": "",
			"sigil_value": 0,
			"guards_defeated": [],
			"sigil_broken": false,
			"destroyed": false,
			"banished": false,
			"consumed": false,
			"excess": 0,
			"recoil_card": "",
			"siphoned_card": "",
			"overkill_return": "",
			"neutral_tear_gain": 0,
			"personal_tear_gain": 0,
			"won": false,
		}

	defender.was_hunted = true

	var marked_lord: String = String(
		game.get_meta(
			"orias_marked_lord",
			""
		)
	)

	var orias_clean_hunt: bool = (
		attacker.lord == "Orias"
		and marked_lord == defender.lord
	)

	var recoil_card = null

	if (
		defender.lord == "Odradek"
		and defender.alive
		and not defender.odradek_recoil_done
		and not orias_clean_hunt
	):
		defender.odradek_recoil_done = true

		recoil_card = _apply_odradek_recoil(
			game,
			attacker,
			rules
		)

		if recoil_card != null:
			_gain_soul(
				defender,
				1
			)

	var strength: int = _committed_value(
		attacker.committed
	)

	strength += _suit_bonus(
		attacker.committed,
		"Butcher"
	)

	if (
		attacker.lord == "Orias"
		and attacker.alive
	):
		strength += 1

		if defender.threat >= 2:
			strength += 1

	var ignore_lowest: bool = false

	if (
		attacker.lord == "Valak"
		and attacker.alive
		and defender.lord_guards.size() >= 2
	):
		ignore_lowest = true

	if (
		attacker.lord == "Kanifous"
		and attacker.alive
		and attacker.kanifous_invoked_suit == "Butcher"
		and not defender.lord_guards.is_empty()
	):
		ignore_lowest = true

	var lord_defense: int = _calculate_lord_defense(
		defender,
		rules
	)

	var sigil_state: String = String(
		defender.sigils.get(
			ZONE_LORD,
			""
		)
	)

	var sigil_value: int = _sigil_value(
		game,
		defender,
		sigil_state
	)

	var combat_result: Dictionary = _resolve_combat(
		game,
		strength,
		defender.lord_guards,
		ignore_lowest,
		sigil_state,
		sigil_value,
		lord_defense
	)

	var guards_defeated: Array = combat_result.get(
		"guards_defeated",
		[]
	)

	var guards_lost: int = guards_defeated.size()

	var destroyed: bool = bool(
		combat_result.get(
			"destroyed",
			false
		)
	)

	var sigil_broken: bool = bool(
		combat_result.get(
			"sigil_broken",
			false
		)
	)

	var excess: int = int(
		combat_result.get(
			"excess",
			0
		)
	)

	var gremory_guard_trigger: Dictionary = (
		_empty_gremory_trigger()
	)

	if guards_lost > 0:
		if attacker.lord == "Kroni":
			attacker.kroni_personally_defeated_guard = true
			attacker.kroni_enemy_destroyed = true

		if defender.lord == "Odradek":
			defender.odradek_guards_defeated += (
				guards_lost
			)

		gremory_guard_trigger = (
			_trigger_gremory_lord_guard(
				game,
				rules
			)
		)

	if sigil_broken:
		defender.sigils[ZONE_LORD] = ""

		if (
			not destroyed
			and (
				sigil_state == SIGIL_FRESH
				or not rules.sigil_soul_fresh_only
			)
		):
			_gain_soul(
				defender,
				1
			)

	var consume_hunt: bool = bool(
		options.get(
			"consume_hunt",
			false
		)
	)

	var consumed: bool = false
	var banished: bool = false

	var neutral_tear_gain: int = 0
	var personal_tear_gain: int = 0

	var harvested_card: String = ""
	var harvested_by: int = -1

	var overkill_return: String = ""

	var banishment_event: Dictionary = (
		_empty_banishment_event()
	)

	if (
		destroyed
		and consume_hunt
	):
		consumed = true

		var tear_event: Dictionary = (
			_gain_personal_tear(
				game,
				attacker
			)
		)

		personal_tear_gain += 1

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
	elif destroyed:
		banished = true

		banishment_event = _banish_lord(
			game,
			rules,
			attacker,
			defender
		)

		neutral_tear_gain += int(
			banishment_event.get(
				"neutral_tear_gain",
				0
			)
		)

		harvested_card = String(
			banishment_event.get(
				"harvested_card",
				""
			)
		)

		harvested_by = int(
			banishment_event.get(
				"harvested_by",
				-1
			)
		)

		if excess >= 3:
			var returned_card = _return_overkill_card(
				attacker
			)

			if returned_card != null:
				overkill_return = _card_id(
					returned_card
				)

	var siphoned_card = null
	var siphon_gremory_trigger: Dictionary = (
		_empty_gremory_trigger()
	)

	if (
		not consumed
		and attacker.lord == "Valak"
		and attacker.alive
		and guards_lost > 0
		and not defender.lord_guards.is_empty()
	):
		var lowest_index: int = _lowest_card_index(
			defender.lord_guards
		)

		siphoned_card = defender.lord_guards[
			lowest_index
		]

		defender.lord_guards.remove_at(
			lowest_index
		)

		game.discard.append(
			siphoned_card
		)

		siphon_gremory_trigger = (
			_trigger_gremory_lord_guard(
				game,
				rules
			)
		)

	if (
		not consumed
		and defender.lord == "Odradek"
		and defender.alive
		and not orias_clean_hunt
		and not rules.no_backwash
	):
		attacker.threat = min(
			rules.max_threat,
			int(
				attacker.threat
			) + 1
		)

	if (
		not consumed
		and attacker.lord == "Orias"
		and attacker.alive
		and guards_lost > 0
		and defender.alive
	):
		var threat_gain: int = 1

		if defender.threat >= 2:
			threat_gain = 2

		defender.threat = min(
			rules.max_threat,
			int(
				defender.threat
			) + threat_gain
		)

	var ravenous_soul_gain: int = 0

	if (
		not consumed
		and destroyed
		and attacker.lord == "Kroni"
		and attacker.alive
		and attacker.kroni_hunger >= 3
		and not attacker.kroni_ravenous_used
	):
		_gain_soul(
			attacker,
			2
		)

		ravenous_soul_gain = 2

		var hunger_event: Dictionary = (
			_gain_kroni_hunger(
				game,
				attacker
			)
		)

		personal_tear_gain += int(
			hunger_event.get(
				"personal_tear_gain",
				0
			)
		)

		if harvested_card.is_empty():
			harvested_card = String(
				hunger_event.get(
					"harvested_card",
					""
				)
			)

			harvested_by = int(
				hunger_event.get(
					"harvested_by",
					-1
				)
			)

		attacker.kroni_ravenous_used = true

	attacker.derived_lord_def = (
		_calculate_lord_defense(
			attacker,
			rules
		)
	)

	defender.derived_lord_def = (
		_calculate_lord_defense(
			defender,
			rules
		)
	)

	game.refresh_derived_values()

	var won: bool = _check_win(
		game,
		rules
	)

	return {
		"action": "hunt",
		"reason": "",
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"strength": strength,
		"lord_defense": lord_defense,
		"ignore_lowest_guard": ignore_lowest,
		"sigil_state": sigil_state,
		"sigil_value": sigil_value,
		"guards_defeated": _card_ids(
			guards_defeated
		),
		"sigil_broken": sigil_broken,
		"destroyed": destroyed,
		"banished": banished,
		"consumed": consumed,
		"excess": excess,
		"stopped_at": String(
			combat_result.get(
				"stopped_at",
				""
			)
		),
		"recoil_card": (
			""
			if recoil_card == null
			else _card_id(
				recoil_card
			)
		),
		"siphoned_card": (
			""
			if siphoned_card == null
			else _card_id(
				siphoned_card
			)
		),
		"overkill_return": overkill_return,
		"neutral_tear_gain": neutral_tear_gain,
		"personal_tear_gain": personal_tear_gain,
		"harvested_card": harvested_card,
		"harvested_by": harvested_by,
		"ravenous_soul_gain": ravenous_soul_gain,
		"gremory_guard_trigger": (
			gremory_guard_trigger
		),
		"siphon_gremory_trigger": (
			siphon_gremory_trigger
		),
		"banishment": banishment_event,
		"won": won,
	}


static func _resolve_combat(
	game,
	strength: int,
	guard_zone: Array,
	ignore_lowest: bool,
	sigil_state: String,
	sigil_value: int,
	lord_defense: int
) -> Dictionary:
	var remaining: int = strength
	var guards_defeated: Array = []

	var ignored_card = null

	if (
		ignore_lowest
		and not guard_zone.is_empty()
	):
		var ignored_index: int = _lowest_card_index(
			guard_zone
		)

		ignored_card = guard_zone[
			ignored_index
		]

	var ordered_guards: Array = []

	for index in range(
		guard_zone.size()
	):
		var guard = guard_zone[
			index
		]

		var effective_value: int = int(
			guard.value
		)

		if guard == ignored_card:
			effective_value = 0

		ordered_guards.append({
			"card": guard,
			"effective_value": effective_value,
			"original_index": index,
		})

	ordered_guards.sort_custom(
		func(
			entry_a: Dictionary,
			entry_b: Dictionary
		) -> bool:
			var value_a: int = int(
				entry_a.get(
					"effective_value",
					0
				)
			)

			var value_b: int = int(
				entry_b.get(
					"effective_value",
					0
				)
			)

			if value_a != value_b:
				return value_a > value_b

			return int(
				entry_a.get(
					"original_index",
					0
				)
			) < int(
				entry_b.get(
					"original_index",
					0
				)
			)
	)

	for entry in ordered_guards:
		var guard = entry.get(
			"card"
		)

		var effective_value: int = int(
			entry.get(
				"effective_value",
				0
			)
		)

		if remaining <= effective_value:
			return {
				"destroyed": false,
				"sigil_broken": false,
				"excess": 0,
				"stopped_at": "Guard",
				"guards_defeated": guards_defeated,
			}

		remaining -= effective_value

		if guard_zone.has(
			guard
		):
			guard_zone.erase(
				guard
			)

			game.discard.append(
				guard
			)

			guards_defeated.append(
				guard
			)

	var sigil_broken: bool = false

	if not sigil_state.is_empty():
		if sigil_value == 0:
			sigil_broken = true
		elif remaining > sigil_value:
			sigil_broken = true
			remaining -= sigil_value
		else:
			return {
				"destroyed": false,
				"sigil_broken": false,
				"excess": 0,
				"stopped_at": "Sigil",
				"guards_defeated": guards_defeated,
			}

	if remaining > lord_defense:
		return {
			"destroyed": true,
			"sigil_broken": sigil_broken,
			"excess": remaining - lord_defense,
			"stopped_at": "",
			"guards_defeated": guards_defeated,
		}

	return {
		"destroyed": false,
		"sigil_broken": sigil_broken,
		"excess": 0,
		"stopped_at": "Lord",
		"guards_defeated": guards_defeated,
	}


static func _apply_odradek_recoil(
	game,
	attacker,
	rules: RuleConfig
):
	if attacker.committed.is_empty():
		return null

	var victim_index: int = 0

	if rules.recoil_lowest:
		victim_index = _lowest_card_index(
			attacker.committed
		)
	else:
		victim_index = _second_highest_index(
			attacker.committed
		)

	var victim = attacker.committed[
		victim_index
	]

	attacker.committed.remove_at(
		victim_index
	)

	game.discard.append(
		victim
	)

	return victim


static func _banish_lord(
	game,
	rules: RuleConfig,
	attacker,
	defender
) -> Dictionary:
	var attacker_souls_before: int = int(
		attacker.souls
	)

	var defender_souls_before: int = int(
		defender.souls
	)

	_gain_soul(
		attacker,
		2
	)

	var orias_bonus: int = 0

	if (
		attacker.lord == "Orias"
		and attacker.alive
		and defender.threat >= 3
	):
		_gain_soul(
			attacker,
			2
		)

		orias_bonus = 2

	_lose_soul(
		defender,
		1
	)

	var kanifous_soul_gain: int = 0
	var kanifous_draws: Array = []

	if defender.lord == "Kanifous":
		_gain_soul(
			defender,
			1
		)

		kanifous_soul_gain = 1

		if defender.souls < attacker.souls:
			for draw_index in range(
				2
			):
				var drawn_card = _draw_outside_development(
					game,
					defender,
					rules
				)

				if drawn_card != null:
					kanifous_draws.append(
						drawn_card
					)

	var gremory_event: Dictionary = (
		_trigger_gremory_ruin(
			game
		)
	)

	if (
		attacker.lord == "Orias"
		and attacker.alive
	):
		game.set_meta(
			"orias_marked_lord",
			String(
				defender.lord
			)
		)

	if defender.lord == "Kroni":
		defender.kroni_hunger = max(
			0,
			int(
				defender.kroni_hunger
			) - 1
		)


	if defender.lord == "Odradek":
		defender.odradek_reconfig_tokens = 0

	var neutral_tear_gain: int = 0
	var harvested_card: String = ""
	var harvested_by: int = -1

	if rules.neutral_tear_on_banish:
		var tear_event: Dictionary = (
			_gain_neutral_tear(
				game
			)
		)

		neutral_tear_gain = 1

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

	var lord_data: Dictionary = (
		GameSetupData.LORD_CONTENT.get(
			defender.lord,
			{}
		)
	)

	defender.threat = int(
		lord_data.get(
			"return_threat",
			0
		)
	)

	game.breach = String(
		defender.lord
	)

	game.breach_owner = int(
		defender.pid
	)

	defender.lord_guards.clear()
	defender.alive = false
	defender.derived_lord_def = 0

	return {
		"attacker_souls_before": (
			attacker_souls_before
		),
		"attacker_souls_after": int(
			attacker.souls
		),
		"defender_souls_before": (
			defender_souls_before
		),
		"defender_souls_after": int(
			defender.souls
		),
		"orias_bonus": orias_bonus,
		"kanifous_soul_gain": (
			kanifous_soul_gain
		),
		"kanifous_draws": _card_ids(
			kanifous_draws
		),
		"gremory_trigger": gremory_event,
		"neutral_tear_gain": (
			neutral_tear_gain
		),
		"harvested_card": harvested_card,
		"harvested_by": harvested_by,
		"breach": String(
			game.breach
		),
		"breach_owner": int(
			game.breach_owner
		),
	}


static func _return_overkill_card(
	attacker
):
	var selected_index: int = -1
	var selected_value: int = -1

	for index in range(
		attacker.committed.size()
	):
		var card = attacker.committed[
			index
		]

		var card_value: int = int(
			card.value
		)

		if card_value > 3:
			continue

		if card_value > selected_value:
			selected_index = index
			selected_value = card_value

	if selected_index < 0:
		return null

	var selected_card = attacker.committed[
		selected_index
	]

	attacker.committed.remove_at(
		selected_index
	)

	attacker.hand.append(
		selected_card
	)

	return selected_card


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

		var drawn_card = _draw_outside_development(
			game,
			player,
			rules
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


static func _trigger_gremory_ruin(
	game
) -> Dictionary:
	for player in game.players:
		if (
			player.lord != "Gremory"
			or not player.alive
			or player.gremory_ruin_done
		):
			continue

		var recovered_card = null

		if not game.discard.is_empty():
			recovered_card = game.discard.pop_back()

			player.hand.append(
				recovered_card
			)

		player.gremory_ruin_done = true

		return {
			"triggered": true,
			"player_id": int(
				player.pid
			),
			"recovered_card": (
				""
				if recovered_card == null
				else _card_id(
					recovered_card
				)
			),
		}

	return {
		"triggered": false,
		"player_id": -1,
		"recovered_card": "",
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


static func _draw_outside_development(
	game,
	player,
	rules: RuleConfig
):
	var random_source = game.get_meta(
		"_resolution_random_source",
		null
	)

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

	if player.hand.is_empty():
		return null

	return player.hand.back()


static func _calculate_lord_defense(
	player,
	rules: RuleConfig
) -> int:
	if not player.alive:
		return 0

	if player.lord == "Humbaba":
		return LordMathData.lord_base_def(
			"Humbaba",
			player.castles,
			int(
				player.threat
			),
			rules
		)

	var defense: int = 0

	if player.lord == "Kroni":
		if player.kroni_hunger >= 3:
			defense = (
				7
				if rules.kroni_def_soft
				else 8
			)
		elif player.kroni_hunger >= 1:
			defense = (
				5
				if rules.kroni_def_soft
				else 6
			)
		else:
			defense = 4
	else:
		var lord_data: Dictionary = (
			GameSetupData.LORD_CONTENT.get(
				player.lord,
				{}
			)
		)

		defense = int(
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


static func _sigil_value(
	game,
	player,
	sigil_state: String
) -> int:
	if not [
		SIGIL_FRESH,
		SIGIL_FLIPPED,
	].has(
		sigil_state
	):
		return 0

	var value: int = (
		2
		if sigil_state == SIGIL_FRESH
		else 1
	)

	if player.castles.has(
		"Keep"
	):
		value += 1

	if (
		game.calculate_veil_total()
		>= OMEN_THRESHOLD
		and player.tears < OMEN_THRESHOLD
	):
		value = max(
			0,
			value - 1
		)

	return value


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

			if (
				candidate.souls
				> collapse_winner.souls
			):
				collapse_winner = candidate

		game.winner = int(
			collapse_winner.pid
		)

		game.win_by = "FinalCollapse"

		return true

	if veil_total < rules.dominion_track:
		return false

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


static func _gain_soul(
	player,
	amount: int
) -> void:
	player.souls += max(
		0,
		amount
	)


static func _lose_soul(
	player,
	amount: int
) -> void:
	player.souls = max(
		0,
		int(
			player.souls
		) - max(
			0,
			amount
		)
	)


static func _committed_value(
	cards: Array
) -> int:
	var total: int = 0

	for card in cards:
		total += int(
			card.value
		)

	return total


static func _suit_bonus(
	cards: Array,
	suit_name: String
) -> int:
	var count: int = 0

	for card in cards:
		if String(
			card.suit
		) == suit_name:
			count += 1

	return (
		1
		if count >= 2
		else 0
	)


static func _lowest_card_index(
	cards: Array
) -> int:
	if cards.is_empty():
		return -1

	var selected_index: int = 0
	var selected_value: int = int(
		cards[0].value
	)

	for index in range(
		1,
		cards.size()
	):
		var card_value: int = int(
			cards[index].value
		)

		if card_value < selected_value:
			selected_index = index
			selected_value = card_value

	return selected_index


static func _second_highest_index(
	cards: Array
) -> int:
	if cards.size() <= 1:
		return 0

	var indices: Array[int] = []

	for index in range(
		cards.size()
	):
		indices.append(
			index
		)

	indices.sort_custom(
		func(
			index_a: int,
			index_b: int
		) -> bool:
			var value_a: int = int(
				cards[index_a].value
			)

			var value_b: int = int(
				cards[index_b].value
			)

			if value_a != value_b:
				return value_a > value_b

			return index_a < index_b
	)

	return indices[1]


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


static func _empty_gremory_trigger() -> Dictionary:
	return {
		"triggered": false,
		"player_id": -1,
		"drawn_card": "",
		"discarded_card": "",
	}


static func _empty_banishment_event() -> Dictionary:
	return {
		"attacker_souls_before": 0,
		"attacker_souls_after": 0,
		"defender_souls_before": 0,
		"defender_souls_after": 0,
		"orias_bonus": 0,
		"kanifous_soul_gain": 0,
		"kanifous_draws": [],
		"gremory_trigger": {
			"triggered": false,
			"player_id": -1,
			"recovered_card": "",
		},
		"neutral_tear_gain": 0,
		"harvested_card": "",
		"harvested_by": -1,
		"breach": "",
		"breach_owner": -1,
	}


static func _invalid_result(
	attacker_id: int,
	defender_id: int,
	reason: String
) -> Dictionary:
	return {
		"action": "invalid",
		"reason": reason,
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"strength": 0,
		"lord_defense": 0,
		"sigil_state": "",
		"sigil_value": 0,
		"guards_defeated": [],
		"sigil_broken": false,
		"destroyed": false,
		"banished": false,
		"consumed": false,
		"excess": 0,
		"recoil_card": "",
		"siphoned_card": "",
		"overkill_return": "",
		"neutral_tear_gain": 0,
		"personal_tear_gain": 0,
		"won": false,
	}
