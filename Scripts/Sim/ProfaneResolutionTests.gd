class_name ProfaneResolutionTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const ProfaneResolutionEngineData = preload(
	"res://Scripts/Sim/ProfaneResolutionEngine.gd"
)


const SUCCESS_TEST_NAME := "unit_profane_success"
const FRESH_SIGIL_TEST_NAME := "unit_profane_fresh_sigil_denial"
const FLIPPED_SIGIL_TEST_NAME := "unit_profane_flipped_sigil"
const INVALID_TARGET_TEST_NAME := "unit_profane_invalid_target"


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_success(
			rules
		),
		_test_fresh_sigil_denial(
			rules
		),
		_test_flipped_sigil(
			rules
		),
		_test_invalid_target(
			rules
		),
	]


static func _test_success(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			SUCCESS_TEST_NAME,
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

	_prepare_profane_player(
		player
	)

	_set_castles(
		player,
		[
			"Keep",
			"SiegeEngine",
		]
	)

	opponent.sigils = {
		"Lord": "",
		"Castle": "",
	}

	player.committed = _cards_from_ids([
		"Butcher:4",
		"Wright:2",
	])

	var committed_before: Array[String] = _card_ids(
		player.committed
	)

	var veil_before: int = int(
		game.calculate_veil_total()
	)

	var result: Dictionary = (
		ProfaneResolutionEngineData.resolve(
			game,
			rules,
			0,
			{
				"target_castle": "SiegeEngine",
			}
		)
	)

	if String(
		result.get(
			"action",
			""
		)
	) != "profane":
		return _fail(
			SUCCESS_TEST_NAME,
			"Profane did not resolve."
		)

	if not bool(
		result.get(
			"profaned",
			false
		)
	):
		return _fail(
			SUCCESS_TEST_NAME,
			"Successful Profane was not recorded."
		)

	if bool(
		result.get(
			"blocked",
			true
		)
	):
		return _fail(
			SUCCESS_TEST_NAME,
			"Unopposed Profane was marked blocked."
		)

	if player.castles.has(
		"SiegeEngine"
	):
		return _fail(
			SUCCESS_TEST_NAME,
			"Profaned Castle remained active."
		)

	if not player.castles.has(
		"Keep"
	):
		return _fail(
			SUCCESS_TEST_NAME,
			"Profane removed the wrong Castle."
		)

	if not player.profaned_castles.has(
		"SiegeEngine"
	):
		return _fail(
			SUCCESS_TEST_NAME,
			"Castle was not moved to Profaned Castles."
		)

	if player.pending_profane != "SiegeEngine":
		return _fail(
			SUCCESS_TEST_NAME,
			"Pending Profane did not track the selected Castle."
		)

	if not player.profane_this_round:
		return _fail(
			SUCCESS_TEST_NAME,
			"Profane round flag was not set."
		)

	if player.tears != 0:
		return _fail(
			SUCCESS_TEST_NAME,
			"Profane granted its Tear before Resolution ended."
		)

	if int(
		game.calculate_veil_total()
	) != veil_before:
		return _fail(
			SUCCESS_TEST_NAME,
			"Profane advanced the Veil before Resolution ended."
		)

	if not bool(
		result.get(
			"tear_pending",
			false
		)
	):
		return _fail(
			SUCCESS_TEST_NAME,
			"Successful Profane did not record its pending Tear."
		)

	if int(
		result.get(
			"tear_gain",
			-1
		)
	) != 0:
		return _fail(
			SUCCESS_TEST_NAME,
			"Profane result recorded an immediate Tear."
		)

	if _card_ids(
		player.committed
	) != committed_before:
		return _fail(
			SUCCESS_TEST_NAME,
			"Profane changed committed cards."
		)

	return _pass(
		SUCCESS_TEST_NAME
	)


static func _test_fresh_sigil_denial(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			FRESH_SIGIL_TEST_NAME,
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

	_prepare_profane_player(
		player
	)

	_set_castles(
		player,
		[
			"Keep",
			"Stockpile",
		]
	)

	opponent.sigils = {
		"Lord": "fresh",
		"Castle": "",
	}

	var result: Dictionary = (
		ProfaneResolutionEngineData.resolve(
			game,
			rules,
			0,
			{
				"target_castle": "Stockpile",
			}
		)
	)

	if not bool(
		result.get(
			"blocked",
			false
		)
	):
		return _fail(
			FRESH_SIGIL_TEST_NAME,
			"Fresh Sigil did not block Profane."
		)

	if String(
		result.get(
			"blocking_zone",
			""
		)
	) != "Lord":
		return _fail(
			FRESH_SIGIL_TEST_NAME,
			"Profane recorded the wrong blocking zone."
		)

	if not player.castles.has(
		"Stockpile"
	):
		return _fail(
			FRESH_SIGIL_TEST_NAME,
			"Blocked Profane removed its Castle."
		)

	if not player.profaned_castles.is_empty():
		return _fail(
			FRESH_SIGIL_TEST_NAME,
			"Blocked Profane created a Profaned Castle."
		)

	if not player.pending_profane.is_empty():
		return _fail(
			FRESH_SIGIL_TEST_NAME,
			"Blocked Profane left a pending Tear marker."
		)

	if player.profane_this_round:
		return _fail(
			FRESH_SIGIL_TEST_NAME,
			"Blocked Profane set the success flag."
		)

	if player.tears != 0:
		return _fail(
			FRESH_SIGIL_TEST_NAME,
			"Blocked Profane granted a Tear."
		)

	return _pass(
		FRESH_SIGIL_TEST_NAME
	)


static func _test_flipped_sigil(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			FLIPPED_SIGIL_TEST_NAME,
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

	_prepare_profane_player(
		player
	)

	_set_castles(
		player,
		[
			"Keep",
			"SummoningCircle",
		]
	)

	opponent.sigils = {
		"Lord": "",
		"Castle": "flipped",
	}

	var result: Dictionary = (
		ProfaneResolutionEngineData.resolve(
			game,
			rules,
			0,
			{
				"target_castle": "SummoningCircle",
			}
		)
	)

	if bool(
		result.get(
			"blocked",
			true
		)
	):
		return _fail(
			FLIPPED_SIGIL_TEST_NAME,
			"Flipped Sigil incorrectly blocked Profane."
		)

	if not bool(
		result.get(
			"profaned",
			false
		)
	):
		return _fail(
			FLIPPED_SIGIL_TEST_NAME,
			"Profane did not resolve through a Flipped Sigil."
		)

	if player.castles.has(
		"SummoningCircle"
	):
		return _fail(
			FLIPPED_SIGIL_TEST_NAME,
			"Flipped-Sigil Profane left the Castle active."
		)

	if not player.profaned_castles.has(
		"SummoningCircle"
	):
		return _fail(
			FLIPPED_SIGIL_TEST_NAME,
			"Flipped-Sigil Profane did not create a Profaned Castle."
		)

	if player.tears != 0:
		return _fail(
			FLIPPED_SIGIL_TEST_NAME,
			"Flipped-Sigil Profane granted its Tear early."
		)

	return _pass(
		FLIPPED_SIGIL_TEST_NAME
	)


static func _test_invalid_target(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			INVALID_TARGET_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player = fixture["p0"]

	_prepare_game(
		game
	)

	_prepare_profane_player(
		player
	)

	_set_castles(
		player,
		[
			"Keep",
		]
	)

	_set_ruined_castles(
		player,
		[
			"Bastion",
		]
	)

	var active_before: Array[String] = (
		player.castles.duplicate()
	)

	var ruined_before: Array[String] = (
		player.ruined_castles.duplicate()
	)

	var result: Dictionary = (
		ProfaneResolutionEngineData.resolve(
			game,
			rules,
			0,
			{
				"target_castle": "Bastion",
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
			INVALID_TARGET_TEST_NAME,
			"Profane accepted a non-active Castle."
		)

	if String(
		result.get(
			"reason",
			""
		)
	) != "target_castle_not_active":
		return _fail(
			INVALID_TARGET_TEST_NAME,
			"Profane returned the wrong invalid-target reason."
		)

	if player.castles != active_before:
		return _fail(
			INVALID_TARGET_TEST_NAME,
			"Invalid Profane changed active Castles."
		)

	if player.ruined_castles != ruined_before:
		return _fail(
			INVALID_TARGET_TEST_NAME,
			"Invalid Profane changed Ruined Castles."
		)

	if not player.profaned_castles.is_empty():
		return _fail(
			INVALID_TARGET_TEST_NAME,
			"Invalid Profane created a Profaned Castle."
		)

	if not player.pending_profane.is_empty():
		return _fail(
			INVALID_TARGET_TEST_NAME,
			"Invalid Profane created a pending Tear."
		)

	if player.profane_this_round:
		return _fail(
			INVALID_TARGET_TEST_NAME,
			"Invalid Profane set the success flag."
		)

	return _pass(
		INVALID_TARGET_TEST_NAME
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

		player.pending_profane = ""
		player.profane_this_round = false

		player.sigils = {
			"Lord": "",
			"Castle": "",
		}

	game.refresh_derived_values()


static func _prepare_profane_player(
	player
) -> void:
	player.action = "Profane"
	player.tgt_pid = int(
		player.pid
	)
	player.tgt_type = "Castle"

	player.pending_profane = ""
	player.profane_this_round = false


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
