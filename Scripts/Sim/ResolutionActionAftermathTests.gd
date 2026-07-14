class_name ResolutionActionAftermathTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const ResolutionActionAftermathEngineData = preload(
	"res://Scripts/Sim/ResolutionActionAftermathEngine.gd"
)


const KRONI_TEST_NAME := "unit_aftermath_kroni_consume"
const SUIT_TEST_NAME := "unit_aftermath_suit_bonuses"
const VESSEL_TEST_NAME := "unit_aftermath_offer_vessel"
const ATOMIC_TEST_NAME := "unit_aftermath_vessel_atomic_validation"


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_kroni_consume(
			rules
		),
		_test_suit_bonuses(
			rules
		),
		_test_offer_vessel(
			rules
		),
		_test_vessel_atomic_validation(
			rules
		),
	]


static func _test_kroni_consume(
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
	var kroni = fixture["p0"]

	_prepare_game(
		game
	)

	kroni.lord = "Kroni"
	kroni.alive = true
	kroni.kroni_hunger = 2
	kroni.kroni_personally_defeated_guard = true
	kroni.kroni_consume_done = false
	kroni.kroni_tear_milestone_fired = false

	kroni.committed = _cards_from_ids([
		"Butcher:4",
		"Wright:2",
	])

	var result: Dictionary = (
		ResolutionActionAftermathEngineData.resolve(
			game,
			rules,
			0,
			{
				"action": "hunt",
				"guards_defeated": [
					"Penitent:1",
				],
				"destroyed": false,
			}
		)
	)

	if not kroni.kroni_consume_done:
		return _fail(
			KRONI_TEST_NAME,
			"Kroni Consume did not trigger."
		)

	if kroni.kroni_hunger != 3:
		return _fail(
			KRONI_TEST_NAME,
			"Kroni did not advance from Hunger 2 to 3."
		)

	if kroni.tears != 1:
		return _fail(
			KRONI_TEST_NAME,
			"Hunger-3 milestone did not grant a Tear."
		)

	if kroni.souls != 1:
		return _fail(
			KRONI_TEST_NAME,
			"Gorge did not grant its Soul."
		)

	if not kroni.kroni_tear_milestone_fired:
		return _fail(
			KRONI_TEST_NAME,
			"Kroni milestone flag was not set."
		)

	if not kroni.committed.is_empty():
		return _fail(
			KRONI_TEST_NAME,
			"Committed cards were not cleared."
		)

	if _card_ids(
		game.discard
	) != [
		"Butcher:4",
		"Wright:2",
	]:
		return _fail(
			KRONI_TEST_NAME,
			"Aftermath discarded the wrong committed cards."
		)

	var events: Array = result.get(
		"kroni_events",
		[]
	)

	if events.size() != 1:
		return _fail(
			KRONI_TEST_NAME,
			"Expected exactly one Kroni event."
		)

	var event: Dictionary = events[0]

	if int(
		event.get(
			"personal_tear_gain",
			0
		)
	) != 1:
		return _fail(
			KRONI_TEST_NAME,
			"Kroni event did not record its milestone Tear."
		)

	if int(
		event.get(
			"gorge_soul_gain",
			0
		)
	) != 1:
		return _fail(
			KRONI_TEST_NAME,
			"Kroni event did not record Gorge."
		)

	return _pass(
		KRONI_TEST_NAME
	)


static func _test_suit_bonuses(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			SUIT_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player = fixture["p0"]

	_prepare_game(
		game
	)

	player.lord = "Orias"

	player.committed = _cards_from_ids([
		"Vulture:4",
		"Vulture:2",
		"Wright:3",
		"Wright:1",
	])

	game.deck = _cards_from_ids([
		"Butcher:5",
	])

	var result: Dictionary = (
		ResolutionActionAftermathEngineData.resolve(
			game,
			rules,
			0
		)
	)

	if _card_ids(
		player.hand
	) != [
		"Butcher:5",
	]:
		return _fail(
			SUIT_TEST_NAME,
			"Vulture bonus did not draw the top card."
		)

	if player.repair_token != 1:
		return _fail(
			SUIT_TEST_NAME,
			"Wright bonus did not grant a Repair token."
		)

	if player.kanifous_outside_draws != 1:
		return _fail(
			SUIT_TEST_NAME,
			"Outside draw counter was not incremented."
		)

	if not player.committed.is_empty():
		return _fail(
			SUIT_TEST_NAME,
			"Suit-bonus committed cards were not cleared."
		)

	if _card_ids(
		game.discard
	) != [
		"Vulture:4",
		"Vulture:2",
		"Wright:3",
		"Wright:1",
	]:
		return _fail(
			SUIT_TEST_NAME,
			"Suit-bonus aftermath reached the wrong discard state."
		)

	if String(
		result.get(
			"vulture_draw",
			""
		)
	) != "Butcher:5":
		return _fail(
			SUIT_TEST_NAME,
			"Aftermath recorded the wrong Vulture draw."
		)

	if not bool(
		result.get(
			"wright_token_gained",
			false
		)
	):
		return _fail(
			SUIT_TEST_NAME,
			"Aftermath did not record the Wright token."
		)

	return _pass(
		SUIT_TEST_NAME
	)


static func _test_offer_vessel(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			VESSEL_TEST_NAME,
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

	game.breach = "Valak"
	game.breach_owner = 1

	player.lord = "Orias"
	player.alive = true
	player.vessel_used = false

	player.lord_guards = _cards_from_ids([
		"Butcher:1",
		"Wright:2",
	])

	player.committed = _cards_from_ids([
		"Penitent:3",
	])

	opponent.souls = 1

	var result: Dictionary = (
		ResolutionActionAftermathEngineData.resolve(
			game,
			rules,
			0,
			{},
			{
				"offer": true,
			}
		)
	)

	if player.alive:
		return _fail(
			VESSEL_TEST_NAME,
			"Offered Lord remained alive."
		)

	if not player.vessel_used:
		return _fail(
			VESSEL_TEST_NAME,
			"Vessel usage flag was not set."
		)

	if player.vessel_offered_lord != "Orias":
		return _fail(
			VESSEL_TEST_NAME,
			"Vessel did not record the offered Lord."
		)

	if player.tears != 1:
		return _fail(
			VESSEL_TEST_NAME,
			"Offer the Vessel did not grant a Tear."
		)

	if opponent.souls != 2:
		return _fail(
			VESSEL_TEST_NAME,
			"Opponent did not gain one Soul."
		)

	if not player.lord_guards.is_empty():
		return _fail(
			VESSEL_TEST_NAME,
			"Offered Lord Guards remained in play."
		)

	if game.breach != "Valak":
		return _fail(
			VESSEL_TEST_NAME,
			"Offer the Vessel changed the Breach."
		)

	if game.breach_owner != 1:
		return _fail(
			VESSEL_TEST_NAME,
			"Offer the Vessel changed the Breach owner."
		)

	if _card_ids(
		game.discard
	) != [
		"Butcher:1",
		"Wright:2",
		"Penitent:3",
	]:
		return _fail(
			VESSEL_TEST_NAME,
			"Offer the Vessel reached the wrong discard state."
		)

	var vessel_event: Dictionary = result.get(
		"vessel_event",
		{}
	)

	if String(
		vessel_event.get(
			"offered_lord",
			""
		)
	) != "Orias":
		return _fail(
			VESSEL_TEST_NAME,
			"Vessel event recorded the wrong Lord."
		)

	if _string_array(
		vessel_event.get(
			"discarded_lord_guards",
			[]
		)
	) != [
		"Butcher:1",
		"Wright:2",
	]:
		return _fail(
			VESSEL_TEST_NAME,
			"Vessel event recorded the wrong Guards."
		)

	return _pass(
		VESSEL_TEST_NAME
	)


static func _test_vessel_atomic_validation(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			ATOMIC_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player = fixture["p0"]

	_prepare_game(
		game
	)

	player.vessel_used = true

	player.committed = _cards_from_ids([
		"Vulture:4",
	])

	var result: Dictionary = (
		ResolutionActionAftermathEngineData.resolve(
			game,
			rules,
			0,
			{
				"action": "siege",
				"destroyed": true,
				"guards_defeated": [],
			},
			{
				"offer": true,
			}
		)
	)

	if String(
		result.get(
			"action",
			""
		)
	) != "invalid":
		return _fail(
			ATOMIC_TEST_NAME,
			"Already-used Vessel was accepted."
		)

	if String(
		result.get(
			"reason",
			""
		)
	) != "vessel_already_used":
		return _fail(
			ATOMIC_TEST_NAME,
			"Invalid Vessel returned the wrong reason."
		)

	if _card_ids(
		player.committed
	) != [
		"Vulture:4",
	]:
		return _fail(
			ATOMIC_TEST_NAME,
			"Invalid Vessel changed committed cards."
		)

	if not game.discard.is_empty():
		return _fail(
			ATOMIC_TEST_NAME,
			"Invalid Vessel changed the discard."
		)

	if game.has_meta(
		"any_destruction_round"
	):
		return _fail(
			ATOMIC_TEST_NAME,
			"Invalid Vessel recorded destruction."
		)

	if player.tears != 0:
		return _fail(
			ATOMIC_TEST_NAME,
			"Invalid Vessel granted a Tear."
		)

	return _pass(
		ATOMIC_TEST_NAME
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

		player.vessel_used = false
		player.vessel_offered_lord = ""

		player.repair_token = 0

		player.kanifous_outside_draws = 0

		player.kroni_hunger = 0
		player.kroni_consume_done = false
		player.kroni_personally_defeated_guard = false
		player.kroni_enemy_destroyed = false
		player.kroni_tear_milestone_fired = false

		player.gremory_veil_draw_done = false

	game.refresh_derived_values()


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
