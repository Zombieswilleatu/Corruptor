class_name BotDeployDoctrineTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const DeployEngineData = preload(
	"res://Scripts/Sim/DeployEngine.gd"
)

const BotDeployDoctrineData = preload(
	"res://Scripts/Sim/BotDeployDoctrine.gd"
)


const NORMAL_TEST_NAME: String = (
	"unit_bot_deploy_reserved_cards"
)

const REPAIR_TEST_NAME: String = (
	"unit_bot_deploy_repair_restriction"
)

const SNARE_TEST_NAME: String = (
	"unit_bot_deploy_orias_snare"
)

const FRENZY_TEST_NAME: String = (
	"unit_bot_deploy_frenzy"
)


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_reserved_deploy(
			rules
		),
		_test_repair_restriction(
			rules
		),
		_test_orias_snare(
			rules
		),
		_test_frenzy(
			rules
		),
	]


static func _test_reserved_deploy(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			NORMAL_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player = fixture["p0"]

	player.lord = "Odradek"
	player.alive = true
	player.souls = 2
	player.threat = 2
	player.tears = 0

	player.hand = _cards_from_ids([
		"Penitent:5",
		"Penitent:4",
		"Butcher:1",
		"Vulture:2",
		"Wright:3",
	])

	player.garrison = _cards_from_ids([
		"Butcher:5",
	])

	player.castle_guards = _cards_from_ids([
		"Vulture:1",
	])

	player.lord_guards = _cards_from_ids([
		"Wright:1",
		"Wright:2",
	])

	player.repaired_this_round = false
	player.repair_token_used_this_repair = false
	player.orias_snare_active = false

	var choices: Dictionary = (
		BotDeployDoctrineData.deploy_choices(
			game,
			rules
		)
	)

	var decision: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	var moves: Array = decision.get(
		"moves",
		[]
	)

	if _move_signatures(
		moves
	) != [
		"Garrison>Castle>Butcher:5",
		"Hand>Castle>Vulture:2",
		"Hand>Lord>Wright:3",
	]:
		return _fail(
			NORMAL_TEST_NAME,
			"Deploy did not preserve Commitment and Bid cards."
		)

	var results: Array[Dictionary] = (
		DeployEngineData.resolve(
			game,
			rules,
			choices
		)
	)

	if int(
		results[0].get(
			"invalid_count",
			-1
		)
	) != 0:
		return _fail(
			NORMAL_TEST_NAME,
			"DeployEngine rejected a doctrine move."
		)

	if _card_ids(
		player.hand
	) != [
		"Penitent:5",
		"Penitent:4",
		"Butcher:1",
	]:
		return _fail(
			NORMAL_TEST_NAME,
			"Reserved cards did not remain in hand."
		)

	if _card_ids(
		player.castle_guards
	) != [
		"Vulture:1",
		"Butcher:5",
		"Vulture:2",
	]:
		return _fail(
			NORMAL_TEST_NAME,
			"Castle Guards reached the wrong state."
		)

	if _card_ids(
		player.lord_guards
	) != [
		"Wright:1",
		"Wright:2",
		"Wright:3",
	]:
		return _fail(
			NORMAL_TEST_NAME,
			"Lord Guards reached the wrong state."
		)

	return _pass(
		NORMAL_TEST_NAME
	)


static func _test_repair_restriction(
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
	var player = fixture["p0"]

	player.hand = _cards_from_ids([
		"Butcher:1",
		"Penitent:2",
		"Wright:5",
	])

	player.garrison = _cards_from_ids([
		"Vulture:5",
		"Wright:4",
	])

	player.castle_guards = _cards_from_ids([
		"Penitent:1",
	])

	player.lord_guards.clear()

	player.repaired_this_round = true
	player.repair_token_used_this_repair = false
	player.orias_snare_active = false
	player.threat = 0

	var hand_before: Array[String] = _card_ids(
		player.hand
	)

	var choices: Dictionary = (
		BotDeployDoctrineData.deploy_choices(
			game,
			rules
		)
	)

	var decision: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	var moves: Array = decision.get(
		"moves",
		[]
	)

	for move in moves:
		if String(
			move.get(
				"source",
				""
			)
		) == "Hand":
			return _fail(
				REPAIR_TEST_NAME,
				"Repair restriction allowed Hand deployment."
			)

	var results: Array[Dictionary] = (
		DeployEngineData.resolve(
			game,
			rules,
			choices
		)
	)

	if int(
		results[0].get(
			"invalid_count",
			-1
		)
	) != 0:
		return _fail(
			REPAIR_TEST_NAME,
			"Restricted Deploy generated an invalid move."
		)

	if _card_ids(
		player.hand
	) != hand_before:
		return _fail(
			REPAIR_TEST_NAME,
			"Repair-restricted hand changed."
		)

	if _card_ids(
		player.castle_guards
	) != [
		"Penitent:1",
		"Vulture:5",
		"Wright:4",
	]:
		return _fail(
			REPAIR_TEST_NAME,
			"Garrison did not deploy during the Repair restriction."
		)

	return _pass(
		REPAIR_TEST_NAME
	)


static func _test_orias_snare(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			SNARE_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player = fixture["p0"]
	var opponent = fixture["p1"]

	player.alive = true
	player.orias_snare_active = true
	player.repaired_this_round = false
	player.threat = 1

	opponent.alive = true

	player.hand = _cards_from_ids([
		"Butcher:1",
		"Penitent:3",
		"Wright:4",
	])

	player.garrison = _cards_from_ids([
		"Vulture:2",
		"Vulture:5",
	])

	player.castle_guards.clear()
	player.lord_guards.clear()

	var choices: Dictionary = (
		BotDeployDoctrineData.deploy_choices(
			game,
			rules
		)
	)

	var decision: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	var moves: Array = decision.get(
		"moves",
		[]
	)

	if _move_signatures(
		moves
	) != [
		"Garrison>Lord>Vulture:5",
	]:
		return _fail(
			SNARE_TEST_NAME,
			"Orias Snare did not restrict Deploy to one best move."
		)

	var results: Array[Dictionary] = (
		DeployEngineData.resolve(
			game,
			rules,
			choices
		)
	)

	if int(
		results[0].get(
			"moved_count",
			-1
		)
	) != 1:
		return _fail(
			SNARE_TEST_NAME,
			"Snared Deploy did not resolve exactly one move."
		)

	if _card_ids(
		player.lord_guards
	) != [
		"Vulture:5",
	]:
		return _fail(
			SNARE_TEST_NAME,
			"Snared Guard entered the wrong zone."
		)

	return _pass(
		SNARE_TEST_NAME
	)


static func _test_frenzy(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			FRENZY_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player = fixture["p0"]

	game.breach = "Orias"

	player.threat = 3
	player.tears = 0
	player.orias_snare_active = false
	player.repaired_this_round = false

	player.hand = _cards_from_ids([
		"Penitent:5",
		"Penitent:4",
		"Butcher:1",
		"Vulture:2",
	])

	player.garrison = _cards_from_ids([
		"Wright:5",
	])

	player.castle_guards = _cards_from_ids([
		"Wright:1",
		"Wright:2",
	])

	player.lord_guards.clear()

	var choices: Dictionary = (
		BotDeployDoctrineData.deploy_choices(
			game,
			rules
		)
	)

	var decision: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	var moves: Array = decision.get(
		"moves",
		[]
	)

	for move in moves:
		if String(
			move.get(
				"source",
				""
			)
		) == "Garrison":
			return _fail(
				FRENZY_TEST_NAME,
				"Frenzy allowed Garrison deployment."
			)

	var results: Array[Dictionary] = (
		DeployEngineData.resolve(
			game,
			rules,
			choices
		)
	)

	if int(
		results[0].get(
			"invalid_count",
			-1
		)
	) != 0:
		return _fail(
			FRENZY_TEST_NAME,
			"Frenzy doctrine generated an invalid move."
		)

	if _card_ids(
		player.garrison
	) != [
		"Wright:5",
	]:
		return _fail(
			FRENZY_TEST_NAME,
			"Frenzy moved a Garrison card."
		)

	return _pass(
		FRENZY_TEST_NAME
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


static func _move_signatures(
	moves: Array
) -> Array[String]:
	var result: Array[String] = []

	for raw_move in moves:
		if typeof(
			raw_move
		) != TYPE_DICTIONARY:
			continue

		var move: Dictionary = raw_move

		result.append(
			"%s>%s>%s" % [
				String(
					move.get(
						"source",
						""
					)
				),
				String(
					move.get(
						"target",
						""
					)
				),
				String(
					move.get(
						"card",
						""
					)
				),
			]
		)

	return result


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

	return str(
		card
	)


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
