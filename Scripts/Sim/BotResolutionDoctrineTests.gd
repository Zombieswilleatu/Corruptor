class_name BotResolutionDoctrineTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const ResolutionEngineData = preload(
	"res://Scripts/Sim/ResolutionEngine.gd"
)

const ResolutionActionAftermathEngineData = preload(
	"res://Scripts/Sim/ResolutionActionAftermathEngine.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const BotResolutionDoctrineData = preload(
	"res://Scripts/Sim/BotResolutionDoctrine.gd"
)

const DevelopmentStartTestsData = preload(
	"res://Scripts/Sim/DevelopmentStartTests.gd"
)


const ACTION_TEST_NAME: String = (
	"unit_bot_resolution_action_bundle"
)

const VESSEL_TEST_NAME: String = (
	"unit_bot_resolution_vessel_dominion"
)

const VESSEL_SAFETY_TEST_NAME: String = (
	"unit_bot_resolution_vessel_ritual_safety"
)

const GREMORY_TEST_NAME: String = (
	"unit_bot_resolution_gremory_preview"
)


static func run(
	rules: RuleConfig
) -> Array:
	var results: Array = [
		_test_action_bundle(
			rules
		),
		_test_vessel_dominion(
			rules
		),
		_test_vessel_ritual_safety(
			rules
		),
		_test_gremory_preview(
			rules
		),
	]

	results.append_array(
		DevelopmentStartTestsData.run(
			rules
		)
	)

	return results


static func _test_action_bundle(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			ACTION_TEST_NAME,
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

	game.first_player = 1

	attacker.lord = "Deimos"
	attacker.action = "Siege"
	attacker.tgt_pid = 1
	attacker.tgt_type = "Castle"

	attacker.committed = _cards_from_ids([
		"Butcher:3",
	])

	defender.action = ""

	_set_castles(
		defender,
		[
			"Keep",
			"Stockpile",
		]
	)

	var commitment_choices: Dictionary = {
		0: {
			"action": "Siege",
			"target_pid": 1,
			"target_castle": "Stockpile",
			"cards": [
				"Butcher:3",
			],
		},
	}

	var decisions: Dictionary = (
		BotResolutionDoctrineData
		.build_decisions(
			game,
			rules,
			commitment_choices,
			null,
			BotPolicyData.golden_core()
		)
	)

	var action_choices: Dictionary = (
		_nested_dictionary(
			decisions,
			"actions"
		)
	)

	var attacker_options: Dictionary = (
		_decision_for_player(
			action_choices,
			0
		)
	)

	if String(
		attacker_options.get(
			"target_castle",
			""
		)
	) != "Stockpile":
		return _fail(
			ACTION_TEST_NAME,
			"Resolution bundle lost the sealed Siege target."
		)

	if not bool(
		attacker_options.get(
			"use_inferno",
			false
		)
	):
		return _fail(
			ACTION_TEST_NAME,
			"Resolution bundle disabled Inferno."
		)

	if int(
		decisions.get(
			"tie_first_player",
			-1
		)
	) != 1:
		return _fail(
			ACTION_TEST_NAME,
			"Resolution bundle lost the deterministic tie order."
		)

	if _card_ids(
		attacker.committed
	) != [
		"Butcher:3",
	]:
		return _fail(
			ACTION_TEST_NAME,
			"Resolution preview mutated the real Commitment."
		)

	if not defender.castles.has(
		"Stockpile"
	):
		return _fail(
			ACTION_TEST_NAME,
			"Resolution preview mutated the real Castle state."
		)

	return _pass(
		ACTION_TEST_NAME
	)


static func _test_vessel_dominion(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			VESSEL_TEST_NAME,
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

	player.alive = true
	player.tears = 2
	player.souls = 0
	player.vessel_used = false

	opponent.alive = true
	opponent.tears = 1
	opponent.souls = 0

	game.neutral_tears = max(
		0,
		rules.dominion_track
		- 1
		- player.tears
		- opponent.tears
	)

	game.refresh_derived_values()

	var choices: Dictionary = (
		BotResolutionDoctrineData
		.vessel_choices(
			game,
			rules
		)
	)

	var decision: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	if not bool(
		decision.get(
			"offer",
			false
		)
	):
		return _fail(
			VESSEL_TEST_NAME,
			"Immediate Dominion Vessel was not offered."
		)

	var result: Dictionary = (
		ResolutionActionAftermathEngineData.resolve(
			game,
			rules,
			0,
			{
				"action": "pass",
				"destroyed": false,
			},
			decision
		)
	)

	if not bool(
		result.get(
			"stopped_on_win",
			false
		)
	):
		return _fail(
			VESSEL_TEST_NAME,
			"Vessel Dominion did not stop Resolution."
		)

	if game.winner != 0:
		return _fail(
			VESSEL_TEST_NAME,
			"Vessel Dominion awarded the wrong winner."
		)

	if game.win_by != "Dominion":
		return _fail(
			VESSEL_TEST_NAME,
			"Vessel produced the wrong win condition."
		)

	if player.alive:
		return _fail(
			VESSEL_TEST_NAME,
			"Offered Vessel left the Lord active."
		)

	return _pass(
		VESSEL_TEST_NAME
	)


static func _test_vessel_ritual_safety(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			VESSEL_SAFETY_TEST_NAME,
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

	player.alive = true
	player.tears = 2
	player.vessel_used = false

	opponent.alive = true
	opponent.tears = 1
	opponent.souls = rules.win_souls - 1

	game.neutral_tears = max(
		0,
		rules.dominion_track
		- 1
		- player.tears
		- opponent.tears
	)

	game.refresh_derived_values()

	var choices: Dictionary = (
		BotResolutionDoctrineData
		.vessel_choices(
			game,
			rules
		)
	)

	var decision: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	if not bool(
		decision.get(
			"pass",
			false
		)
	):
		return _fail(
			VESSEL_SAFETY_TEST_NAME,
			"Bot gifted the opponent a Ritual victory."
		)

	return _pass(
		VESSEL_SAFETY_TEST_NAME
	)


static func _test_gremory_preview(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			GREMORY_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var gremory = fixture["p0"]
	var defender = fixture["p1"]

	_prepare_game(
		game
	)

	game.first_player = 0

	gremory.lord = "Gremory"
	gremory.alive = true
	gremory.action = "Siege"
	gremory.tgt_pid = 1
	gremory.tgt_type = "Castle"

	gremory.committed = _cards_from_ids([
		"Butcher:1",
	])

	gremory.hand = _cards_from_ids([
		"Penitent:1",
		"Vulture:2",
		"Butcher:5",
	])

	gremory.garrison = _cards_from_ids([
		"Wright:1",
	])

	gremory.gremory_inevitable_ruin_done = false

	defender.lord = "Valak"
	defender.alive = true
	defender.action = ""

	_set_castles(
		defender,
		[
			"Keep",
		]
	)

	defender.castle_guards.clear()

	var commitment_choices: Dictionary = {
		0: {
			"action": "Siege",
			"target_pid": 1,
			"target_castle": "Keep",
			"cards": [
				"Butcher:1",
			],
		},
	}

	var decisions: Dictionary = (
		BotResolutionDoctrineData
		.build_decisions(
			game,
			rules,
			commitment_choices,
			null,
			BotPolicyData.golden_core()
		)
	)

	var gremory_choices: Dictionary = (
		_nested_dictionary(
			decisions,
			"gremory"
		)
	)

	var gremory_decision: Dictionary = (
		_decision_for_player(
			gremory_choices,
			0
		)
	)

	if _payment_signatures(
		gremory_decision.get(
			"payment",
			[]
		)
	) != [
		"Garrison>Wright:1",
		"Hand>Penitent:1",
	]:
		return _fail(
			GREMORY_TEST_NAME,
			"Gremory preview selected the wrong payment."
		)

	if defender.was_sieged:
		return _fail(
			GREMORY_TEST_NAME,
			"Preview mutated the real Siege history."
		)

	if not defender.castles.has(
		"Keep"
	):
		return _fail(
			GREMORY_TEST_NAME,
			"Preview destroyed the real Keep."
		)

	if _card_ids(
		gremory.committed
	) != [
		"Butcher:1",
	]:
		return _fail(
			GREMORY_TEST_NAME,
			"Preview consumed the real Commitment."
		)

	var result: Dictionary = (
		ResolutionEngineData.resolve(
			game,
			rules,
			decisions
		)
	)

	if String(
		result.get(
			"action",
			""
		)
	) == "invalid":
		return _fail(
			GREMORY_TEST_NAME,
			"Resolution rejected the generated bundle."
		)

	var cleanup_result: Dictionary = (
		_nested_dictionary(
			result,
			"cleanup_result"
		)
	)

	var raw_events = cleanup_result.get(
		"gremory_events",
		[]
	)

	if typeof(
		raw_events
	) != TYPE_ARRAY:
		return _fail(
			GREMORY_TEST_NAME,
			"Cleanup returned no Gremory event list."
		)

	var events: Array = raw_events

	if events.is_empty():
		return _fail(
			GREMORY_TEST_NAME,
			"Gremory generated no Cleanup event."
		)

	var event: Dictionary = events[0]

	if String(
		event.get(
			"action",
			""
		)
	) != "inevitable_ruin":
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin did not execute."
		)

	if defender.castles.has(
		"Keep"
	):
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin left the Keep active."
		)

	if not defender.ruined_castles.has(
		"Keep"
	):
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin did not create the Ruin."
		)

	if not gremory.gremory_inevitable_ruin_done:
		return _fail(
			GREMORY_TEST_NAME,
			"Inevitable Ruin use flag was not set."
		)

	return _pass(
		GREMORY_TEST_NAME
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

	for metadata_name: String in [
		"reflex_action_resolved_round",
		"first_castle_tear_round",
		"any_destruction_round",
		"orias_marked_lord",
	]:
		if game.has_meta(
			metadata_name
		):
			game.remove_meta(
				metadata_name
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

		player.vessel_used = false
		player.vessel_offered_lord = ""

		player.gremory_inevitable_ruin_done = false
		player.gremory_ruin_done = false
		player.gremory_veil_draw_done = false
		player.gremory_lord_guard_draw_done = false

		player.pending_profane = ""
		player.profane_this_round = false

		player.odradek_recoil_done = false
		player.odradek_guards_defeated = 0

		player.kroni_consume_done = false
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
	card_ids: Array
) -> Array:
	var cards: Array = []

	for raw_card_identifier in card_ids:
		var card_identifier: String = String(
			raw_card_identifier
		)

		var separator_index: int = (
			card_identifier.rfind(
				":"
			)
		)

		assert(
			separator_index > 0,
			"Invalid card identifier: %s"
			% card_identifier
		)

		cards.append(
			CardData.new(
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
		)

	return cards


static func _decision_for_player(
	decisions: Dictionary,
	player_id: int
) -> Dictionary:
	var raw_decision = decisions.get(
		player_id,
		null
	)

	if raw_decision == null:
		raw_decision = decisions.get(
			str(
				player_id
			),
			{}
		)

	if typeof(
		raw_decision
	) != TYPE_DICTIONARY:
		return {}

	return raw_decision


static func _nested_dictionary(
	source: Dictionary,
	key: String
) -> Dictionary:
	var raw_value = source.get(
		key,
		{}
	)

	if typeof(
		raw_value
	) != TYPE_DICTIONARY:
		return {}

	return raw_value


static func _payment_signatures(
	raw_payment
) -> Array[String]:
	var result: Array[String] = []

	if typeof(
		raw_payment
	) != TYPE_ARRAY:
		return result

	var payment: Array = raw_payment

	for raw_entry in payment:
		if typeof(
			raw_entry
		) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = raw_entry

		result.append(
			"%s>%s" % [
				String(
					entry.get(
						"source",
						""
					)
				),
				String(
					entry.get(
						"card",
						""
					)
				),
			]
		)

	return result


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
		"text": (
			"PASS  %s"
			% test_name
		),
	}


static func _fail(
	test_name: String,
	reason: String
) -> Dictionary:
	return {
		"passed": false,
		"text": (
			"FAIL  %s: %s"
			% [
				test_name,
				reason,
			]
		),
	}
