class_name BotDevelopmentDoctrineTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const PythonRandomData = preload(
	"res://Scripts/Sim/PythonRandom.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)

const SummonEngineData = preload(
	"res://Scripts/Sim/SummonEngine.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const BotDevelopmentDoctrineData = preload(
	"res://Scripts/Sim/BotDevelopmentDoctrine.gd"
)


const REPAIR_TEST_NAME: String = (
	"unit_bot_development_repair"
)

const SUMMON_TEST_NAME: String = (
	"unit_bot_development_summon"
)

const SUMMON_PASS_TEST_NAME: String = (
	"unit_bot_development_summon_unaffordable"
)


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_repair_choice(
			rules
		),
		_test_summon_choice(
			rules
		),
		_test_unaffordable_summon(
			rules
		),
	]


static func _test_repair_choice(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			REPAIR_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	player_zero.lord = "Deimos"
	player_zero.alive = true
	player_zero.repair_token = 1

	player_zero.ruined_castles.clear()
	player_zero.ruined_castles.append(
		"Keep"
	)
	player_zero.ruined_castles.append(
		"SiegeEngine"
	)

	player_zero.castles.erase(
		"Keep"
	)
	player_zero.castles.erase(
		"SiegeEngine"
	)

	player_zero.hand = _cards_from_ids([
		"Butcher:1",
		"Vulture:3",
	])

	player_zero.garrison = _cards_from_ids([
		"Wright:2",
	])

	player_one.ruined_castles.clear()

	var random_source = PythonRandomData.new(
		1
	)

	var choices: Dictionary = (
		BotDevelopmentDoctrineData
		.repair_choices(
			game,
			rules,
			random_source,
			BotPolicyData.golden_core()
		)
	)

	var player_zero_choice: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	if String(
		player_zero_choice.get(
			"castle",
			""
		)
	) != "SiegeEngine":
		return _fail(
			REPAIR_TEST_NAME,
			"Deimos did not prioritize Siege Engine."
		)

	if not bool(
		player_zero_choice.get(
			"use_token",
			false
		)
	):
		return _fail(
			REPAIR_TEST_NAME,
			"Available Repair token was not selected."
		)

	if _string_array(
		player_zero_choice.get(
			"payment",
			[]
		)
	) != [
		"Butcher:1",
		"Wright:2",
		"Vulture:3",
	]:
		return _fail(
			REPAIR_TEST_NAME,
			"Repair payment did not use the lowest cards."
		)

	var player_one_choice: Dictionary = (
		_decision_for_player(
			choices,
			1
		)
	)

	if not bool(
		player_one_choice.get(
			"pass",
			false
		)
	):
		return _fail(
			REPAIR_TEST_NAME,
			"Player without Ruins did not pass."
		)

	var next_random: float = (
		random_source.random_float()
	)

	if next_random != 0.13436424411240122:
		return _fail(
			REPAIR_TEST_NAME,
			"Golden Repair selection consumed RNG."
		)

	var results: Array[Dictionary] = (
		RoundEngineData.resolve_repairs(
			game,
			rules,
			choices
		)
	)

	if String(
		results[0].get(
			"action",
			""
		)
	) != "repair":
		return _fail(
			REPAIR_TEST_NAME,
			"RoundEngine rejected the Repair decision."
		)

	if player_zero.repair_token != 0:
		return _fail(
			REPAIR_TEST_NAME,
			"Repair token was not consumed."
		)

	if not player_zero.repaired_this_round:
		return _fail(
			REPAIR_TEST_NAME,
			"Repair flag was not set."
		)

	if not player_zero.repair_token_used_this_repair:
		return _fail(
			REPAIR_TEST_NAME,
			"Token deploy exception was not recorded."
		)

	if not player_zero.castles.has(
		"SiegeEngine"
	):
		return _fail(
			REPAIR_TEST_NAME,
			"Siege Engine was not restored."
		)

	if player_zero.ruined_castles.has(
		"SiegeEngine"
	):
		return _fail(
			REPAIR_TEST_NAME,
			"Siege Engine remained Ruined."
		)

	return _pass(
		REPAIR_TEST_NAME
	)


static func _test_summon_choice(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			SUMMON_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	player_zero.alive = false
	player_zero.first_summon_done = true
	player_zero.vessel_offered_lord = ""

	player_zero.lord_pool.clear()
	player_zero.lord_pool.append(
		"Orias"
	)
	player_zero.lord_pool.append(
		"Deimos"
	)

	player_zero.hand = _cards_from_ids([
		"Butcher:1",
		"Penitent:1",
		"Vulture:2",
		"Wright:4",
	])

	player_zero.lord_guards.clear()

	player_one.alive = true
	player_one.threat = 2

	player_one.lord_guards = _cards_from_ids([
		"Butcher:2",
		"Vulture:3",
	])

	var random_source = PythonRandomData.new(
		1
	)

	var choices: Dictionary = (
		BotDevelopmentDoctrineData
		.summon_choices(
			game,
			rules,
			random_source,
			BotPolicyData.golden_core()
		)
	)

	var player_zero_choice: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	if String(
		player_zero_choice.get(
			"lord",
			""
		)
	) != "Orias":
		return _fail(
			SUMMON_TEST_NAME,
			"Summon evaluator selected the wrong Lord."
		)

	if _string_array(
		player_zero_choice.get(
			"payment",
			[]
		)
	) != [
		"Butcher:1",
		"Penitent:1",
		"Vulture:2",
	]:
		return _fail(
			SUMMON_TEST_NAME,
			"Summon payment did not use the lowest cards."
		)

	var player_one_choice: Dictionary = (
		_decision_for_player(
			choices,
			1
		)
	)

	if not bool(
		player_one_choice.get(
			"pass",
			false
		)
	):
		return _fail(
			SUMMON_TEST_NAME,
			"Living player did not pass Summon."
		)

	var next_random: float = (
		random_source.random_float()
	)

	if next_random != 0.13436424411240122:
		return _fail(
			SUMMON_TEST_NAME,
			"Golden Summon selection consumed RNG."
		)

	var neutral_tears_before: int = int(
		game.neutral_tears
	)

	var results: Array[Dictionary] = (
		SummonEngineData.resolve(
			game,
			rules,
			choices
		)
	)

	if String(
		results[0].get(
			"action",
			""
		)
	) != "summon":
		return _fail(
			SUMMON_TEST_NAME,
			"SummonEngine rejected the decision."
		)

	if not player_zero.alive:
		return _fail(
			SUMMON_TEST_NAME,
			"Player remained Banished."
		)

	if player_zero.lord != "Orias":
		return _fail(
			SUMMON_TEST_NAME,
			"Wrong Lord entered play."
		)

	if player_zero.threat != 0:
		return _fail(
			SUMMON_TEST_NAME,
			"Orias entered with the wrong Threat."
		)

	if game.neutral_tears != neutral_tears_before + 1:
		return _fail(
			SUMMON_TEST_NAME,
			"Repeat Summon did not place a Neutral Tear."
		)

	return _pass(
		SUMMON_TEST_NAME
	)


static func _test_unaffordable_summon(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			SUMMON_PASS_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]

	player_zero.alive = false

	player_zero.lord_pool.clear()
	player_zero.lord_pool.append(
		"Deimos"
	)

	player_zero.hand = _cards_from_ids([
		"Butcher:1",
	])

	var choices: Dictionary = (
		BotDevelopmentDoctrineData
		.summon_choices(
			game,
			rules,
			null,
			BotPolicyData.golden_core()
		)
	)

	var player_zero_choice: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	if not bool(
		player_zero_choice.get(
			"pass",
			false
		)
	):
		return _fail(
			SUMMON_PASS_TEST_NAME,
			"Unaffordable Summon did not pass."
		)

	return _pass(
		SUMMON_PASS_TEST_NAME
	)


static func _build_fixture(
	rules: RuleConfig
) -> Dictionary:
	var game = (
		GameDealFixtureData
		.build_game_deimos_valak_s1(
			rules
		)
	)

	if game == null:
		return {
			"error": "Fixture returned no GameState.",
		}

	var player_zero = game.get_player(
		0
	)

	var player_one = game.get_player(
		1
	)

	if (
		player_zero == null
		or player_one == null
	):
		return {
			"error": "Fixture players are missing.",
		}

	return {
		"game": game,
		"p0": player_zero,
		"p1": player_one,
	}


static func _cards_from_ids(
	card_ids: Array
) -> Array:
	var cards: Array = []

	for raw_card_id in card_ids:
		var card_identifier: String = String(
			raw_card_id
		)

		var separator_index: int = (
			card_identifier.rfind(
				":"
			)
		)

		assert(
			separator_index > 0,
			"Invalid card identifier: %s"
			% card_identifier
		)

		cards.append(
			CardData.new(
				card_identifier.substr(
					0,
					separator_index
				),
				int(
					card_identifier.substr(
						separator_index + 1
					)
				)
			)
		)

	return cards


static func _decision_for_player(
	decisions: Dictionary,
	player_id: int
) -> Dictionary:
	var raw_decision = decisions.get(
		player_id,
		null
	)

	if raw_decision == null:
		raw_decision = decisions.get(
			str(
				player_id
			),
			{}
		)

	if typeof(
		raw_decision
	) != TYPE_DICTIONARY:
		return {}

	return raw_decision


static func _string_array(
	values
) -> Array[String]:
	var result: Array[String] = []

	if typeof(
		values
	) != TYPE_ARRAY:
		return result

	for value in values:
		result.append(
			String(
				value
			)
		)

	return result


static func _pass(
	test_name: String
) -> Dictionary:
	return {
		"passed": true,
		"text": (
			"PASS  %s"
			% test_name
		),
	}


static func _fail(
	test_name: String,
	reason: String
) -> Dictionary:
	return {
		"passed": false,
		"text": (
			"FAIL  %s: %s"
			% [
				test_name,
				reason,
			]
		),
	}
