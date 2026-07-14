class_name ReflexBidTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)

const DominionRiteEngineData = preload(
	"res://Scripts/Sim/DominionRiteEngine.gd"
)

const DeployEngineData = preload(
	"res://Scripts/Sim/DeployEngine.gd"
)

const SummonEngineData = preload(
	"res://Scripts/Sim/SummonEngine.gd"
)

const ReflexBidEngineData = preload(
	"res://Scripts/Sim/ReflexBidEngine.gd"
)


const ROUND_ONE_SKIP_TEST_NAME := "unit_round1_reflex_skip"
const TIE_TEST_NAME := "unit_reflex_bid_tie"
const WINNER_TEST_NAME := "unit_reflex_bid_winner"
const OVERFLOW_TEST_NAME := "unit_reflex_bid_garrison_overflow"


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_round_one_skip(
			rules
		),
		_test_tie(
			rules
		),
		_test_winner(
			rules
		),
		_test_garrison_overflow(
			rules
		),
	]


static func _test_round_one_skip(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			ROUND_ONE_SKIP_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_advance_through_round_one_development(
		game,
		rules
	)

	var result: Dictionary = ReflexBidEngineData.resolve(
		game,
		rules,
		{
			0: {
				"bid": [
					"Butcher:1",
					"Penitent:1",
				],
			},
			1: {
				"bid": [
					"Vulture:2",
					"Butcher:2",
				],
			},
		}
	)

	var error: String = _validate_round_one_skip(
		game,
		player_zero,
		player_one,
		result
	)

	return _result_from_error(
		ROUND_ONE_SKIP_TEST_NAME,
		error
	)


static func _test_tie(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			TIE_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	game.round = 2
	game.reflex_winner = -1
	game.discard.clear()

	_prepare_player(
		player_zero,
		[
			"Butcher:1",
			"Wright:3",
			"Vulture:5",
		],
		[
			"Penitent:4",
		]
	)

	_prepare_player(
		player_one,
		[
			"Penitent:2",
			"Butcher:2",
			"Wright:4",
		],
		[]
	)

	var result: Dictionary = ReflexBidEngineData.resolve(
		game,
		rules,
		{
			0: {
				"bid": [
					"Butcher:1",
					"Wright:3",
				],
			},
			1: {
				"bid": [
					"Penitent:2",
					"Butcher:2",
				],
			},
		}
	)

	var error: String = _validate_tie(
		game,
		player_zero,
		player_one,
		result
	)

	return _result_from_error(
		TIE_TEST_NAME,
		error
	)


static func _test_winner(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			WINNER_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	game.round = 2
	game.reflex_winner = -1
	game.discard.clear()

	_prepare_player(
		player_zero,
		[
			"Butcher:1",
			"Wright:4",
			"Vulture:5",
		],
		[]
	)

	_prepare_player(
		player_one,
		[
			"Vulture:1",
			"Penitent:2",
			"Butcher:5",
		],
		[]
	)

	var result: Dictionary = ReflexBidEngineData.resolve(
		game,
		rules,
		{
			0: {
				"bid": [
					"Butcher:1",
					"Wright:4",
				],
			},
			1: {
				"bid": [
					"Vulture:1",
					"Penitent:2",
				],
			},
		}
	)

	var error: String = _validate_winner(
		game,
		player_zero,
		player_one,
		result
	)

	return _result_from_error(
		WINNER_TEST_NAME,
		error
	)


static func _test_garrison_overflow(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			OVERFLOW_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	game.round = 3
	game.reflex_winner = -1
	game.discard.clear()

	_prepare_player(
		player_zero,
		[
			"Butcher:2",
			"Wright:5",
		],
		[]
	)

	_prepare_player(
		player_one,
		[
			"Vulture:1",
			"Penitent:2",
			"Butcher:3",
			"Wright:5",
		],
		[
			"Wright:1",
			"Wright:2",
			"Wright:3",
			"Wright:4",
		]
	)

	var result: Dictionary = ReflexBidEngineData.resolve(
		game,
		rules,
		{
			0: {
				"bid": [
					"Butcher:2",
					"Wright:5",
				],
			},
			1: {
				"bid": [
					"Vulture:1",
					"Penitent:2",
					"Butcher:3",
				],
			},
		}
	)

	var error: String = _validate_garrison_overflow(
		game,
		player_zero,
		player_one,
		result
	)

	return _result_from_error(
		OVERFLOW_TEST_NAME,
		error
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


static func _advance_through_round_one_development(
	game,
	rules: RuleConfig
) -> void:
	RoundEngineData.advance_to_round_repair(
		game,
		1,
		rules,
		_round_one_market_choices(),
		_pass_choices()
	)

	DominionRiteEngineData.resolve(
		game,
		rules,
		_pass_choices()
	)

	DeployEngineData.resolve(
		game,
		rules,
		_round_one_deploy_choices()
	)

	SummonEngineData.resolve(
		game,
		rules,
		_pass_choices()
	)


static func _prepare_player(
	player,
	hand_ids: Array[String],
	garrison_ids: Array[String]
) -> void:
	player.hand = _cards_from_ids(
		hand_ids
	)

	player.garrison = _cards_from_ids(
		garrison_ids
	)


static func _round_one_market_choices() -> Dictionary:
	return {
		1: {
			"pass": true,
		},
		0: {
			"take": "Wright:5",
			"give": "Vulture:1",
		},
	}


static func _pass_choices() -> Dictionary:
	return {
		0: {
			"pass": true,
		},
		1: {
			"pass": true,
		},
	}


static func _round_one_deploy_choices() -> Dictionary:
	return {
		0: {
			"moves": [
				{
					"source": "Hand",
					"card": "Penitent:2",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Penitent:3",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Penitent:3",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Wright:4",
					"target": "Lord",
				},
				{
					"source": "Hand",
					"card": "Penitent:5",
					"target": "Lord",
				},
			],
		},
		1: {
			"moves": [
				{
					"source": "Hand",
					"card": "Wright:3",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Wright:3",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Wright:3",
					"target": "Castle",
				},
				{
					"source": "Hand",
					"card": "Vulture:4",
					"target": "Lord",
				},
				{
					"source": "Hand",
					"card": "Vulture:5",
					"target": "Lord",
				},
			],
		},
	}


static func _validate_round_one_skip(
	game,
	player_zero,
	player_one,
	result: Dictionary
) -> String:
	if String(
		result.get(
			"action",
			""
		)
	) != "skip":
		return "Round 1 Reflex Bid was not skipped."

	if String(
		result.get(
			"reason",
			""
		)
	) != "round_one":
		return "Round 1 Reflex Bid returned the wrong reason."

	if game.reflex_winner != -1:
		return "Round 1 incorrectly assigned a Reflex winner."

	if _card_ids(
		player_zero.hand
	) != [
		"Butcher:4",
		"Butcher:1",
		"Penitent:1",
		"Wright:5",
	]:
		return "Round 1 skip changed player zero's hand."

	if _card_ids(
		player_one.hand
	) != [
		"Butcher:4",
		"Vulture:2",
		"Butcher:2",
		"Butcher:3",
	]:
		return "Round 1 skip changed player one's hand."

	if (
		not player_zero.garrison.is_empty()
		or not player_one.garrison.is_empty()
	):
		return "Round 1 skip created Garrison cards."

	if game.discard.size() != 4:
		return "Round 1 skip changed the discard."

	return ""


static func _validate_tie(
	game,
	player_zero,
	player_one,
	result: Dictionary
) -> String:
	if String(
		result.get(
			"action",
			""
		)
	) != "tie":
		return "Equal Reflex bids did not resolve as a tie."

	if not bool(
		result.get(
			"tie",
			false
		)
	):
		return "Tie result did not set its tie flag."

	if game.reflex_winner != -1:
		return "A tied Reflex Bid assigned a winner."

	if _int_array(
		result.get(
			"bid_totals",
			[]
		)
	) != [
		4,
		4,
	]:
		return "Tie totals should be 4 to 4."

	if _card_ids(
		player_zero.hand
	) != [
		"Vulture:5",
		"Butcher:1",
		"Wright:3",
	]:
		return "Player zero did not receive all tied bid cards."

	if _card_ids(
		player_one.hand
	) != [
		"Wright:4",
		"Penitent:2",
		"Butcher:2",
	]:
		return "Player one did not receive all tied bid cards."

	if _card_ids(
		player_zero.garrison
	) != [
		"Penitent:4",
	]:
		return "Tie changed player zero's existing Garrison."

	if not player_one.garrison.is_empty():
		return "Tie incorrectly added cards to player one's Garrison."

	if not game.discard.is_empty():
		return "Tie incorrectly discarded bid cards."

	return ""


static func _validate_winner(
	game,
	player_zero,
	player_one,
	result: Dictionary
) -> String:
	if String(
		result.get(
			"action",
			""
		)
	) != "resolve":
		return "Clear Reflex winner did not resolve."

	if int(
		result.get(
			"winner",
			-1
		)
	) != 0:
		return "Player zero should win the Reflex Bid."

	if game.reflex_winner != 0:
		return "GameState did not record player zero as Reflex winner."

	if _int_array(
		result.get(
			"bid_totals",
			[]
		)
	) != [
		5,
		3,
	]:
		return "Winner test totals should be 5 to 3."

	if _card_ids(
		player_zero.hand
	) != [
		"Vulture:5",
		"Butcher:1",
	]:
		return "Winner did not retrieve the lowest bid card."

	if _card_ids(
		player_one.hand
	) != [
		"Butcher:5",
		"Vulture:1",
	]:
		return "Loser did not retrieve the lowest bid card."

	if _card_ids(
		player_one.garrison
	) != [
		"Penitent:2",
	]:
		return "Loser's remaining bid did not enter Garrison."

	if _card_ids(
		game.discard
	) != [
		"Wright:4",
	]:
		return "Winner's remaining bid was not discarded."

	var winner_result: Dictionary = _player_result(
		result,
		0
	)

	var loser_result: Dictionary = _player_result(
		result,
		1
	)

	if String(
		winner_result.get(
			"retrieved_card",
			""
		)
	) != "Butcher:1":
		return "Winner result recorded the wrong retrieved card."

	if _string_array(
		winner_result.get(
			"discarded_cards",
			[]
		)
	) != [
		"Wright:4",
	]:
		return "Winner result recorded the wrong discard."

	if _string_array(
		loser_result.get(
			"garrisoned_cards",
			[]
		)
	) != [
		"Penitent:2",
	]:
		return "Loser result recorded the wrong Garrison card."

	return ""


static func _validate_garrison_overflow(
	game,
	player_zero,
	player_one,
	result: Dictionary
) -> String:
	if int(
		result.get(
			"winner",
			-1
		)
	) != 0:
		return "Player zero should win the overflow fixture."

	if game.reflex_winner != 0:
		return "Overflow fixture did not record the Reflex winner."

	if _card_ids(
		player_zero.hand
	) != [
		"Butcher:2",
	]:
		return "Overflow winner retrieved the wrong card."

	if _card_ids(
		player_one.hand
	) != [
		"Wright:5",
		"Vulture:1",
	]:
		return "Overflow loser retrieved the wrong card."

	if _card_ids(
		player_one.garrison
	) != [
		"Wright:1",
		"Wright:2",
		"Wright:3",
		"Wright:4",
		"Penitent:2",
	]:
		return "Overflow loser did not fill the final Garrison slot correctly."

	if _card_ids(
		game.discard
	) != [
		"Wright:5",
		"Butcher:3",
	]:
		return "Reflex overflow reached the wrong discard state."

	var loser_result: Dictionary = _player_result(
		result,
		1
	)

	if _string_array(
		loser_result.get(
			"garrisoned_cards",
			[]
		)
	) != [
		"Penitent:2",
	]:
		return "Overflow result recorded the wrong Garrison card."

	if _string_array(
		loser_result.get(
			"discarded_cards",
			[]
		)
	) != [
		"Butcher:3",
	]:
		return "Overflow result recorded the wrong discarded card."

	return ""


static func _player_result(
	phase_result: Dictionary,
	player_id: int
) -> Dictionary:
	var raw_players = phase_result.get(
		"players",
		[]
	)

	if typeof(raw_players) != TYPE_ARRAY:
		return {}

	var player_results: Array = raw_players

	for raw_result in player_results:
		if typeof(raw_result) != TYPE_DICTIONARY:
			continue

		var result: Dictionary = raw_result

		if int(
			result.get(
				"player_id",
				-1
			)
		) == player_id:
			return result

	return {}


static func _cards_from_ids(
	card_ids: Array[String]
) -> Array:
	var cards: Array = []

	for card_identifier in card_ids:
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


static func _result_from_error(
	test_name: String,
	error: String
) -> Dictionary:
	if error.is_empty():
		return _pass(
			test_name
		)

	return _fail(
		test_name,
		error
	)


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
