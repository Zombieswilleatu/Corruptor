class_name ResolutionEngineTests
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


const ORDER_TEST_NAME := (
	"unit_resolution_orchestrator_order"
)

const PROFANE_TEST_NAME := (
	"unit_resolution_orchestrator_profane"
)

const REFLEX_TEST_NAME := (
	"unit_resolution_orchestrator_reflex"
)

const LATE_REFLEX_TEST_NAME := (
	"unit_resolution_orchestrator_late_reflex"
)

const WIN_TEST_NAME := (
	"unit_resolution_orchestrator_early_win"
)


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_resolution_order(
			rules
		),
		_test_profane_cleanup(
			rules
		),
		_test_reflex_action(
			rules
		),
		_test_late_reflex_provider(
			rules
		),
		_test_early_win(
			rules
		),
	]


static func _test_resolution_order(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			ORDER_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_prepare_game(
		game
	)

	player_zero.lord = "Orias"
	player_zero.action = "Ward"
	player_zero.tgt_pid = 0
	player_zero.tgt_type = "Lord"
	player_zero.ward_target = "Lord"
	player_zero.sigils["Lord"] = "fresh"

	player_zero.committed = _cards_from_ids([
		"Wright:2",
	])

	player_one.lord = "Valak"
	player_one.action = "Ward"
	player_one.tgt_pid = 1
	player_one.tgt_type = "Castle"
	player_one.ward_target = "Castle"
	player_one.sigils["Castle"] = "fresh"

	player_one.committed = _cards_from_ids([
		"Vulture:5",
	])

	var result: Dictionary = (
		ResolutionEngineData.resolve(
			game,
			rules
		)
	)

	if String(
		result.get(
			"action",
			""
		)
	) != "resolution":
		return _fail(
			ORDER_TEST_NAME,
			"Resolution orchestrator did not complete."
		)

	var prelude_result: Dictionary = result.get(
		"prelude_result",
		{}
	)

	if _int_array(
		prelude_result.get(
			"order",
			[]
		)
	) != [
		1,
		0,
	]:
		return _fail(
			ORDER_TEST_NAME,
			"Resolution did not preserve committed-value order."
		)

	var action_events: Array = result.get(
		"action_events",
		[]
	)

	if action_events.size() != 2:
		return _fail(
			ORDER_TEST_NAME,
			"Expected two committed-action events."
		)

	var first_event: Dictionary = action_events[0]
	var second_event: Dictionary = action_events[1]

	if int(
		first_event.get(
			"player_id",
			-1
		)
	) != 1:
		return _fail(
			ORDER_TEST_NAME,
			"Player one did not resolve first."
		)

	if int(
		second_event.get(
			"player_id",
			-1
		)
	) != 0:
		return _fail(
			ORDER_TEST_NAME,
			"Player zero did not resolve second."
		)

	if not player_zero.committed.is_empty():
		return _fail(
			ORDER_TEST_NAME,
			"Player-zero committed cards were not cleared."
		)

	if not player_one.committed.is_empty():
		return _fail(
			ORDER_TEST_NAME,
			"Player-one committed cards were not cleared."
		)

	if _card_ids(
		game.discard
	) != [
		"Vulture:5",
		"Wright:2",
	]:
		return _fail(
			ORDER_TEST_NAME,
			"Committed cards were discarded in the wrong order."
		)

	if player_zero.prev_ward_target != "Lord":
		return _fail(
			ORDER_TEST_NAME,
			"Player-zero Ward history was not finalized."
		)

	if player_one.prev_ward_target != "Castle":
		return _fail(
			ORDER_TEST_NAME,
			"Player-one Ward history was not finalized."
		)

	return _pass(
		ORDER_TEST_NAME
	)


static func _test_profane_cleanup(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			PROFANE_TEST_NAME,
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

	player.lord = "Orias"
	player.action = "Profane"
	player.tgt_pid = 0
	player.tgt_type = "Castle"

	_set_castles(
		player,
		[
			"Keep",
			"Stockpile",
		]
	)

	player.committed = _cards_from_ids([
		"Butcher:2",
	])

	opponent.lord = "Valak"
	opponent.action = ""
	opponent.sigils = {
		"Lord": "",
		"Castle": "",
	}

	var result: Dictionary = (
		ResolutionEngineData.resolve(
			game,
			rules,
			{
				"actions": {
					0: {
						"target_castle": "Stockpile",
					},
				},
			}
		)
	)

	if player.castles.has(
		"Stockpile"
	):
		return _fail(
			PROFANE_TEST_NAME,
			"Successful Profane left Stockpile active."
		)

	if not player.profaned_castles.has(
		"Stockpile"
	):
		return _fail(
			PROFANE_TEST_NAME,
			"Stockpile was not moved to Profaned Castles."
		)

	if player.tears != 1:
		return _fail(
			PROFANE_TEST_NAME,
			"Resolution cleanup did not grant the delayed Tear."
		)

	if not player.pending_profane.is_empty():
		return _fail(
			PROFANE_TEST_NAME,
			"Resolution cleanup left the pending Profane marker."
		)

	if game.calculate_veil_total() != 1:
		return _fail(
			PROFANE_TEST_NAME,
			"Profane produced the wrong Veil total."
		)

	if _card_ids(
		game.discard
	) != [
		"Butcher:2",
	]:
		return _fail(
			PROFANE_TEST_NAME,
			"Profane committed card was not discarded."
		)

	var cleanup_result: Dictionary = result.get(
		"cleanup_result",
		{}
	)

	var profane_events: Array = cleanup_result.get(
		"profane_events",
		[]
	)

	if profane_events.size() != 1:
		return _fail(
			PROFANE_TEST_NAME,
			"Expected one delayed Profane event."
		)

	var profane_event: Dictionary = profane_events[0]

	if String(
		profane_event.get(
			"castle",
			""
		)
	) != "Stockpile":
		return _fail(
			PROFANE_TEST_NAME,
			"Cleanup recorded the wrong Profaned Castle."
		)

	return _pass(
		PROFANE_TEST_NAME
	)


static func _test_reflex_action(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			REFLEX_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_prepare_game(
		game
	)

	game.reflex_winner = 0

	player_zero.lord = "Orias"
	player_zero.action = "Ward"
	player_zero.tgt_pid = 0
	player_zero.tgt_type = "Lord"
	player_zero.ward_target = "Lord"

	player_zero.sigils = {
		"Lord": "fresh",
		"Castle": "",
	}

	_set_castles(
		player_zero,
		[
			"Keep",
		]
	)

	player_zero.committed = _cards_from_ids([
		"Wright:2",
	])

	player_one.lord = "Valak"
	player_one.action = "Ward"
	player_one.tgt_pid = 1
	player_one.tgt_type = "Lord"
	player_one.ward_target = "Lord"

	player_one.sigils = {
		"Lord": "fresh",
		"Castle": "",
	}

	player_one.committed = _cards_from_ids([
		"Vulture:1",
	])

	var result: Dictionary = (
		ResolutionEngineData.resolve(
			game,
			rules,
			{
				"reflex": {
					"action": "Ward",
					"ward_target": "Castle",
				},
			}
		)
	)

	var reflex_result: Dictionary = result.get(
		"reflex_result",
		{}
	)

	if String(
		reflex_result.get(
			"executed_action",
			""
		)
	) != "Ward":
		return _fail(
			REFLEX_TEST_NAME,
			"Resolution did not execute the Reflex Ward."
		)

	if int(
		reflex_result.get(
			"executed_by",
			-1
		)
	) != 0:
		return _fail(
			REFLEX_TEST_NAME,
			"Reflex Ward executed for the wrong player."
		)

	if String(
		player_zero.sigils.get(
			"Lord",
			""
		)
	) != "fresh":
		return _fail(
			REFLEX_TEST_NAME,
			"Original Lord Sigil was lost."
		)

	if String(
		player_zero.sigils.get(
			"Castle",
			""
		)
	) != "fresh":
		return _fail(
			REFLEX_TEST_NAME,
			"Reflex Ward did not place a Castle Sigil."
		)

	if player_zero.prev_ward_target != "Lord":
		return _fail(
			REFLEX_TEST_NAME,
			"Reflex action overwrote original Ward history."
		)

	if _card_ids(
		game.discard
	) != [
		"Wright:2",
		"Vulture:1",
	]:
		return _fail(
			REFLEX_TEST_NAME,
			"Reflex integration reached the wrong discard state."
		)

	return _pass(
		REFLEX_TEST_NAME
	)



static func _test_late_reflex_provider(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			LATE_REFLEX_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	_prepare_game(
		game
	)

	game.reflex_winner = 0

	player_zero.lord = "Orias"
	player_zero.action = "Ward"
	player_zero.tgt_pid = 0
	player_zero.tgt_type = "Lord"
	player_zero.ward_target = "Lord"
	player_zero.sigils = {
		"Lord": "fresh",
		"Castle": "",
	}

	_set_castles(
		player_zero,
		[
			"Keep",
		]
	)

	player_zero.committed = _cards_from_ids([
		"Wright:2",
	])

	player_one.lord = "Valak"
	player_one.action = "Ward"
	player_one.tgt_pid = 1
	player_one.tgt_type = "Lord"
	player_one.ward_target = "Lord"
	player_one.sigils = {
		"Lord": "fresh",
		"Castle": "",
	}

	player_one.committed = _cards_from_ids([
		"Vulture:1",
	])

	var result: Dictionary = (
		ResolutionEngineData.resolve(
			game,
			rules,
			{
				"reflex_provider": Callable(
					ResolutionEngineTests,
					"_late_reflex_provider"
				),
			}
		)
	)

	if String(
		result.get(
			"action",
			""
		)
	) != "resolution":
		return _fail(
			LATE_REFLEX_TEST_NAME,
			"Resolution rejected the late Reflex provider."
		)

	var reflex_result: Dictionary = result.get(
		"reflex_result",
		{}
	)

	if String(
		reflex_result.get(
			"executed_action",
			""
		)
	) != "Ward":
		return _fail(
			LATE_REFLEX_TEST_NAME,
			"Late provider did not execute its post-action Ward."
		)

	if String(
		player_zero.sigils.get(
			"Castle",
			""
		)
	) != "fresh":
		return _fail(
			LATE_REFLEX_TEST_NAME,
			"Late provider did not see cleared commitments."
		)

	return _pass(
		LATE_REFLEX_TEST_NAME
	)


static func _late_reflex_provider(
	game,
	_rules: RuleConfig
) -> Dictionary:
	var actor = game.get_player(
		int(
			game.reflex_winner
		)
	)

	if (
		actor == null
		or not actor.committed.is_empty()
	):
		return {
			"winner_decision": {
				"pass": true,
			},
			"breach_decision": {},
		}

	return {
		"winner_decision": {
			"action": "Ward",
			"ward_target": "Castle",
		},
		"breach_decision": {},
	}


static func _test_early_win(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			WIN_TEST_NAME,
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
	attacker.souls = rules.win_souls - 1

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
		]
	)

	defender.action = "Ward"
	defender.tgt_pid = 1
	defender.tgt_type = "Lord"
	defender.ward_target = "Lord"
	defender.sigils["Lord"] = "fresh"

	defender.committed = _cards_from_ids([
		"Vulture:1",
	])

	game.reflex_winner = 1

	var result: Dictionary = (
		ResolutionEngineData.resolve(
			game,
			rules,
			{
				"actions": {
					0: {
						"target_castle": "SiegeEngine",
					},
				},
				"reflex": {
					"action": "Ward",
					"ward_target": "Castle",
				},
			}
		)
	)

	if game.winner != 0:
		return _fail(
			WIN_TEST_NAME,
			"Winning Siege did not set player zero as winner."
		)

	if game.win_by != "Ritual":
		return _fail(
			WIN_TEST_NAME,
			"Winning Siege recorded the wrong victory type."
		)

	if String(
		result.get(
			"stopped_stage",
			""
		)
	) != "actions":
		return _fail(
			WIN_TEST_NAME,
			"Resolution did not stop after the winning action."
		)

	var action_events: Array = result.get(
		"action_events",
		[]
	)

	if action_events.size() != 1:
		return _fail(
			WIN_TEST_NAME,
			"Resolution continued to the losing player's action."
		)

	if defender.castles.has(
		"SiegeEngine"
	):
		return _fail(
			WIN_TEST_NAME,
			"Winning Siege left the target Castle active."
		)

	if not defender.ruined_castles.has(
		"SiegeEngine"
	):
		return _fail(
			WIN_TEST_NAME,
			"Winning Siege did not create a Ruined Castle."
		)

	if defender.committed.is_empty():
		return _fail(
			WIN_TEST_NAME,
			"Losing player's unresolved commitment was cleared."
		)

	if not Dictionary(
		result.get(
			"reflex_result",
			{}
		)
	).is_empty():
		return _fail(
			WIN_TEST_NAME,
			"Reflex resolved after the game was won."
		)

	if not Dictionary(
		result.get(
			"finale_result",
			{}
		)
	).is_empty():
		return _fail(
			WIN_TEST_NAME,
			"Finale resolved after the game was won."
		)

	if not Dictionary(
		result.get(
			"cleanup_result",
			{}
		)
	).is_empty():
		return _fail(
			WIN_TEST_NAME,
			"Cleanup resolved after the game was won."
		)

	return _pass(
		WIN_TEST_NAME
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

	game.breach = ""
	game.breach_owner = -1
	game.reflex_winner = -1

	game.persist_scorch_pid = -1
	game.persist_scorch_type = ""

	game.neutral_tears = 0
	game.winner = -1
	game.win_by = ""

	game.deck.clear()
	game.discard.clear()
	game.market.clear()

	_clear_meta(
		game,
		"first_castle_tear_round"
	)

	_clear_meta(
		game,
		"any_destruction_round"
	)

	_clear_meta(
		game,
		"reflex_action_resolved_round"
	)

	_clear_meta(
		game,
		"odradek_reconfig_tokens"
	)

	for player in game.players:
		player.alive = true

		player.souls = 0
		player.tears = 0
		player.threat = 0
		player.kroni_hunger = 0

		player.action = ""
		player.tgt_pid = -1
		player.tgt_type = ""
		player.ward_target = ""
		player.prev_ward_target = ""

		player.was_hunted = false
		player.was_sieged = false
		player.was_lord_attacked_prev = false
		player.was_castle_attacked_prev = false
		player.last_sieged_castle = ""

		player.pending_profane = ""
		player.profane_this_round = false
		player.profane_ruins_used_this_round = false

		player.hand.clear()
		player.garrison.clear()
		player.castle_guards.clear()
		player.lord_guards.clear()
		player.committed.clear()
		player.penitent_temp_guards.clear()

		player.castles.clear()
		player.ruined_castles.clear()
		player.profaned_castles.clear()

		player.sigils = {
			"Lord": "",
			"Castle": "",
		}

		player.vessel_used = false
		player.vessel_offered_lord = ""

		player.repair_token = 0

		player.odradek_recoil_done = false
		player.odradek_guards_defeated = 0

		player.gremory_ruin_done = false
		player.gremory_inevitable_ruin_done = false
		player.gremory_veil_draw_done = false
		player.gremory_lord_guard_draw_done = false

		player.kanifous_outside_draws = 0
		player.kanifous_invoked_suit = ""
		player.kanifous_invoked_high = false
		player.kanifous_invokes_this_round = 0

		player.kroni_consume_done = false
		player.kroni_ravenous_used = false
		player.kroni_personally_defeated_guard = false
		player.kroni_enemy_destroyed = false
		player.kroni_tear_milestone_fired = false

		player.deimos_breach_claimed = false
		player.humbaba_patient = false

	game.refresh_derived_values()


static func _clear_meta(
	game,
	key: String
) -> void:
	if game.has_meta(
		key
	):
		game.remove_meta(
			key
		)


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


static func _int_array(
	values
) -> Array[int]:
	var result: Array[int] = []

	if typeof(
		values
	) != TYPE_ARRAY:
		return result

	for value in values:
		result.append(
			int(
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
