class_name SiegeResolutionTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const SiegeResolutionEngineData = preload(
	"res://Scripts/Sim/SiegeResolutionEngine.gd"
)


const GOLDEN_RULE_TEST_NAME := "unit_siege_golden_rule"
const BYPASS_TEST_NAME := "unit_siege_engine_resolution"
const DEIMOS_TEST_NAME := "unit_siege_deimos_claim"
const KALLIGAN_TEST_NAME := "unit_siege_kalligan_wildfire"
const VALAK_TEST_NAME := "unit_siege_valak_siphon"


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_golden_rule(
			rules
		),
		_test_siege_engine_bypass(
			rules
		),
		_test_deimos_claim(
			rules
		),
		_test_kalligan_wildfire(
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

	attacker.lord = "Orias"
	attacker.action = "Siege"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Castle"

	attacker.committed = _cards_from_ids([
		"Wright:5",
		"Vulture:2",
	])

	defender.lord = "Valak"

	_set_castles(
		defender,
		[
			"SiegeEngine",
		]
	)

	var result: Dictionary = (
		SiegeResolutionEngineData.resolve(
			game,
			rules,
			0,
			{
				"target_castle": "SiegeEngine",
			}
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
			"Strength equal to Castle Defense destroyed the Castle."
		)

	if String(
		result.get(
			"stopped_at",
			""
		)
	) != "Castle":
		return _fail(
			GOLDEN_RULE_TEST_NAME,
			"Equal Strength did not stop at the Castle layer."
		)

	if int(
		result.get(
			"strength",
			0
		)
	) != 7:
		return _fail(
			GOLDEN_RULE_TEST_NAME,
			"Siege Strength should be 7."
		)

	if int(
		result.get(
			"structural_defense",
			0
		)
	) != 7:
		return _fail(
			GOLDEN_RULE_TEST_NAME,
			"Siege Engine Defense should be 7."
		)

	if not defender.castles.has(
		"SiegeEngine"
	):
		return _fail(
			GOLDEN_RULE_TEST_NAME,
			"Equal Strength removed the Siege Engine."
		)

	if not defender.ruined_castles.is_empty():
		return _fail(
			GOLDEN_RULE_TEST_NAME,
			"Equal Strength created a Ruined Castle."
		)

	if game.neutral_tears != 0:
		return _fail(
			GOLDEN_RULE_TEST_NAME,
			"Failed Siege placed a Neutral Tear."
		)

	return _pass(
		GOLDEN_RULE_TEST_NAME
	)


static func _test_siege_engine_bypass(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			BYPASS_TEST_NAME,
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

	attacker.lord = "Orias"
	attacker.action = "Siege"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Castle"

	_set_castles(
		attacker,
		[
			"SiegeEngine",
		]
	)

	attacker.committed = _cards_from_ids([
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
		SiegeResolutionEngineData.resolve(
			game,
			rules,
			0,
			{
				"target_castle": "SiegeEngine",
			}
		)
	)

	if not bool(
		result.get(
			"siege_engine_bypass",
			false
		)
	):
		return _fail(
			BYPASS_TEST_NAME,
			"Active Siege Engine did not enable bypass order."
		)

	if not bool(
		result.get(
			"destroyed",
			false
		)
	):
		return _fail(
			BYPASS_TEST_NAME,
			"Bypass did not destroy the structure before reaching Guards."
		)

	if String(
		result.get(
			"stopped_at",
			""
		)
	) != "Guard":
		return _fail(
			BYPASS_TEST_NAME,
			"Bypass should destroy the Castle and then stop at its Guard."
		)

	if _card_ids(
		defender.castle_guards
	) != [
		"Vulture:5",
	]:
		return _fail(
			BYPASS_TEST_NAME,
			"Bypass incorrectly defeated the value-5 Guard."
		)

	if defender.castles.has(
		"SiegeEngine"
	):
		return _fail(
			BYPASS_TEST_NAME,
			"Destroyed Siege Engine remained intact."
		)

	if not defender.ruined_castles.has(
		"SiegeEngine"
	):
		return _fail(
			BYPASS_TEST_NAME,
			"Destroyed Siege Engine was not moved to Ruins."
		)

	if attacker.souls != 1:
		return _fail(
			BYPASS_TEST_NAME,
			"Unguarded Castle destruction should grant one Soul."
		)

	if game.neutral_tears != 1:
		return _fail(
			BYPASS_TEST_NAME,
			"First Castle destruction did not place a Neutral Tear."
		)

	return _pass(
		BYPASS_TEST_NAME
	)


static func _test_deimos_claim(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			DEIMOS_TEST_NAME,
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
	attacker.action = "Siege"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Castle"

	attacker.committed = _cards_from_ids([
		"Butcher:5",
		"Butcher:4",
	])

	defender.lord = "Valak"

	_set_castles(
		defender,
		[
			"SiegeEngine",
			"Keep",
		]
	)

	defender.castle_guards = _cards_from_ids([
		"Penitent:2",
	])

	var result: Dictionary = (
		SiegeResolutionEngineData.resolve(
			game,
			rules,
			0,
			{
				"target_castle": "SiegeEngine",
			}
		)
	)

	if int(
		result.get(
			"strength",
			0
		)
	) != 12:
		return _fail(
			DEIMOS_TEST_NAME,
			"Deimos Siege Strength should be 12."
		)

	if int(
		result.get(
			"war_machine_bonus",
			0
		)
	) != 2:
		return _fail(
			DEIMOS_TEST_NAME,
			"War Machine did not grant its full +2 bonus."
		)

	if not bool(
		result.get(
			"destroyed",
			false
		)
	):
		return _fail(
			DEIMOS_TEST_NAME,
			"Deimos did not destroy the Siege Engine."
		)

	if _string_array(
		result.get(
			"guards_defeated",
			[]
		)
	) != [
		"Penitent:2",
	]:
		return _fail(
			DEIMOS_TEST_NAME,
			"Deimos defeated the wrong Castle Guard."
		)

	if attacker.tears != 1:
		return _fail(
			DEIMOS_TEST_NAME,
			"Claim the Breach did not grant a personal Tear."
		)

	if game.neutral_tears != 0:
		return _fail(
			DEIMOS_TEST_NAME,
			"Deimos Claim incorrectly placed a Neutral Tear."
		)

	if String(
		result.get(
			"tear_source",
			""
		)
	) != "deimos_claim":
		return _fail(
			DEIMOS_TEST_NAME,
			"Siege result recorded the wrong Tear source."
		)

	if not attacker.deimos_breach_claimed:
		return _fail(
			DEIMOS_TEST_NAME,
			"Deimos per-game Claim flag was not set."
		)

	if attacker.souls != 2:
		return _fail(
			DEIMOS_TEST_NAME,
			"Guarded Castle destruction should grant two Souls."
		)

	if _card_ids(
		game.discard
	) != [
		"Penitent:2",
	]:
		return _fail(
			DEIMOS_TEST_NAME,
			"Deimos fixture reached the wrong discard state."
		)

	return _pass(
		DEIMOS_TEST_NAME
	)


static func _test_kalligan_wildfire(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			KALLIGAN_TEST_NAME,
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
	attacker.action = "Siege"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Castle"

	attacker.committed = _cards_from_ids([
		"Wright:5",
		"Vulture:4",
	])

	defender.lord = "Orias"

	_set_castles(
		defender,
		[
			"SiegeEngine",
			"Keep",
		]
	)

	_set_ruined_castles(
		defender,
		[
			"Bastion",
		]
	)

	defender.lord_guards = _cards_from_ids([
		"Butcher:2",
		"Vulture:5",
	])

	var result: Dictionary = (
		SiegeResolutionEngineData.resolve(
			game,
			rules,
			0,
			{
				"target_castle": "SiegeEngine",
			}
		)
	)

	if int(
		result.get(
			"pyroclasm_bonus",
			0
		)
	) != 2:
		return _fail(
			KALLIGAN_TEST_NAME,
			"Pyroclasm did not detect the existing Ruined Castle."
		)

	if not bool(
		result.get(
			"destroyed",
			false
		)
	):
		return _fail(
			KALLIGAN_TEST_NAME,
			"Kalligan did not destroy the Siege Engine."
		)

	if attacker.threat != 1:
		return _fail(
			KALLIGAN_TEST_NAME,
			"Inferno did not increase Kalligan's Threat."
		)

	if String(
		result.get(
			"inferno_card",
			""
		)
	) != "Vulture:5":
		return _fail(
			KALLIGAN_TEST_NAME,
			"Inferno did not defeat the highest Lord Guard."
		)

	if _card_ids(
		defender.lord_guards
	) != [
		"Butcher:2",
	]:
		return _fail(
			KALLIGAN_TEST_NAME,
			"Inferno left the wrong Lord Guard."
		)

	if game.persist_scorch_pid != 1:
		return _fail(
			KALLIGAN_TEST_NAME,
			"Wildfire targeted the wrong player."
		)

	if game.persist_scorch_type != "Castle":
		return _fail(
			KALLIGAN_TEST_NAME,
			"Wildfire should target Castle while another Castle remains."
		)

	if String(
		result.get(
			"wildfire_zone",
			""
		)
	) != "Castle":
		return _fail(
			KALLIGAN_TEST_NAME,
			"Siege result recorded the wrong Wildfire zone."
		)

	if game.neutral_tears != 1:
		return _fail(
			KALLIGAN_TEST_NAME,
			"Kalligan Castle destruction did not place a Neutral Tear."
		)

	if attacker.souls != 1:
		return _fail(
			KALLIGAN_TEST_NAME,
			"Unguarded Castle destruction should grant one Soul."
		)

	if _card_ids(
		game.discard
	) != [
		"Vulture:5",
	]:
		return _fail(
			KALLIGAN_TEST_NAME,
			"Kalligan fixture reached the wrong discard state."
		)

	return _pass(
		KALLIGAN_TEST_NAME
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
	attacker.action = "Siege"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Castle"

	attacker.committed = _cards_from_ids([
		"Butcher:5",
		"Wright:3",
	])

	defender.lord = "Orias"

	_set_castles(
		defender,
		[
			"Keep",
		]
	)

	defender.castle_guards = _cards_from_ids([
		"Vulture:5",
		"Wright:4",
		"Penitent:1",
	])

	var result: Dictionary = (
		SiegeResolutionEngineData.resolve(
			game,
			rules,
			0,
			{
				"target_castle": "Keep",
			}
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
		defender.castle_guards
	) != [
		"Wright:4",
	]:
		return _fail(
			VALAK_TEST_NAME,
			"Valak Siphon left the wrong Castle Guard."
		)

	if not defender.castles.has(
		"Keep"
	):
		return _fail(
			VALAK_TEST_NAME,
			"Valak fixture unexpectedly destroyed the Keep."
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

	if game.neutral_tears != 0:
		return _fail(
			VALAK_TEST_NAME,
			"Failed Siege placed a Neutral Tear."
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

	game.persist_scorch_pid = -1
	game.persist_scorch_type = ""

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

		player.castles.clear()
		player.ruined_castles.clear()
		player.profaned_castles.clear()

		player.action = ""
		player.tgt_pid = -1
		player.tgt_type = ""

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


static func _set_ruined_castles(
	player,
	castle_names: Array
) -> void:
	player.ruined_castles.clear()

	for raw_castle_name in castle_names:
		player.ruined_castles.append(
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
