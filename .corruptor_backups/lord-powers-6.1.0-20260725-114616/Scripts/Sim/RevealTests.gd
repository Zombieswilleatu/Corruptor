class_name RevealTests
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

const CommitmentEngineData = preload(
	"res://Scripts/Sim/CommitmentEngine.gd"
)

const RevealEngineData = preload(
	"res://Scripts/Sim/RevealEngine.gd"
)


const ROUND_ONE_TEST_NAME := "unit_round1_reveal"
const FLIPPED_SIGIL_TEST_NAME := "unit_reveal_flipped_sigil"
const KANIFOUS_VULTURE_TEST_NAME := "unit_reveal_kanifous_vulture"
const KANIFOUS_PENITENT_TEST_NAME := "unit_reveal_kanifous_penitent"


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_round_one_reveal(
			rules
		),
		_test_flipped_sigil(
			rules
		),
		_test_kanifous_vulture(
			rules
		),
		_test_kanifous_penitent(
			rules
		),
	]


static func _test_round_one_reveal(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			ROUND_ONE_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_advance_round_one_to_commitment(
		game,
		rules
	)

	var discard_before: int = game.discard.size()

	var result: Dictionary = RevealEngineData.resolve(
		game,
		rules
	)

	var error: String = _validate_round_one_reveal(
		game,
		player_zero,
		player_one,
		result,
		discard_before
	)

	return _result_from_error(
		ROUND_ONE_TEST_NAME,
		error
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
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	game.round = 2

	_prepare_commitment_player(
		player_zero,
		[
			"Butcher:5",
			"Vulture:2",
		]
	)

	_prepare_commitment_player(
		player_one,
		[
			"Penitent:4",
		]
	)

	var commitment_result: Dictionary = (
		CommitmentEngineData.resolve(
			game,
			{
				0: {
					"action": "Siege",
					"target_pid": 1,
					"cards": [
						"Butcher:5",
						"Vulture:2",
					],
				},
				1: {
					"action": "Ward",
					"target_pid": 1,
					"target_type": "Castle",
					"cards": [
						"Penitent:4",
					],
				},
			}
		)
	)

	if String(
		commitment_result.get(
			"action",
			""
		)
	) != "commit":
		return _fail(
			FLIPPED_SIGIL_TEST_NAME,
			"Fixture Commitment failed."
		)

	var result: Dictionary = RevealEngineData.resolve(
		game,
		rules
	)

	var error: String = _validate_flipped_sigil(
		player_zero,
		player_one,
		result
	)

	return _result_from_error(
		FLIPPED_SIGIL_TEST_NAME,
		error
	)


static func _test_kanifous_vulture(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			KANIFOUS_VULTURE_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	game.round = 2
	game.deck = _cards_from_ids([
		"Butcher:2",
		"Penitent:5",
		"Wright:1",
		"Vulture:3",
		"Butcher:4",
	])
	game.discard.clear()
	game.neutral_tears = 0

	player_zero.lord = "Kanifous"
	player_zero.alive = true
	player_zero.threat = 2
	player_zero.souls = 0
	player_zero.garrison.clear()
	player_zero.lord_guards.clear()
	player_zero.castle_guards.clear()
	player_zero.penitent_temp_guards.clear()
	player_zero.kanifous_invoked_suit = ""
	player_zero.kanifous_invoked_high = false
	player_zero.kanifous_invokes_this_round = 0
	player_zero.kanifous_outside_draws = 0

	_prepare_commitment_player(
		player_zero,
		[
			"Penitent:2",
			"Penitent:1",
		]
	)

	_prepare_commitment_player(
		player_one,
		[]
	)

	var commitment_result: Dictionary = (
		CommitmentEngineData.resolve(
			game,
			{
				0: {
					"action": "Ward",
					"target_pid": 0,
					"target_type": "Castle",
					"cards": [
						"Penitent:2",
					],
				},
				1: {
					"action": "Profane",
					"target_pid": 1,
					"cards": [],
				},
			}
		)
	)

	if String(
		commitment_result.get(
			"action",
			""
		)
	) != "commit":
		return _fail(
			KANIFOUS_VULTURE_TEST_NAME,
			"Fixture Commitment failed."
		)

	var result: Dictionary = RevealEngineData.resolve(
		game,
		rules
	)

	var error: String = _validate_kanifous_vulture(
		game,
		player_zero,
		result
	)

	return _result_from_error(
		KANIFOUS_VULTURE_TEST_NAME,
		error
	)


static func _test_kanifous_penitent(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			KANIFOUS_PENITENT_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	game.round = 2
	game.deck = _cards_from_ids([
		"Vulture:5",
		"Wright:4",
		"Butcher:1",
		"Penitent:2",
	])
	game.discard.clear()
	game.neutral_tears = 0

	player_zero.lord = "Kanifous"
	player_zero.alive = true
	player_zero.threat = 0
	player_zero.souls = 0
	player_zero.garrison.clear()
	player_zero.penitent_temp_guards.clear()
	player_zero.kanifous_invoked_suit = ""
	player_zero.kanifous_invoked_high = false
	player_zero.kanifous_invokes_this_round = 0

	player_zero.lord_guards = _cards_from_ids([
		"Butcher:1",
	])

	player_zero.castle_guards = _cards_from_ids([
		"Wright:2",
		"Vulture:3",
	])

	_prepare_commitment_player(
		player_zero,
		[
			"Penitent:3",
		]
	)

	_prepare_commitment_player(
		player_one,
		[]
	)

	var commitment_result: Dictionary = (
		CommitmentEngineData.resolve(
			game,
			{
				0: {
					"action": "Ward",
					"target_pid": 0,
					"target_type": "Castle",
					"cards": [
						"Penitent:3",
					],
				},
				1: {
					"action": "Profane",
					"target_pid": 1,
					"cards": [],
				},
			}
		)
	)

	if String(
		commitment_result.get(
			"action",
			""
		)
	) != "commit":
		return _fail(
			KANIFOUS_PENITENT_TEST_NAME,
			"Fixture Commitment failed."
		)

	var result: Dictionary = RevealEngineData.resolve(
		game,
		rules
	)

	var error: String = _validate_kanifous_penitent(
		game,
		player_zero,
		result
	)

	return _result_from_error(
		KANIFOUS_PENITENT_TEST_NAME,
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


static func _advance_round_one_to_commitment(
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

	ReflexBidEngineData.resolve(
		game,
		rules,
		_pass_choices()
	)

	CommitmentEngineData.resolve(
		game,
		{
			0: {
				"action": "Hunt",
				"target_pid": 1,
				"cards": [
					"Butcher:4",
					"Butcher:1",
				],
			},
			1: {
				"action": "Ward",
				"target_pid": 1,
				"target_type": "Lord",
				"cards": [
					"Butcher:2",
					"Butcher:3",
				],
			},
		}
	)


static func _prepare_commitment_player(
	player,
	hand_ids: Array[String]
) -> void:
	player.hand = _cards_from_ids(
		hand_ids
	)

	player.action = ""
	player.tgt_pid = -1
	player.tgt_type = ""
	player.ward_target = ""
	player.prev_ward_target = ""
	player.pending_profane = ""
	player.last_sieged_castle = ""
	player.committed.clear()

	player.sigils = {
		"Lord": "",
		"Castle": "",
	}


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


static func _validate_round_one_reveal(
	game,
	player_zero,
	player_one,
	result: Dictionary,
	discard_before: int
) -> String:
	if String(
		result.get(
			"action",
			""
		)
	) != "reveal":
		return "Round 1 Reveal did not resolve."

	if player_zero.threat != 1:
		return "Player zero Hunt did not increase Threat to 1."

	if player_one.threat != 0:
		return "Player one Lord Ward did not reduce Threat to 0."

	if String(
		player_one.sigils.get(
			"Lord",
			""
		)
	) != "fresh":
		return "Equal committed values should create a Fresh Lord Sigil."

	if not String(
		player_zero.sigils.get(
			"Lord",
			""
		)
	).is_empty():
		return "Hunting player unexpectedly gained a Lord Sigil."

	if _card_ids(
		player_zero.committed
	) != [
		"Butcher:4",
		"Butcher:1",
	]:
		return "Reveal changed player zero's committed cards."

	if _card_ids(
		player_one.committed
	) != [
		"Butcher:2",
		"Butcher:3",
	]:
		return "Reveal changed player one's committed cards."

	if game.discard.size() != discard_before:
		return "Non-Kanifous Reveal changed the discard."

	var player_one_result: Dictionary = _player_result(
		result,
		1
	)

	var ward_event: Dictionary = player_one_result.get(
		"ward",
		{}
	)

	if not bool(
		ward_event.get(
			"contested",
			false
		)
	):
		return "Lord Ward should have been contested by Hunt."

	if String(
		ward_event.get(
			"sigil_state",
			""
		)
	) != "fresh":
		return "Reveal result recorded the wrong Lord Sigil state."

	if int(
		ward_event.get(
			"own_committed_value",
			0
		)
	) != 5:
		return "Ward committed value should be 5."

	if int(
		ward_event.get(
			"opposing_committed_value",
			0
		)
	) != 5:
		return "Hunt committed value should be 5."

	return ""


static func _validate_flipped_sigil(
	player_zero,
	player_one,
	result: Dictionary
) -> String:
	if String(
		result.get(
			"action",
			""
		)
	) != "reveal":
		return "Flipped-Sigil Reveal did not resolve."

	if String(
		player_one.sigils.get(
			"Castle",
			""
		)
	) != "flipped":
		return "Stronger Siege did not Flip the Castle Sigil."

	if player_zero.threat != 0:
		return "Siege incorrectly increased Threat."

	if player_one.threat != 1:
		return "Castle Ward incorrectly changed Valak's Threat."

	var player_one_result: Dictionary = _player_result(
		result,
		1
	)

	var ward_event: Dictionary = player_one_result.get(
		"ward",
		{}
	)

	if not bool(
		ward_event.get(
			"contested",
			false
		)
	):
		return "Castle Ward was not marked contested."

	if int(
		ward_event.get(
			"own_committed_value",
			0
		)
	) != 4:
		return "Castle Ward committed value should be 4."

	if int(
		ward_event.get(
			"opposing_committed_value",
			0
		)
	) != 7:
		return "Siege committed value should be 7."

	return ""


static func _validate_kanifous_vulture(
	game,
	player_zero,
	result: Dictionary
) -> String:
	if player_zero.threat != 3:
		return "Kanifous should advance from Threat 2 to 3."

	if player_zero.souls != 1:
		return "Chosen value 3 should match Threat 3 and gain one Soul."

	if player_zero.kanifous_invokes_this_round != 1:
		return "Kanifous Invoke count should be one."

	if player_zero.kanifous_invoked_suit != "Vulture":
		return "Kanifous should choose Vulture in this fixture."

	if game.neutral_tears != 1:
		return "First revealed value 4 did not place a Neutral Tear."

	if game.calculate_veil_total() != 1:
		return "Kanifous Neutral Tear did not advance the Veil."

	if _card_ids(
		player_zero.hand
	) != [
		"Wright:1",
		"Penitent:5",
		"Butcher:2",
	]:
		return "Vulture Invoke produced the wrong final hand."

	if _card_ids(
		player_zero.garrison
	) != [
		"Vulture:3",
	]:
		return "Chosen Vulture was not banked in Garrison."

	if _card_ids(
		game.discard
	) != [
		"Butcher:4",
		"Penitent:1",
	]:
		return "Vulture Invoke produced the wrong discard."

	if not game.deck.is_empty():
		return "Vulture fixture should consume the prepared deck."

	if player_zero.kanifous_outside_draws != 3:
		return "Vulture Invoke should record three outside draws."

	var player_result: Dictionary = _player_result(
		result,
		0
	)

	var invoke_event: Dictionary = player_result.get(
		"kanifous",
		{}
	)

	if String(
		invoke_event.get(
			"chosen_card",
			""
		)
	) != "Vulture:3":
		return "Invoke result recorded the wrong chosen card."

	if _string_array(
		invoke_event.get(
			"revealed_cards",
			[]
		)
	) != [
		"Butcher:4",
		"Vulture:3",
	]:
		return "Invoke result recorded the wrong revealed cards."

	if _string_array(
		invoke_event.get(
			"drawn_cards",
			[]
		)
	) != [
		"Wright:1",
		"Penitent:5",
		"Butcher:2",
	]:
		return "Invoke result recorded the wrong Vulture draws."

	if String(
		invoke_event.get(
			"hand_discarded",
			""
		)
	) != "Penitent:1":
		return "Vulture discarded the wrong hand card."

	if int(
		invoke_event.get(
			"soul_gain",
			0
		)
	) != 1:
		return "Invoke result did not record the Soul gain."

	return ""


static func _validate_kanifous_penitent(
	game,
	player_zero,
	result: Dictionary
) -> String:
	if player_zero.threat != 1:
		return "Kanifous should advance from Threat 0 to 1."

	if player_zero.souls != 0:
		return "Chosen value 2 should not match Threat 1."

	if player_zero.kanifous_invoked_suit != "Penitent":
		return "Kanifous should choose Penitent in this fixture."

	if game.neutral_tears != 0:
		return "First revealed value 2 should not place a Neutral Tear."

	if _card_ids(
		player_zero.lord_guards
	) != [
		"Butcher:1",
		"Wright:4",
		"Vulture:5",
	]:
		return "Penitent temporary Guards reached the wrong Lord zone state."

	if _card_ids(
		player_zero.castle_guards
	) != [
		"Wright:2",
		"Vulture:3",
	]:
		return "Penitent incorrectly changed the Castle Guard zone."

	if _card_ids(
		player_zero.penitent_temp_guards
	) != [
		"Wright:4",
		"Vulture:5",
	]:
		return "Penitent temporary Guard tracking is incorrect."

	if _card_ids(
		player_zero.garrison
	) != [
		"Penitent:2",
	]:
		return "Chosen Penitent was not banked in Garrison."

	if _card_ids(
		game.discard
	) != [
		"Butcher:1",
	]:
		return "Penitent Invoke discarded the wrong revealed card."

	if not game.deck.is_empty():
		return "Penitent fixture should consume the prepared deck."

	var player_result: Dictionary = _player_result(
		result,
		0
	)

	var invoke_event: Dictionary = player_result.get(
		"kanifous",
		{}
	)

	if _string_array(
		invoke_event.get(
			"temporary_guards",
			[]
		)
	) != [
		"Wright:4",
		"Vulture:5",
	]:
		return "Invoke result recorded the wrong temporary Guards."

	if String(
		invoke_event.get(
			"banked_card",
			""
		)
	) != "Penitent:2":
		return "Invoke result recorded the wrong Garrison card."

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
