class_name ProfaneRuinsCostTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const DominionRiteEngineData = preload(
	"res://Scripts/Sim/DominionRiteEngine.gd"
)

const BotDominionRiteDoctrineData = preload(
	"res://Scripts/Sim/BotDominionRiteDoctrine.gd"
)


const PAYMENT_TEST_NAME := "unit_profane_ruins_cost_five"
const REJECTION_TEST_NAME := "unit_profane_ruins_rejects_insufficient_payment"
const BOT_TEST_NAME := "unit_bot_profane_ruins_supplies_payment"


static func run(
	_rules: RuleConfig
) -> Array:
	return [
		_test_payment(),
		_test_insufficient_payment(),
		_test_bot_payment(),
	]


static func _test_payment() -> Dictionary:
	var fixture: Dictionary = _build_fixture()
	if fixture.has("error"):
		return _fail(PAYMENT_TEST_NAME, String(fixture["error"]))

	var game = fixture["game"]
	var player = fixture["player"]
	var rules: RuleConfig = fixture["rules"]

	var result: Dictionary = DominionRiteEngineData.resolve_player(
		game,
		0,
		rules,
		{
			"profane_ruins": {
				"castle": "Stockpile",
				"payment": [
					"Butcher:3",
					"Wright:2",
				],
			},
		}
	)

	var action: Dictionary = _single_action(result)
	if action.is_empty():
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins returned no action.")

	if String(action.get("action", "")) != "profane_ruins":
		return _fail(
			PAYMENT_TEST_NAME,
			"Profane the Ruins did not resolve: %s"
			% String(action.get("reason", "unknown"))
		)

	if int(action.get("cost", -1)) != 5:
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins cost should be 5.")

	if int(action.get("paid_total", -1)) != 5:
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins paid_total should be 5.")

	if _string_array(action.get("paid_cards", [])) != [
		"Butcher:3",
		"Wright:2",
	]:
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins reported the wrong payment.")

	if _card_ids(player.hand) != ["Vulture:1"]:
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins left the wrong Hand.")

	if _card_ids(game.discard) != [
		"Butcher:3",
		"Wright:2",
	]:
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins did not discard its payment.")

	if player.ruined_castles.has("Stockpile"):
		return _fail(PAYMENT_TEST_NAME, "Paid Stockpile remained Ruined.")

	if not player.profaned_castles.has("Stockpile"):
		return _fail(PAYMENT_TEST_NAME, "Paid Stockpile did not become Profaned.")

	if player.tears != 1:
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins did not grant one Tear.")

	return _pass(PAYMENT_TEST_NAME)


static func _test_insufficient_payment() -> Dictionary:
	var fixture: Dictionary = _build_fixture()
	if fixture.has("error"):
		return _fail(REJECTION_TEST_NAME, String(fixture["error"]))

	var game = fixture["game"]
	var player = fixture["player"]
	var rules: RuleConfig = fixture["rules"]

	var hand_before: Array[String] = _card_ids(player.hand)
	var ruined_before: Array[String] = _string_array(player.ruined_castles)
	var discard_before: Array[String] = _card_ids(game.discard)

	var result: Dictionary = DominionRiteEngineData.resolve_player(
		game,
		0,
		rules,
		{
			"profane_ruins": {
				"castle": "Stockpile",
				"payment": [
					"Butcher:3",
					"Vulture:1",
				],
			},
		}
	)

	var action: Dictionary = _single_action(result)
	if String(action.get("action", "")) != "invalid":
		return _fail(REJECTION_TEST_NAME, "Sub-five Profane payment was accepted.")

	if String(action.get("reason", "")) != "insufficient_payment":
		return _fail(
			REJECTION_TEST_NAME,
			"Sub-five Profane returned the wrong rejection reason."
		)

	if _card_ids(player.hand) != hand_before:
		return _fail(REJECTION_TEST_NAME, "Rejected Profane changed the Hand.")

	if _string_array(player.ruined_castles) != ruined_before:
		return _fail(REJECTION_TEST_NAME, "Rejected Profane changed Ruined Castles.")

	if not player.profaned_castles.is_empty():
		return _fail(REJECTION_TEST_NAME, "Rejected Profane created a Profaned Castle.")

	if _card_ids(game.discard) != discard_before:
		return _fail(REJECTION_TEST_NAME, "Rejected Profane changed discard.")

	if player.tears != 0:
		return _fail(REJECTION_TEST_NAME, "Rejected Profane changed Tears.")

	return _pass(REJECTION_TEST_NAME)


static func _test_bot_payment() -> Dictionary:
	var fixture: Dictionary = _build_fixture()
	if fixture.has("error"):
		return _fail(BOT_TEST_NAME, String(fixture["error"]))

	var game = fixture["game"]
	var player = fixture["player"]
	var rules: RuleConfig = fixture["rules"]

	# This bypasses plan ambiguity; the existing doctrine also Profanes once
	# the player already owns a Tear.
	player.tears = 1

	var candidates: Array = BotDominionRiteDoctrineData.evaluate_profane_candidates(
		game,
		0,
		rules
	)

	for raw_candidate in candidates:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = raw_candidate
		var payload = candidate.get("payload", {})
		if typeof(payload) != TYPE_DICTIONARY:
			continue

		if String(payload.get("castle", "")).is_empty():
			continue

		if _string_array(payload.get("payment", [])) != [
			"Butcher:3",
			"Wright:2",
		]:
			return _fail(BOT_TEST_NAME, "Bot Profane supplied the wrong payment.")

		return _pass(BOT_TEST_NAME)

	return _fail(BOT_TEST_NAME, "Bot produced no paid Profane-the-Ruins candidate.")


static func _build_fixture() -> Dictionary:
	var rules: RuleConfig = RuleConfig.lab_v6_5()
	var game = GameDealFixtureData.build_game_deimos_valak_s1(
		rules
	)

	if game == null:
		return {"error": "Fixture returned no GameState."}

	var player = game.get_player(0)
	if player == null:
		return {"error": "Fixture player zero is missing."}

	player.hand = [
		CardData.new("Butcher", 3),
		CardData.new("Wright", 2),
		CardData.new("Vulture", 1),
	]
	player.garrison.clear()
	player.tears = 0
	player.profane_ruins_used_this_round = false
	player.profaned_castles.clear()
	player.ruined_castles.clear()
	player.castles.erase("Stockpile")
	player.castles.erase("SiegeEngine")
	player.ruined_castles.append("Stockpile")
	player.ruined_castles.append("SiegeEngine")

	game.discard.clear()
	game.neutral_tears = 0
	game.winner = -1
	game.win_by = ""
	game.refresh_derived_values()

	return {
		"game": game,
		"player": player,
		"rules": rules,
	}


static func _single_action(
	result: Dictionary
) -> Dictionary:
	var actions = result.get("actions", [])
	if typeof(actions) != TYPE_ARRAY:
		return {}
	if actions.size() != 1:
		return {}
	if typeof(actions[0]) != TYPE_DICTIONARY:
		return {}
	return actions[0]


static func _card_ids(
	cards: Array
) -> Array[String]:
	var result: Array[String] = []
	for card in cards:
		result.append(
			String(card.card_id())
		)
	return result


static func _string_array(
	values
) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result


static func _pass(
	test_name: String
) -> Dictionary:
	return {
		"passed": true,
		"text": "PASS  %s" % test_name,
	}


static func _fail(
	test_name: String,
	reason: String
) -> Dictionary:
	return {
		"passed": false,
		"text": "FAIL  %s: %s" % [
			test_name,
			reason,
		],
	}

