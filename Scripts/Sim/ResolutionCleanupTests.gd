class_name ResolutionCleanupTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const ResolutionCleanupEngineData = preload(
	"res://Scripts/Sim/ResolutionCleanupEngine.gd"
)


const GREMORY_TEST_NAME := "unit_cleanup_gremory_inevitable_ruin"
const GREMORY_ATOMIC_TEST_NAME := "unit_cleanup_gremory_atomic_validation"
const PENITENT_TEST_NAME := "unit_cleanup_penitent_guards"
const PENITENT_DEFEATED_TEST_NAME := "unit_cleanup_penitent_defeated_guard_conservation"
const PROFANE_TEST_NAME := "unit_cleanup_profane_tears"


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_gremory_inevitable_ruin(
			rules
		),
		_test_gremory_atomic_validation(
			rules
		),
		_test_penitent_cleanup(
			rules
		),
		_test_penitent_defeated_guard_conservation(
			rules
		),
		_test_profane_tears(
			rules
		),
	]


static func _test_gremory_inevitable_ruin(
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

	gremory.hand = _cards_from_ids([
		"Butcher:1",
	])

	gremory.garrison = _cards_from_ids([
		"Wright:2",
	])

	_set_castles(
		opponent,
		[
			"Keep",
			"Stockpile",
		]
	)

	opponent.was_sieged = true
	opponent.last_sieged_castle = "Keep"

	var result: Dictionary = (
		ResolutionCleanupEngineData.resolve(
			game,
			rules,
			{
				0: {
					"payment": [
						{
							"source": "Hand",
							"card": "Butcher:1",
						},
						{
							"source": "Garrison",
							"card": "Wright:2",
						},
					],
				},
			}
		)
	)

	var event: Dictionary = _first_event(
		result,
		"gremory_events"
	)

	if String(
		event.get(
			"action",
			""
		)
	) != "inevitable_ruin":
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin did not resolve."
		)

	if opponent.castles.has(
		"Keep"
	):
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin left the Keep active."
		)

	if not opponent.castles.has(
		"Stockpile"
	):
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin removed the wrong Castle."
		)

	if not opponent.ruined_castles.has(
		"Keep"
	):
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin did not create a Ruined Keep."
		)

	if game.neutral_tears != 1:
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin did not place its Neutral Tear."
		)

	if not gremory.gremory_inevitable_ruin_done:
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin usage flag was not set."
		)

	if not gremory.gremory_ruin_done:
		return _fail(
			GREMORY_TEST_NAME,
			"Predator of Ruin did not trigger."
		)

	if not gremory.garrison.is_empty():
		return _fail(
			GREMORY_TEST_NAME,
			"Garrison payment was not removed."
		)

	if _card_ids(
		gremory.hand
	) != [
		"Wright:2",
	]:
		return _fail(
			GREMORY_TEST_NAME,
			"Predator of Ruin recovered the wrong card."
		)

	if _card_ids(
		game.discard
	) != [
		"Butcher:1",
	]:
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin reached the wrong discard state."
		)

	if _string_array(
		event.get(
			"paid_cards",
			[]
		)
	) != [
		"Butcher:1",
		"Wright:2",
	]:
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin recorded the wrong payment."
		)

	if String(
		event.get(
			"recovered_card",
			""
		)
	) != "Wright:2":
		return _fail(
			GREMORY_TEST_NAME,
			"Predator event recorded the wrong recovered card."
		)

	if int(
		event.get(
			"neutral_tear_gain",
			0
		)
	) != 1:
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin result did not record its Tear."
		)

	return _pass(
		GREMORY_TEST_NAME
	)


static func _test_gremory_atomic_validation(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			GREMORY_ATOMIC_TEST_NAME,
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

	gremory.hand = _cards_from_ids([
		"Butcher:1",
	])

	_set_castles(
		opponent,
		[
			"Keep",
		]
	)

	opponent.was_sieged = true
	opponent.last_sieged_castle = "Keep"

	var hand_before: Array[String] = _card_ids(
		gremory.hand
	)

	var result: Dictionary = (
		ResolutionCleanupEngineData.resolve(
			game,
			rules,
			{
				0: {
					"payment": [
						{
							"source": "Hand",
							"card": "Butcher:1",
						},
						{
							"source": "Garrison",
							"card": "Wright:2",
						},
					],
				},
			}
		)
	)

	var event: Dictionary = _first_event(
		result,
		"gremory_events"
	)

	if String(
		event.get(
			"action",
			""
		)
	) != "invalid":
		return _fail(
			GREMORY_ATOMIC_TEST_NAME,
			"Invalid payment was accepted."
		)

	if String(
		event.get(
			"reason",
			""
		)
	) != "payment_card_missing_Garrison_Wright:2":
		return _fail(
			GREMORY_ATOMIC_TEST_NAME,
			"Invalid payment returned the wrong reason."
		)

	if _card_ids(
		gremory.hand
	) != hand_before:
		return _fail(
			GREMORY_ATOMIC_TEST_NAME,
			"Invalid payment changed Gremory's hand."
		)

	if not opponent.castles.has(
		"Keep"
	):
		return _fail(
			GREMORY_ATOMIC_TEST_NAME,
			"Invalid payment destroyed the Keep."
		)

	if not opponent.ruined_castles.is_empty():
		return _fail(
			GREMORY_ATOMIC_TEST_NAME,
			"Invalid payment created a Ruined Castle."
		)

	if game.neutral_tears != 0:
		return _fail(
			GREMORY_ATOMIC_TEST_NAME,
			"Invalid payment placed a Neutral Tear."
		)

	if gremory.gremory_inevitable_ruin_done:
		return _fail(
			GREMORY_ATOMIC_TEST_NAME,
			"Invalid payment consumed Inevitable Ruin."
		)

	if not game.discard.is_empty():
		return _fail(
			GREMORY_ATOMIC_TEST_NAME,
			"Invalid payment changed the discard."
		)

	return _pass(
		GREMORY_ATOMIC_TEST_NAME
	)


static func _test_penitent_cleanup(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			PENITENT_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player = fixture["p0"]

	_prepare_game(
		game
	)

	var permanent_lord_guard = _card_from_id(
		"Butcher:4"
	)

	var permanent_castle_guard = _card_from_id(
		"Wright:3"
	)

	var temporary_lord_guard = _card_from_id(
		"Penitent:1"
	)

	var temporary_castle_guard = _card_from_id(
		"Vulture:2"
	)

	player.lord_guards = [
		permanent_lord_guard,
		temporary_lord_guard,
	]

	player.castle_guards = [
		temporary_castle_guard,
		permanent_castle_guard,
	]

	player.penitent_temp_guards = [
		temporary_lord_guard,
		temporary_castle_guard,
	]

	var result: Dictionary = (
		ResolutionCleanupEngineData.resolve(
			game,
			rules
		)
	)

	if _card_ids(
		player.lord_guards
	) != [
		"Butcher:4",
	]:
		return _fail(
			PENITENT_TEST_NAME,
			"Penitent cleanup left the wrong Lord Guards."
		)

	if _card_ids(
		player.castle_guards
	) != [
		"Wright:3",
	]:
		return _fail(
			PENITENT_TEST_NAME,
			"Penitent cleanup left the wrong Castle Guards."
		)

	if not player.penitent_temp_guards.is_empty():
		return _fail(
			PENITENT_TEST_NAME,
			"Temporary Guard tracking was not cleared."
		)

	if _card_ids(
		game.discard
	) != [
		"Penitent:1",
		"Vulture:2",
	]:
		return _fail(
			PENITENT_TEST_NAME,
			"Penitent cleanup discarded the wrong cards."
		)

	var event: Dictionary = _first_event(
		result,
		"penitent_events"
	)

	if _string_array(
		event.get(
			"cards",
			[]
		)
	) != [
		"Penitent:1",
		"Vulture:2",
	]:
		return _fail(
			PENITENT_TEST_NAME,
			"Cleanup event recorded the wrong temporary Guards."
		)

	if _string_array(
		event.get(
			"zones",
			[]
		)
	) != [
		"Lord",
		"Castle",
	]:
		return _fail(
			PENITENT_TEST_NAME,
			"Cleanup event recorded the wrong Guard zones."
		)

	return _pass(
		PENITENT_TEST_NAME
	)


static func _test_penitent_defeated_guard_conservation(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			PENITENT_DEFEATED_TEST_NAME,
			String(fixture["error"])
		)

	var game = fixture["game"]
	var player = fixture["p0"]

	_prepare_game(game)

	var defeated_guard = _card_from_id("Vulture:4")

	# Combat already removed this temporary Guard from its Guard zone.
	game.discard = [defeated_guard]
	player.penitent_temp_guards = [defeated_guard]

	var result: Dictionary = (
		ResolutionCleanupEngineData.resolve(
			game,
			rules
		)
	)

	if game.discard.size() != 1:
		return _fail(
			PENITENT_DEFEATED_TEST_NAME,
			"Cleanup duplicated an already-defeated temporary Guard."
		)

	if game.discard[0] != defeated_guard:
		return _fail(
			PENITENT_DEFEATED_TEST_NAME,
			"Cleanup replaced the defeated Guard object."
		)

	if not player.penitent_temp_guards.is_empty():
		return _fail(
			PENITENT_DEFEATED_TEST_NAME,
			"Cleanup retained defeated-Guard tracking."
		)

	var event: Dictionary = _first_event(
		result,
		"penitent_events"
	)

	if not _string_array(event.get("cards", [])).is_empty():
		return _fail(
			PENITENT_DEFEATED_TEST_NAME,
			"Cleanup event re-recorded a previously defeated Guard."
		)

	return _pass(PENITENT_DEFEATED_TEST_NAME)

static func _test_profane_tears(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			PROFANE_TEST_NAME,
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

	player_zero.pending_profane = "Stockpile"
	player_zero.profane_this_round = true

	player_one.pending_profane = "SiegeEngine"
	player_one.profane_this_round = true

	var result: Dictionary = (
		ResolutionCleanupEngineData.resolve(
			game,
			rules
		)
	)

	if player_zero.tears != 1:
		return _fail(
			PROFANE_TEST_NAME,
			"Player zero did not receive the delayed Profane Tear."
		)

	if player_one.tears != 1:
		return _fail(
			PROFANE_TEST_NAME,
			"Player one did not receive the delayed Profane Tear."
		)

	if not player_zero.pending_profane.is_empty():
		return _fail(
			PROFANE_TEST_NAME,
			"Player zero retained its pending Profane marker."
		)

	if not player_one.pending_profane.is_empty():
		return _fail(
			PROFANE_TEST_NAME,
			"Player one retained its pending Profane marker."
		)

	if game.neutral_tears != 0:
		return _fail(
			PROFANE_TEST_NAME,
			"Profane cleanup incorrectly placed Neutral Tears."
		)

	if game.calculate_veil_total() != 2:
		return _fail(
			PROFANE_TEST_NAME,
			"Delayed Profane Tears produced the wrong Veil total."
		)

	var events: Array = result.get(
		"profane_events",
		[]
	)

	if events.size() != 2:
		return _fail(
			PROFANE_TEST_NAME,
			"Expected two delayed Profane events."
		)

	var event_zero: Dictionary = events[0]
	var event_one: Dictionary = events[1]

	if String(
		event_zero.get(
			"castle",
			""
		)
	) != "Stockpile":
		return _fail(
			PROFANE_TEST_NAME,
			"Player zero event recorded the wrong Castle."
		)

	if String(
		event_one.get(
			"castle",
			""
		)
	) != "SiegeEngine":
		return _fail(
			PROFANE_TEST_NAME,
			"Player one event recorded the wrong Castle."
		)

	return _pass(
		PROFANE_TEST_NAME
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

	game.breach = ""
	game.breach_owner = -1

	game.neutral_tears = 0
	game.winner = -1
	game.win_by = ""

	game.deck.clear()
	game.discard.clear()

	if game.has_meta(
		"first_castle_tear_round"
	):
		game.remove_meta(
			"first_castle_tear_round"
		)

	if game.has_meta(
		"any_destruction_round"
	):
		game.remove_meta(
			"any_destruction_round"
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
		player.penitent_temp_guards.clear()

		player.castles.clear()
		player.ruined_castles.clear()
		player.profaned_castles.clear()

		player.was_sieged = false
		player.last_sieged_castle = ""

		player.pending_profane = ""
		player.profane_this_round = false

		player.gremory_ruin_done = false
		player.gremory_inevitable_ruin_done = false
		player.gremory_veil_draw_done = false

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


static func _first_event(
	result: Dictionary,
	key: String
) -> Dictionary:
	var raw_events = result.get(
		key,
		[]
	)

	if typeof(
		raw_events
	) != TYPE_ARRAY:
		return {}

	var events: Array = raw_events

	if events.is_empty():
		return {}

	if typeof(
		events[0]
	) != TYPE_DICTIONARY:
		return {}

	return events[0]


static func _cards_from_ids(
	card_ids: Array[String]
) -> Array:
	var cards: Array = []

	for card_identifier: String in card_ids:
		cards.append(
			_card_from_id(
				card_identifier
			)
		)

	return cards


static func _card_from_id(
	card_identifier: String
):
	var separator_index: int = card_identifier.rfind(
		":"
	)

	assert(
		separator_index > 0,
		"Invalid card identifier: %s"
		% card_identifier
	)

	return CardData.new(
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


static func _string_array(
	values: Array
) -> Array[String]:
	var result: Array[String] = []

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
