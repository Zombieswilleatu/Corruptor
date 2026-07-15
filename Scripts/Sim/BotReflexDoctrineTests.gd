class_name BotReflexDoctrineTests
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

const ReflexActionEngineData = preload(
	"res://Scripts/Sim/ReflexActionEngine.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const BotReflexDoctrineData = preload(
	"res://Scripts/Sim/BotReflexDoctrine.gd"
)


const HUNT_TEST_NAME: String = (
	"unit_bot_reflex_hunt_argmax"
)

const WARD_TEST_NAME: String = (
	"unit_bot_reflex_ward_argmax"
)

const SOFTMAX_TEST_NAME: String = (
	"unit_bot_reflex_softmax_draw"
)

const ODRADEK_TEST_NAME: String = (
	"unit_bot_reflex_odradek_prediction"
)


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_hunt_argmax(
			rules
		),
		_test_ward_argmax(
			rules
		),
		_test_softmax_draw(
			rules
		),
		_test_odradek_prediction(
			rules
		),
	]


static func _test_hunt_argmax(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			HUNT_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var attacker = fixture["p0"]
	var defender = fixture["p1"]

	_prepare_game(
		game
	)

	game.reflex_winner = 0

	attacker.lord = "Kalligan"
	attacker.threat = 0

	attacker.hand = _cards_from_ids([
		"Wright:5",
		"Vulture:4",
	])

	defender.lord = "Valak"
	defender.alive = true
	defender.threat = 0

	_set_castles(
		defender,
		[
			"SiegeEngine",
		]
	)

	var random_source = PythonRandomData.new(
		1
	)

	var decision: Dictionary = (
		BotReflexDoctrineData.decision_for_actor(
			game,
			0,
			rules,
			random_source,
			BotPolicyData.golden_core()
		)
	)

	if String(
		decision.get(
			"action",
			""
		)
	) != "Hunt":
		return _fail(
			HUNT_TEST_NAME,
			"Reflex evaluator did not prioritize Hunt."
		)

	if _string_array(
		decision.get(
			"cards",
			[]
		)
	) != [
		"Wright:5",
		"Vulture:4",
	]:
		return _fail(
			HUNT_TEST_NAME,
			"Reflex Hunt selected the wrong cards."
		)

	var next_random: float = (
		random_source.random_float()
	)

	if next_random != 0.13436424411240122:
		return _fail(
			HUNT_TEST_NAME,
			"Golden Reflex selection consumed RNG."
		)

	var result: Dictionary = (
		ReflexActionEngineData.resolve(
			game,
			rules,
			decision
		)
	)

	if String(
		result.get(
			"executed_action",
			""
		)
	) != "Hunt":
		return _fail(
			HUNT_TEST_NAME,
			"ReflexActionEngine did not execute Hunt."
		)

	var action_result: Dictionary = (
		_nested_dictionary(
			result,
			"action_result"
		)
	)

	if not bool(
		action_result.get(
			"destroyed",
			false
		)
	):
		return _fail(
			HUNT_TEST_NAME,
			"Selected Reflex Hunt failed to destroy its target."
		)

	if defender.alive:
		return _fail(
			HUNT_TEST_NAME,
			"Destroyed Lord remained active."
		)

	return _pass(
		HUNT_TEST_NAME
	)


static func _test_ward_argmax(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			WARD_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player = fixture["p0"]
	var opponent = fixture["p1"]

	_prepare_game(
		game
	)

	game.reflex_winner = 0

	player.lord = "Kalligan"
	player.alive = true
	player.threat = 3

	player.hand = _cards_from_ids([
		"Butcher:1",
	])

	_set_castles(
		player,
		[
			"Keep",
		]
	)

	opponent.lord = "Valak"
	opponent.alive = true

	_set_castles(
		opponent,
		[
			"Bastion",
		]
	)

	var decision: Dictionary = (
		BotReflexDoctrineData.decision_for_actor(
			game,
			0,
			rules,
			null,
			BotPolicyData.golden_core()
		)
	)

	if String(
		decision.get(
			"action",
			""
		)
	) != "Ward":
		return _fail(
			WARD_TEST_NAME,
			"Reflex evaluator did not choose Ward."
		)

	if String(
		decision.get(
			"ward_target",
			""
		)
	) != "Lord":
		return _fail(
			WARD_TEST_NAME,
			"Reflex evaluator chose the wrong Ward zone."
		)

	var result: Dictionary = (
		ReflexActionEngineData.resolve(
			game,
			rules,
			decision
		)
	)

	if String(
		player.sigils.get(
			"Lord",
			""
		)
	) != "fresh":
		return _fail(
			WARD_TEST_NAME,
			"Reflex Ward did not place a Fresh Sigil."
		)

	if player.threat != 2:
		return _fail(
			WARD_TEST_NAME,
			"Reflex Lord Ward did not reduce Threat."
		)

	if String(
		result.get(
			"executed_action",
			""
		)
	) != "Ward":
		return _fail(
			WARD_TEST_NAME,
			"ReflexActionEngine did not execute Ward."
		)

	return _pass(
		WARD_TEST_NAME
	)


static func _test_softmax_draw(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			SOFTMAX_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player = fixture["p0"]
	var opponent = fixture["p1"]

	_prepare_game(
		game
	)

	game.reflex_winner = 0

	player.lord = "Kalligan"
	player.alive = true
	player.threat = 2

	player.hand = _cards_from_ids([
		"Wright:5",
		"Vulture:4",
		"Butcher:3",
	])

	_set_castles(
		player,
		[
			"Keep",
		]
	)

	opponent.lord = "Valak"
	opponent.alive = true

	_set_castles(
		opponent,
		[
			"Bastion",
		]
	)

	var random_source = PythonRandomData.new(
		1
	)

	var policy = BotPolicyData.new(
		"unit-reflex-softmax",
		1.0,
		0.0
	)

	var decision: Dictionary = (
		BotReflexDoctrineData.decision_for_actor(
			game,
			0,
			rules,
			random_source,
			policy
		)
	)

	if String(
		decision.get(
			"action",
			""
		)
	) != "Hunt":
		return _fail(
			SOFTMAX_TEST_NAME,
			"Seed-one Reflex softmax selected the wrong action."
		)

	var next_random: float = (
		random_source.random_float()
	)

	if next_random != 0.8474337369372327:
		return _fail(
			SOFTMAX_TEST_NAME,
			"Reflex softmax did not consume exactly one draw."
		)

	return _pass(
		SOFTMAX_TEST_NAME
	)


static func _test_odradek_prediction(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			ODRADEK_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var winner = fixture["p0"]
	var thief = fixture["p1"]

	_prepare_game(
		game
	)

	game.reflex_winner = 0
	game.breach = "Odradek"
	game.breach_owner = 1

	winner.lord = "Orias"
	winner.alive = true
	winner.threat = 0

	winner.hand = _cards_from_ids([
		"Wright:5",
		"Vulture:4",
	])

	_set_castles(
		winner,
		[
			"SiegeEngine",
		]
	)

	thief.lord = "Odradek"
	thief.alive = true
	thief.threat = 3

	thief.hand = _cards_from_ids([
		"Butcher:1",
	])

	_set_castles(
		thief,
		[
			"Keep",
		]
	)

	var decisions: Dictionary = (
		BotReflexDoctrineData.build_decisions(
			game,
			rules,
			null,
			BotPolicyData.golden_core()
		)
	)

	var winner_decision: Dictionary = (
		_nested_dictionary(
			decisions,
			"winner_decision"
		)
	)

	var breach_decision: Dictionary = (
		_nested_dictionary(
			decisions,
			"breach_decision"
		)
	)

	if String(
		winner_decision.get(
			"action",
			""
		)
	) != "Hunt":
		return _fail(
			ODRADEK_TEST_NAME,
			"Reflex winner did not choose the expected Hunt."
		)

	if String(
		breach_decision.get(
			"guess",
			""
		)
	) != "Hunt":
		return _fail(
			ODRADEK_TEST_NAME,
			"Odradek did not predict Hunt from public state."
		)

	var stolen_action: Dictionary = (
		_nested_dictionary(
			breach_decision,
			"stolen_action"
		)
	)

	if String(
		stolen_action.get(
			"action",
			""
		)
	) != "Ward":
		return _fail(
			ODRADEK_TEST_NAME,
			"Odradek selected the wrong stolen action."
		)

	if String(
		stolen_action.get(
			"ward_target",
			""
		)
	) != "Lord":
		return _fail(
			ODRADEK_TEST_NAME,
			"Odradek selected the wrong stolen Ward zone."
		)

	var result: Dictionary = (
		ReflexActionEngineData.resolve(
			game,
			rules,
			winner_decision,
			breach_decision
		)
	)

	if not bool(
		result.get(
			"stolen",
			false
		)
	):
		return _fail(
			ODRADEK_TEST_NAME,
			"Matching public prediction did not steal Reflex."
		)

	if int(
		result.get(
			"executed_by",
			-1
		)
	) != 1:
		return _fail(
			ODRADEK_TEST_NAME,
			"Stolen Reflex executed for the wrong player."
		)

	if String(
		result.get(
			"executed_action",
			""
		)
	) != "Ward":
		return _fail(
			ODRADEK_TEST_NAME,
			"Stolen Reflex executed the wrong action."
		)

	if String(
		thief.sigils.get(
			"Lord",
			""
		)
	) != "fresh":
		return _fail(
			ODRADEK_TEST_NAME,
			"Stolen Ward did not place a Fresh Lord Sigil."
		)

	if not winner.hand.is_empty():
		return _fail(
			ODRADEK_TEST_NAME,
			"Stolen Reflex left the winner's selected cards in hand."
		)

	return _pass(
		ODRADEK_TEST_NAME
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


static func _prepare_game(
	game
) -> void:
	game.round = 2
	game.first_player = 0

	game.reflex_winner = -1

	game.breach = ""
	game.breach_owner = -1

	game.persist_scorch_pid = -1
	game.persist_scorch_type = ""

	game.neutral_tears = 0
	game.winner = -1
	game.win_by = ""

	game.deck.clear()
	game.discard.clear()

	if game.has_meta(
		"reflex_action_resolved_round"
	):
		game.remove_meta(
			"reflex_action_resolved_round"
		)

	if game.has_meta(
		"first_castle_tear_round"
	):
		game.remove_meta(
			"first_castle_tear_round"
		)

	if game.has_meta(
		"orias_marked_lord"
	):
		game.remove_meta(
			"orias_marked_lord"
		)

	for player in game.players:
		player.alive = true

		player.souls = 0
		player.tears = 0
		player.threat = 0

		player.hand.clear()
		player.garrison.clear()
		player.castle_guards.clear()
		player.lord_guards.clear()
		player.committed.clear()

		player.castles.clear()
		player.ruined_castles.clear()
		player.profaned_castles.clear()

		player.action = ""
		player.tgt_pid = -1
		player.tgt_type = ""
		player.ward_target = ""

		player.was_hunted = false
		player.was_sieged = false
		player.last_sieged_castle = ""

		player.sigils = {
			"Lord": "",
			"Castle": "",
		}

		player.odradek_recoil_done = false
		player.odradek_guards_defeated = 0

		player.gremory_ruin_done = false
		player.gremory_veil_draw_done = false
		player.gremory_lord_guard_draw_done = false

		player.kroni_hunger = 0
		player.kroni_ravenous_used = false
		player.kroni_personally_defeated_guard = false
		player.kroni_enemy_destroyed = false
		player.kroni_tear_milestone_fired = false

		player.kanifous_invoked_suit = ""

		player.deimos_breach_claimed = false

	game.refresh_derived_values()


static func _set_castles(
	player,
	castle_names: Array
) -> void:
	player.castles.clear()

	for raw_castle_name in castle_names:
		player.castles.append(
			String(
				raw_castle_name
			)
		)


static func _cards_from_ids(
	card_ids: Array
) -> Array:
	var cards: Array = []

	for raw_card_identifier in card_ids:
		var card_identifier: String = String(
			raw_card_identifier
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


static func _nested_dictionary(
	source: Dictionary,
	key: String
) -> Dictionary:
	var raw_value = source.get(
		key,
		{}
	)

	if typeof(
		raw_value
	) != TYPE_DICTIONARY:
		return {}

	return raw_value


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
