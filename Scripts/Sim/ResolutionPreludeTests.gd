class_name ResolutionPreludeTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const ResolutionPreludeEngineData = preload(
	"res://Scripts/Sim/ResolutionPreludeEngine.gd"
)


const ORDER_TEST_NAME := "unit_resolution_order"
const SCORCH_TEST_NAME := "unit_resolution_persistent_scorch"
const COLLAPSE_TEST_NAME := "unit_resolution_collapse_stack"
const KRONI_TEST_NAME := "unit_resolution_kroni_aura"


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_resolution_order(
			rules
		),
		_test_persistent_scorch(
			rules
		),
		_test_collapse_stack(
			rules
		),
		_test_kroni_aura(
			rules
		),
	]


static func _test_resolution_order(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			ORDER_TEST_NAME,
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

	player_zero.committed = _cards_from_ids([
		"Butcher:3",
		"Wright:2",
	])

	player_one.committed = _cards_from_ids([
		"Vulture:4",
	])

	var clear_result: Dictionary = (
		ResolutionPreludeEngineData.resolve(
			game,
			rules
		)
	)

	if _int_array(
		clear_result.get(
			"order",
			[]
		)
	) != [
		0,
		1,
	]:
		return _fail(
			ORDER_TEST_NAME,
			"Higher committed value did not resolve first."
		)

	if bool(
		clear_result.get(
			"tied",
			true
		)
	):
		return _fail(
			ORDER_TEST_NAME,
			"Unequal committed values were marked tied."
		)

	player_one.committed = _cards_from_ids([
		"Vulture:5",
	])

	var tie_result: Dictionary = (
		ResolutionPreludeEngineData.resolve(
			game,
			rules,
			1
		)
	)

	if _int_array(
		tie_result.get(
			"order",
			[]
		)
	) != [
		1,
		0,
	]:
		return _fail(
			ORDER_TEST_NAME,
			"Explicit tie first-player was not honored."
		)

	if not bool(
		tie_result.get(
			"tied",
			false
		)
	):
		return _fail(
			ORDER_TEST_NAME,
			"Equal committed values were not marked tied."
		)

	return _pass(
		ORDER_TEST_NAME
	)


static func _test_persistent_scorch(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			SCORCH_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_one = fixture["p1"]

	_prepare_game(
		game
	)

	game.persist_scorch_pid = 1
	game.persist_scorch_type = "Lord"

	player_one.lord_guards = _cards_from_ids([
		"Butcher:1",
		"Wright:2",
		"Vulture:3",
	])

	var result: Dictionary = (
		ResolutionPreludeEngineData.resolve(
			game,
			rules,
			0
		)
	)

	if _card_ids(
		player_one.lord_guards
	) != [
		"Vulture:3",
	]:
		return _fail(
			SCORCH_TEST_NAME,
			"Persistent Scorch left the wrong Lord Guards."
		)

	if _card_ids(
		game.discard
	) != [
		"Butcher:1",
		"Wright:2",
	]:
		return _fail(
			SCORCH_TEST_NAME,
			"Persistent Scorch discarded the wrong Guards."
		)

	var scorch_event: Dictionary = result.get(
		"persistent_scorch",
		{}
	)

	if not bool(
		scorch_event.get(
			"applied",
			false
		)
	):
		return _fail(
			SCORCH_TEST_NAME,
			"Persistent Scorch event was not recorded."
		)

	if _string_array(
		scorch_event.get(
			"discarded_cards",
			[]
		)
	) != [
		"Butcher:1",
		"Wright:2",
	]:
		return _fail(
			SCORCH_TEST_NAME,
			"Persistent Scorch result listed the wrong cards."
		)

	return _pass(
		SCORCH_TEST_NAME
	)


static func _test_collapse_stack(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			COLLAPSE_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_one = fixture["p1"]

	_prepare_game(
		game
	)

	game.neutral_tears = 9
	game.breach = "Valak"
	game.breach_owner = 0

	player_one.was_lord_attacked_prev = true

	player_one.lord_guards = _cards_from_ids([
		"Butcher:1",
		"Penitent:2",
		"Wright:3",
		"Vulture:4",
	])

	var result: Dictionary = (
		ResolutionPreludeEngineData.resolve(
			game,
			rules,
			0
		)
	)

	if _card_ids(
		player_one.lord_guards
	) != [
		"Vulture:4",
	]:
		return _fail(
			COLLAPSE_TEST_NAME,
			"Collapse, Valak Breach, and Waning did not stack."
		)

	if _card_ids(
		game.discard
	) != [
		"Butcher:1",
		"Penitent:2",
		"Wright:3",
	]:
		return _fail(
			COLLAPSE_TEST_NAME,
			"Stacked attrition discarded the wrong Guards."
		)

	var collapse_events: Array = result.get(
		"collapse_events",
		[]
	)

	var waning_events: Array = result.get(
		"waning_events",
		[]
	)

	if _discarded_event_cards(
		collapse_events,
		1
	) != [
		"Butcher:1",
	]:
		return _fail(
			COLLAPSE_TEST_NAME,
			"Collapse event recorded the wrong Guard."
		)

	if _discarded_event_cards(
		waning_events,
		1
	) != [
		"Penitent:2",
		"Wright:3",
	]:
		return _fail(
			COLLAPSE_TEST_NAME,
			"Valak/Waning events recorded the wrong Guards."
		)

	return _pass(
		COLLAPSE_TEST_NAME
	)


static func _test_kroni_aura(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			KRONI_TEST_NAME,
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

	player_zero.lord = "Kroni"
	player_zero.alive = true
	player_zero.kroni_hunger = 3

	player_zero.committed = _cards_from_ids([
		"Penitent:2",
	])

	player_one.committed = _cards_from_ids([
		"Vulture:5",
		"Butcher:1",
		"Wright:3",
	])

	var result: Dictionary = (
		ResolutionPreludeEngineData.resolve(
			game,
			rules,
			0
		)
	)

	if _int_array(
		result.get(
			"order",
			[]
		)
	) != [
		1,
		0,
	]:
		return _fail(
			KRONI_TEST_NAME,
			"Resolution order was not locked before Kroni stripped a card."
		)

	if _card_ids(
		player_one.committed
	) != [
		"Vulture:5",
		"Wright:3",
	]:
		return _fail(
			KRONI_TEST_NAME,
			"Kroni removed the wrong committed card."
		)

	if _card_ids(
		game.discard
	) != [
		"Butcher:1",
	]:
		return _fail(
			KRONI_TEST_NAME,
			"Kroni's Hungering Aura reached the wrong discard state."
		)

	var kroni_events: Array = result.get(
		"kroni_events",
		[]
	)

	if kroni_events.size() != 1:
		return _fail(
			KRONI_TEST_NAME,
			"Expected exactly one Kroni Aura event."
		)

	var aura_event: Dictionary = kroni_events[0]

	if String(
		aura_event.get(
			"discarded_card",
			""
		)
	) != "Butcher:1":
		return _fail(
			KRONI_TEST_NAME,
			"Kroni Aura event recorded the wrong card."
		)

	return _pass(
		KRONI_TEST_NAME
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

	game.persist_scorch_pid = -1
	game.persist_scorch_type = ""

	game.neutral_tears = 0
	game.discard.clear()
	game.deck.clear()

	for player in game.players:
		player.tears = 0
		player.hand.clear()
		player.garrison.clear()
		player.castle_guards.clear()
		player.lord_guards.clear()
		player.committed.clear()

		player.was_lord_attacked_prev = false
		player.was_castle_attacked_prev = false

		player.gremory_lord_guard_draw_done = false
		player.kroni_hunger = 0

	game.refresh_derived_values()


static func _discarded_event_cards(
	events: Array,
	player_id: int
) -> Array[String]:
	var cards: Array[String] = []

	for raw_event in events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event

		if int(
			event.get(
				"player_id",
				-1
			)
		) != player_id:
			continue

		var card_identifier: String = String(
			event.get(
				"discarded_card",
				""
			)
		)

		if not card_identifier.is_empty():
			cards.append(
				card_identifier
			)

	return cards


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


static func _int_array(
	values: Array
) -> Array[int]:
	var result: Array[int] = []

	for value in values:
		result.append(
			int(
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
