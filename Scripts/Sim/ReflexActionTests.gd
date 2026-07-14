class_name ReflexActionTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const ReflexActionEngineData = preload(
	"res://Scripts/Sim/ReflexActionEngine.gd"
)


const HUNT_TEST_NAME := "unit_reflex_second_hunt"
const SIEGE_TEST_NAME := "unit_reflex_second_siege"
const WARD_TEST_NAME := "unit_reflex_second_ward"
const ODRADEK_TEST_NAME := "unit_reflex_odradek_steal"


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_second_hunt(
			rules
		),
		_test_second_siege(
			rules
		),
		_test_second_ward(
			rules
		),
		_test_odradek_steal(
			rules
		),
	]


static func _test_second_hunt(
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
	attacker.action = "Ward"
	attacker.ward_target = "Castle"
	attacker.threat = 0

	attacker.hand = _cards_from_ids([
		"Wright:5",
		"Vulture:2",
	])

	defender.lord = "Valak"
	defender.alive = true
	defender.threat = 1

	_set_castles(
		defender,
		[
			"Bastion",
		]
	)

	var result: Dictionary = (
		ReflexActionEngineData.resolve(
			game,
			rules,
			{
				"action": "Hunt",
				"cards": [
					"Wright:5",
					"Vulture:2",
				],
			}
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
			"Reflex Hunt did not execute."
		)

	if int(
		result.get(
			"executed_by",
			-1
		)
	) != 0:
		return _fail(
			HUNT_TEST_NAME,
			"Reflex Hunt executed for the wrong player."
		)

	var action_result: Dictionary = result.get(
		"action_result",
		{}
	)

	if int(
		action_result.get(
			"strength",
			0
		)
	) != 7:
		return _fail(
			HUNT_TEST_NAME,
			"Reflex Hunt reached the wrong Strength."
		)

	if bool(
		action_result.get(
			"destroyed",
			true
		)
	):
		return _fail(
			HUNT_TEST_NAME,
			"Equal Strength incorrectly Banished Valak."
		)

	if attacker.threat != 1:
		return _fail(
			HUNT_TEST_NAME,
			"Reflex Hunt did not pay one Threat."
		)

	if not attacker.hand.is_empty():
		return _fail(
			HUNT_TEST_NAME,
			"Reflex Hunt cards remained in hand."
		)

	if _card_ids(
		game.discard
	) != [
		"Wright:5",
		"Vulture:2",
	]:
		return _fail(
			HUNT_TEST_NAME,
			"Reflex Hunt discarded the wrong cards."
		)

	if attacker.action != "Ward":
		return _fail(
			HUNT_TEST_NAME,
			"Reflex Hunt overwrote the original action."
		)

	if attacker.ward_target != "Castle":
		return _fail(
			HUNT_TEST_NAME,
			"Reflex Hunt overwrote the original Ward target."
		)

	if not defender.alive:
		return _fail(
			HUNT_TEST_NAME,
			"Reflex Hunt fixture Banished the defender."
		)

	return _pass(
		HUNT_TEST_NAME
	)


static func _test_second_siege(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			SIEGE_TEST_NAME,
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

	attacker.lord = "Orias"
	attacker.action = "Hunt"

	_set_castles(
		attacker,
		[
			"SiegeEngine",
		]
	)

	attacker.hand = _cards_from_ids([
		"Wright:5",
		"Vulture:3",
	])

	defender.lord = "Valak"

	_set_castles(
		defender,
		[
			"SiegeEngine",
		]
	)

	defender.castle_guards = _cards_from_ids([
		"Vulture:5",
	])

	var result: Dictionary = (
		ReflexActionEngineData.resolve(
			game,
			rules,
			{
				"action": "Siege",
				"cards": [
					"Wright:5",
					"Vulture:3",
				],
				"target_castle": "SiegeEngine",
			}
		)
	)

	var action_result: Dictionary = result.get(
		"action_result",
		{}
	)

	if bool(
		action_result.get(
			"siege_engine_bypass",
			true
		)
	):
		return _fail(
			SIEGE_TEST_NAME,
			"Reflex Siege incorrectly used Siege Engine bypass."
		)

	if bool(
		action_result.get(
			"destroyed",
			true
		)
	):
		return _fail(
			SIEGE_TEST_NAME,
			"Reflex Siege incorrectly destroyed the structure."
		)

	if _string_array(
		action_result.get(
			"guards_defeated",
			[]
		)
	) != [
		"Vulture:5",
	]:
		return _fail(
			SIEGE_TEST_NAME,
			"Reflex Siege defeated the wrong Guard."
		)

	if not defender.castles.has(
		"SiegeEngine"
	):
		return _fail(
			SIEGE_TEST_NAME,
			"Reflex Siege removed the surviving Siege Engine."
		)

	if not defender.castle_guards.is_empty():
		return _fail(
			SIEGE_TEST_NAME,
			"Reflex Siege left the defeated Guard in play."
		)

	if _card_ids(
		game.discard
	) != [
		"Vulture:5",
		"Wright:5",
		"Vulture:3",
	]:
		return _fail(
			SIEGE_TEST_NAME,
			"Reflex Siege reached the wrong discard state."
		)

	if attacker.action != "Hunt":
		return _fail(
			SIEGE_TEST_NAME,
			"Reflex Siege overwrote the original action."
		)

	if game.neutral_tears != 0:
		return _fail(
			SIEGE_TEST_NAME,
			"Failed Reflex Siege placed a Tear."
		)

	return _pass(
		SIEGE_TEST_NAME
	)


static func _test_second_ward(
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

	_prepare_game(
		game
	)

	game.reflex_winner = 0

	player.action = "Siege"
	player.tgt_pid = 1
	player.tgt_type = "Castle"
	player.threat = 3

	var result: Dictionary = (
		ReflexActionEngineData.resolve(
			game,
			rules,
			{
				"action": "Ward",
				"ward_target": "Lord",
			}
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
			"Reflex Ward did not place a Fresh Lord Sigil."
		)

	if player.threat != 2:
		return _fail(
			WARD_TEST_NAME,
			"Reflex Lord Ward did not reduce Threat."
		)

	if player.action != "Siege":
		return _fail(
			WARD_TEST_NAME,
			"Reflex Ward overwrote the original action."
		)

	if player.tgt_pid != 1:
		return _fail(
			WARD_TEST_NAME,
			"Reflex Ward overwrote the original target player."
		)

	if player.tgt_type != "Castle":
		return _fail(
			WARD_TEST_NAME,
			"Reflex Ward overwrote the original target type."
		)

	if not game.discard.is_empty():
		return _fail(
			WARD_TEST_NAME,
			"Reflex Ward changed the discard."
		)

	var action_result: Dictionary = result.get(
		"action_result",
		{}
	)

	if String(
		action_result.get(
			"sigil_state",
			""
		)
	) != "fresh":
		return _fail(
			WARD_TEST_NAME,
			"Reflex Ward result recorded the wrong Sigil state."
		)

	return _pass(
		WARD_TEST_NAME
	)


static func _test_odradek_steal(
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

	winner.hand = _cards_from_ids([
		"Wright:5",
		"Vulture:4",
	])

	thief.lord = "Odradek"
	thief.alive = true

	thief.hand = _cards_from_ids([
		"Butcher:1",
	])

	_set_castles(
		thief,
		[
			"SiegeEngine",
			"Keep",
		]
	)

	var result: Dictionary = (
		ReflexActionEngineData.resolve(
			game,
			rules,
			{
				"action": "Siege",
				"cards": [
					"Wright:5",
					"Vulture:4",
				],
				"target_castle": "SiegeEngine",
			},
			{
				"guess": "Siege",
				"stolen_action": {
					"action": "Ward",
					"ward_target": "Castle",
				},
			}
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
			"Matching Odradek guess did not steal Reflex."
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
			"requested_action",
			""
		)
	) != "Siege":
		return _fail(
			ODRADEK_TEST_NAME,
			"Stolen Reflex recorded the wrong requested action."
		)

	if String(
		result.get(
			"executed_action",
			""
		)
	) != "Ward":
		return _fail(
			ODRADEK_TEST_NAME,
			"Stolen Reflex recorded the wrong executed action."
		)

	if not winner.hand.is_empty():
		return _fail(
			ODRADEK_TEST_NAME,
			"Original Reflex cards remained in the winner's hand."
		)

	if _card_ids(
		game.discard
	) != [
		"Wright:5",
		"Vulture:4",
	]:
		return _fail(
			ODRADEK_TEST_NAME,
			"Odradek steal discarded the wrong winner cards."
		)

	if not thief.castles.has(
		"SiegeEngine"
	):
		return _fail(
			ODRADEK_TEST_NAME,
			"Stolen Reflex allowed the original Siege to resolve."
		)

	if String(
		thief.sigils.get(
			"Castle",
			""
		)
	) != "fresh":
		return _fail(
			ODRADEK_TEST_NAME,
			"Stolen Ward did not place a Fresh Castle Sigil."
		)

	if _card_ids(
		thief.hand
	) != [
		"Butcher:1",
	]:
		return _fail(
			ODRADEK_TEST_NAME,
			"Stolen Ward incorrectly consumed the thief's hand."
		)

	if _string_array(
		result.get(
			"winner_discarded_cards",
			[]
		)
	) != [
		"Wright:5",
		"Vulture:4",
	]:
		return _fail(
			ODRADEK_TEST_NAME,
			"Steal result recorded the wrong discarded cards."
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
