class_name CastleIntegrityTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameStateData = preload(
	"res://Scripts/Sim/GameState.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const CastleIntegrityRulesData = preload(
	"res://Scripts/Sim/CastleIntegrityRules.gd"
)

const SiegeResolutionEngineData = preload(
	"res://Scripts/Sim/SiegeResolutionEngine.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)

const ProfaneResolutionEngineData = preload(
	"res://Scripts/Sim/ProfaneResolutionEngine.gd"
)


static func run(_baseline_rules: RuleConfig) -> Array:
	return [
		_test_profile_contract(),
		_test_opening_loadout(),
		_test_direct_integrity_damage(),
		_test_breach_vulnerability_preserves_integrity_baseline(),
		_test_equal_strength_ruination(),
		_test_structure_first_spill(),
		_test_attack_tax_and_forge(),
		_test_granular_repair(),
		_test_wright_repair_tax_accepts_offsuit(),
		_test_granular_construction(),
		_test_irreparable_ruination(),
		_test_profane_burns_type_without_soul_bonus(),
		_test_damaged_profane_is_rejected(),
		_test_doctrine_denominator(),
	]


static func _test_profile_contract() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	if (
		rules.lab_profile_version != "7.5.0-suit-identities"
		or not rules.castle_loadout
		or rules.starting_castles != 3
		or rules.castle_type_count != 5
		or rules.castle_doctrine_denominator != 5
		or not rules.castle_integrity
		or not rules.castle_granular_repair
		or not rules.castle_construction
		or not rules.castle_irreparable
		or rules.castle_damage_mode != "arriving_strength"
		or rules.castle_construction_mode != "granular"
		or rules.castle_action_limit != 1
		or rules.siege_engine_bypass
		or rules.siege_engine_scope != "siege"
		or rules.attack_offsuit_penalty != 1
		or rules.construction_action_cap != 5
		or rules.repair_wright_mode != "tax"
		or not rules.profane_requires_full_integrity
		or rules.ruination_soul_bonus != 1
		or rules.ruination_soul_source != "enemy_siege"
		or rules.castle_scarring
		or rules.castle_permanent_loss
		or not rules.profane_no_castle_gate
	):
		return _fail(
			"unit_castle_integrity_profile",
			"Castle Integrity profile contract drifted."
		)
	return _pass("unit_castle_integrity_profile")


static func _test_opening_loadout() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
	var deimos = game.players[0]
	var valak = game.players[1]
	var expected_deimos: Array[String] = [
		"SiegeEngine", "Bastion", "Stockpile",
	]
	var expected_valak: Array[String] = [
		"SiegeEngine", "Keep", "Bastion",
	]
	if deimos.castles != expected_deimos or valak.castles != expected_valak:
		return _fail(
			"unit_castle_integrity_loadout",
			"Setup did not select each Lord's first three Castle priorities."
		)
	for player in game.players:
		for castle_name: String in player.castles:
			if int(player.castle_integrity.get(castle_name, 0)) != 14:
				return _fail(
					"unit_castle_integrity_loadout",
					"Opening Castle did not begin at flat 14 Integrity."
				)
	return _pass("unit_castle_integrity_loadout")


static func _test_direct_integrity_damage() -> Dictionary:
	var fixture: Dictionary = _siege_fixture(14, false)
	var game = fixture["game"]
	var attacker = fixture["attacker"]
	var defender = fixture["defender"]
	attacker.committed = [CardData.new("Vulture", 5)]
	var result: Dictionary = SiegeResolutionEngineData.resolve(
		game,
		fixture["rules"],
		0,
		{"target_castle": "Keep"}
	)
	if (
		bool(result.get("destroyed", true))
		or int(result.get("structure_hit", 0)) != 4
		or int(result.get("structure_damage", 0)) != 4
		or int(result.get("structure_spill", -1)) != 0
		or int(defender.castle_integrity.get("Keep", 0)) != 10
	):
		return _fail(
			"unit_castle_integrity_direct_damage",
			"Arriving Strength did not directly remove Integrity."
		)
	return _pass("unit_castle_integrity_direct_damage")


static func _test_breach_vulnerability_preserves_integrity_baseline() -> Dictionary:
	for breach_name: String in ["Deimos", "Humbaba"]:
		var fixture: Dictionary = _siege_fixture(14, false)
		var game = fixture["game"]
		var attacker = fixture["attacker"]
		var defender = fixture["defender"]
		game.breach = breach_name
		attacker.committed = [CardData.new("Vulture", 5)]
		var result: Dictionary = SiegeResolutionEngineData.resolve(
			game, fixture["rules"], 0, {"target_castle": "Keep"}
		)
		if (
			int(result.get("integrity_before", 0)) != 14
			or int(result.get("structure_hit", 0)) != 5
			or int(result.get("structure_damage", 0)) != 5
			or int(result.get("integrity_after", 0)) != 9
			or int(defender.castle_integrity.get("Keep", 0)) != 9
		):
			return _fail(
				"unit_castle_integrity_breach_vulnerability",
				"%s Breach altered the Integrity baseline instead of adding exactly +1 incoming structure damage." % breach_name
			)
	return _pass("unit_castle_integrity_breach_vulnerability")


static func _test_equal_strength_ruination() -> Dictionary:
	var fixture: Dictionary = _siege_fixture(14, false)
	var game = fixture["game"]
	var attacker = fixture["attacker"]
	var defender = fixture["defender"]
	attacker.committed = [
		CardData.new("Butcher", 5),
		CardData.new("Butcher", 5),
		CardData.new("Butcher", 4),
	]
	var result: Dictionary = SiegeResolutionEngineData.resolve(
		game,
		fixture["rules"],
		0,
		{"target_castle": "Keep"}
	)
	if (
		not bool(result.get("destroyed", false))
		or int(result.get("structure_damage", 0)) != 14
		or int(defender.castle_integrity.get("Keep", -1)) != 0
		or defender.castles.has("Keep")
		or not defender.ruined_castles.has("Keep")
		or int(attacker.souls) != 2
	):
		return _fail(
			"unit_castle_integrity_equal_ruin",
			"Equal arriving Strength did not Ruin or pay base+1 Soul."
		)
	return _pass("unit_castle_integrity_equal_ruin")


static func _test_structure_first_spill() -> Dictionary:
	var fixture: Dictionary = _siege_fixture(4, true)
	var game = fixture["game"]
	var attacker = fixture["attacker"]
	var defender = fixture["defender"]
	var guard = CardData.new("Penitent", 3)
	defender.castle_guards = [guard]
	attacker.committed = [
		CardData.new("Vulture", 5),
		CardData.new("Wright", 3),
	]
	var result: Dictionary = SiegeResolutionEngineData.resolve(
		game,
		fixture["rules"],
		0,
		{"target_castle": "Keep"}
	)
	if (
		int(result.get("structure_hit", 0)) != 5
		or int(result.get("structure_damage", 0)) != 4
		or int(result.get("structure_spill", 0)) != 0
		or not defender.castle_guards.is_empty()
		or not game.discard.has(guard)
	):
		return _fail(
			"unit_castle_integrity_spill",
			"Forge Discipline should keep printed Siege values without reordering Guards."
		)
	return _pass("unit_castle_integrity_spill")


static func _test_attack_tax_and_forge() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game = _state("Orias", "Valak")
	var player = game.players[0]
	player.committed = [
		CardData.new("Butcher", 2),
		CardData.new("Vulture", 2),
		CardData.new("Penitent", 1),
	]
	if player.attack_value(rules, false) != 4:
		return _fail("unit_suit_economy_attack_tax", "Hunt did not tax non-Butchers with floor 1.")
	if player.attack_value(rules, true) != 4:
		return _fail("unit_suit_economy_attack_tax", "Ordinary Siege did not use the same tax.")
	player.castles.append("SiegeEngine")
	if player.attack_value(rules, true) != 5 or player.attack_value(rules, false) != 4:
		return _fail("unit_suit_economy_forge", "Forge Discipline did not exempt Sieges only.")
	rules.siege_engine_scope = "all"
	if player.attack_value(rules, false) != 5:
		return _fail("unit_suit_economy_forge_scope", "Siege Engine scope=all did not exempt Hunts.")
	rules.siege_engine_scope = "siege"
	return _pass("unit_suit_economy_attack_tax_and_forge")


static func _test_granular_repair() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game = _state("Orias", "Valak")
	var player = game.players[0]
	player.castles.clear()
	player.castles.append("Keep")
	player.castle_integrity = {"Keep": 4}
	player.hand = [
		CardData.new("Wright", 4),
		CardData.new("Wright", 3),
		CardData.new("Wright", 3),
	]
	var result: Dictionary = RoundEngineData.resolve_repair_player(
		game,
		0,
		rules,
		{
			"action": "repair",
			"castle": "Keep",
			"payment": ["Wright:4", "Wright:3", "Wright:3"],
		}
	)
	if (
		String(result.get("action", "")) != "repair"
		or int(player.castle_integrity.get("Keep", 0)) != 14
		or not player.hand.is_empty()
		or not player.castle_action_used_this_round
	):
		return _fail(
			"unit_castle_integrity_repair",
			"Granular Repair did not spend multiple cards and restore exact value."
		)
	return _pass("unit_castle_integrity_repair")


static func _test_wright_repair_tax_accepts_offsuit() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game = _state("Orias", "Valak")
	var player = game.players[0]
	player.castles.clear()
	player.castles.append("Keep")
	player.castle_integrity = {"Keep": 10}
	player.hand = [CardData.new("Butcher", 4)]

	var result: Dictionary = RoundEngineData.resolve_repair_player(
		game,
		0,
		rules,
		{
			"action": "repair",
			"castle": "Keep",
			"payment": ["Butcher:4"],
		}
	)

	if (
		String(result.get("action", "")) != "repair"
		or int(result.get("effective_paid_total", 0)) != 3
		or int(player.castle_integrity.get("Keep", 0)) != 13
		or not player.hand.is_empty()
	):
		return _fail(
			"unit_suit_economy_wright_repair",
			"Off-suit Repair did not pay printed value -1 (floor 1)."
		)

	return _pass("unit_suit_economy_wright_repair")


static func _test_granular_construction() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game = _state("Orias", "Valak")
	var player = game.players[0]
	player.castles.clear()
	for castle_name: String in ["SiegeEngine", "Bastion", "Stockpile"]:
		player.castles.append(castle_name)
	player.castle_integrity = {"SiegeEngine": 14, "Bastion": 14, "Stockpile": 14}
	player.hand = [CardData.new("Butcher", 5), CardData.new("Wright", 3)]
	var first: Dictionary = RoundEngineData.resolve_repair_player(
		game, 0, rules, {"action": "construct", "castle": "SummoningCircle", "payment": ["Butcher:5", "Wright:3"]}
	)
	player.castle_action_used_this_round = false
	player.hand = [CardData.new("Vulture", 5), CardData.new("Penitent", 1)]
	var second: Dictionary = RoundEngineData.resolve_repair_player(
		game, 0, rules, {"action": "construct", "castle": "SummoningCircle", "payment": ["Vulture:5", "Penitent:1"]}
	)
	player.castle_action_used_this_round = false
	player.hand = [CardData.new("Butcher", 4)]
	var third: Dictionary = RoundEngineData.resolve_repair_player(
		game, 0, rules, {"action": "construct", "castle": "SummoningCircle", "payment": ["Butcher:4"]}
	)
	if (
		int(first.get("progress_after", 0)) != 5
		or int(second.get("progress_after", 0)) != 10
		or bool(first.get("completed", true))
		or bool(second.get("completed", true))
		or not bool(third.get("completed", false))
		or not player.castles.has("SummoningCircle")
		or int(player.castle_integrity.get("SummoningCircle", 0)) != 14
	):
		return _fail(
			"unit_castle_integrity_construction",
			"Construction did not obey the five-Integrity per-action progress cap."
		)
	return _pass("unit_castle_integrity_construction")


static func _test_irreparable_ruination() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game = _state("Orias", "Valak")
	var player = game.players[0]
	player.castles.clear()
	for castle_name: String in ["Bastion", "Stockpile", "SiegeEngine"]:
		player.castles.append(castle_name)
	player.ruined_castles.clear()
	player.ruined_castles.append("Keep")
	player.castle_integrity = {"Keep": 0}
	player.hand = [CardData.new("Butcher", 5)]
	var result: Dictionary = RoundEngineData.resolve_repair_player(
		game, 0, rules,
		{
			"action": "construct",
			"castle": "Keep",
			"payment": ["Butcher:5"],
		}
	)
	if (
		String(result.get("reason", "")) != "castle_type_burned"
		or player.castles.has("Keep")
		or not player.ruined_castles.has("Keep")
		or player.hand.size() != 1
	):
		return _fail(
			"unit_castle_integrity_irreparable",
			"Ruined Castle type was repairable or constructible."
		)
	return _pass("unit_castle_integrity_irreparable")


static func _test_profane_burns_type_without_soul_bonus() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game = _state("Orias", "Valak")
	var player = game.players[0]
	player.castles.clear()
	player.castles.append("Keep")
	player.castle_integrity = {"Keep": 14}
	player.action = "Profane"
	player.tgt_pid = 0
	player.tgt_type = "Castle"
	player.pending_profane = "Keep"
	var souls_before: int = int(player.souls)
	var result: Dictionary = ProfaneResolutionEngineData.resolve(
		game,
		rules,
		0,
		{"target_castle": "Keep"}
	)
	if (
		not bool(result.get("profaned", false))
		or int(player.castle_integrity.get("Keep", -1)) != 0
		or player.castles.has("Keep")
		or int(player.souls) != souls_before
	):
		return _fail(
			"unit_castle_integrity_profane",
			"Profane did not burn the Castle type without Ruination Soul."
		)
	return _pass("unit_castle_integrity_profane")


static func _test_damaged_profane_is_rejected() -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game = _state("Orias", "Valak")
	var player = game.players[0]
	player.castles.clear()
	player.castles.append("Keep")
	player.castle_integrity = {"Keep": 13}
	player.action = "Profane"
	player.tgt_pid = 0
	player.tgt_type = "Castle"
	player.pending_profane = "Keep"
	var result: Dictionary = ProfaneResolutionEngineData.resolve(game, rules, 0, {"target_castle": "Keep"})
	if String(result.get("reason", "")) != "profane_requires_full_integrity" or not player.castles.has("Keep"):
		return _fail("unit_suit_economy_profane_full", "Damaged Castle was allowed to Profane.")
	return _pass("unit_suit_economy_profane_full")


static func _test_doctrine_denominator() -> Dictionary:
	if (
		not is_equal_approx(CastleIntegrityRulesData.board_fraction(0, 5), 0.0)
		or not is_equal_approx(CastleIntegrityRulesData.board_fraction(3, 5), 0.6)
		or not is_equal_approx(CastleIntegrityRulesData.board_fraction(4, 5), 0.8)
		or not is_equal_approx(CastleIntegrityRulesData.board_fraction(5, 5), 1.0)
		or not is_equal_approx(CastleIntegrityRulesData.board_fraction(6, 5), 1.0)
	):
		return _fail(
			"unit_castle_integrity_denominator",
			"Castle doctrine denominator did not normalize against all five types."
		)
	return _pass("unit_castle_integrity_denominator")


static func _siege_fixture(
	integrity: int,
	with_siege_engine: bool
) -> Dictionary:
	var rules := RuleConfig.lab_v6_5()
	var game = _state("Orias", "Valak")
	var attacker = game.players[0]
	var defender = game.players[1]
	attacker.action = "Siege"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Castle"
	attacker.castles.clear()
	if with_siege_engine:
		attacker.castles.append("SiegeEngine")
	defender.castles.clear()
	defender.castles.append("Keep")
	defender.castle_integrity = {"Keep": integrity}
	defender.castle_guards.clear()
	defender.committed.clear()
	defender.sigils = {"Lord": "", "Castle": ""}
	return {
		"rules": rules,
		"game": game,
		"attacker": attacker,
		"defender": defender,
	}


static func _state(
	lord_zero: String,
	lord_one: String
):
	var game = GameStateData.new([lord_zero], [lord_one])
	game.players[0].lord = lord_zero
	game.players[1].lord = lord_one
	game.players[0].alive = true
	game.players[1].alive = true
	return game


static func _pass(test_name: String) -> Dictionary:
	return {
		"passed": true,
		"text": "PASS  %s" % test_name,
	}


static func _fail(test_name: String, why: String) -> Dictionary:
	return {
		"passed": false,
		"text": "FAIL  %s — %s" % [test_name, why],
	}
