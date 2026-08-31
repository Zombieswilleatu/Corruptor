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


const PAYMENT_TEST_NAME := "unit_profane_ruins_cost_two_souls"
const REJECTION_TEST_NAME := "unit_profane_ruins_rejects_insufficient_souls"
const BOT_TEST_NAME := "unit_bot_profane_ruins_respects_soul_cost"


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
	player.souls = 3
	var hand_before: Array[String] = _card_ids(player.hand)

	var result: Dictionary = DominionRiteEngineData.resolve_player(
		game,
		0,
		rules,
		{
			"profane_ruins": {
				"castle": "Stockpile",
			},
		}
	)

	var action: Dictionary = _single_action(result)
	if action.is_empty():
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins returned no action.")
	if String(action.get("action", "")) != "profane_ruins":
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins did not resolve.")
	if String(action.get("cost_type", "")) != "souls":
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins did not report a Soul cost.")
	if int(action.get("soul_cost", -1)) != 2:
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins Soul cost should be 2.")
	if int(action.get("souls_before", -1)) != 3 or int(action.get("souls_after", -1)) != 1:
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins reported the wrong Soul exchange.")
	if player.souls != 1:
		return _fail(PAYMENT_TEST_NAME, "Profane the Ruins did not spend exactly 2 Souls.")
	if _card_ids(player.hand) != hand_before or not game.discard.is_empty():
		return _fail(PAYMENT_TEST_NAME, "Soul-priced Profane the Ruins touched Hand/discard.")
	if player.ruined_castles.has("Stockpile"):
		return _fail(PAYMENT_TEST_NAME, "Stockpile remained Ruined.")
	if not player.profaned_castles.has("Stockpile"):
		return _fail(PAYMENT_TEST_NAME, "Stockpile did not become Profaned.")
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
	player.souls = 1
	var hand_before: Array[String] = _card_ids(player.hand)
	var ruined_before: Array[String] = _string_array(player.ruined_castles)

	var result: Dictionary = DominionRiteEngineData.resolve_player(
		game,
		0,
		rules,
		{
			"profane_ruins": {
				"castle": "Stockpile",
			},
		}
	)

	var action: Dictionary = _single_action(result)
	if String(action.get("action", "")) != "invalid":
		return _fail(REJECTION_TEST_NAME, "One-Soul Profane was accepted.")
	if String(action.get("reason", "")) != "insufficient_souls":
		return _fail(REJECTION_TEST_NAME, "Insufficient-Souls Profane returned the wrong reason.")
	if player.souls != 1 or player.tears != 0:
		return _fail(REJECTION_TEST_NAME, "Rejected Profane changed Souls/Tears.")
	if _card_ids(player.hand) != hand_before:
		return _fail(REJECTION_TEST_NAME, "Rejected Profane changed the Hand.")
	if _string_array(player.ruined_castles) != ruined_before or not player.profaned_castles.is_empty():
		return _fail(REJECTION_TEST_NAME, "Rejected Profane changed Castle state.")
	return _pass(REJECTION_TEST_NAME)


static func _test_bot_payment() -> Dictionary:
	var fixture: Dictionary = _build_fixture()
	if fixture.has("error"):
		return _fail(BOT_TEST_NAME, String(fixture["error"]))

	var game = fixture["game"]
	var player = fixture["player"]
	var rules: RuleConfig = fixture["rules"]
	player.tears = 4
	player.souls = 2

	var candidates: Array = BotDominionRiteDoctrineData.evaluate_profane_candidates(
		game,
		0,
		rules
	)

	var found: bool = false
	for raw_candidate in candidates:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue
		var payload = raw_candidate.get("payload", {})
		if typeof(payload) != TYPE_DICTIONARY:
			continue
		if String(payload.get("castle", "")).is_empty():
			continue
		if payload.has("payment") and not _string_array(payload.get("payment", [])).is_empty():
			return _fail(BOT_TEST_NAME, "Soul-priced bot Profane still supplied Hand payment.")
		found = true
		break

	if not found:
		return _fail(BOT_TEST_NAME, "Bot produced no affordable Soul-priced Profane candidate.")

	player.souls = 1
	var poor_candidates: Array = BotDominionRiteDoctrineData.evaluate_profane_candidates(
		game,
		0,
		rules
	)
	for raw_candidate in poor_candidates:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue
		var payload = raw_candidate.get("payload", {})
		if typeof(payload) == TYPE_DICTIONARY and not String(payload.get("castle", "")).is_empty():
			return _fail(BOT_TEST_NAME, "Bot attempted Profane the Ruins with only 1 Soul.")

	return _pass(BOT_TEST_NAME)


static func _build_fixture() -> Dictionary:
	var rules: RuleConfig = RuleConfig.lab_v6_5()
	var game = GameDealFixtureData.build_game_deimos_valak_s1(rules)
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
	return {"game": game, "player": player, "rules": rules}


static func _single_action(result: Dictionary) -> Dictionary:
	var actions = result.get("actions", [])
	if typeof(actions) != TYPE_ARRAY or actions.size() != 1:
		return {}
	if typeof(actions[0]) != TYPE_DICTIONARY:
		return {}
	return actions[0]


static func _card_ids(cards: Array) -> Array[String]:
	var result: Array[String] = []
	for card in cards:
		result.append(String(card.card_id()))
	return result


static func _string_array(values) -> Array[String]:
	var result: Array[String] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		result.append(String(value))
	result.sort()
	return result


static func _pass(name: String) -> Dictionary:
	return {"text": "PASS  %s" % name, "passed": true}


static func _fail(name: String, reason: String) -> Dictionary:
	return {"text": "FAIL  %s: %s" % [name, reason], "passed": false}
