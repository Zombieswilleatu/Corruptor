class_name HuntResolutionTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const HuntResolutionEngineData = preload(
	"res://Scripts/Sim/HuntResolutionEngine.gd"
)


const GOLDEN_RULE_TEST_NAME := "unit_hunt_golden_rule"
const BANISH_TEST_NAME := "unit_hunt_banish_overkill"
const ODRADEK_TEST_NAME := "unit_hunt_odradek_recoil"
const VALAK_TEST_NAME := "unit_hunt_valak_siphon"


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_golden_rule(
			rules
		),
		_test_banish_overkill(
			rules
		),
		_test_odradek_recoil(
			rules
		),
		_test_valak_siphon(
			rules
		),
	]


static func _test_golden_rule(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			GOLDEN_RULE_TEST_NAME,
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

	attacker.lord = "Deimos"
	attacker.action = "Hunt"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Lord"

	attacker.committed = _cards_from_ids([
		"Wright:5",
		"Vulture:2",
	])

	defender.lord = "Valak"
	defender.alive = true
	defender.threat = 1

	defender.castles.clear()
	defender.castles.append(
		"Bastion"
	)

	defender.lord_guards.clear()

	var result: Dictionary = (
		HuntResolutionEngineData.resolve(
			game,
			rules,
			0
		)
	)

	if bool(
		result.get(
			"destroyed",
			true
		)
	):
		return _fail(
			GOLDEN_RULE_TEST_NAME,
			"Strength equal to Lord Defense destroyed the Lord."
		)

	if String(
		result.get(
			"stopped_at",
			""
		)
	) != "Lord":
		return _fail(
			GOLDEN_RULE_TEST_NAME,
			"Equal Strength did not stop at the Lord layer."
		)

	if int(
		result.get(
			"strength",
			0
		)
	) != 7:
		return _fail(
			GOLDEN_RULE_TEST_NAME,
			"Hunt Strength should be 7."
		)

	if int(
		result.get(
			"lord_defense",
			0
		)
	) != 7:
		return _fail(
			GOLDEN_RULE_TEST_NAME,
			"Valak Defense should be 7 with Bastion."
		)

	if not defender.alive:
		return _fail(
			GOLDEN_RULE_TEST_NAME,
			"Golden Rule fixture Banished the defender."
		)

	if not game.discard.is_empty():
		return _fail(
			GOLDEN_RULE_TEST_NAME,
			"Golden Rule fixture changed the discard."
		)

	return _pass(
		GOLDEN_RULE_TEST_NAME
	)


static func _test_banish_overkill(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			BANISH_TEST_NAME,
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

	attacker.lord = "Deimos"
	attacker.souls = 0
	attacker.action = "Hunt"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Lord"

	attacker.committed = _cards_from_ids([
		"Butcher:5",
		"Wright:4",
		"Penitent:3",
	])

	defender.lord = "Valak"
	defender.alive = true
	defender.souls = 1
	defender.threat = 1
	defender.castles.clear()
	defender.lord_guards.clear()

	var result: Dictionary = (
		HuntResolutionEngineData.resolve(
			game,
			rules,
			0
		)
	)

	if not bool(
		result.get(
			"banished",
			false
		)
	):
		return _fail(
			BANISH_TEST_NAME,
			"Lethal Hunt did not Banish Valak."
		)

	if defender.alive:
		return _fail(
			BANISH_TEST_NAME,
			"Banished Valak remained alive."
		)

	if attacker.souls != 2:
		return _fail(
			BANISH_TEST_NAME,
			"Attacker did not gain two Banishment Souls."
		)

	if defender.souls != 0:
		return _fail(
			BANISH_TEST_NAME,
			"Defender did not lose one Soul."
		)

	if game.neutral_tears != 1:
		return _fail(
			BANISH_TEST_NAME,
			"Banishment did not place its Neutral Tear."
		)

	if game.breach != "Valak":
		return _fail(
			BANISH_TEST_NAME,
			"Valak did not become the Breach."
		)

	if game.breach_owner != 1:
		return _fail(
			BANISH_TEST_NAME,
			"Breach owner should be player one."
		)

	if defender.threat != 1:
		return _fail(
			BANISH_TEST_NAME,
			"Valak did not reset to return Threat 1."
		)

	if String(
		result.get(
			"overkill_return",
			""
		)
	) != "Penitent:3":
		return _fail(
			BANISH_TEST_NAME,
			"Overkill returned the wrong committed card."
		)

	if _card_ids(
		attacker.hand
	) != [
		"Penitent:3",
	]:
		return _fail(
			BANISH_TEST_NAME,
			"Overkill card did not return to hand."
		)

	if _card_ids(
		attacker.committed
	) != [
		"Butcher:5",
		"Wright:4",
	]:
		return _fail(
			BANISH_TEST_NAME,
			"Overkill left the wrong committed cards."
		)

	return _pass(
		BANISH_TEST_NAME
	)


static func _test_odradek_recoil(
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
	var attacker = fixture["p0"]
	var defender = fixture["p1"]

	_prepare_game(
		game
	)

	attacker.lord = "Kalligan"
	attacker.threat = 0
	attacker.action = "Hunt"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Lord"

	attacker.committed = _cards_from_ids([
		"Vulture:5",
		"Wright:3",
		"Butcher:1",
	])

	defender.lord = "Odradek"
	defender.alive = true
	defender.souls = 0
	defender.threat = 0
	defender.castles.clear()

	defender.lord_guards = _cards_from_ids([
		"Penitent:3",
	])

	var result: Dictionary = (
		HuntResolutionEngineData.resolve(
			game,
			rules,
			0
		)
	)

	if String(
		result.get(
			"recoil_card",
			""
		)
	) != "Butcher:1":
		return _fail(
			ODRADEK_TEST_NAME,
			"DE v2 Recoil did not strip the lowest committed card."
		)

	if not defender.odradek_recoil_done:
		return _fail(
			ODRADEK_TEST_NAME,
			"Odradek Recoil flag was not set."
		)

	if defender.souls != 1:
		return _fail(
			ODRADEK_TEST_NAME,
			"Odradek did not gain its Recoil Soul."
		)

	if attacker.threat != 1:
		return _fail(
			ODRADEK_TEST_NAME,
			"Psychic Backwash did not add one Threat."
		)

	if defender.odradek_guards_defeated != 1:
		return _fail(
			ODRADEK_TEST_NAME,
			"Odradek did not track its defeated Lord Guard."
		)

	if not defender.lord_guards.is_empty():
		return _fail(
			ODRADEK_TEST_NAME,
			"Hunt did not defeat the value-3 Lord Guard."
		)

	if not defender.alive:
		return _fail(
			ODRADEK_TEST_NAME,
			"Equal remaining Strength incorrectly Banished Odradek."
		)

	if _card_ids(
		game.discard
	) != [
		"Butcher:1",
		"Penitent:3",
	]:
		return _fail(
			ODRADEK_TEST_NAME,
			"Recoil fixture reached the wrong discard state."
		)

	return _pass(
		ODRADEK_TEST_NAME
	)


static func _test_valak_siphon(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			VALAK_TEST_NAME,
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

	attacker.lord = "Valak"
	attacker.action = "Hunt"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Lord"

	attacker.committed = _cards_from_ids([
		"Butcher:5",
		"Wright:1",
	])

	defender.lord = "Orias"
	defender.alive = true
	defender.castles.clear()

	defender.lord_guards = _cards_from_ids([
		"Vulture:5",
		"Wright:4",
		"Penitent:1",
	])

	var result: Dictionary = (
		HuntResolutionEngineData.resolve(
			game,
			rules,
			0
		)
	)

	if not bool(
		result.get(
			"ignore_lowest_guard",
			false
		)
	):
		return _fail(
			VALAK_TEST_NAME,
			"Valak did not activate Crushing Presence."
		)

	if _string_array(
		result.get(
			"guards_defeated",
			[]
		)
	) != [
		"Vulture:5",
	]:
		return _fail(
			VALAK_TEST_NAME,
			"Valak combat defeated the wrong initial Guard."
		)

	if String(
		result.get(
			"siphoned_card",
			""
		)
	) != "Penitent:1":
		return _fail(
			VALAK_TEST_NAME,
			"Siphon removed the wrong remaining Guard."
		)

	if _card_ids(
		defender.lord_guards
	) != [
		"Wright:4",
	]:
		return _fail(
			VALAK_TEST_NAME,
			"Valak Siphon left the wrong Lord Guard."
		)

	if _card_ids(
		game.discard
	) != [
		"Vulture:5",
		"Penitent:1",
	]:
		return _fail(
			VALAK_TEST_NAME,
			"Valak fixture reached the wrong discard state."
		)

	if not defender.alive:
		return _fail(
			VALAK_TEST_NAME,
			"Valak fixture unexpectedly Banished Orias."
		)

	return _pass(
		VALAK_TEST_NAME
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

		player.was_hunted = false

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
