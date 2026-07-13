class_name DominionRiteTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)

const DominionRiteEngineData = preload(
	"res://Scripts/Sim/DominionRiteEngine.gd"
)


const RITES_NOOP_TEST_NAME := "unit_round1_dominion_rites_noop"
const INVOCATION_TEST_NAME := "unit_cataclysmic_invocation"
const PROFANE_RUINS_TEST_NAME := "unit_profane_the_ruins"


const EXPECTED_PLAYER_ZERO_MARKET_HAND: Array[String] = [
	"Butcher:4",
	"Penitent:3",
	"Wright:4",
	"Penitent:3",
	"Butcher:1",
	"Penitent:2",
	"Penitent:5",
	"Penitent:1",
	"Wright:5",
]

const EXPECTED_PLAYER_ONE_MARKET_HAND: Array[String] = [
	"Butcher:4",
	"Vulture:2",
	"Wright:3",
	"Butcher:2",
	"Butcher:3",
	"Wright:3",
	"Vulture:4",
	"Vulture:5",
	"Wright:3",
]

const EXPECTED_MARKET: Array[String] = [
	"Penitent:1",
	"Wright:1",
	"Vulture:1",
]


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_round1_dominion_rites_noop(
			rules
		),
		_test_cataclysmic_invocation(
			rules
		),
		_test_profane_the_ruins(
			rules
		),
	]


static func _test_round1_dominion_rites_noop(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			RITES_NOOP_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	RoundEngineData.advance_to_round_repair(
		game,
		1,
		rules,
		_round_one_market_choices(),
		_pass_choices()
	)

	var results: Array[Dictionary] = (
		DominionRiteEngineData.resolve(
			game,
			rules,
			_pass_choices()
		)
	)

	var error: String = _validate_rites_noop(
		game,
		player_zero,
		player_one,
		results
	)

	return _result_from_error(
		RITES_NOOP_TEST_NAME,
		error
	)


static func _test_cataclysmic_invocation(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			INVOCATION_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_configure_invocation_fixture(
		game,
		player_zero,
		player_one,
		rules
	)

	var results: Array[Dictionary] = (
		DominionRiteEngineData.resolve(
			game,
			rules,
			_invocation_choices()
		)
	)

	var error: String = _validate_invocation(
		game,
		player_zero,
		player_one,
		results,
		rules
	)

	if error.is_empty():
		error = _validate_invocation_cannot_repeat(
			game,
			player_zero,
			rules
		)

	return _result_from_error(
		INVOCATION_TEST_NAME,
		error
	)


static func _test_profane_the_ruins(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			PROFANE_RUINS_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]

	_configure_profane_fixture(
		game,
		player_zero
	)

	var results: Array[Dictionary] = (
		DominionRiteEngineData.resolve(
			game,
			rules,
			_profane_choices(
				"Stockpile"
			)
		)
	)

	var error: String = _validate_profane_ruins(
		game,
		player_zero,
		results
	)

	if error.is_empty():
		error = _validate_profane_cannot_repeat(
			game,
			player_zero,
			rules
		)

	return _result_from_error(
		PROFANE_RUINS_TEST_NAME,
		error
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
			"error": "Fixture returned no GameState."
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
			"error": "Fixture players are missing."
		}

	return {
		"game": game,
		"p0": player_zero,
		"p1": player_one,
	}


static func _configure_invocation_fixture(
	game,
	player_zero,
	player_one,
	rules: RuleConfig
) -> void:
	player_zero.hand = [
		CardData.new(
			"Butcher",
			5
		),
		CardData.new(
			"Penitent",
			4
		),
		CardData.new(
			"Wright",
			2
		),
		CardData.new(
			"Vulture",
			1
		),
	]

	player_zero.garrison = [
		CardData.new(
			"Wright",
			5
		),
	]

	player_zero.cataclysmic_used = false

	player_zero.tears = max(
		0,
		rules.dominion_requirement - 1
	)

	player_one.lord = "Gremory"
	player_one.alive = true
	player_one.tears = 0
	player_one.hand.clear()
	player_one.gremory_veil_draw_done = false

	game.discard.clear()

	game.discard.append(
		CardData.new(
			"Butcher",
			1
		)
	)

	game.winner = -1
	game.win_by = ""

	var neutral_for_dominion: int = (
		rules.dominion_track
		- player_zero.tears
		- 1
	)

	var neutral_for_gate: int = (
		rules.invocation_gate
		- player_zero.tears
	)

	game.neutral_tears = max(
		0,
		max(
			neutral_for_dominion,
			neutral_for_gate
		)
	)

	game.refresh_derived_values()


static func _configure_profane_fixture(
	game,
	player_zero
) -> void:
	player_zero.tears = 0
	player_zero.profane_ruins_used_this_round = false

	player_zero.profaned_castles.clear()
	player_zero.ruined_castles.clear()

	player_zero.castles.erase(
		"Stockpile"
	)

	player_zero.castles.erase(
		"SiegeEngine"
	)

	player_zero.ruined_castles.append(
		"Stockpile"
	)

	player_zero.ruined_castles.append(
		"SiegeEngine"
	)

	game.neutral_tears = 0
	game.winner = -1
	game.win_by = ""

	game.refresh_derived_values()


static func _round_one_market_choices() -> Dictionary:
	return {
		1: {
			"pass": true,
		},
		0: {
			"take": "Wright:5",
			"give": "Vulture:1",
		},
	}


static func _pass_choices() -> Dictionary:
	return {
		0: {
			"pass": true,
		},
		1: {
			"pass": true,
		},
	}


static func _invocation_choices() -> Dictionary:
	return {
		0: {
			"invocation": {
				"payment": [
					"Butcher:5",
					"Penitent:4",
					"Wright:2",
				],
			},
		},
		1: {
			"pass": true,
		},
	}


static func _profane_choices(
	castle_name: String
) -> Dictionary:
	return {
		0: {
			"profane_ruins": {
				"castle": castle_name,
			},
		},
		1: {
			"pass": true,
		},
	}


static func _validate_rites_noop(
	game,
	player_zero,
	player_one,
	results: Array[Dictionary]
) -> String:
	if results.size() != 2:
		return (
			"Expected two Dominion Rite results, received %d."
			% results.size()
		)

	for player_id: int in range(2):
		var result: Dictionary = results[
			player_id
		]

		if int(
			result.get(
				"player_id",
				-1
			)
		) != player_id:
			return (
				"Dominion Rite player order mismatch."
			)

		var actions: Array = result.get(
			"actions",
			[]
		)

		if not actions.is_empty():
			return (
				"Player %d unexpectedly performed a Dominion Rite."
				% player_id
			)

		if String(
			result.get(
				"reason",
				""
			)
		) != "pass":
			return (
				"Player %d should record an explicit Rite pass."
				% player_id
			)

	if (
		player_zero.tears != 0
		or player_one.tears != 0
	):
		return (
			"Round 1 no-op Rites changed personal Tears."
		)

	if (
		player_zero.cataclysmic_used
		or player_one.cataclysmic_used
	):
		return (
			"Round 1 no-op Rites used an Invocation."
		)

	if (
		player_zero.profane_ruins_used_this_round
		or player_one.profane_ruins_used_this_round
	):
		return (
			"Round 1 no-op Rites used Profane the Ruins."
		)

	if _card_ids(
		player_zero.hand
	) != EXPECTED_PLAYER_ZERO_MARKET_HAND:
		return (
			"Player zero hand changed during no-op Rites."
		)

	if _card_ids(
		player_one.hand
	) != EXPECTED_PLAYER_ONE_MARKET_HAND:
		return (
			"Player one hand changed during no-op Rites."
		)

	if _card_ids(
		game.market
	) != EXPECTED_MARKET:
		return (
			"Market changed during no-op Rites."
		)

	if game.deck.size() != 35:
		return (
			"Deck changed during no-op Rites."
		)

	if game.discard.size() != 4:
		return (
			"Discard changed during no-op Rites."
		)

	if game.calculate_veil_total() != 0:
		return (
			"Veil changed during no-op Rites."
		)

	return ""


static func _validate_invocation(
	game,
	player_zero,
	player_one,
	results: Array[Dictionary],
	rules: RuleConfig
) -> String:
	if results.size() != 2:
		return (
			"Expected two Invocation-phase player results."
		)

	var player_result: Dictionary = results[0]

	var actions: Array = player_result.get(
		"actions",
		[]
	)

	if actions.size() != 1:
		return (
			"Expected exactly one Invocation action."
		)

	var action: Dictionary = actions[0]

	if String(
		action.get(
			"action",
			""
		)
	) != "cataclysmic_invocation":
		return (
			"Cataclysmic Invocation did not resolve."
		)

	if int(
		action.get(
			"cost",
			0
		)
	) != 11:
		return (
			"Invocation cost should be 11."
		)

	if int(
		action.get(
			"paid_total",
			0
		)
	) != 11:
		return (
			"Invocation payment should total 11."
		)

	if _string_array(
		action.get(
			"paid_cards",
			[]
		)
	) != [
		"Butcher:5",
		"Penitent:4",
		"Wright:2",
	]:
		return (
			"Invocation used the wrong payment cards."
		)

	if not player_zero.cataclysmic_used:
		return (
			"Invocation once-per-game flag was not set."
		)

	if player_zero.tears != rules.dominion_requirement:
		return (
			"Invocation did not grant the expected personal Tear."
		)

	if _card_ids(
		player_zero.hand
	) != [
		"Vulture:1",
	]:
		return (
			"Invocation left the wrong cards in hand."
		)

	if _card_ids(
		player_zero.garrison
	) != [
		"Wright:5",
	]:
		return (
			"Invocation incorrectly used Garrison cards."
		)

	if String(
		action.get(
			"harvested_card",
			""
		)
	) != "Penitent:4":
		return (
			"Gremory did not harvest the latest eligible discard."
		)

	if int(
		action.get(
			"harvested_by",
			-1
		)
	) != 1:
		return (
			"Gremory harvest was credited to the wrong player."
		)

	if not player_one.gremory_veil_draw_done:
		return (
			"Gremory harvest flag was not set."
		)

	if _card_ids(
		player_one.hand
	) != [
		"Penitent:4",
	]:
		return (
			"Gremory received the wrong harvested card."
		)

	if _card_ids(
		game.discard
	) != [
		"Butcher:1",
		"Butcher:5",
		"Wright:2",
	]:
		return (
			"Invocation discard or Gremory harvest order is wrong."
		)

	if game.calculate_veil_total() < rules.dominion_track:
		return (
			"Invocation did not reach the Dominion track."
		)

	if game.winner != 0:
		return (
			"Invocation should award Dominion victory to player zero."
		)

	if game.win_by != "Dominion":
		return (
			"Invocation victory should be recorded as Dominion."
		)

	if not bool(
		action.get(
			"won",
			false
		)
	):
		return (
			"Invocation result did not report the victory."
		)

	return ""


static func _validate_invocation_cannot_repeat(
	game,
	player_zero,
	rules: RuleConfig
) -> String:
	if rules.invocation_repeatable:
		return ""

	var tears_before: int = int(
		player_zero.tears
	)

	player_zero.hand.append(
		CardData.new(
			"Butcher",
			5
		)
	)

	player_zero.hand.append(
		CardData.new(
			"Penitent",
			5
		)
	)

	player_zero.hand.append(
		CardData.new(
			"Wright",
			1
		)
	)

	var results: Array[Dictionary] = (
		DominionRiteEngineData.resolve(
			game,
			rules,
			{
				0: {
					"invocation": {
						"payment": [
							"Butcher:5",
							"Penitent:5",
							"Wright:1",
						],
					},
				},
				1: {
					"pass": true,
				},
			}
		)
	)

	var player_result: Dictionary = results[0]
	var actions: Array = player_result.get(
		"actions",
		[]
	)

	if actions.size() != 1:
		return (
			"Repeated Invocation did not return one result."
		)

	var action: Dictionary = actions[0]

	if String(
		action.get(
			"action",
			""
		)
	) != "invalid":
		return (
			"Repeated Invocation was not rejected."
		)

	if String(
		action.get(
			"reason",
			""
		)
	) != "invocation_already_used":
		return (
			"Repeated Invocation returned the wrong rejection reason."
		)

	if player_zero.tears != tears_before:
		return (
			"Rejected Invocation changed personal Tears."
		)

	return ""


static func _validate_profane_ruins(
	game,
	player_zero,
	results: Array[Dictionary]
) -> String:
	if results.size() != 2:
		return (
			"Expected two Profane-the-Ruins player results."
		)

	var player_result: Dictionary = results[0]

	var actions: Array = player_result.get(
		"actions",
		[]
	)

	if actions.size() != 1:
		return (
			"Expected exactly one Profane-the-Ruins action."
		)

	var action: Dictionary = actions[0]

	if String(
		action.get(
			"action",
			""
		)
	) != "profane_ruins":
		return (
			"Profane the Ruins did not resolve."
		)

	if String(
		action.get(
			"castle",
			""
		)
	) != "Stockpile":
		return (
			"Profane the Ruins targeted the wrong Castle."
		)

	if player_zero.ruined_castles.has(
		"Stockpile"
	):
		return (
			"Stockpile remained in Ruined Castles."
		)

	if not player_zero.profaned_castles.has(
		"Stockpile"
	):
		return (
			"Stockpile was not moved into Profaned Castles."
		)

	if not player_zero.ruined_castles.has(
		"SiegeEngine"
	):
		return (
			"Untargeted Siege Engine should remain Ruined."
		)

	if player_zero.castles.has(
		"Stockpile"
	):
		return (
			"Profaned Stockpile incorrectly returned to intact Castles."
		)

	if not player_zero.profane_ruins_used_this_round:
		return (
			"Profane-the-Ruins round flag was not set."
		)

	if player_zero.tears != 1:
		return (
			"Profane the Ruins did not grant one personal Tear."
		)

	if game.calculate_veil_total() != 1:
		return (
			"Profane the Ruins did not advance the Veil."
		)

	return ""


static func _validate_profane_cannot_repeat(
	game,
	player_zero,
	rules: RuleConfig
) -> String:
	var tears_before: int = int(
		player_zero.tears
	)

	var results: Array[Dictionary] = (
		DominionRiteEngineData.resolve(
			game,
			rules,
			_profane_choices(
				"SiegeEngine"
			)
		)
	)

	var player_result: Dictionary = results[0]

	var actions: Array = player_result.get(
		"actions",
		[]
	)

	if actions.size() != 1:
		return (
			"Repeated Profane the Ruins did not return one result."
		)

	var action: Dictionary = actions[0]

	if String(
		action.get(
			"action",
			""
		)
	) != "invalid":
		return (
			"Repeated Profane the Ruins was not rejected."
		)

	if String(
		action.get(
			"reason",
			""
		)
	) != "profane_ruins_already_used":
		return (
			"Repeated Profane returned the wrong rejection reason."
		)

	if not player_zero.ruined_castles.has(
		"SiegeEngine"
	):
		return (
			"Rejected Profane removed the remaining Ruined Castle."
		)

	if player_zero.tears != tears_before:
		return (
			"Rejected Profane changed personal Tears."
		)

	return ""


static func _card_ids(
	cards: Array
) -> Array[String]:
	var result: Array[String] = []

	for card in cards:
		if card == null:
			result.append(
				"<null>"
			)
		elif card.has_method(
			"card_id"
		):
			result.append(
				String(
					card.card_id()
				)
			)
		else:
			result.append(
				str(card)
			)

	return result


static func _string_array(
	values: Array
) -> Array[String]:
	var result: Array[String] = []

	for value in values:
		result.append(
			String(value)
		)

	return result


static func _result_from_error(
	test_name: String,
	error: String
) -> Dictionary:
	if error.is_empty():
		return _pass(
			test_name
		)

	return _fail(
		test_name,
		error
	)


static func _pass(
	test_name: String
) -> Dictionary:
	return {
		"passed": true,
		"text": "PASS  %s"
		% test_name,
	}


static func _fail(
	test_name: String,
	reason: String
) -> Dictionary:
	return {
		"passed": false,
		"text": "FAIL  %s: %s"
		% [
			test_name,
			reason,
		],
	}
