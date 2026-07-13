class_name RoundTransitionTests
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


const RESET_DRAW_TEST_NAME := "unit_round1_reset_and_draw"
const MARKET_TEST_NAME := "unit_round1_market"
const REPAIR_NOOP_TEST_NAME := "unit_round1_repair_noop"
const REPAIR_PAYMENT_TEST_NAME := "unit_repair_payment_and_restore"
const KALLIGAN_REPAIR_TEST_NAME := "unit_kalligan_repair_scorch"

const EXPECTED_PLAYER_ZERO_DRAW_HAND: Array[String] = [
	"Butcher:4",
	"Penitent:3",
	"Wright:4",
	"Penitent:3",
	"Vulture:1",
	"Butcher:1",
	"Penitent:2",
	"Penitent:5",
	"Penitent:1",
]

const EXPECTED_PLAYER_ONE_DRAW_HAND: Array[String] = [
	"Butcher:4",
	"Vulture:2",
	"Wright:3",
	"Butcher:2",
	"Butcher:3",
	"Wright:3",
	"Vulture:4",
	"Vulture:5",
	"Wright:3",
]

const EXPECTED_PLAYER_ZERO_MARKET_HAND: Array[String] = [
	"Butcher:4",
	"Penitent:3",
	"Wright:4",
	"Penitent:3",
	"Butcher:1",
	"Penitent:2",
	"Penitent:5",
	"Penitent:1",
	"Wright:5",
]

const EXPECTED_MARKET_AFTER_SWAPS: Array[String] = [
	"Penitent:1",
	"Wright:1",
	"Vulture:1",
]

const EXPECTED_REPAIR_PAID_CARDS: Array[String] = [
	"Butcher:1",
	"Penitent:2",
	"Butcher:2",
]


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_round1_reset_and_draw(
			rules
		),
		_test_round1_market(
			rules
		),
		_test_round1_repair_noop(
			rules
		),
		_test_repair_payment_and_restore(
			rules
		),
		_test_kalligan_repair_scorch(
			rules
		),
	]


static func _test_round1_reset_and_draw(
	rules: RuleConfig
) -> Dictionary:
	var fixture := _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			RESET_DRAW_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_dirty_round_state(
		game,
		player_zero,
		player_one
	)

	RoundEngineData.advance_to_round_draw(
		game,
		1,
		rules
	)

	var error := _validate_draw_state(
		game,
		player_zero,
		player_one
	)

	return _result_from_error(
		RESET_DRAW_TEST_NAME,
		error
	)


static func _test_round1_market(
	rules: RuleConfig
) -> Dictionary:
	var fixture := _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			MARKET_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	var results: Array[Dictionary] = (
		RoundEngineData.advance_to_round_market(
			game,
			1,
			rules,
			_round_one_market_choices()
		)
	)

	var error := _validate_market_state(
		game,
		player_zero,
		player_one,
		results
	)

	return _result_from_error(
		MARKET_TEST_NAME,
		error
	)


static func _test_round1_repair_noop(
	rules: RuleConfig
) -> Dictionary:
	var fixture := _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			REPAIR_NOOP_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	var results: Array[Dictionary] = (
		RoundEngineData.advance_to_round_repair(
			game,
			1,
			rules,
			_round_one_market_choices(),
			_round_one_repair_choices()
		)
	)

	var error := (
		_validate_post_market_collections(
			game,
			player_zero,
			player_one
		)
	)

	if error.is_empty():
		error = _validate_repair_noop_results(
			results,
			player_zero,
			player_one
		)

	return _result_from_error(
		REPAIR_NOOP_TEST_NAME,
		error
	)


static func _test_repair_payment_and_restore(
	rules: RuleConfig
) -> Dictionary:
	var fixture := _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			REPAIR_PAYMENT_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_configure_standard_repair_fixture(
		player_zero
	)

	var discard_size_before: int = (
	game.discard.size()
	)

	var results: Array[Dictionary] = (
		RoundEngineData.resolve_repairs(
			game,
			rules,
			_standard_repair_choices()
		)
	)

	var error := _validate_standard_repair(
		game,
		player_zero,
		player_one,
		results,
		discard_size_before
	)

	return _result_from_error(
		REPAIR_PAYMENT_TEST_NAME,
		error
	)


static func _test_kalligan_repair_scorch(
	rules: RuleConfig
) -> Dictionary:
	var fixture := _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			KALLIGAN_REPAIR_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_configure_kalligan_repair_fixture(
		game,
		player_zero
	)

	var results: Array[Dictionary] = (
		RoundEngineData.resolve_repairs(
			game,
			rules,
			_kalligan_repair_choices()
		)
	)

	var error := _validate_kalligan_repair(
		game,
		player_zero,
		player_one,
		results
	)

	return _result_from_error(
		KALLIGAN_REPAIR_TEST_NAME,
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
			"error": "Fixture returned no GameState."
		}

	var player_zero = game.get_player(0)
	var player_one = game.get_player(1)

	if (
		player_zero == null
		or player_one == null
	):
		return {
			"error": "Fixture players are missing."
		}

	return {
		"game": game,
		"p0": player_zero,
		"p1": player_one,
	}


static func _round_one_market_choices() -> Dictionary:
	return {
		1: {
			"pass": true
		},
		0: {
			"take": "Wright:5",
			"give": "Vulture:1"
		},
	}


static func _round_one_repair_choices() -> Dictionary:
	return {
		0: {
			"pass": true
		},
		1: {
			"pass": true
		},
	}


static func _standard_repair_choices() -> Dictionary:
	return {
		0: {
			"castle": "SiegeEngine",
			"use_token": true,
			"payment": [
				"Butcher:1",
				"Penitent:2",
				"Butcher:2",
			],
		},
		1: {
			"pass": true
		},
	}


static func _kalligan_repair_choices() -> Dictionary:
	return {
		0: {
			"castle": "Stockpile",
			"use_token": false,
			"payment": [
				"Butcher:1",
			],
		},
		1: {
			"pass": true
		},
	}


static func _dirty_round_state(
	game,
	player_zero,
	player_one
) -> void:
	game.reflex_winner = 1

	player_zero.action = "Hunt"
	player_zero.tgt_pid = 1
	player_zero.tgt_type = "Lord"
	player_zero.ward_target = "Castle"
	player_zero.was_hunted = true
	player_zero.was_sieged = false
	player_zero.repaired_this_round = true
	player_zero.repair_token_used_this_repair = true

	player_zero.committed.append(
		CardData.new(
			"Butcher",
			1
		)
	)

	player_zero.penitent_temp_guards.append(
		CardData.new(
			"Penitent",
			1
		)
	)

	player_one.action = "Siege"
	player_one.tgt_pid = 0
	player_one.tgt_type = "Castle"
	player_one.ward_target = "Lord"
	player_one.was_hunted = false
	player_one.was_sieged = true
	player_one.repaired_this_round = true
	player_one.repair_token_used_this_repair = true

	player_one.committed.append(
		CardData.new(
			"Wright",
			1
		)
	)

	player_zero.sigils = {
		"Lord": "fresh",
		"Castle": "flipped",
	}

	player_one.sigils = {
		"Lord": "",
		"Castle": "fresh",
	}


static func _configure_standard_repair_fixture(
	player_zero
) -> void:
	player_zero.hand = [
		CardData.new(
			"Butcher",
			1
		),
		CardData.new(
			"Penitent",
			2
		),
		CardData.new(
			"Vulture",
			3
		),
		CardData.new(
			"Wright",
			4
		),
	]

	player_zero.garrison = [
		CardData.new(
			"Butcher",
			2
		),
		CardData.new(
			"Wright",
			5
		),
	]

	player_zero.castles.erase(
		"SiegeEngine"
	)

	if not player_zero.ruined_castles.has(
		"SiegeEngine"
	):
		player_zero.ruined_castles.append(
			"SiegeEngine"
		)

	player_zero.repair_token = 1
	player_zero.repaired_this_round = false
	player_zero.repair_token_used_this_repair = false


static func _configure_kalligan_repair_fixture(
	game,
	player_zero
) -> void:
	player_zero.lord = "Kalligan"
	player_zero.alive = true
	player_zero.kalligan_repair_used = false

	player_zero.hand = [
		CardData.new(
			"Butcher",
			1
		),
		CardData.new(
			"Wright",
			4
		),
	]

	player_zero.garrison.clear()
	player_zero.castles.erase(
		"Stockpile"
	)

	if not player_zero.ruined_castles.has(
		"Stockpile"
	):
		player_zero.ruined_castles.append(
			"Stockpile"
		)

	game.persist_scorch_pid = -1
	game.persist_scorch_type = ""


static func _validate_draw_state(
	game,
	player_zero,
	player_one
) -> String:
	if game.round != 1:
		return (
			"Expected round 1, received %d."
			% game.round
		)

	if game.reflex_winner != -1:
		return "Reflex winner was not reset."

	if not player_zero.was_lord_attacked_prev:
		return (
			"Player zero did not preserve the previous Hunt flag."
		)

	if player_zero.was_castle_attacked_prev:
		return (
			"Player zero incorrectly preserved a Siege flag."
		)

	if player_one.was_lord_attacked_prev:
		return (
			"Player one incorrectly preserved a Hunt flag."
		)

	if not player_one.was_castle_attacked_prev:
		return (
			"Player one did not preserve the previous Siege flag."
		)

	var error := _validate_player_reset(
		player_zero,
		"Player zero"
	)

	if not error.is_empty():
		return error

	error = _validate_player_reset(
		player_one,
		"Player one"
	)

	if not error.is_empty():
		return error

	if String(
		player_zero.sigils.get(
			"Lord",
			""
		)
	) != "flipped":
		return (
			"Player zero Fresh Lord Sigil did not flip."
		)

	if String(
		player_zero.sigils.get(
			"Castle",
			""
		)
	) != "":
		return (
			"Player zero Flipped Castle Sigil was not removed."
		)

	if String(
		player_one.sigils.get(
			"Castle",
			""
		)
	) != "flipped":
		return (
			"Player one Fresh Castle Sigil did not flip."
		)

	var player_zero_hand := _card_ids(
		player_zero.hand
	)

	if (
		player_zero_hand
		!= EXPECTED_PLAYER_ZERO_DRAW_HAND
	):
		return (
			"Player zero Round 1 hand mismatch. Expected %s, received %s."
			% [
				str(
					EXPECTED_PLAYER_ZERO_DRAW_HAND
				),
				str(
					player_zero_hand
				),
			]
		)

	var player_one_hand := _card_ids(
		player_one.hand
	)

	if (
		player_one_hand
		!= EXPECTED_PLAYER_ONE_DRAW_HAND
	):
		return (
			"Player one Round 1 hand mismatch. Expected %s, received %s."
			% [
				str(
					EXPECTED_PLAYER_ONE_DRAW_HAND
				),
				str(
					player_one_hand
				),
			]
		)

	return _validate_shared_draw_state(
		game
	)


static func _validate_market_state(
	game,
	player_zero,
	player_one,
	market_results: Array[Dictionary]
) -> String:
	if market_results.size() != 2:
		return (
			"Expected two Market decisions, received %d."
			% market_results.size()
		)

	var first_result := market_results[0]
	var second_result := market_results[1]

	if int(
		first_result.get(
			"player_id",
			-1
		)
	) != 1:
		return (
			"Market did not begin with first player 1."
		)

	if String(
		first_result.get(
			"action",
			""
		)
	) != "pass":
		return (
			"Player one should pass during the seed-one Market."
		)

	if int(
		second_result.get(
			"player_id",
			-1
		)
	) != 0:
		return (
			"Player zero did not resolve second."
		)

	if String(
		second_result.get(
			"action",
			""
		)
	) != "swap":
		return (
			"Player zero should perform a Market swap."
		)

	if String(
		second_result.get(
			"take",
			""
		)
	) != "Wright:5":
		return (
			"Player zero took the wrong Market card."
		)

	if String(
		second_result.get(
			"give",
			""
		)
	) != "Vulture:1":
		return (
			"Player zero returned the wrong hand card."
		)

	return _validate_post_market_collections(
		game,
		player_zero,
		player_one
	)


static func _validate_post_market_collections(
	game,
	player_zero,
	player_one
) -> String:
	var player_zero_hand := _card_ids(
		player_zero.hand
	)

	if (
		player_zero_hand
		!= EXPECTED_PLAYER_ZERO_MARKET_HAND
	):
		return (
			"Player zero post-Market hand mismatch. Expected %s, received %s."
			% [
				str(
					EXPECTED_PLAYER_ZERO_MARKET_HAND
				),
				str(
					player_zero_hand
				),
			]
		)

	var player_one_hand := _card_ids(
		player_one.hand
	)

	if (
		player_one_hand
		!= EXPECTED_PLAYER_ONE_DRAW_HAND
	):
		return (
			"Player one hand changed despite passing. Expected %s, received %s."
			% [
				str(
					EXPECTED_PLAYER_ONE_DRAW_HAND
				),
				str(
					player_one_hand
				),
			]
		)

	var market_cards := _card_ids(
		game.market
	)

	if (
		market_cards
		!= EXPECTED_MARKET_AFTER_SWAPS
	):
		return (
			"Post-Market cards mismatch. Expected %s, received %s."
			% [
				str(
					EXPECTED_MARKET_AFTER_SWAPS
				),
				str(
					market_cards
				),
			]
		)

	return _validate_shared_draw_state(
		game
	)


static func _validate_repair_noop_results(
	repair_results: Array[Dictionary],
	player_zero,
	player_one
) -> String:
	if repair_results.size() != 2:
		return (
			"Expected two Repair decisions, received %d."
			% repair_results.size()
		)

	for player_id: int in range(2):
		var result := repair_results[
			player_id
		]

		if int(
			result.get(
				"player_id",
				-1
			)
		) != player_id:
			return (
				"Repair order mismatch at player %d."
				% player_id
			)

		if String(
			result.get(
				"action",
				""
			)
		) != "pass":
			return (
				"Player %d should pass the seed-one Repair step."
				% player_id
			)

		if String(
			result.get(
				"reason",
				""
			)
		) != "no_ruins":
			return (
				"Player %d Repair pass should report no_ruins."
				% player_id
			)

	if (
		player_zero.repaired_this_round
		or player_one.repaired_this_round
	):
		return (
			"The seed-one Repair step incorrectly recorded a repair."
		)

	return ""


static func _validate_standard_repair(
	game,
	player_zero,
	player_one,
	repair_results: Array[Dictionary],
	discard_size_before: int
) -> String:
	if repair_results.size() != 2:
		return (
			"Expected two Repair results, received %d."
			% repair_results.size()
		)

	var repair_result := repair_results[0]

	if String(
		repair_result.get(
			"action",
			""
		)
	) != "repair":
		return (
			"Player zero did not complete the repair."
		)

	if String(
		repair_result.get(
			"castle",
			""
		)
	) != "SiegeEngine":
		return (
			"Player zero repaired the wrong Castle."
		)

	if int(
		repair_result.get(
			"cost",
			0
		)
	) != 4:
		return (
			"Expected Repair cost 4 after token, received %d."
			% int(
				repair_result.get(
					"cost",
					0
				)
			)
		)

	if int(
		repair_result.get(
			"paid_total",
			0
		)
	) != 5:
		return (
			"Expected Repair payment total 5."
		)

	var paid_card_values: Array = (
		repair_result.get(
			"paid_cards",
			[]
		)
	)

	var paid_cards := _string_array(
		paid_card_values
	)

	if paid_cards != EXPECTED_REPAIR_PAID_CARDS:
		return (
			"Repair payment cards mismatch. Expected %s, received %s."
			% [
				str(
					EXPECTED_REPAIR_PAID_CARDS
				),
				str(
					paid_cards
				),
			]
		)

	if not bool(
		repair_result.get(
			"used_token",
			false
		)
	):
		return (
			"Repair result did not record token use."
		)

	if not player_zero.castles.has(
		"SiegeEngine"
	):
		return (
			"Siege Engine was not restored."
		)

	if player_zero.ruined_castles.has(
		"SiegeEngine"
	):
		return (
			"Siege Engine remained in Ruined Castles."
		)

	if player_zero.repair_token != 0:
		return (
			"Repair token was not consumed."
		)

	if not player_zero.repaired_this_round:
		return (
			"Repair round flag was not set."
		)

	if not player_zero.repair_token_used_this_repair:
		return (
			"Repair token-use flag was not set."
		)

	var remaining_hand := _card_ids(
		player_zero.hand
	)

	if remaining_hand != [
		"Vulture:3",
		"Wright:4",
	]:
		return (
			"Unexpected hand after Repair payment: %s."
			% str(
				remaining_hand
			)
		)

	var remaining_garrison := _card_ids(
		player_zero.garrison
	)

	if remaining_garrison != [
		"Wright:5",
	]:
		return (
			"Unexpected Garrison after Repair payment: %s."
			% str(
				remaining_garrison
			)
		)

	if (
		game.discard.size()
		!= discard_size_before + 3
	):
		return (
			"Repair did not add three payment cards to discard."
		)

	var discard_ids := _card_ids(
		game.discard
	)

	var discard_tail: Array[String] = []

	for index: int in range(
		discard_ids.size() - 3,
		discard_ids.size()
	):
		discard_tail.append(
			discard_ids[index]
		)

	if (
		discard_tail
		!= EXPECTED_REPAIR_PAID_CARDS
	):
		return (
			"Repair discard order mismatch. Expected %s, received %s."
			% [
				str(
					EXPECTED_REPAIR_PAID_CARDS
				),
				str(
					discard_tail
				),
			]
		)

	if String(
		repair_results[1].get(
			"action",
			""
		)
	) != "pass":
		return (
			"Player one should pass the focused Repair test."
		)

	if player_one.repaired_this_round:
		return (
			"Player one incorrectly recorded a repair."
		)

	return ""


static func _validate_kalligan_repair(
	game,
	player_zero,
	player_one,
	repair_results: Array[Dictionary]
) -> String:
	if repair_results.size() != 2:
		return (
			"Expected two Kalligan Repair results."
		)

	var repair_result := repair_results[0]

	if String(
		repair_result.get(
			"action",
			""
		)
	) != "repair":
		return (
			"Kalligan did not complete the repair."
		)

	if int(
		repair_result.get(
			"cost",
			0
		)
	) != 1:
		return (
			"Kalligan first Repair should cost 1 for Stockpile."
		)

	if not player_zero.kalligan_repair_used:
		return (
			"Kalligan first-Repair flag was not set."
		)

	if not player_zero.castles.has(
		"Stockpile"
	):
		return (
			"Kalligan did not restore Stockpile."
		)

	if player_zero.ruined_castles.has(
		"Stockpile"
	):
		return (
			"Stockpile remained Ruined after Kalligan repair."
		)

	if (
		game.persist_scorch_pid
		!= int(player_one.pid)
	):
		return (
			"Kalligan Repair did not target the opposing player with Scorch."
		)

	if game.persist_scorch_type != "Lord":
		return (
			"Kalligan Repair Scorch did not target the Lord zone."
		)

	if _card_ids(
		player_zero.hand
	) != [
		"Wright:4",
	]:
		return (
			"Kalligan paid the wrong Repair card."
		)

	return ""


static func _validate_shared_draw_state(
	game
) -> String:
	if game.deck.size() != 35:
		return (
			"Expected 35 cards after the Round 1 Draw Step, received %d."
			% game.deck.size()
		)

	if game.deck.is_empty():
		return (
			"Round 1 deck unexpectedly became empty."
		)

	var top_card = game.deck[
		game.deck.size() - 1
	]

	if top_card == null:
		return (
			"Round 1 deck has no top card."
		)

	if top_card.card_id() != "Butcher:4":
		return (
			"Expected Butcher:4 on top of the remaining deck, received %s."
			% top_card.card_id()
		)

	if game.discard.size() != 4:
		return (
			"Opening summon discard changed during Development."
		)

	if game.neutral_tears != 0:
		return (
			"Round 1 incorrectly triggered Veil drift."
		)

	if game.veil_total != 0:
		return (
			"Round 1 Veil total should remain zero."
		)

	return ""


static func _validate_player_reset(
	player,
	label: String
) -> String:
	if not player.action.is_empty():
		return (
			"%s action was not reset."
			% label
		)

	if player.tgt_pid != -1:
		return (
			"%s target player was not reset."
			% label
		)

	if not player.tgt_type.is_empty():
		return (
			"%s target type was not reset."
			% label
		)

	if not player.ward_target.is_empty():
		return (
			"%s Ward target was not reset."
			% label
		)

	if player.was_hunted:
		return (
			"%s current Hunt flag was not reset."
			% label
		)

	if player.was_sieged:
		return (
			"%s current Siege flag was not reset."
			% label
		)

	if player.repaired_this_round:
		return (
			"%s Repair flag was not reset."
			% label
		)

	if player.repair_token_used_this_repair:
		return (
			"%s Repair token-use flag was not reset."
			% label
		)

	if not player.committed.is_empty():
		return (
			"%s committed cards were not cleared."
			% label
		)

	if not player.penitent_temp_guards.is_empty():
		return (
			"%s temporary Penitent Guards were not cleared."
			% label
		)

	return ""


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
				str(card)
			)

	return result


static func _string_array(
	values: Array
) -> Array[String]:
	var result: Array[String] = []

	for value in values:
		result.append(
			String(value)
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
