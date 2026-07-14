class_name SiegeResolutionEngine
extends RefCounted


const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
)


const ACTION_SIEGE: String = "Siege"
const ZONE_CASTLE: String = "Castle"

const SIGIL_FRESH: String = "fresh"
const SIGIL_FLIPPED: String = "flipped"

const OMEN_THRESHOLD: int = 3

const CASTLE_DEFENSES: Dictionary = {
	"Keep": 13,
	"Bastion": 11,
	"SummoningCircle": 9,
	"Stockpile": 8,
	"SiegeEngine": 7,
}


static func resolve(
	game,
	rules: RuleConfig,
	attacker_id: int,
	options: Dictionary = {}
) -> Dictionary:
	assert(
		game != null,
		"Siege Resolution requires a GameState."
	)

	assert(
		rules != null,
		"Siege Resolution requires RuleConfig."
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

	if attacker.action != ACTION_SIEGE:
		return _invalid_result(
			attacker_id,
			int(
				attacker.tgt_pid
			),
			"attacker_not_sieging"
		)

	if attacker.tgt_type != ZONE_CASTLE:
		return _invalid_result(
			attacker_id,
			int(
				attacker.tgt_pid
			),
			"siege_target_type_invalid"
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
			"siege_cannot_target_self"
		)

	if defender.castles.is_empty():
		return _pass_result(
			attacker_id,
			defender_id,
			"target_has_no_castles"
		)

	var target_castle: String = _choose_target_castle(
		game,
		defender,
		String(
			options.get(
				"target_castle",
				""
			)
		)
	)

	if target_castle.is_empty():
		return _invalid_result(
			attacker_id,
			defender_id,
			"target_castle_missing"
		)

	defender.was_sieged = true
	defender.last_sieged_castle = target_castle

	var reflex: bool = bool(
		options.get(
			"reflex",
			false
		)
	)

	var consume_requested: bool = bool(
		options.get(
			"consume_siege",
			false
		)
	)

	var use_inferno: bool = bool(
		options.get(
			"use_inferno",
			true
		)
	)

	var attacker_souls_before: int = int(
		attacker.souls
	)

	var recoil_card = null

	if (
		defender.lord == "Odradek"
		and defender.alive
		and not defender.odradek_recoil_done
		and not rules.recoil_hunts_only
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

	var siege_engine_bypass: bool = (
		attacker.castles.has(
			"SiegeEngine"
		)
		and not reflex
	)

	var war_machine_bonus: int = 0

	if (
		attacker.lord == "Deimos"
		and attacker.alive
		and (
			attacker.castles.has(
				"SiegeEngine"
			)
			or rules.deimos_war_machine_free
		)
	):
		var lost_castles: int = (
			attacker.ruined_castles.size()
		)

		if not rules.war_machine_ignores_profaned:
			lost_castles += (
				attacker.profaned_castles.size()
			)

		war_machine_bonus = max(
			0,
			2 - lost_castles
		)

		strength += war_machine_bonus

	var pyroclasm_bonus: int = 0

	if (
		attacker.lord == "Kalligan"
		and attacker.alive
	):
		pyroclasm_bonus = (
			2
			if not defender.ruined_castles.is_empty()
			else 1
		)

		strength += pyroclasm_bonus

	var fear_returned_card = null

	if (
		attacker.lord == "Deimos"
		and attacker.alive
		and defender.castle_guards.size() >= 2
	):
		var weakest_index: int = _lowest_card_index(
			defender.castle_guards
		)

		fear_returned_card = defender.castle_guards[
			weakest_index
		]

		defender.castle_guards.remove_at(
			weakest_index
		)

		defender.hand.append(
			fear_returned_card
		)

	var ignore_lowest: bool = false

	if (
		attacker.lord == "Valak"
		and attacker.alive
		and defender.castle_guards.size() >= 2
	):
		ignore_lowest = true

	if (
		attacker.lord == "Kanifous"
		and attacker.alive
		and attacker.kanifous_invoked_suit == "Butcher"
		and not defender.castle_guards.is_empty()
	):
		ignore_lowest = true

	var structural_defense: int = _castle_defense(
		game,
		target_castle
	)

	var penitent_bonus: int = _suit_bonus(
		defender.committed,
		"Penitent"
	)

	structural_defense += penitent_bonus

	var sigil_state: String = String(
		defender.sigils.get(
			ZONE_CASTLE,
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
		defender.castle_guards,
		ignore_lowest,
		sigil_state,
		sigil_value,
		structural_defense,
		siege_engine_bypass
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

	if guards_lost > 0:
		_mark_destruction(
			game
		)

		if attacker.lord == "Kroni":
			attacker.kroni_personally_defeated_guard = true
			attacker.kroni_enemy_destroyed = true

		if defender.lord == "Odradek":
			defender.odradek_guards_defeated += (
				guards_lost
			)

	if sigil_broken:
		defender.sigils[ZONE_CASTLE] = ""

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

	var consumed: bool = (
		destroyed
		and consume_requested
		and rules.consume_the_siege
	)

	var neutral_tear_gain: int = 0
	var personal_tear_gain: int = 0

	var tear_source: String = ""

	var harvested_card: String = ""
	var harvested_by: int = -1

	var gremory_ruin_trigger: Dictionary = (
		_empty_gremory_ruin_trigger()
	)

	var inferno_card = null

	var wildfire_zone: String = ""

	var ravenous_soul_gain: int = 0

	var siphoned_card = null

	var won_after_tear: bool = false

	if destroyed:
		defender.castles.erase(
			target_castle
		)

		if not defender.ruined_castles.has(
			target_castle
		):
			defender.ruined_castles.append(
				target_castle
			)

		_mark_destruction(
			game
		)

		if attacker.lord == "Kroni":
			attacker.kroni_enemy_destroyed = true

		if _castle_tear_available(
			game,
			rules
		):
			var tear_event: Dictionary = {}

			if consumed:
				tear_event = _gain_personal_tear(
					game,
					attacker
				)

				personal_tear_gain += 1
				tear_source = "consume_siege"
			elif (
				rules.deimos_claims_breach > 0
				and attacker.lord == "Deimos"
				and attacker.alive
				and (
					rules.deimos_claims_breach >= 2
					or not attacker.deimos_breach_claimed
				)
			):
				attacker.deimos_breach_claimed = true

				tear_event = _gain_personal_tear(
					game,
					attacker
				)

				personal_tear_gain += 1
				tear_source = "deimos_claim"
			else:
				tear_event = _gain_neutral_tear(
					game
				)

				neutral_tear_gain += 1
				tear_source = "neutral"

			_mark_castle_tear_used(
				game
			)

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

			won_after_tear = _check_win(
				game,
				rules
			)

		if not won_after_tear:
			if not consumed:
				if guards_lost > 0:
					_gain_soul(
						attacker,
						2
					)
				else:
					_gain_soul(
						attacker,
						1
					)

			gremory_ruin_trigger = _trigger_gremory_ruin(
				game
			)

			if (
				attacker.lord == "Kalligan"
				and attacker.alive
			):
				if (
					use_inferno
					and attacker.threat < rules.max_threat
				):
					attacker.threat = min(
						rules.max_threat,
						int(
							attacker.threat
						) + 1
					)

					if not defender.lord_guards.is_empty():
						var highest_index: int = (
							_highest_card_index(
								defender.lord_guards
							)
						)

						inferno_card = defender.lord_guards[
							highest_index
						]

						defender.lord_guards.remove_at(
							highest_index
						)

						game.discard.append(
							inferno_card
						)
					else:
						game.persist_scorch_pid = int(
							defender.pid
						)

						game.persist_scorch_type = "Lord"

				game.persist_scorch_pid = int(
					defender.pid
				)

				if defender.castles.is_empty():
					game.persist_scorch_type = "Lord"
				else:
					game.persist_scorch_type = "Castle"

				wildfire_zone = String(
					game.persist_scorch_type
				)

			if (
				attacker.lord == "Kroni"
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

	if (
		not won_after_tear
		and attacker.lord == "Valak"
		and attacker.alive
		and guards_lost > 0
		and not defender.castle_guards.is_empty()
	):
		var lowest_index: int = _lowest_card_index(
			defender.castle_guards
		)

		siphoned_card = defender.castle_guards[
			lowest_index
		]

		defender.castle_guards.remove_at(
			lowest_index
		)

		game.discard.append(
			siphoned_card
		)

		_mark_destruction(
			game
		)

	attacker.derived_lord_def = _calculate_lord_defense(
		attacker,
		rules
	)

	defender.derived_lord_def = _calculate_lord_defense(
		defender,
		rules
	)

	game.refresh_derived_values()

	var won: bool = (
		won_after_tear
		or _check_win(
			game,
			rules
		)
	)

	return {
		"action": "siege",
		"reason": "",
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"target_castle": target_castle,
		"reflex": reflex,
		"strength": strength,
		"war_machine_bonus": war_machine_bonus,
		"pyroclasm_bonus": pyroclasm_bonus,
		"structural_defense": structural_defense,
		"penitent_bonus": penitent_bonus,
		"siege_engine_bypass": siege_engine_bypass,
		"fear_returned_card": (
			""
			if fear_returned_card == null
			else _card_id(
				fear_returned_card
			)
		),
		"ignore_lowest_guard": ignore_lowest,
		"sigil_state": sigil_state,
		"sigil_value": sigil_value,
		"guards_defeated": _card_ids(
			guards_defeated
		),
		"sigil_broken": sigil_broken,
		"destroyed": destroyed,
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
		"consumed": consumed,
		"soul_gain": (
			int(
				attacker.souls
			) - attacker_souls_before
		),
		"neutral_tear_gain": neutral_tear_gain,
		"personal_tear_gain": personal_tear_gain,
		"tear_source": tear_source,
		"harvested_card": harvested_card,
		"harvested_by": harvested_by,
		"gremory_ruin_trigger": (
			gremory_ruin_trigger
		),
		"inferno_card": (
			""
			if inferno_card == null
			else _card_id(
				inferno_card
			)
		),
		"wildfire_zone": wildfire_zone,
		"ravenous_soul_gain": (
			ravenous_soul_gain
		),
		"won": won,
	}


static func _resolve_combat(
	game,
	strength: int,
	guard_zone: Array,
	ignore_lowest: bool,
	sigil_state: String,
	sigil_value: int,
	structural_defense: int,
	bypass: bool
) -> Dictionary:
	var remaining: int = strength
	var guards_defeated: Array = []

	if bypass:
		var sigil_result: Dictionary = _resolve_sigil_layer(
			remaining,
			sigil_state,
			sigil_value
		)

		var sigil_broken: bool = bool(
			sigil_result.get(
				"broken",
				false
			)
		)

		if bool(
			sigil_result.get(
				"stopped",
				false
			)
		):
			return {
				"destroyed": false,
				"sigil_broken": false,
				"excess": 0,
				"stopped_at": "Sigil",
				"guards_defeated": guards_defeated,
			}

		remaining = int(
			sigil_result.get(
				"remaining",
				remaining
			)
		)

		if remaining <= structural_defense:
			return {
				"destroyed": false,
				"sigil_broken": sigil_broken,
				"excess": 0,
				"stopped_at": "Castle",
				"guards_defeated": guards_defeated,
			}

		remaining -= structural_defense

		var guard_result: Dictionary = _strip_guards(
			game,
			remaining,
			guard_zone,
			ignore_lowest
		)

		guards_defeated = guard_result.get(
			"guards_defeated",
			[]
		)

		if bool(
			guard_result.get(
				"stopped",
				false
			)
		):
			return {
				"destroyed": true,
				"sigil_broken": sigil_broken,
				"excess": 0,
				"stopped_at": "Guard",
				"guards_defeated": guards_defeated,
			}

		return {
			"destroyed": true,
			"sigil_broken": sigil_broken,
			"excess": int(
				guard_result.get(
					"remaining",
					0
				)
			),
			"stopped_at": "",
			"guards_defeated": guards_defeated,
		}

	var guard_result: Dictionary = _strip_guards(
		game,
		remaining,
		guard_zone,
		ignore_lowest
	)

	guards_defeated = guard_result.get(
		"guards_defeated",
		[]
	)

	if bool(
		guard_result.get(
			"stopped",
			false
		)
	):
		return {
			"destroyed": false,
			"sigil_broken": false,
			"excess": 0,
			"stopped_at": "Guard",
			"guards_defeated": guards_defeated,
		}

	remaining = int(
		guard_result.get(
			"remaining",
			remaining
		)
	)

	var sigil_result: Dictionary = _resolve_sigil_layer(
		remaining,
		sigil_state,
		sigil_value
	)

	var sigil_broken: bool = bool(
		sigil_result.get(
			"broken",
			false
		)
	)

	if bool(
		sigil_result.get(
			"stopped",
			false
		)
	):
		return {
			"destroyed": false,
			"sigil_broken": false,
			"excess": 0,
			"stopped_at": "Sigil",
			"guards_defeated": guards_defeated,
		}

	remaining = int(
		sigil_result.get(
			"remaining",
			remaining
		)
	)

	if remaining > structural_defense:
		return {
			"destroyed": true,
			"sigil_broken": sigil_broken,
			"excess": (
				remaining - structural_defense
			),
			"stopped_at": "",
			"guards_defeated": guards_defeated,
		}

	return {
		"destroyed": false,
		"sigil_broken": sigil_broken,
		"excess": 0,
		"stopped_at": "Castle",
		"guards_defeated": guards_defeated,
	}


static func _strip_guards(
	game,
	strength: int,
	guard_zone: Array,
	ignore_lowest: bool
) -> Dictionary:
	var remaining: int = strength
	var defeated: Array = []

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

	var entries: Array[Dictionary] = []

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

		entries.append({
			"card": guard,
			"effective_value": effective_value,
			"original_index": index,
		})

	entries.sort_custom(
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

	for entry in entries:
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
				"stopped": true,
				"remaining": remaining,
				"guards_defeated": defeated,
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

			defeated.append(
				guard
			)

	return {
		"stopped": false,
		"remaining": remaining,
		"guards_defeated": defeated,
	}


static func _resolve_sigil_layer(
	strength: int,
	sigil_state: String,
	sigil_value: int
) -> Dictionary:
	if sigil_state.is_empty():
		return {
			"broken": false,
			"stopped": false,
			"remaining": strength,
		}

	if sigil_value == 0:
		return {
			"broken": true,
			"stopped": false,
			"remaining": strength,
		}

	if strength > sigil_value:
		return {
			"broken": true,
			"stopped": false,
			"remaining": strength - sigil_value,
		}

	return {
		"broken": false,
		"stopped": true,
		"remaining": strength,
	}


static func _choose_target_castle(
	game,
	defender,
	requested_castle: String
) -> String:
	if defender.castles.has(
		requested_castle
	):
		return requested_castle

	var selected_castle: String = ""
	var selected_defense: int = 1000000

	for raw_castle_name in defender.castles:
		var castle_name: String = String(
			raw_castle_name
		)

		var defense: int = _castle_defense(
			game,
			castle_name
		)

		if (
			defense < selected_defense
			or (
				defense == selected_defense
				and (
					selected_castle.is_empty()
					or castle_name < selected_castle
				)
			)
		):
			selected_castle = castle_name
			selected_defense = defense

	return selected_castle


static func _castle_defense(
	game,
	castle_name: String
) -> int:
	if not CASTLE_DEFENSES.has(
		castle_name
	):
		return 0

	var defense: int = int(
		CASTLE_DEFENSES[
			castle_name
		]
	)

	if game.breach == "Deimos":
		defense = max(
			0,
			defense - 1
		)

	if game.breach == "Humbaba":
		defense = max(
			1,
			defense - 1
		)

	return defense


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


static func _castle_tear_available(
	game,
	rules: RuleConfig
) -> bool:
	if rules.castle_tear_uncapped:
		return true

	return int(
		game.get_meta(
			"first_castle_tear_round",
			-1
		)
	) != int(
		game.round
	)


static func _mark_castle_tear_used(
	game
) -> void:
	game.set_meta(
		"first_castle_tear_round",
		int(
			game.round
		)
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

	return _empty_gremory_ruin_trigger()


static func _empty_gremory_ruin_trigger() -> Dictionary:
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

	var harvest_event: Dictionary = _trigger_gremory_harvest(
		game
	)

	game.refresh_derived_values()

	return harvest_event


static func _gain_neutral_tear(
	game
) -> Dictionary:
	game.neutral_tears += 1

	var harvest_event: Dictionary = _trigger_gremory_harvest(
		game
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


static func _gain_soul(
	player,
	amount: int
) -> void:
	player.souls += max(
		0,
		amount
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


static func _highest_card_index(
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

		if card_value > selected_value:
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


static func _pass_result(
	attacker_id: int,
	defender_id: int,
	reason: String
) -> Dictionary:
	return {
		"action": "pass",
		"reason": reason,
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"target_castle": "",
		"destroyed": false,
		"guards_defeated": [],
		"won": false,
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
		"target_castle": "",
		"destroyed": false,
		"guards_defeated": [],
		"won": false,
	}
