class_name DeployTests
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

const DeployEngineData = preload(
	"res://Scripts/Sim/DeployEngine.gd"
)


const ROUND_ONE_DEPLOY_TEST_NAME := "unit_round1_deploy"
const REPAIR_RESTRICTION_TEST_NAME := "unit_deploy_repair_restriction"
const FRENZY_SNARE_TEST_NAME := "unit_deploy_frenzy_and_snare"
const HUMBABA_GATE_TEST_NAME := "unit_humbaba_gate_guard"
const DUPLICATE_IDENTITY_TEST_NAME := "unit_deploy_duplicate_identity"


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_round1_deploy(
			rules
		),
		_test_repair_restriction(
			rules
		),
		_test_frenzy_and_snare(
			rules
		),
		_test_humbaba_gate_guard(
			rules
		),
		_test_duplicate_identity(
			rules
		),
	]


static func _test_round1_deploy(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			ROUND_ONE_DEPLOY_TEST_NAME,
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

	DominionRiteEngineData.resolve(
		game,
		rules,
		_pass_choices()
	)

	var results: Array[Dictionary] = DeployEngineData.resolve(
		game,
		rules,
		_round_one_deploy_choices()
	)

	var error: String = _validate_round_one_deploy(
		game,
		player_zero,
		player_one,
		results
	)

	return _result_from_error(
		ROUND_ONE_DEPLOY_TEST_NAME,
		error
	)


static func _test_repair_restriction(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			REPAIR_RESTRICTION_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_clear_deploy_zones(
		player_zero
	)

	_clear_deploy_zones(
		player_one
	)

	player_zero.hand = [
		CardData.new(
			"Butcher",
			1
		),
	]

	player_zero.garrison = [
		CardData.new(
			"Wright",
			4
		),
	]

	player_zero.repaired_this_round = true
	player_zero.repair_token_used_this_repair = false

	player_one.hand = [
		CardData.new(
			"Penitent",
			2
		),
	]

	player_one.garrison.clear()
	player_one.repaired_this_round = true
	player_one.repair_token_used_this_repair = true

	var choices: Dictionary = {
		0: {
			"moves": [
				{
					"source": "Garrison",
					"card": "Wright:4",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Butcher:1",
					"target": "Castle",
				},
			],
		},
		1: {
			"moves": [
				{
					"source": "Hand",
					"card": "Penitent:2",
					"target": "Castle",
				},
			],
		},
	}

	var results: Array[Dictionary] = DeployEngineData.resolve(
		game,
		rules,
		choices
	)

	var error: String = _validate_repair_restriction(
		player_zero,
		player_one,
		results
	)

	return _result_from_error(
		REPAIR_RESTRICTION_TEST_NAME,
		error
	)


static func _test_frenzy_and_snare(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			FRENZY_SNARE_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_clear_deploy_zones(
		player_zero
	)

	_clear_deploy_zones(
		player_one
	)

	player_zero.hand = [
		CardData.new(
			"Butcher",
			1
		),
	]

	player_zero.garrison = [
		CardData.new(
			"Wright",
			5
		),
	]

	player_zero.threat = 3
	player_zero.tears = 0
	player_zero.repaired_this_round = false
	player_zero.repair_token_used_this_repair = false
	player_zero.orias_snare_active = false

	player_one.hand = [
		CardData.new(
			"Penitent",
			2
		),
	]

	player_one.garrison = [
		CardData.new(
			"Vulture",
			4
		),
	]

	player_one.threat = 1
	player_one.tears = 6
	player_one.repaired_this_round = false
	player_one.repair_token_used_this_repair = false
	player_one.orias_snare_active = true

	game.neutral_tears = 0
	game.refresh_derived_values()

	var choices: Dictionary = {
		0: {
			"moves": [
				{
					"source": "Garrison",
					"card": "Wright:5",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Butcher:1",
					"target": "Castle",
				},
			],
		},
		1: {
			"moves": [
				{
					"source": "Garrison",
					"card": "Vulture:4",
					"target": "Lord",
				},
				{
					"source": "Hand",
					"card": "Penitent:2",
					"target": "Castle",
				},
			],
		},
	}

	var results: Array[Dictionary] = DeployEngineData.resolve(
		game,
		rules,
		choices
	)

	var error: String = _validate_frenzy_and_snare(
		player_zero,
		player_one,
		results
	)

	return _result_from_error(
		FRENZY_SNARE_TEST_NAME,
		error
	)


static func _test_humbaba_gate_guard(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			HUMBABA_GATE_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_clear_deploy_zones(
		player_zero
	)

	_clear_deploy_zones(
		player_one
	)

	player_zero.lord = "Humbaba"
	player_zero.alive = true
	player_zero.ruined_castles.clear()

	player_zero.castle_guards = [
		CardData.new(
			"Butcher",
			1
		),
		CardData.new(
			"Penitent",
			2
		),
		CardData.new(
			"Vulture",
			3
		),
	]

	player_zero.hand = [
		CardData.new(
			"Wright",
			4
		),
	]

	player_one.lord = "Humbaba"
	player_one.alive = true
	player_one.ruined_castles.clear()
	player_one.ruined_castles.append(
		"Stockpile"
	)

	player_one.castle_guards = [
		CardData.new(
			"Butcher",
			1
		),
		CardData.new(
			"Penitent",
			2
		),
		CardData.new(
			"Vulture",
			3
		),
	]

	player_one.hand = [
		CardData.new(
			"Wright",
			4
		),
	]

	var choices: Dictionary = {
		0: {
			"moves": [
				{
					"source": "Hand",
					"card": "Wright:4",
					"target": "Castle",
				},
			],
		},
		1: {
			"moves": [
				{
					"source": "Hand",
					"card": "Wright:4",
					"target": "Castle",
				},
			],
		},
	}

	var results: Array[Dictionary] = DeployEngineData.resolve(
		game,
		rules,
		choices
	)

	var error: String = _validate_humbaba_gate_guard(
		player_zero,
		player_one,
		results
	)

	return _result_from_error(
		HUMBABA_GATE_TEST_NAME,
		error
	)


static func _test_duplicate_identity(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			DUPLICATE_IDENTITY_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_clear_deploy_zones(
		player_zero
	)

	_clear_deploy_zones(
		player_one
	)

	var earlier_duplicate = CardData.new(
		"Wright",
		5
	)

	var filler = CardData.new(
		"Penitent",
		2
	)

	var later_duplicate = CardData.new(
		"Wright",
		5
	)

	player_zero.hand = [
		earlier_duplicate,
		filler,
		later_duplicate,
	]

	var choices: Dictionary = {
		0: {
			"moves": [
				{
					"source": "Hand",
					"target": "Lord",
					"card": "Wright:5",
					"source_index": 2,
				},
			],
		},
		1: {
			"pass": true,
		},
	}

	var results: Array[Dictionary] = DeployEngineData.resolve(
		game,
		rules,
		choices
	)

	if results.size() != 2:
		return _fail(
			DUPLICATE_IDENTITY_TEST_NAME,
			"Expected two duplicate-identity Deploy results."
		)

	if int(
		results[0].get(
			"moved_count",
			-1
		)
	) != 1:
		return _fail(
			DUPLICATE_IDENTITY_TEST_NAME,
			"Indexed duplicate Deploy did not move exactly one card."
		)

	if (
		player_zero.lord_guards.size() != 1
		or player_zero.lord_guards[0] != later_duplicate
	):
		return _fail(
			DUPLICATE_IDENTITY_TEST_NAME,
			"Deploy moved the wrong physical Wright:5 copy."
		)

	if (
		player_zero.hand.size() != 2
		or player_zero.hand[0] != earlier_duplicate
		or player_zero.hand[1] != filler
	):
		return _fail(
			DUPLICATE_IDENTITY_TEST_NAME,
			"Deploy removed or reordered the wrong source cards."
		)

	return _pass(
		DUPLICATE_IDENTITY_TEST_NAME
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


static func _clear_deploy_zones(
	player
) -> void:
	player.hand.clear()
	player.garrison.clear()
	player.castle_guards.clear()
	player.lord_guards.clear()


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


static func _round_one_deploy_choices() -> Dictionary:
	return {
		0: {
			"moves": [
				{
					"source": "Hand",
					"card": "Penitent:2",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Penitent:3",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Penitent:3",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Wright:4",
					"target": "Lord",
				},
				{
					"source": "Hand",
					"card": "Penitent:5",
					"target": "Lord",
				},
			],
		},
		1: {
			"moves": [
				{
					"source": "Hand",
					"card": "Wright:3",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Wright:3",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Wright:3",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Vulture:4",
					"target": "Lord",
				},
				{
					"source": "Hand",
					"card": "Vulture:5",
					"target": "Lord",
				},
			],
		},
	}


static func _validate_round_one_deploy(
	game,
	player_zero,
	player_one,
	results: Array[Dictionary]
) -> String:
	if results.size() != 2:
		return (
			"Expected two Deploy results, received %d."
			% results.size()
		)

	if int(
		results[0].get(
			"moved_count",
			-1
		)
	) != 5:
		return (
			"Player zero should deploy five Guards."
		)

	if int(
		results[1].get(
			"moved_count",
			-1
		)
	) != 5:
		return (
			"Player one should deploy five Guards."
		)

	if int(
		results[0].get(
			"invalid_count",
			-1
		)
	) != 0:
		return (
			"Player zero had an invalid Round 1 deployment."
		)

	if int(
		results[1].get(
			"invalid_count",
			-1
		)
	) != 0:
		return (
			"Player one had an invalid Round 1 deployment."
		)

	if _card_ids(
		player_zero.castle_guards
	) != [
		"Penitent:2",
		"Penitent:3",
		"Penitent:3",
	]:
		return (
			"Player zero Castle Guards do not match the oracle deployment."
		)

	if _card_ids(
		player_zero.lord_guards
	) != [
		"Wright:4",
		"Penitent:5",
	]:
		return (
			"Player zero Lord Guards do not match the oracle deployment."
		)

	if _card_ids(
		player_zero.hand
	) != [
		"Butcher:4",
		"Butcher:1",
		"Penitent:1",
		"Wright:5",
	]:
		return (
			"Player zero retained the wrong cards after Deploy."
		)

	if _card_ids(
		player_one.castle_guards
	) != [
		"Wright:3",
		"Wright:3",
		"Wright:3",
	]:
		return (
			"Player one Castle Guards do not match the oracle deployment."
		)

	if _card_ids(
		player_one.lord_guards
	) != [
		"Vulture:4",
		"Vulture:5",
	]:
		return (
			"Player one Lord Guards do not match the oracle deployment."
		)

	if _card_ids(
		player_one.hand
	) != [
		"Butcher:4",
		"Vulture:2",
		"Butcher:2",
		"Butcher:3",
	]:
		return (
			"Player one retained the wrong cards after Deploy."
		)

	if (
		not player_zero.garrison.is_empty()
		or not player_one.garrison.is_empty()
	):
		return (
			"Round 1 unexpectedly created Garrison cards."
		)

	if game.deck.size() != 35:
		return (
			"Deploy changed the deck."
		)

	if game.discard.size() != 4:
		return (
			"Deploy changed the discard."
		)

	if _card_ids(
		game.market
	) != [
		"Penitent:1",
		"Wright:1",
		"Vulture:1",
	]:
		return (
			"Deploy changed the Market."
		)

	return ""


static func _validate_repair_restriction(
	player_zero,
	player_one,
	results: Array[Dictionary]
) -> String:
	if results.size() != 2:
		return (
			"Expected two Repair-restriction Deploy results."
		)

	var player_zero_moves: Array = results[0].get(
		"moves",
		[]
	)

	var player_one_moves: Array = results[1].get(
		"moves",
		[]
	)

	if player_zero_moves.size() != 2:
		return (
			"Player zero should have two movement results."
		)

	if _move_action(
		player_zero_moves,
		0
	) != "move":
		return (
			"Garrison deployment should remain legal after Repair."
		)

	if _move_reason(
		player_zero_moves,
		1
	) != "hand_deploy_blocked_by_repair":
		return (
			"Tokenless Repair did not block hand deployment."
		)

	if _card_ids(
		player_zero.castle_guards
	) != [
		"Wright:4",
	]:
		return (
			"Player zero Castle Guards are incorrect after Repair restriction."
		)

	if _card_ids(
		player_zero.hand
	) != [
		"Butcher:1",
	]:
		return (
			"Blocked hand card was removed."
		)

	if not player_zero.garrison.is_empty():
		return (
			"Successful Garrison card was not removed."
		)

	if player_one_moves.size() != 1:
		return (
			"Player one should have one movement result."
		)

	if _move_action(
		player_one_moves,
		0
	) != "move":
		return (
			"Repair-token override did not permit hand deployment."
		)

	if _card_ids(
		player_one.castle_guards
	) != [
		"Penitent:2",
	]:
		return (
			"Repair-token deployment reached the wrong zone."
		)

	if not player_one.hand.is_empty():
		return (
			"Successful Repair-token deployment remained in hand."
		)

	return ""


static func _validate_frenzy_and_snare(
	player_zero,
	player_one,
	results: Array[Dictionary]
) -> String:
	if results.size() != 2:
		return (
			"Expected two Frenzy/Snare Deploy results."
		)

	if not bool(
		results[0].get(
			"frenzy_blocked",
			false
		)
	):
		return (
			"Frenzy was not detected for the Threat 3 player."
		)

	if bool(
		results[1].get(
			"frenzy_blocked",
			true
		)
	):
		return (
			"Attuned player should be immune to Frenzy."
		)

	var player_zero_moves: Array = results[0].get(
		"moves",
		[]
	)

	var player_one_moves: Array = results[1].get(
		"moves",
		[]
	)

	if _move_reason(
		player_zero_moves,
		0
	) != "garrison_deploy_blocked_by_frenzy":
		return (
			"Frenzy did not block Garrison deployment."
		)

	if _move_action(
		player_zero_moves,
		1
	) != "move":
		return (
			"Frenzy incorrectly blocked deployment from hand."
		)

	if _card_ids(
		player_zero.garrison
	) != [
		"Wright:5",
	]:
		return (
			"Frenzy-blocked Garrison card was removed."
		)

	if _card_ids(
		player_zero.castle_guards
	) != [
		"Butcher:1",
	]:
		return (
			"Frenzy hand deployment reached the wrong state."
		)

	if _move_action(
		player_one_moves,
		0
	) != "move":
		return (
			"Orias Snare should permit one Guard movement."
		)

	if _move_reason(
		player_one_moves,
		1
	) != "orias_snare_limit":
		return (
			"Orias Snare did not block the second Guard movement."
		)

	if _card_ids(
		player_one.lord_guards
	) != [
		"Vulture:4",
	]:
		return (
			"Orias-Snared first movement reached the wrong zone."
		)

	if _card_ids(
		player_one.hand
	) != [
		"Penitent:2",
	]:
		return (
			"Orias-Snared second card was incorrectly removed."
		)

	return ""


static func _validate_humbaba_gate_guard(
	player_zero,
	player_one,
	results: Array[Dictionary]
) -> String:
	if results.size() != 2:
		return (
			"Expected two Humbaba Gate Guard results."
		)

	var player_zero_moves: Array = results[0].get(
		"moves",
		[]
	)

	var player_one_moves: Array = results[1].get(
		"moves",
		[]
	)

	if _move_action(
		player_zero_moves,
		0
	) != "move":
		return (
			"Unbroken Humbaba did not receive the fourth Castle Guard."
		)

	if player_zero.castle_guards.size() != 4:
		return (
			"Unbroken Humbaba Castle Guard limit should be four."
		)

	if not player_zero.hand.is_empty():
		return (
			"Humbaba fourth Guard remained in hand."
		)

	if _move_reason(
		player_one_moves,
		0
	) != "target_full":
		return (
			"Ruined Humbaba should have the normal three-Guard limit."
		)

	if player_one.castle_guards.size() != 3:
		return (
			"Ruined Humbaba exceeded the normal Castle Guard limit."
		)

	if _card_ids(
		player_one.hand
	) != [
		"Wright:4",
	]:
		return (
			"Rejected Humbaba Guard was removed from hand."
		)

	return ""


static func _move_action(
	moves: Array,
	index: int
) -> String:
	var move: Dictionary = _move_dictionary(
		moves,
		index
	)

	return String(
		move.get(
			"action",
			""
		)
	)


static func _move_reason(
	moves: Array,
	index: int
) -> String:
	var move: Dictionary = _move_dictionary(
		moves,
		index
	)

	return String(
		move.get(
			"reason",
			""
		)
	)


static func _move_dictionary(
	moves: Array,
	index: int
) -> Dictionary:
	if (
		index < 0
		or index >= moves.size()
	):
		return {}

	var raw_move = moves[
		index
	]

	if typeof(raw_move) != TYPE_DICTIONARY:
		return {}

	return raw_move


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
