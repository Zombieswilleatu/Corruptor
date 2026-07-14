class_name CommitmentTests
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


const ROUND_ONE_TEST_NAME := "unit_round1_commitment"
const SIEGE_PROFANE_TEST_NAME := "unit_commitment_siege_and_profane"
const VALIDATION_TEST_NAME := "unit_commitment_atomic_validation"
const BANISHED_TEST_NAME := "unit_commitment_banished_lord"


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_round_one_commitment(
			rules
		),
		_test_siege_and_profane(
			rules
		),
		_test_atomic_validation(
			rules
		),
		_test_banished_lord(
			rules
		),
	]


static func _test_round_one_commitment(
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

	_advance_through_round_one_pre_commitment(
		game,
		rules
	)

	var result: Dictionary = CommitmentEngineData.resolve(
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

	var error: String = _validate_round_one_commitment(
		game,
		player_zero,
		player_one,
		result
	)

	return _result_from_error(
		ROUND_ONE_TEST_NAME,
		error
	)


static func _test_siege_and_profane(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			SIEGE_PROFANE_TEST_NAME,
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
			"Wright:1",
		],
		[]
	)

	_prepare_commitment_player(
		player_one,
		[
			"Penitent:4",
		],
		[]
	)

	var player_one_castles_before: Array[String] = (
		player_one.castles.duplicate()
	)

	var result: Dictionary = CommitmentEngineData.resolve(
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
				"action": "Profane",
				"target_pid": 1,
				"cards": [],
			},
		}
	)

	var error: String = _validate_siege_and_profane(
		player_zero,
		player_one,
		player_one_castles_before,
		result
	)

	return _result_from_error(
		SIEGE_PROFANE_TEST_NAME,
		error
	)


static func _test_atomic_validation(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			VALIDATION_TEST_NAME,
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
			"Butcher:4",
		],
		[
			"Wright:5",
		]
	)

	_prepare_commitment_player(
		player_one,
		[
			"Penitent:3",
		],
		[]
	)

	player_one.prev_ward_target = "Lord"

	var repeated_ward_result: Dictionary = (
		CommitmentEngineData.resolve(
			game,
			{
				0: {
					"action": "Hunt",
					"target_pid": 1,
					"cards": [
						"Butcher:4",
					],
				},
				1: {
					"action": "Ward",
					"target_pid": 1,
					"target_type": "Lord",
					"cards": [
						"Penitent:3",
					],
				},
			}
		)
	)

	var error: String = _validate_repeated_ward_atomicity(
		player_zero,
		player_one,
		repeated_ward_result
	)

	if not error.is_empty():
		return _fail(
			VALIDATION_TEST_NAME,
			error
		)

	player_one.prev_ward_target = ""

	var garrison_commit_result: Dictionary = (
		CommitmentEngineData.resolve(
			game,
			{
				0: {
					"action": "Hunt",
					"target_pid": 1,
					"cards": [
						"Wright:5",
					],
				},
				1: {
					"action": "Ward",
					"target_pid": 1,
					"target_type": "Castle",
					"cards": [
						"Penitent:3",
					],
				},
			}
		)
	)

	error = _validate_garrison_commit_rejected(
		player_zero,
		player_one,
		garrison_commit_result
	)

	return _result_from_error(
		VALIDATION_TEST_NAME,
		error
	)


static func _test_banished_lord(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			BANISHED_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	game.round = 3

	_prepare_commitment_player(
		player_zero,
		[
			"Butcher:2",
		],
		[]
	)

	_prepare_commitment_player(
		player_one,
		[
			"Vulture:3",
		],
		[]
	)

	player_zero.alive = false

	var invalid_attack_result: Dictionary = (
		CommitmentEngineData.resolve(
			game,
			{
				0: {
					"action": "Hunt",
					"target_pid": 1,
					"cards": [
						"Butcher:2",
					],
				},
				1: {
					"action": "Ward",
					"target_pid": 1,
					"target_type": "Castle",
					"cards": [
						"Vulture:3",
					],
				},
			}
		)
	)

	var error: String = _validate_banished_attack_rejected(
		player_zero,
		player_one,
		invalid_attack_result
	)

	if not error.is_empty():
		return _fail(
			BANISHED_TEST_NAME,
			error
		)

	var valid_ward_result: Dictionary = (
		CommitmentEngineData.resolve(
			game,
			{
				0: {
					"action": "Ward",
					"target_pid": 0,
					"target_type": "Castle",
					"cards": [
						"Butcher:2",
					],
				},
				1: {
					"action": "Siege",
					"target_pid": 0,
					"cards": [
						"Vulture:3",
					],
				},
			}
		)
	)

	error = _validate_banished_castle_ward(
		player_zero,
		player_one,
		valid_ward_result
	)

	return _result_from_error(
		BANISHED_TEST_NAME,
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


static func _advance_through_round_one_pre_commitment(
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


static func _prepare_commitment_player(
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

	player.action = ""
	player.tgt_pid = -1
	player.tgt_type = ""
	player.ward_target = ""
	player.prev_ward_target = ""
	player.pending_profane = ""
	player.last_sieged_castle = ""
	player.committed.clear()


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


static func _validate_round_one_commitment(
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
	) != "commit":
		return "Round 1 Commitment did not resolve."

	if player_zero.action != "Hunt":
		return "Player zero did not commit Hunt."

	if player_zero.tgt_pid != 1:
		return "Player zero Hunt targeted the wrong player."

	if player_zero.tgt_type != "Lord":
		return "Player zero Hunt targeted the wrong zone."

	if not player_zero.ward_target.is_empty():
		return "Hunt incorrectly set a Ward target."

	if _card_ids(
		player_zero.committed
	) != [
		"Butcher:4",
		"Butcher:1",
	]:
		return "Player zero committed the wrong cards."

	if _card_ids(
		player_zero.hand
	) != [
		"Penitent:1",
		"Wright:5",
	]:
		return "Player zero retained the wrong hand."

	if player_one.action != "Ward":
		return "Player one did not commit Ward."

	if player_one.tgt_pid != 1:
		return "Player one Ward targeted the wrong player."

	if player_one.tgt_type != "Lord":
		return "Player one Ward targeted the wrong zone."

	if player_one.ward_target != "Lord":
		return "Player one Ward target was not recorded."

	if _card_ids(
		player_one.committed
	) != [
		"Butcher:2",
		"Butcher:3",
	]:
		return "Player one committed the wrong cards."

	if _card_ids(
		player_one.hand
	) != [
		"Butcher:4",
		"Vulture:2",
	]:
		return "Player one retained the wrong hand."

	if player_zero.threat != 0:
		return "Hunt increased Threat before Reveal."

	if not player_one.sigils["Lord"].is_empty():
		return "Ward placed a Sigil before Reveal."

	if game.discard.size() != 4:
		return "Commitment changed discard."

	var player_zero_result: Dictionary = _player_result(
		result,
		0
	)

	var player_one_result: Dictionary = _player_result(
		result,
		1
	)

	if int(
		player_zero_result.get(
			"committed_value",
			0
		)
	) != 5:
		return "Player zero committed value should be 5."

	if int(
		player_one_result.get(
			"committed_value",
			0
		)
	) != 5:
		return "Player one committed value should be 5."

	var player_zero_suits: Dictionary = (
		player_zero_result.get(
			"suit_counts",
			{}
		)
	)

	if int(
		player_zero_suits.get(
			"Butcher",
			0
		)
	) != 2:
		return "Player zero Butcher count should be 2."

	return ""


static func _validate_siege_and_profane(
	player_zero,
	player_one,
	player_one_castles_before: Array[String],
	result: Dictionary
) -> String:
	if String(
		result.get(
			"action",
			""
		)
	) != "commit":
		return "Siege/Profane Commitment did not resolve."

	if (
		player_zero.action != "Siege"
		or player_zero.tgt_pid != 1
		or player_zero.tgt_type != "Castle"
	):
		return "Siege Commitment recorded the wrong target."

	if _card_ids(
		player_zero.committed
	) != [
		"Butcher:5",
		"Vulture:2",
	]:
		return "Siege committed the wrong cards."

	if _card_ids(
		player_zero.hand
	) != [
		"Wright:1",
	]:
		return "Siege left the wrong hand."

	if not player_zero.last_sieged_castle.is_empty():
		return "Siege selected a specific Castle before Reveal."

	if (
		player_one.action != "Profane"
		or player_one.tgt_pid != 1
		or player_one.tgt_type != "Castle"
	):
		return "Profane Commitment recorded the wrong target."

	if not player_one.committed.is_empty():
		return "Zero-card Profane unexpectedly committed Subjects."

	if not player_one.pending_profane.is_empty():
		return "Profane selected a Castle before Reveal."

	if player_one.castles != player_one_castles_before:
		return "Profane removed a Castle during Commitment."

	if player_one.tears != 0:
		return "Profane granted a Tear during Commitment."

	return ""


static func _validate_repeated_ward_atomicity(
	player_zero,
	player_one,
	result: Dictionary
) -> String:
	if String(
		result.get(
			"action",
			""
		)
	) != "invalid":
		return "Repeated Ward was not rejected."

	if int(
		result.get(
			"invalid_player_id",
			-1
		)
	) != 1:
		return "Repeated Ward rejection named the wrong player."

	if String(
		result.get(
			"reason",
			""
		)
	) != "ward_target_repeated":
		return "Repeated Ward returned the wrong reason."

	if player_zero.action != "":
		return "Atomic validation partially applied player zero's Hunt."

	if not player_zero.committed.is_empty():
		return "Atomic validation partially committed player zero's card."

	if _card_ids(
		player_zero.hand
	) != [
		"Butcher:4",
	]:
		return "Atomic validation changed player zero's hand."

	if player_one.action != "":
		return "Invalid Ward partially changed player one's action."

	if _card_ids(
		player_one.hand
	) != [
		"Penitent:3",
	]:
		return "Invalid Ward changed player one's hand."

	return ""


static func _validate_garrison_commit_rejected(
	player_zero,
	player_one,
	result: Dictionary
) -> String:
	if String(
		result.get(
			"action",
			""
		)
	) != "invalid":
		return "Garrison Commitment was not rejected."

	if int(
		result.get(
			"invalid_player_id",
			-1
		)
	) != 0:
		return "Garrison rejection named the wrong player."

	if String(
		result.get(
			"reason",
			""
		)
	) != "commit_card_missing_Wright:5":
		return "Garrison rejection returned the wrong reason."

	if _card_ids(
		player_zero.hand
	) != [
		"Butcher:4",
	]:
		return "Rejected Garrison Commitment changed the hand."

	if _card_ids(
		player_zero.garrison
	) != [
		"Wright:5",
	]:
		return "Rejected Garrison Commitment removed the Garrison card."

	if player_one.action != "":
		return "Atomic Garrison rejection partially applied player one."

	if _card_ids(
		player_one.hand
	) != [
		"Penitent:3",
	]:
		return "Atomic Garrison rejection changed player one's hand."

	return ""


static func _validate_banished_attack_rejected(
	player_zero,
	player_one,
	result: Dictionary
) -> String:
	if String(
		result.get(
			"action",
			""
		)
	) != "invalid":
		return "Banished Lord attack was not rejected."

	if int(
		result.get(
			"invalid_player_id",
			-1
		)
	) != 0:
		return "Banished Lord rejection named the wrong player."

	if String(
		result.get(
			"reason",
			""
		)
	) != "banished_lord_must_ward":
		return "Banished Lord attack returned the wrong reason."

	if player_zero.action != "":
		return "Rejected Banished Lord attack changed action state."

	if _card_ids(
		player_zero.hand
	) != [
		"Butcher:2",
	]:
		return "Rejected Banished Lord attack changed the hand."

	if player_one.action != "":
		return "Atomic rejection partially committed player one."

	return ""


static func _validate_banished_castle_ward(
	player_zero,
	player_one,
	result: Dictionary
) -> String:
	if String(
		result.get(
			"action",
			""
		)
	) != "commit":
		return "Banished Lord Castle Ward did not resolve."

	if (
		player_zero.action != "Ward"
		or player_zero.tgt_pid != 0
		or player_zero.tgt_type != "Castle"
		or player_zero.ward_target != "Castle"
	):
		return "Banished Lord Castle Ward recorded the wrong state."

	if _card_ids(
		player_zero.committed
	) != [
		"Butcher:2",
	]:
		return "Banished Lord committed the wrong Ward card."

	if not player_zero.hand.is_empty():
		return "Banished Lord Ward card remained in hand."

	if (
		player_one.action != "Siege"
		or player_one.tgt_pid != 0
		or player_one.tgt_type != "Castle"
	):
		return "Opponent Siege recorded the wrong state."

	if _card_ids(
		player_one.committed
	) != [
		"Vulture:3",
	]:
		return "Opponent Siege committed the wrong card."

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
