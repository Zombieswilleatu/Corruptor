class_name SiegeResolutionEngine
extends RefCounted


const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
)

const OdradekInterlockEngineData = preload(
	"res://Scripts/Sim/OdradekInterlockEngine.gd"
)

const CastleIntegrityRulesData = preload(
	"res://Scripts/Sim/CastleIntegrityRules.gd"
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
		rules,
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

	# A threshold Ward turns the entire attack. The committed cards remain in
	# the attacker zone for normal aftermath handling.
	if (
		rules.ward_threshold
		and not rules.ward_frontline
		and bool(defender.ward_turned.get(ZONE_CASTLE, false))
	):
		var display_strength: int = attacker.attack_value(rules, true)
		var display_structural_defense: int = _castle_defense(
			game,
			target_castle,
			defender,
			rules
		)
		game.refresh_derived_values()
		return _ward_turned_result(
			attacker_id,
			defender_id,
			target_castle,
			display_strength,
			display_structural_defense
		)

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

	var recoil_result: Dictionary = OdradekInterlockEngineData.empty_result(
		int(defender.pid),
		int(attacker.pid)
	)

	if (
		defender.lord == "Odradek"
		and defender.alive
		and not rules.recoil_hunts_only
	):
		recoil_result = OdradekInterlockEngineData.resolve_recoil(
			game,
			defender,
			attacker,
			rules
		)

	var recoil_card: String = String(
		recoil_result.get(
			"taken_card",
			recoil_result.get("discarded_card", "")
		)
	)

	var strength: int = attacker.attack_value(rules, true)

	strength += _suit_bonus(
		attacker.committed,
		"Butcher"
	)

	var siege_engine_bypass: bool = (
		rules.siege_engine_bypass
		and CastleIntegrityRulesData.power_active(attacker, "SiegeEngine", rules)
		and not reflex
	)

	var war_machine_bonus: int = 0

	if (
		attacker.lord == "Deimos"
		and attacker.alive
		and (
			CastleIntegrityRulesData.power_active(attacker, "SiegeEngine", rules)
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
	var butcher_suppressed_card = null

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
		var suppressed_index: int = _lowest_card_index(
			defender.castle_guards
		)

		butcher_suppressed_card = defender.castle_guards[
			suppressed_index
		]

		defender.castle_guards.remove_at(
			suppressed_index
		)

		game.discard.append(
			butcher_suppressed_card
		)

	# Guard knowledge only exists in Fog-of-War profiles. A Siege turns the
	# Castle Guard area face-up for later reads in those profiles.
	if rules.fog_of_war:
		for guard in defender.castle_guards:
			guard.guard_revealed = true

	var structural_defense: int = _castle_defense(
		game,
		target_castle,
		defender,
		rules
	)

	var ward_commit_defense: int = 0

	if (
		rules.ward_commit_defense
		and defender.action == "Ward"
		and defender.ward_target == ZONE_CASTLE
	):
		ward_commit_defense = _effective_ward_commitment(
			defender,
			rules
		)

	# Historical non-frontline profiles applied the two-Penitent bonus as
	# structure defense. v7.5 frontline Ward folds that same bonus into
	# ward_reinforcement_value(), so it must not be added twice there.
	var penitent_bonus: int = _suit_bonus(
		defender.committed,
		"Penitent"
	)

	var ward_screen: int = ward_commit_defense if rules.ward_frontline else 0
	var structure_screen: int = (
		0 if rules.ward_frontline else ward_commit_defense + penitent_bonus
	)
	var integrity_before: int = structural_defense
	if rules.castle_integrity:
		integrity_before = int(
			defender.castle_integrity.get(
				target_castle,
				CastleIntegrityRulesData.max_integrity(target_castle)
			)
		)
	var structure_vulnerability: int = (
		1
		if game.breach == "Deimos" or game.breach == "Humbaba"
		else 0
	)

	var sigil_state: String = String(
		defender.sigils.get(
			ZONE_CASTLE,
			""
		)
	)

	var sigil_value: int = _sigil_value(
		game,
		defender,
		sigil_state,
		rules
	)

	var combat_result: Dictionary = {}

	var bastion_ruined_this_siege: bool = false
	if rules.castle_integrity:
		var bastion_screening: bool = (
			rules.bastion_wall
			and target_castle != "Bastion"
			and CastleIntegrityRulesData.standing(defender, "Bastion")
		)
		var bastion_before: int = (
			int(defender.castle_integrity.get(
				"Bastion", CastleIntegrityRulesData.max_integrity("Bastion")
			)) if bastion_screening else 0
		)
		var effective_integrity: int = integrity_before + bastion_before

		combat_result = _resolve_integrity_combat(
			game,
			strength,
			defender.castle_guards,
			ignore_lowest,
			sigil_state,
			sigil_value,
			effective_integrity,
			structure_screen,
			siege_engine_bypass,
			structure_vulnerability,
			ward_screen
		)

		var structure_hit: int = int(combat_result.get("structure_hit", 0))
		var remaining_hit: int = structure_hit
		if bastion_screening and remaining_hit > 0:
			var bastion_damage: int = mini(bastion_before, remaining_hit)
			defender.castle_integrity["Bastion"] = bastion_before - bastion_damage
			remaining_hit -= bastion_damage
			bastion_ruined_this_siege = (
				bastion_before > 0
				and int(defender.castle_integrity.get("Bastion", 0)) <= 0
			)

		var target_damage: int = mini(integrity_before, maxi(0, remaining_hit))
		var integrity_after: int = maxi(0, integrity_before - target_damage)
		defender.castle_integrity[target_castle] = integrity_after
		combat_result["integrity_before"] = integrity_before
		combat_result["integrity_after"] = integrity_after
		combat_result["structure_damage"] = target_damage
		combat_result["bastion_screened"] = bastion_screening
		combat_result["bastion_integrity_before"] = bastion_before
		combat_result["bastion_integrity_after"] = int(
			defender.castle_integrity.get("Bastion", 0)
		) if bastion_screening else 0
		combat_result["destroyed"] = integrity_before > 0 and integrity_after == 0
		combat_result["excess"] = maxi(0, remaining_hit - integrity_before)

		assert(
			integrity_after == maxi(0, integrity_before - target_damage),
			"Castle Integrity damage equation diverged."
		)
	else:
		structural_defense += structure_screen
		combat_result = _resolve_combat(
			game,
			strength,
			defender.castle_guards,
			ignore_lowest,
			sigil_state,
			sigil_value,
			structural_defense,
			siege_engine_bypass,
			ward_screen
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

	if (
		rules.momentum
		and destroyed
		and int(game.reflex_winner) < 0
		and excess >= 0
		and excess <= rules.momentum_band
	):
		game.reflex_winner = attacker_id
		attacker.momentum_refund_due += rules.momentum_refund

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

	var consumed: bool = false

	var neutral_tear_gain: int = 0
	var personal_tear_gain: int = 0
	var permanent_loss: bool = false
	var permanent_loss_tear_gain: int = 0

	var tear_source: String = ""

	var harvested_card: String = ""
	var harvested_by: int = -1

	var gremory_ruin_trigger: Dictionary = (
		_empty_gremory_ruin_trigger()
	)

	var inferno_card = null
	var inferno_threat_gain: int = 0

	var wildfire_zone: String = ""

	var ravenous_soul_gain: int = 0

	var siphoned_card = null

	var won_after_tear: bool = false
	var ruined_this_siege: Array[String] = []
	if bastion_ruined_this_siege:
		ruined_this_siege.append("Bastion")
	if destroyed and not ruined_this_siege.has(target_castle):
		ruined_this_siege.append(target_castle)

	# A through-Bastion Siege can Ruin the wall and the rear Castle in one hit.
	# Every Ruination uses the same consequence chain, in physical order.
	for ruin_index: int in range(ruined_this_siege.size()):
		var ruined_castle: String = ruined_this_siege[ruin_index]
		var ruin_event: Dictionary = _apply_castle_ruination(
			game,
			rules,
			attacker,
			defender,
			ruined_castle,
			guards_lost,
			consume_requested and ruin_index == 0,
			use_inferno
		)

		consumed = consumed or bool(ruin_event.get("consumed", false))
		neutral_tear_gain += int(ruin_event.get("neutral_tear_gain", 0))
		personal_tear_gain += int(ruin_event.get("personal_tear_gain", 0))
		permanent_loss = permanent_loss or bool(ruin_event.get("permanent_loss", false))
		permanent_loss_tear_gain += int(
			ruin_event.get("permanent_loss_tear_gain", 0)
		)
		if tear_source.is_empty():
			tear_source = String(ruin_event.get("tear_source", ""))
		if harvested_card.is_empty():
			harvested_card = String(ruin_event.get("harvested_card", ""))
			harvested_by = int(ruin_event.get("harvested_by", -1))
		var gremory_event: Dictionary = ruin_event.get(
			"gremory_ruin_trigger", _empty_gremory_ruin_trigger()
		)
		if bool(gremory_event.get("triggered", false)):
			gremory_ruin_trigger = gremory_event
		var ruin_inferno_card = ruin_event.get("inferno_card", null)
		if ruin_inferno_card != null:
			inferno_card = ruin_inferno_card
		inferno_threat_gain += int(ruin_event.get("inferno_threat_gain", 0))
		var ruin_wildfire_zone: String = String(ruin_event.get("wildfire_zone", ""))
		if not ruin_wildfire_zone.is_empty():
			wildfire_zone = ruin_wildfire_zone
		ravenous_soul_gain += int(ruin_event.get("ravenous_soul_gain", 0))
		if bool(ruin_event.get("won", false)):
			won_after_tear = true
			break

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
		"structure_screen": structure_screen,
		"integrity_before": int(combat_result.get("integrity_before", 0)),
		"integrity_after": int(combat_result.get("integrity_after", 0)),
		"structure_hit": int(combat_result.get("structure_hit", 0)),
		"structure_damage": int(combat_result.get("structure_damage", 0)),
		"structure_spill": int(combat_result.get("structure_spill", 0)),
		"ward_commit_defense": ward_commit_defense,
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
		"butcher_suppressed_card": (
			""
			if butcher_suppressed_card == null
			else _card_id(
				butcher_suppressed_card
			)
		),
		"sigil_state": sigil_state,
		"sigil_value": sigil_value,
		"guards_defeated": _card_ids(
			guards_defeated
		),
		"sigil_broken": sigil_broken,
		"destroyed": not ruined_this_siege.is_empty(),
		"target_destroyed": destroyed,
		"bastion_ruined": bastion_ruined_this_siege,
		"excess": excess,
		"stopped_at": String(
			combat_result.get(
				"stopped_at",
				""
			)
		),
		"recoil_card": recoil_card,
		"recoil_result": recoil_result,
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
		"permanent_loss": permanent_loss,
		"permanent_loss_tear_gain": permanent_loss_tear_gain,
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
		"inferno_threat_gain": inferno_threat_gain,
		"wildfire_zone": wildfire_zone,
		"ravenous_soul_gain": (
			ravenous_soul_gain
		),
		"won": won,
	}


static func _apply_castle_ruination(
	game,
	rules: RuleConfig,
	attacker,
	defender,
	castle_name: String,
	guards_lost: int,
	consume_requested: bool,
	use_inferno: bool
) -> Dictionary:
	var result: Dictionary = {
		"consumed": false,
		"neutral_tear_gain": 0,
		"personal_tear_gain": 0,
		"permanent_loss": false,
		"permanent_loss_tear_gain": 0,
		"tear_source": "",
		"harvested_card": "",
		"harvested_by": -1,
		"gremory_ruin_trigger": _empty_gremory_ruin_trigger(),
		"inferno_card": null,
		"inferno_threat_gain": 0,
		"wildfire_zone": "",
		"ravenous_soul_gain": 0,
		"won": false,
	}

	if not defender.castles.has(castle_name):
		return result

	defender.castles.erase(castle_name)
	if rules.castle_integrity:
		defender.castle_integrity[castle_name] = 0
		defender.castle_construction_progress.erase(castle_name)

	if (
		rules.castle_permanent_loss
		and int(defender.castle_scars.get(castle_name, 0)) >= 1
	):
		result["permanent_loss"] = true
		if not defender.lost_castles.has(castle_name):
			defender.lost_castles.append(castle_name)
		if rules.veil_on_permanent_loss:
			_gain_neutral_tear(game)
			result["neutral_tear_gain"] = int(result["neutral_tear_gain"]) + 1
			result["permanent_loss_tear_gain"] = 1
	elif not defender.ruined_castles.has(castle_name):
		defender.ruined_castles.append(castle_name)

	_mark_destruction(game)
	if attacker.lord == "Kroni":
		attacker.kroni_enemy_destroyed = true

	var consumed: bool = consume_requested and rules.consume_the_siege
	result["consumed"] = consumed

	if _castle_tear_available(game, rules):
		var tear_event: Dictionary = {}
		if consumed:
			tear_event = _gain_personal_tear(game, attacker)
			result["personal_tear_gain"] = int(result["personal_tear_gain"]) + 1
			result["tear_source"] = "consume_siege"
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
			tear_event = _gain_personal_tear(game, attacker)
			result["personal_tear_gain"] = int(result["personal_tear_gain"]) + 1
			result["tear_source"] = "deimos_claim"
		else:
			tear_event = _gain_neutral_tear(game)
			result["neutral_tear_gain"] = int(result["neutral_tear_gain"]) + 1
			result["tear_source"] = "neutral"

		_mark_castle_tear_used(game)
		result["harvested_card"] = String(tear_event.get("harvested_card", ""))
		result["harvested_by"] = int(tear_event.get("harvested_by", -1))
		if _check_win(game, rules):
			result["won"] = true
			return result

	if not consumed:
		var base_soul_reward: int = 2 if guards_lost > 0 else 1
		var ruination_bonus: int = (
			rules.ruination_soul_bonus
			if rules.ruination_soul_source == "enemy_siege"
			else 0
		)
		_gain_soul(attacker, base_soul_reward + ruination_bonus)

	result["gremory_ruin_trigger"] = _trigger_gremory_ruin(game)

	if attacker.lord == "Kalligan" and attacker.alive:
		var wildfire_target: int = int(defender.pid)
		var wildfire_type: String = "Lord" if defender.castles.is_empty() else "Castle"
		if (
			int(game.persist_scorch_pid) != wildfire_target
			or String(game.persist_scorch_type) != wildfire_type
		):
			game.persist_scorch_level = 1
		game.persist_scorch_pid = wildfire_target
		game.persist_scorch_type = wildfire_type
		result["wildfire_zone"] = String(game.persist_scorch_type)

		if (
			use_inferno
			and (attacker.threat < rules.max_threat or not rules.kal_inferno_threat)
		):
			if rules.kal_inferno_threat:
				var threat_before: int = int(attacker.threat)
				CastleIntegrityRulesData.gain_threat(attacker, rules, 1)
				result["inferno_threat_gain"] = int(attacker.threat) - threat_before
			if not defender.lord_guards.is_empty():
				var highest_index: int = _highest_card_index(defender.lord_guards)
				var inferno_card = defender.lord_guards[highest_index]
				defender.lord_guards.remove_at(highest_index)
				game.discard.append(inferno_card)
				result["inferno_card"] = inferno_card
			else:
				game.persist_scorch_pid = int(defender.pid)
				game.persist_scorch_type = "Lord"
			result["wildfire_zone"] = String(game.persist_scorch_type)

	if (
		attacker.lord == "Kroni"
		and attacker.alive
		and attacker.kroni_hunger >= 3
		and not attacker.kroni_ravenous_used
	):
		_gain_soul(attacker, 2)
		result["ravenous_soul_gain"] = 2
		var hunger_event: Dictionary = _gain_kroni_hunger(game, attacker)
		result["personal_tear_gain"] = int(result["personal_tear_gain"]) + int(
			hunger_event.get("personal_tear_gain", 0)
		)
		if String(result["harvested_card"]).is_empty():
			result["harvested_card"] = String(hunger_event.get("harvested_card", ""))
			result["harvested_by"] = int(hunger_event.get("harvested_by", -1))
		attacker.kroni_ravenous_used = true

	return result


static func _ward_turned_result(
	attacker_id: int,
	defender_id: int,
	target_castle: String,
	strength: int,
	structural_defense: int
) -> Dictionary:
	return {
		"action": "siege",
		"reason": "ward_turned",
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"target_castle": target_castle,
		"reflex": false,
		"strength": strength,
		"war_machine_bonus": 0,
		"pyroclasm_bonus": 0,
		"structural_defense": structural_defense,
		"penitent_bonus": 0,
		"siege_engine_bypass": false,
		"fear_returned_card": "",
		"ignore_lowest_guard": false,
		"butcher_suppressed_card": "",
		"sigil_state": "",
		"sigil_value": 0,
		"guards_defeated": [],
		"sigil_broken": false,
		"destroyed": false,
		"excess": 0,
		"stopped_at": "ward_turned",
		"recoil_card": "",
		"siphoned_card": "",
		"consumed": false,
		"soul_gain": 0,
		"neutral_tear_gain": 0,
		"personal_tear_gain": 0,
		"permanent_loss": false,
		"permanent_loss_tear_gain": 0,
		"tear_source": "",
		"harvested_card": "",
		"harvested_by": -1,
		"gremory_ruin_trigger": _empty_gremory_ruin_trigger(),
		"inferno_card": "",
		"inferno_threat_gain": 0,
		"wildfire_zone": "",
		"ravenous_soul_gain": 0,
		"won": false,
	}


static func _resolve_integrity_combat(
	game,
	strength: int,
	guard_zone: Array,
	ignore_lowest: bool,
	sigil_state: String,
	sigil_value: int,
	integrity_before: int,
	structure_screen: int,
	bypass: bool,
	structure_vulnerability: int,
	ward_screen: int = 0
) -> Dictionary:
	var remaining: int = strength
	var guards_defeated: Array = []
	var sigil_broken: bool = false

	# v7.4: Ward is first contact, before bypass/Guards/Sigil/structures.
	if ward_screen > 0:
		if remaining <= ward_screen:
			return _integrity_combat_result(
				false, false, 0, "Ward", guards_defeated,
				0, 0, 0
			)
		remaining -= ward_screen

	if bypass:
		var bypass_sigil_result: Dictionary = _resolve_sigil_layer(
			remaining,
			sigil_state,
			sigil_value
		)
		if bool(bypass_sigil_result.get("stopped", false)):
			return _integrity_combat_result(
				false, false, 0, "Sigil", guards_defeated,
				0, 0, 0
			)
		sigil_broken = bool(bypass_sigil_result.get("broken", false))
		remaining = int(bypass_sigil_result.get("remaining", remaining))
		remaining -= maxi(0, structure_screen)
		if remaining <= 0:
			return _integrity_combat_result(
				false, sigil_broken, 0, "Castle", guards_defeated,
				0, 0, 0
			)

		var bypass_structure_hit: int = maxi(
			1,
			remaining + maxi(0, structure_vulnerability)
		)
		var bypass_structure_damage: int = mini(
			maxi(0, integrity_before),
			bypass_structure_hit
		)
		var structure_spill: int = maxi(
			0,
			bypass_structure_hit - maxi(0, integrity_before)
		)
		var bypass_destroyed: bool = (
			integrity_before > 0
			and bypass_structure_damage >= integrity_before
		)
		if not bypass_destroyed:
			return _integrity_combat_result(
				false, sigil_broken, bypass_structure_hit - integrity_before,
				"Castle", guards_defeated,
				bypass_structure_hit, bypass_structure_damage, structure_spill
			)

		var bypass_guard_result: Dictionary = _strip_guards(
			game,
			structure_spill,
			guard_zone,
			ignore_lowest
		)
		guards_defeated = bypass_guard_result.get("guards_defeated", [])
		if bool(bypass_guard_result.get("stopped", false)):
			return _integrity_combat_result(
				true, sigil_broken, 0, "Guard", guards_defeated,
				bypass_structure_hit, bypass_structure_damage, structure_spill
			)
		return _integrity_combat_result(
			true, sigil_broken,
			int(bypass_guard_result.get("remaining", 0)), "", guards_defeated,
			bypass_structure_hit, bypass_structure_damage, structure_spill
		)

	var guard_result: Dictionary = _strip_guards(
		game,
		remaining,
		guard_zone,
		ignore_lowest
	)
	guards_defeated = guard_result.get("guards_defeated", [])
	if bool(guard_result.get("stopped", false)):
		return _integrity_combat_result(
			false, false, 0, "Guard", guards_defeated,
			0, 0, 0
		)
	remaining = int(guard_result.get("remaining", remaining))

	var sigil_result: Dictionary = _resolve_sigil_layer(
		remaining,
		sigil_state,
		sigil_value
	)
	if bool(sigil_result.get("stopped", false)):
		return _integrity_combat_result(
			false, false, 0, "Sigil", guards_defeated,
			0, 0, 0
		)
	sigil_broken = bool(sigil_result.get("broken", false))
	remaining = int(sigil_result.get("remaining", remaining))
	remaining -= maxi(0, structure_screen)
	if remaining <= 0:
		return _integrity_combat_result(
			false, sigil_broken, 0, "Castle", guards_defeated,
			0, 0, 0
		)

	var structure_hit: int = maxi(
		1,
		remaining + maxi(0, structure_vulnerability)
	)
	var structure_damage: int = mini(
		maxi(0, integrity_before),
		structure_hit
	)
	var destroyed: bool = integrity_before > 0 and structure_damage >= integrity_before
	return _integrity_combat_result(
		destroyed,
		sigil_broken,
		structure_hit - integrity_before,
		"" if destroyed else "Castle",
		guards_defeated,
		structure_hit,
		structure_damage,
		0
	)


static func _integrity_combat_result(
	destroyed: bool,
	sigil_broken: bool,
	excess: int,
	stopped_at: String,
	guards_defeated: Array,
	structure_hit: int,
	structure_damage: int,
	structure_spill: int
) -> Dictionary:
	return {
		"destroyed": destroyed,
		"sigil_broken": sigil_broken,
		"excess": excess,
		"stopped_at": stopped_at,
		"guards_defeated": guards_defeated,
		"structure_hit": structure_hit,
		"structure_damage": structure_damage,
		"structure_spill": structure_spill,
	}


static func _resolve_combat(
	game,
	strength: int,
	guard_zone: Array,
	ignore_lowest: bool,
	sigil_state: String,
	sigil_value: int,
	structural_defense: int,
	bypass: bool,
	ward_screen: int = 0
) -> Dictionary:
	var remaining: int = strength
	var guards_defeated: Array = []

	if ward_screen > 0:
		if remaining <= ward_screen:
			return {
				"destroyed": false,
				"sigil_broken": false,
				"excess": 0,
				"stopped_at": "Ward",
				"guards_defeated": guards_defeated,
			}
		remaining -= ward_screen

	if bypass:
		var bypass_sigil_result: Dictionary = (
			_resolve_sigil_layer(
				remaining,
				sigil_state,
				sigil_value
			)
		)

		var bypass_sigil_broken: bool = bool(
			bypass_sigil_result.get(
				"broken",
				false
			)
		)

		if bool(
			bypass_sigil_result.get(
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
			bypass_sigil_result.get(
				"remaining",
				remaining
			)
		)

		if remaining <= structural_defense:
			return {
				"destroyed": false,
				"sigil_broken": bypass_sigil_broken,
				"excess": 0,
				"stopped_at": "Castle",
				"guards_defeated": guards_defeated,
			}

		remaining -= structural_defense

		var bypass_guard_result: Dictionary = (
			_strip_guards(
				game,
				remaining,
				guard_zone,
				ignore_lowest
			)
		)

		guards_defeated = bypass_guard_result.get(
			"guards_defeated",
			[]
		)

		if bool(
			bypass_guard_result.get(
				"stopped",
				false
			)
		):
			return {
				"destroyed": true,
				"sigil_broken": bypass_sigil_broken,
				"excess": 0,
				"stopped_at": "Guard",
				"guards_defeated": guards_defeated,
			}

		return {
			"destroyed": true,
			"sigil_broken": bypass_sigil_broken,
			"excess": int(
				bypass_guard_result.get(
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
	rules: RuleConfig,
	requested_castle: String
) -> String:
	if defender.castles.has(
		requested_castle
	):
		return requested_castle

	var selected_castle: String = ""
	var selected_defense: int = 1000000

	for raw_castle_name in defender.castles:
		var castle_name: String = String(raw_castle_name)
		if (
			rules.bastion_wall
			and castle_name == "Bastion"
			and CastleIntegrityRulesData.standing(defender, "Bastion")
			and defender.castles.size() > 1
		):
			continue

		var defense: int = _castle_defense(
			game,
			castle_name,
			defender,
			rules
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
	castle_name: String,
	defender = null,
	rules: RuleConfig = null
) -> int:
	if not CASTLE_DEFENSES.has(
		castle_name
	):
		return 0

	if rules != null and rules.castle_integrity and defender != null:
		var integrity_defense: int = int(
			defender.castle_integrity.get(
				castle_name,
				CastleIntegrityRulesData.max_integrity(castle_name)
			)
		)
		if game.breach == "Deimos":
			integrity_defense = maxi(0, integrity_defense - 1)
		elif game.breach == "Humbaba":
			integrity_defense = maxi(1, integrity_defense - 1)
		return integrity_defense

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

	if (
		rules != null
		and rules.castle_scarring
		and defender != null
	):
		defense = max(
			1,
			defense - (
				int(defender.castle_scars.get(castle_name, 0))
				* rules.castle_scar_def
			)
		)

	return defense


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

		player.gremory_veil_draw_done = true

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

	if player.castles.has("Bastion"):
		defense += maxi(0, int(rules.bastion_lord_def_bonus))

	return max(
		0,
		defense
	)


static func _sigil_value(
	game,
	player,
	sigil_state: String,
	rules: RuleConfig = null
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

	if rules != null and rules.sigil_flat:
		return value

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


static func _effective_ward_commitment(
	player,
	rules: RuleConfig
) -> int:
	if rules.ward_frontline:
		return int(player.ward_reinforcement_value(rules))

	# Frozen DE-v2 / historical path. Keep byte-for-behavior compatibility
	# with the pre-v7.5 Siege resolver when Ward was not a frontline layer.
	var total: int = _committed_value(
		player.committed
	)

	if (
		rules.humbaba_sigil_commit
		and player.lord == "Humbaba"
	):
		total += 2

		if player.castles.has("Keep"):
			total += 1

	return total


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
