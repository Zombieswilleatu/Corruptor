class_name DevelopmentStartTests
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

const DrawEngineData = preload(
	"res://Scripts/Sim/DrawEngine.gd"
)

const DevelopmentStartEngineData = preload(
	"res://Scripts/Sim/DevelopmentStartEngine.gd"
)

const BotRoundEngineTestsData = preload(
	"res://Scripts/Sim/BotRoundEngineTests.gd"
)


const RECYCLE_TEST_NAME: String = (
	"unit_draw_engine_seeded_recycle"
)

const OUTSIDE_TEST_NAME: String = (
	"unit_draw_engine_kanifous_breach"
)

const SNARE_TEST_NAME: String = (
	"unit_development_start_orias_snare"
)

const GREMORY_TEST_NAME: String = (
	"unit_development_start_gremory_draws"
)

const BREACH_TEST_NAME: String = (
	"unit_development_start_gremory_breach"
)


static func run(
	rules: RuleConfig
) -> Array:
	var results: Array = [
		_test_seeded_recycle(
			rules
		),
		_test_kanifous_outside_draw(
			rules
		),
		_test_orias_snare(
			rules
		),
		_test_gremory_draws(
			rules
		),
		_test_gremory_breach(
			rules
		),
	]

	results.append_array(
		BotRoundEngineTestsData.run(
			rules
		)
	)

	return results


static func _test_seeded_recycle(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			RECYCLE_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player = fixture["p0"]

	_prepare_game(
		game
	)

	game.deck.clear()

	game.discard = _cards_from_ids([
		"Butcher:1",
		"Penitent:2",
		"Vulture:3",
	])

	var random_source = PythonRandomData.new(
		1
	)

	var result: Dictionary = (
		DrawEngineData.draw_to_hand(
			game,
			player,
			rules,
			random_source,
			false
		)
	)

	if not bool(
		result.get(
			"drawn",
			false
		)
	):
		return _fail(
			RECYCLE_TEST_NAME,
			"Recycled deck produced no card."
		)

	if not bool(
		result.get(
			"recycled",
			false
		)
	):
		return _fail(
			RECYCLE_TEST_NAME,
			"Empty deck did not recycle the discard."
		)

	if String(
		result.get(
			"card",
			""
		)
	) != "Butcher:1":
		return _fail(
			RECYCLE_TEST_NAME,
			"Seed-one recycle drew the wrong card."
		)

	if _card_ids(
		game.deck
	) != [
		"Penitent:2",
		"Vulture:3",
	]:
		return _fail(
			RECYCLE_TEST_NAME,
			"Recycled deck reached the wrong order."
		)

	if not game.discard.is_empty():
		return _fail(
			RECYCLE_TEST_NAME,
			"Recycled cards remained in the discard."
		)

	var next_random: float = (
		random_source.random_float()
	)

	if next_random != 0.2550690257394217:
		return _fail(
			RECYCLE_TEST_NAME,
			"Seeded recycle consumed the wrong RNG stream."
		)

	return _pass(
		RECYCLE_TEST_NAME
	)


static func _test_kanifous_outside_draw(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			OUTSIDE_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player = fixture["p0"]

	_prepare_game(
		game
	)

	game.breach = "Kanifous"

	game.deck = _cards_from_ids([
		"Wright:4",
	])

	player.threat = 0

	var result: Dictionary = (
		DrawEngineData.draw_to_hand(
			game,
			player,
			rules,
			null,
			true
		)
	)

	if String(
		result.get(
			"card",
			""
		)
	) != "Wright:4":
		return _fail(
			OUTSIDE_TEST_NAME,
			"Outside draw selected the wrong card."
		)

	if player.kanifous_outside_draws != 1:
		return _fail(
			OUTSIDE_TEST_NAME,
			"Outside draw counter did not advance."
		)

	if player.threat != 1:
		return _fail(
			OUTSIDE_TEST_NAME,
			"Kanifous Breach did not increase Threat."
		)

	if not bool(
		result.get(
			"kanifous_breach_triggered",
			false
		)
	):
		return _fail(
			OUTSIDE_TEST_NAME,
			"Kanifous Breach was not recorded."
		)

	return _pass(
		OUTSIDE_TEST_NAME
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
	var orias = fixture["p0"]
	var opponent = fixture["p1"]

	_prepare_game(
		game
	)

	orias.lord = "Orias"
	orias.alive = true
	orias.threat = 2

	opponent.hand = _cards_from_ids([
		"Butcher:1",
	])

	opponent.garrison = _cards_from_ids([
		"Vulture:2",
	])

	var result: Dictionary = (
		DevelopmentStartEngineData.resolve(
			game,
			rules,
			null
		)
	)

	if orias.threat != 3:
		return _fail(
			SNARE_TEST_NAME,
			"Orias did not pay the Snare Threat."
		)

	if not opponent.orias_snare_active:
		return _fail(
			SNARE_TEST_NAME,
			"Orias Snare did not mark the opponent."
		)

	var events: Array = result.get(
		"snare_events",
		[]
	)

	if events.size() != 1:
		return _fail(
			SNARE_TEST_NAME,
			"Snare produced the wrong event count."
		)

	if not bool(
		events[0].get(
			"applied",
			false
		)
	):
		return _fail(
			SNARE_TEST_NAME,
			"Snare event did not record application."
		)

	return _pass(
		SNARE_TEST_NAME
	)


static func _test_gremory_draws(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			GREMORY_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var gremory = fixture["p0"]
	var opponent = fixture["p1"]

	_prepare_game(
		game
	)

	gremory.lord = "Gremory"
	gremory.alive = true

	gremory.ruined_castles.append(
		"Keep"
	)

	opponent.ruined_castles.append(
		"Bastion"
	)

	game.deck = _cards_from_ids([
		"Butcher:1",
		"Penitent:2",
		"Vulture:3",
	])

	var result: Dictionary = (
		DevelopmentStartEngineData.resolve(
			game,
			rules,
			null
		)
	)

	if _card_ids(
		gremory.hand
	) != [
		"Vulture:3",
		"Penitent:2",
		"Butcher:1",
	]:
		return _fail(
			GREMORY_TEST_NAME,
			"Picking the Bones drew the wrong cards."
		)

	if gremory.kanifous_outside_draws != 3:
		return _fail(
			GREMORY_TEST_NAME,
			"Picking the Bones did not count three outside draws."
		)

	var events: Array = result.get(
		"gremory_draw_events",
		[]
	)

	if events.size() != 1:
		return _fail(
			GREMORY_TEST_NAME,
			"Picking the Bones produced the wrong event count."
		)

	if int(
		events[0].get(
			"requested_draws",
			0
		)
	) != 3:
		return _fail(
			GREMORY_TEST_NAME,
			"Picking the Bones requested the wrong number of draws."
		)

	return _pass(
		GREMORY_TEST_NAME
	)


static func _test_gremory_breach(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			BREACH_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_prepare_game(
		game
	)

	player_zero.lord = "Deimos"
	player_one.lord = "Valak"

	player_zero.ruined_castles.append(
		"Stockpile"
	)

	player_one.ruined_castles.append(
		"SiegeEngine"
	)

	game.breach = "Gremory"

	game.deck = _cards_from_ids([
		"Butcher:1",
		"Penitent:2",
	])

	var result: Dictionary = (
		DevelopmentStartEngineData.resolve(
			game,
			rules,
			null
		)
	)

	if _card_ids(
		player_zero.hand
	) != [
		"Penitent:2",
	]:
		return _fail(
			BREACH_TEST_NAME,
			"Gremory Breach gave player zero the wrong card."
		)

	if _card_ids(
		player_one.hand
	) != [
		"Butcher:1",
	]:
		return _fail(
			BREACH_TEST_NAME,
			"Gremory Breach gave player one the wrong card."
		)

	if (
		player_zero.kanifous_outside_draws != 1
		or player_one.kanifous_outside_draws != 1
	):
		return _fail(
			BREACH_TEST_NAME,
			"Gremory Breach draws were not marked as outside draws."
		)

	var events: Array = result.get(
		"breach_draw_events",
		[]
	)

	if events.size() != 2:
		return _fail(
			BREACH_TEST_NAME,
			"Gremory Breach produced the wrong event count."
		)

	return _pass(
		BREACH_TEST_NAME
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

	game.breach = ""
	game.breach_owner = -1

	game.winner = -1
	game.win_by = ""

	game.deck.clear()
	game.discard.clear()

	for player in game.players:
		player.alive = true
		player.threat = 0

		player.hand.clear()
		player.garrison.clear()
		player.castle_guards.clear()
		player.lord_guards.clear()
		player.committed.clear()

		player.ruined_castles.clear()
		player.profaned_castles.clear()

		player.orias_snare_active = false
		player.kanifous_outside_draws = 0

	game.refresh_derived_values()


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
				str(
					card
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
