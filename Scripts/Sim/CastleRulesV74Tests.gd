class_name CastleRulesV74Tests
extends RefCounted


const CardData = preload("res://Scripts/Sim/Card.gd")
const GameDealFixtureData = preload("res://Scripts/Sim/GameDealFixture.gd")
const HuntResolutionEngineData = preload("res://Scripts/Sim/HuntResolutionEngine.gd")
const SiegeResolutionEngineData = preload("res://Scripts/Sim/SiegeResolutionEngine.gd")
const SummonEngineData = preload("res://Scripts/Sim/SummonEngine.gd")
const ResolutionEngineData = preload("res://Scripts/Sim/ResolutionEngine.gd")
const RoundEngineData = preload("res://Scripts/Sim/RoundEngine.gd")
const RevealEngineData = preload("res://Scripts/Sim/RevealEngine.gd")
const CastleIntegrityRulesData = preload("res://Scripts/Sim/CastleIntegrityRules.gd")


static func run() -> Array[Dictionary]:
	var rules: RuleConfig = RuleConfig.lab_v6_5()
	return [
		_test_locked_profile(rules),
		_test_ward_frontline_lifetime(rules),
		_test_penitent_ward_tax(rules),
		_test_vulture_recon(rules),
		_test_keep_interposition(rules),
		_test_repair_lock_and_repeat(rules),
		_test_bastion_wall_overflow(rules),
		_test_bastion_direct_target(rules),
		_test_circle_blood_conduit(rules),
		_test_circle_blood_offering_no_resummon_tear(rules),
		_test_stockpile_selective_stores(rules),
		_test_siege_engine_operational_gate(rules),
	]


static func _test_locked_profile(rules: RuleConfig) -> Dictionary:
	# CASTLE_RULES_PROFILE_VERSION_SEMANTICS_V1
	# lab_profile_version tracks the measured Balance Lab lineage, not the
	# current SIM/mechanics version. v7.6 Keep/Repair behavior is locked by
	# the explicit flags immediately below.
	if (
		String(rules.lab_profile_version) != "6.8.3-kroni-cannibal-no-gorge"
		or not rules.ward_frontline
		or String(rules.castle_power_gate_mode) != "operational"
		or int(rules.castle_operational_floor) != 7
		or rules.keep_sanctuary
		or not rules.keep_interposition
		or int(rules.keep_fortification) != 3
		or not rules.defunct_repair_lock
		or not rules.bastion_wall
		or int(rules.bastion_lord_def_bonus) != 0
		or not rules.stockpile_filter
		or not rules.circle_blood_conduit
		or not rules.circle_blood_summon
		or String(rules.resummon_tear_mode) != "none"
		or int(rules.ward_offsuit_penalty) != 1
		or String(rules.ward_penalty_exempt_suit) != "Penitent"
		or int(rules.ward_offsuit_floor) != 1
		or bool(rules.keep_ignores_ward_tax)
		or not bool(rules.vulture_recon)
	):
		return _fail(
			"keep_repair_profile",
			"Measured lab lineage or current Keep / Repair profile flags are not canonical."
		)
	return _pass("keep_repair_profile")


static func _test_ward_frontline_lifetime(rules: RuleConfig) -> Dictionary:
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	_prepare_game(game)
	var attacker = game.get_player(0)
	var defender = game.get_player(1)

	attacker.lord = "Deimos"
	attacker.alive = true
	attacker.action = "Hunt"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Lord"
	attacker.committed = _cards(["Butcher:5", "Butcher:1"])

	defender.lord = "Valak"
	defender.alive = true
	defender.action = "Ward"
	defender.tgt_pid = 1
	defender.tgt_type = "Lord"
	defender.ward_target = "Lord"
	defender.committed = _cards(["Penitent:5", "Wright:3"])
	defender.lord_guards.clear()
	defender.sigils["Lord"] = ""

	var resolution: Dictionary = ResolutionEngineData.resolve(game, rules)
	if not defender.alive:
		return _fail("ward_frontline_lifetime", "Higher-initiative Ward vanished before the later Hunt.")
	if not defender.committed.is_empty():
		return _fail("ward_frontline_lifetime", "Ward commitment was not cleaned after both primaries.")

	var stopped_at: String = ""
	for event in resolution.get("action_events", []):
		if int(event.get("player_id", -1)) == 0:
			var action_result = event.get("action_result", {})
			if typeof(action_result) == TYPE_DICTIONARY:
				stopped_at = String(action_result.get("stopped_at", ""))
			break
	if stopped_at != "Ward":
		return _fail("ward_frontline_lifetime", "Incoming Hunt was not stopped at the Ward reinforcement layer.")
	return _pass("ward_frontline_lifetime")


static func _test_penitent_ward_tax(rules: RuleConfig) -> Dictionary:
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	_prepare_game(game)
	var player = game.get_player(0)
	player.action = "Ward"
	player.committed = _cards(["Penitent:5", "Wright:3", "Vulture:1"])
	if int(player.ward_card_value(player.committed[0], rules)) != 5:
		return _fail("penitent_ward_tax", "Penitent did not Ward at printed value.")
	if int(player.ward_card_value(player.committed[1], rules)) != 2:
		return _fail("penitent_ward_tax", "Off-suit Ward did not lose exactly 1 Strength.")
	if int(player.ward_card_value(player.committed[2], rules)) != 1:
		return _fail("penitent_ward_tax", "Ward tax floor dropped a value-1 card below 1.")
	if int(player.ward_reinforcement_value(rules)) != 8:
		return _fail("penitent_ward_tax", "Ward reinforcement total did not use taxed card values.")
	return _pass("penitent_ward_tax")


static func _test_vulture_recon(rules: RuleConfig) -> Dictionary:
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	_prepare_game(game)
	var scout = game.get_player(0)
	var defender = game.get_player(1)
	scout.action = "Hunt"
	scout.tgt_pid = 1
	scout.tgt_type = "Lord"
	scout.committed = _cards(["Vulture:2", "Butcher:3"])
	defender.lord_guards = _cards(["Butcher:5"])
	defender.castle_guards = _cards(["Wright:2", "Penitent:4"])
	var event: Dictionary = RevealEngineData._resolve_vulture_recon(game, scout)
	if not bool(event.get("triggered", false)):
		return _fail("vulture_recon", "Committed Vulture did not trigger Reconnaissance.")
	if String(event.get("zone", "")) != "Castle":
		return _fail("vulture_recon", "Hunt did not scout the opposite Castle Guard area.")
	for card in defender.castle_guards:
		if not bool(card.guard_revealed):
			return _fail("vulture_recon", "Reconnaissance failed to reveal the entire chosen Guard area.")
	if bool(defender.lord_guards[0].guard_revealed):
		return _fail("vulture_recon", "Reconnaissance also revealed the attacked Lord Guard area.")
	var new_guard = CardData.new("Vulture", 5)
	defender.castle_guards.append(new_guard)
	if bool(new_guard.guard_revealed):
		return _fail("vulture_recon", "A newly added Guard incorrectly inherited old Reconnaissance knowledge.")
	return _pass("vulture_recon")


static func _test_keep_interposition(
	rules: RuleConfig
) -> Dictionary:
	# Operational Keep: 6 Hunt Strength -> Fortification 3 -> 3 Keep damage.
	var game = GameDealFixtureData.build_game_deimos_valak_s1(
		rules
	)
	_prepare_game(game)

	var attacker = game.get_player(0)
	var defender = game.get_player(1)

	attacker.lord = "Deimos"
	attacker.alive = true
	attacker.action = "Hunt"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Lord"
	attacker.committed = _cards([
		"Butcher:5",
		"Wright:2",
	])

	defender.lord = "Valak"
	defender.alive = true
	defender.threat = 0
	defender.action = "Pass"
	defender.lord_guards.clear()
	defender.sigils["Lord"] = ""
	_set_castles(
		defender,
		["Keep"]
	)
	defender.castle_integrity["Keep"] = 14

	var result: Dictionary = (
		HuntResolutionEngineData.resolve(
			game,
			rules,
			0
		)
	)

	if not defender.alive:
		return _fail(
			"keep_interposition",
			"Operational Keep failed to interpose before Lord DEF."
		)

	if int(
		result.get(
			"keep_fortification",
			-1
		)
	) != 3:
		return _fail(
			"keep_interposition",
			"Operational Keep did not apply Fortification 3."
		)

	if int(
		defender.castle_integrity.get(
			"Keep",
			0
		)
	) != 11:
		return _fail(
			"keep_interposition",
			"Strength 6 should lose 3 to Fortification and deal exactly 3 Keep damage."
		)

	# Per-player framework overrides the profile value.
	defender.keep_fortification_level = 1

	if int(
		CastleIntegrityRulesData.keep_fortification(
			defender,
			rules
		)
	) != 1:
		return _fail(
			"keep_interposition",
			"Per-player Keep Fortification override did not replace the profile value."
		)

	# Defunct Keep: still a physical wall, but Fortification is zero.
	# Also verify Humbaba immediately loses his fourth Castle Guard slot.
	game = GameDealFixtureData.build_game_deimos_valak_s1(
		rules
	)
	_prepare_game(game)

	attacker = game.get_player(0)
	defender = game.get_player(1)

	attacker.lord = "Deimos"
	attacker.alive = true
	attacker.action = "Hunt"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Lord"
	attacker.committed = _cards([
		"Butcher:5",
		"Butcher:5",
		"Butcher:5",
	])

	defender.lord = "Humbaba"
	defender.alive = true
	defender.threat = 0
	defender.action = "Pass"
	defender.lord_guards.clear()
	defender.sigils["Lord"] = ""
	defender.garrison.clear()

	_set_castles(
		defender,
		["Keep"]
	)

	defender.castle_integrity["Keep"] = 2
	defender.castle_guards = _cards([
		"Butcher:5",
		"Penitent:4",
		"Vulture:3",
		"Wright:1",
	])

	result = HuntResolutionEngineData.resolve(
		game,
		rules,
		0
	)

	if int(
		result.get(
			"keep_fortification",
			-1
		)
	) != 0:
		return _fail(
			"keep_interposition",
			"Defunct Keep incorrectly retained Fortification."
		)

	if not bool(
		result.get(
			"keep_destroyed",
			false
		)
	):
		return _fail(
			"keep_interposition",
			"Defunct Keep did not absorb the Hunt and Ruin at zero Integrity."
		)

	if (
		defender.castles.has("Keep")
		or not defender.ruined_castles.has("Keep")
	):
		return _fail(
			"keep_interposition",
			"Hunt-caused Keep Ruin did not update physical Castle state."
		)

	if defender.castle_guards.size() != 3:
		return _fail(
			"keep_interposition",
			"Humbaba retained an illegal fourth Castle Guard after first Ruin."
		)

	if (
		defender.garrison.size() != 1
		or int(defender.garrison[0].value) != 1
	):
		return _fail(
			"keep_interposition",
			"Humbaba Gate Guard did not return the lowest-value displaced Guard to Garrison."
		)

	return _pass(
		"keep_interposition"
	)


static func _test_repair_lock_and_repeat(
	rules: RuleConfig
) -> Dictionary:
	var game = GameDealFixtureData.build_game_deimos_valak_s1(
		rules
	)
	_prepare_game(game)

	var player = game.get_player(0)

	_set_castles(
		player,
		["Keep"]
	)

	player.hand = _cards([
		"Wright:5",
		"Wright:3",
		"Butcher:5",
		"Butcher:4",
	])

	# Round 1 begins with an Operational Keep, then it is broken to Defunct.
	RoundEngineData.begin_round(
		game,
		1,
		rules
	)

	player.castle_integrity["Keep"] = 6

	# Round 2 must lock Repair on that newly Defunct Keep.
	RoundEngineData.begin_round(
		game,
		2,
		rules
	)

	if not CastleIntegrityRulesData.repair_locked(
		player,
		"Keep",
		rules
	):
		return _fail(
			"repair_lock_and_repeat",
			"Newly Defunct Keep was not Repair-locked for the following round."
		)

	var locked_result: Dictionary = (
		RoundEngineData.resolve_repair_player(
			game,
			0,
			rules,
			{
				"action": "repair",
				"castle": "Keep",
				"payment": ["Wright:5"],
			}
		)
	)

	if (
		String(
			locked_result.get(
				"action",
				""
			)
		) != "invalid"
		or String(
			locked_result.get(
				"reason",
				""
			)
		) != "castle_repair_locked_defunct"
	):
		return _fail(
			"repair_lock_and_repeat",
			"Repair was allowed during the one-round Defunct vulnerability window."
		)

	# It remained Defunct for all of round 2, so round 3 unlocks Repair.
	RoundEngineData.begin_round(
		game,
		3,
		rules
	)

	if CastleIntegrityRulesData.repair_locked(
		player,
		"Keep",
		rules
	):
		return _fail(
			"repair_lock_and_repeat",
			"Defunct Repair lock lasted longer than one round."
		)

	var first_repair: Dictionary = (
		RoundEngineData.resolve_repair_player(
			game,
			0,
			rules,
			{
				"action": "repair",
				"castle": "Keep",
				"payment": ["Wright:5"],
			}
		)
	)

	if (
		String(
			first_repair.get(
				"action",
				""
			)
		) != "repair"
		or int(
			player.castle_integrity.get(
				"Keep",
				0
			)
		) != 11
	):
		return _fail(
			"repair_lock_and_repeat",
			"First unlocked Repair did not restore 5 Integrity."
		)

	var second_repair: Dictionary = (
		RoundEngineData.resolve_repair_player(
			game,
			0,
			rules,
			{
				"action": "repair",
				"castle": "Keep",
				"payment": ["Wright:3"],
			}
		)
	)

	if (
		String(
			second_repair.get(
				"action",
				""
			)
		) != "repair"
		or int(
			player.castle_integrity.get(
				"Keep",
				0
			)
		) != 14
	):
		return _fail(
			"repair_lock_and_repeat",
			"Second Repair in the same Development phase was incorrectly blocked."
		)

	if player.castle_action_used_this_round:
		return _fail(
			"repair_lock_and_repeat",
			"Repair incorrectly consumed the Construction action slot."
		)

	# Construction still consumes its one-per-round Castle action.
	var construct_one: Dictionary = (
		RoundEngineData.resolve_repair_player(
			game,
			0,
			rules,
			{
				"action": "construct",
				"castle": "Bastion",
				"payment": ["Butcher:5"],
			}
		)
	)

	if String(
		construct_one.get(
			"action",
			""
		)
	) != "construct":
		return _fail(
			"repair_lock_and_repeat",
			"Construction failed after repeated Repairs."
		)

	var construct_two: Dictionary = (
		RoundEngineData.resolve_repair_player(
			game,
			0,
			rules,
			{
				"action": "construct",
				"castle": "Stockpile",
				"payment": ["Butcher:4"],
			}
		)
	)

	if (
		String(
			construct_two.get(
				"action",
				""
			)
		) != "invalid"
		or String(
			construct_two.get(
				"reason",
				""
			)
		) != "castle_action_already_used"
	):
		return _fail(
			"repair_lock_and_repeat",
			"Second Construction in one round was not blocked."
		)

	return _pass(
		"repair_lock_and_repeat"
	)


static func _test_bastion_wall_overflow(rules: RuleConfig) -> Dictionary:
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	_prepare_game(game)
	var attacker = game.get_player(0)
	var defender = game.get_player(1)

	attacker.lord = "Orias"
	attacker.alive = true
	attacker.action = "Siege"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Castle"
	attacker.committed = _cards(["Butcher:5", "Butcher:2"])

	defender.lord = "Valak"
	defender.alive = true
	defender.action = "Pass"
	defender.castle_guards.clear()
	defender.sigils["Castle"] = ""
	_set_castles(defender, ["Bastion", "Stockpile"])
	# Bastion is deliberately Defunct. The physical wall must still exist.
	defender.castle_integrity["Bastion"] = 3
	defender.castle_integrity["Stockpile"] = 8

	var result: Dictionary = SiegeResolutionEngineData.resolve(
		game, rules, 0, {"target_castle": "Stockpile"}
	)
	if not bool(result.get("bastion_ruined", false)):
		return _fail("bastion_wall_overflow", "Defunct standing Bastion did not screen the rear Castle.")
	if bool(result.get("target_destroyed", true)):
		return _fail("bastion_wall_overflow", "Rear Stockpile was Ruined instead of receiving only overflow.")
	if defender.castles.has("Bastion") or not defender.castles.has("Stockpile"):
		return _fail("bastion_wall_overflow", "Bastion/Stockpile standing state is wrong after overflow.")
	if int(defender.castle_integrity.get("Stockpile", 0)) != 3:
		return _fail("bastion_wall_overflow", "Eight arriving Strength should route 3 into Bastion and 5 into Stockpile.")
	if game.neutral_tears != 1:
		return _fail("bastion_wall_overflow", "Bastion Ruination skipped the normal Castle Tear consequence.")
	return _pass("bastion_wall_overflow")


static func _test_bastion_direct_target(rules: RuleConfig) -> Dictionary:
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	_prepare_game(game)
	var attacker = game.get_player(0)
	var defender = game.get_player(1)

	attacker.lord = "Orias"
	attacker.alive = true
	attacker.action = "Siege"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Castle"
	attacker.committed = _cards(["Butcher:5", "Butcher:5"])

	defender.action = "Pass"
	defender.castle_guards.clear()
	defender.sigils["Castle"] = ""
	_set_castles(defender, ["Bastion", "Stockpile"])
	defender.castle_integrity["Bastion"] = 3
	defender.castle_integrity["Stockpile"] = 8

	var result: Dictionary = SiegeResolutionEngineData.resolve(
		game, rules, 0, {"target_castle": "Bastion"}
	)
	if not bool(result.get("target_destroyed", false)):
		return _fail("bastion_direct_target", "Explicit direct Siege did not Ruin Bastion.")
	if int(defender.castle_integrity.get("Stockpile", 0)) != 8:
		return _fail("bastion_direct_target", "Direct Bastion target incorrectly spilled into the rear Castle.")
	return _pass("bastion_direct_target")


static func _test_circle_blood_conduit(rules: RuleConfig) -> Dictionary:
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	_prepare_game(game)
	var player = game.get_player(0)
	_set_castles(player, ["SummoningCircle"])
	player.castle_integrity["SummoningCircle"] = 14
	player.threat = 1

	var event: Dictionary = CastleIntegrityRulesData.gain_threat(player, rules, 1)
	if int(player.threat) != 1 or int(event.get("prevented", 0)) != 1:
		return _fail("circle_blood_conduit", "Blood Conduit did not prevent the Threat-2 breakpoint.")
	if int(player.castle_integrity.get("SummoningCircle", 0)) != 11:
		return _fail("circle_blood_conduit", "Blood Conduit did not burn exactly 3 Integrity.")
	return _pass("circle_blood_conduit")


static func _test_circle_blood_offering_no_resummon_tear(rules: RuleConfig) -> Dictionary:
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	_prepare_game(game)
	var player = game.get_player(0)
	player.alive = false
	player.lord_pool.clear()
	player.lord_pool.append("Kalligan")
	player.lord = "Kalligan"
	player.first_summon_done = true
	player.hand = _cards(["Butcher:1"])
	_set_castles(player, ["SummoningCircle"])
	player.castle_integrity["SummoningCircle"] = 14
	game.neutral_tears = 0
	game.breach = ""

	var result: Dictionary = SummonEngineData.resolve_player(
		game, 0, rules, {"lord": "Kalligan", "payment": ["Butcher:1"]}
	)
	if String(result.get("action", "")) != "summon":
		return _fail("circle_blood_offering", "Blood Offering summon did not resolve.")
	if int(result.get("cost", -1)) != 1:
		return _fail("circle_blood_offering", "Printed cost 4 was not reduced to 1 by Blood Offering.")
	if int(player.castle_integrity.get("SummoningCircle", 0)) != 11:
		return _fail("circle_blood_offering", "Blood Offering did not burn exactly 3 Circle Integrity.")
	if game.neutral_tears != 0:
		return _fail("circle_blood_offering", "Resummon incorrectly advanced the Veil.")
	return _pass("circle_blood_offering")


static func _test_stockpile_selective_stores(rules: RuleConfig) -> Dictionary:
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	_prepare_game(game)
	var player = game.get_player(0)
	player.hand.clear()
	_set_castles(player, ["Stockpile"])
	player.castle_integrity["Stockpile"] = 14
	game.deck = _cards([
		"Butcher:1", "Wright:2", "Vulture:3", "Penitent:4",
		"Butcher:5", "Wright:1", "Vulture:2"
	])
	game.discard.clear()

	RoundEngineData._run_draw_step(game, rules)
	if player.hand.size() != 6:
		return _fail("stockpile_selective_stores", "Stockpile should net one extra card after draw 2 / keep 1.")
	if game.discard.size() != 1:
		return _fail("stockpile_selective_stores", "Stockpile did not discard exactly one of the two selection cards.")
	return _pass("stockpile_selective_stores")


static func _test_siege_engine_operational_gate(rules: RuleConfig) -> Dictionary:
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	_prepare_game(game)
	var player = game.get_player(0)
	_set_castles(player, ["SiegeEngine"])
	var wright = CardData.new("Wright", 5)
	player.castle_integrity["SiegeEngine"] = 14
	if int(player.attack_card_value(wright, rules, true)) != 5:
		return _fail("siege_engine_gate", "Operational Siege Engine did not waive the off-suit Siege tax.")
	player.castle_integrity["SiegeEngine"] = 6
	if int(player.attack_card_value(wright, rules, true)) != 4:
		return _fail("siege_engine_gate", "Defunct Siege Engine still waived the off-suit Siege tax.")
	return _pass("siege_engine_gate")


static func _prepare_game(game) -> void:
	game.round = 2
	game.winner = -1
	game.win_by = ""
	game.breach = ""
	game.breach_owner = -1
	game.reflex_winner = -1
	game.neutral_tears = 0
	game.set_meta("first_castle_tear_round", -1)
	game.set_meta("_resolution_committed_values_round", -1)
	game.set_meta("_resolution_committed_values", [])
	for player in game.players:
		player.souls = 0
		player.tears = 0
		player.threat = 0
		player.action = "Pass"
		player.tgt_pid = -1
		player.tgt_type = ""
		player.ward_target = ""
		player.committed.clear()
		player.lord_guards.clear()
		player.castle_guards.clear()
		player.sigils = {"Lord": "", "Castle": ""}
		player.ruined_castles.clear()
		player.profaned_castles.clear()
		player.lost_castles.clear()
		player.ward_turned.clear()


static func _set_castles(player, names: Array) -> void:
	player.castles.clear()
	player.castle_integrity.clear()
	for castle_name: String in names:
		player.castles.append(castle_name)
		player.castle_integrity[castle_name] = CastleIntegrityRulesData.max_integrity(castle_name)


static func _cards(ids: Array) -> Array:
	var out: Array = []
	for card_id: String in ids:
		var parts: PackedStringArray = card_id.split(":")
		out.append(CardData.new(String(parts[0]), int(parts[1])))
	return out


# CASTLE_RULES_TEST_REPORTING_FIX_V1
# GoldenTests/Main consumes the standard {"text", "passed"} result schema.
# Keep name/message too because they are useful to focused callers/debugging.
static func _pass(name: String) -> Dictionary:
	return {
		"name": name,
		"passed": true,
		"message": "",
		"text": "PASS  unit_castle_rules_%s" % name,
	}


static func _fail(name: String, message: String) -> Dictionary:
	return {
		"name": name,
		"passed": false,
		"message": message,
		"text": "FAIL  unit_castle_rules_%s: %s" % [name, message],
	}
