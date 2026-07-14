class_name ResolutionFinaleTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const ResolutionFinaleEngineData = preload(
	"res://Scripts/Sim/ResolutionFinaleEngine.gd"
)


const KRONI_FALLBACK_TEST_NAME := (
	"unit_finale_kroni_decay_fallback"
)

const KRONI_BREACH_TEST_NAME := (
	"unit_finale_kroni_breach"
)

const ODRADEK_TEAR_TEST_NAME := (
	"unit_finale_odradek_reconfiguration"
)

const ODRADEK_DENIAL_TEST_NAME := (
	"unit_finale_odradek_strict_denial"
)

const STATE_TEST_NAME := (
	"unit_finale_ward_and_patient_state"
)


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_kroni_decay_fallback(
			rules
		),
		_test_kroni_breach(
			rules
		),
		_test_odradek_reconfiguration(
			rules
		),
		_test_odradek_strict_denial(
			rules
		),
		_test_ward_and_patient_state(
			rules
		),
	]


static func _test_kroni_decay_fallback(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			KRONI_FALLBACK_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var kroni = fixture["p0"]

	_prepare_game(
		game
	)

	kroni.lord = "Kroni"
	kroni.alive = true
	kroni.action = "Ward"

	kroni.kroni_hunger = 2
	kroni.kroni_consume_done = false

	kroni.lord_guards = _cards_from_ids([
		"Butcher:4",
	])

	kroni.castle_guards = _cards_from_ids([
		"Penitent:1",
	])

	kroni.garrison = _cards_from_ids([
		"Vulture:2",
	])

	var result: Dictionary = (
		ResolutionFinaleEngineData.resolve(
			game,
			rules
		)
	)

	if kroni.kroni_hunger != 2:
		return _fail(
			KRONI_FALLBACK_TEST_NAME,
			"Decay then fallback should leave Hunger at 2."
		)

	if not kroni.kroni_consume_done:
		return _fail(
			KRONI_FALLBACK_TEST_NAME,
			"Fallback Consume did not trigger."
		)

	if _card_ids(
		kroni.castle_guards
	) != []:
		return _fail(
			KRONI_FALLBACK_TEST_NAME,
			"Fallback Consume left the lowest Castle Guard."
		)

	if _card_ids(
		kroni.lord_guards
	) != [
		"Butcher:4",
	]:
		return _fail(
			KRONI_FALLBACK_TEST_NAME,
			"Fallback Consume removed the wrong Guard."
		)

	if _card_ids(
		kroni.garrison
	) != [
		"Vulture:2",
	]:
		return _fail(
			KRONI_FALLBACK_TEST_NAME,
			"Fallback Consume used Garrison despite Guards existing."
		)

	if _card_ids(
		game.discard
	) != [
		"Penitent:1",
	]:
		return _fail(
			KRONI_FALLBACK_TEST_NAME,
			"Fallback Consume discarded the wrong card."
		)

	var decay_events: Array = result.get(
		"decay_events",
		[]
	)

	if decay_events.size() != 1:
		return _fail(
			KRONI_FALLBACK_TEST_NAME,
			"Expected one Kroni decay event."
		)

	var decay_event: Dictionary = decay_events[0]

	if (
		int(
			decay_event.get(
				"hunger_before",
				-1
			)
		) != 2
		or int(
			decay_event.get(
				"hunger_after",
				-1
			)
		) != 1
	):
		return _fail(
			KRONI_FALLBACK_TEST_NAME,
			"Kroni decay event recorded the wrong Hunger values."
		)

	var fallback_events: Array = result.get(
		"fallback_events",
		[]
	)

	if fallback_events.size() != 1:
		return _fail(
			KRONI_FALLBACK_TEST_NAME,
			"Expected one fallback Consume event."
		)

	var fallback_event: Dictionary = (
		fallback_events[0]
	)

	if String(
		fallback_event.get(
			"discarded_card",
			""
		)
	) != "Penitent:1":
		return _fail(
			KRONI_FALLBACK_TEST_NAME,
			"Fallback event recorded the wrong card."
		)

	if String(
		fallback_event.get(
			"zone",
			""
		)
	) != "Castle":
		return _fail(
			KRONI_FALLBACK_TEST_NAME,
			"Fallback event recorded the wrong zone."
		)

	return _pass(
		KRONI_FALLBACK_TEST_NAME
	)


static func _test_kroni_breach(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			KRONI_BREACH_TEST_NAME,
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

	game.breach = "Kroni"
	game.breach_owner = 1

	player_zero.lord = "Orias"
	player_one.lord = "Valak"

	player_zero.lord_guards = _cards_from_ids([
		"Butcher:2",
	])

	player_zero.castle_guards = _cards_from_ids([
		"Wright:2",
	])

	player_one.lord_guards = _cards_from_ids([
		"Vulture:4",
	])

	player_one.castle_guards = _cards_from_ids([
		"Penitent:1",
	])

	var result: Dictionary = (
		ResolutionFinaleEngineData.resolve(
			game,
			rules
		)
	)

	if not player_zero.lord_guards.is_empty():
		return _fail(
			KRONI_BREACH_TEST_NAME,
			"Kroni Breach did not use Lord-first tie order."
		)

	if _card_ids(
		player_zero.castle_guards
	) != [
		"Wright:2",
	]:
		return _fail(
			KRONI_BREACH_TEST_NAME,
			"Kroni Breach removed both tied Guards."
		)

	if _card_ids(
		player_one.lord_guards
	) != [
		"Vulture:4",
	]:
		return _fail(
			KRONI_BREACH_TEST_NAME,
			"Kroni Breach removed the wrong player-one Guard."
		)

	if not player_one.castle_guards.is_empty():
		return _fail(
			KRONI_BREACH_TEST_NAME,
			"Kroni Breach left the value-1 Castle Guard."
		)

	if _card_ids(
		game.discard
	) != [
		"Butcher:2",
		"Penitent:1",
	]:
		return _fail(
			KRONI_BREACH_TEST_NAME,
			"Kroni Breach reached the wrong discard state."
		)

	var breach_events: Array = result.get(
		"breach_events",
		[]
	)

	if breach_events.size() != 2:
		return _fail(
			KRONI_BREACH_TEST_NAME,
			"Expected one Kroni Breach event per player."
		)

	var event_zero: Dictionary = breach_events[0]
	var event_one: Dictionary = breach_events[1]

	if String(
		event_zero.get(
			"zone",
			""
		)
	) != "Lord":
		return _fail(
			KRONI_BREACH_TEST_NAME,
			"Player-zero Breach event recorded the wrong zone."
		)

	if String(
		event_one.get(
			"zone",
			""
		)
	) != "Castle":
		return _fail(
			KRONI_BREACH_TEST_NAME,
			"Player-one Breach event recorded the wrong zone."
		)

	return _pass(
		KRONI_BREACH_TEST_NAME
	)


static func _test_odradek_reconfiguration(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			ODRADEK_TEAR_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var odradek = fixture["p0"]

	_prepare_game(
		game
	)

	odradek.lord = "Odradek"
	odradek.alive = true
	odradek.odradek_guards_defeated = 0

	game.set_meta(
		"odradek_reconfig_tokens",
		rules.reconfig_tokens_needed - 1
	)

	var result: Dictionary = (
		ResolutionFinaleEngineData.resolve(
			game,
			rules
		)
	)

	if odradek.tears != 1:
		return _fail(
			ODRADEK_TEAR_TEST_NAME,
			"Reconfiguration did not grant its personal Tear."
		)

	if game.neutral_tears != 0:
		return _fail(
			ODRADEK_TEAR_TEST_NAME,
			"Personal Reconfiguration placed a Neutral Tear."
		)

	if int(
		game.get_meta(
			"odradek_reconfig_tokens",
			-1
		)
	) != 0:
		return _fail(
			ODRADEK_TEAR_TEST_NAME,
			"Reconfiguration tokens were not spent."
		)

	var events: Array = result.get(
		"reconfiguration_events",
		[]
	)

	if events.size() != 1:
		return _fail(
			ODRADEK_TEAR_TEST_NAME,
			"Expected one Reconfiguration event."
		)

	var event: Dictionary = events[0]

	if bool(
		event.get(
			"blocked",
			true
		)
	):
		return _fail(
			ODRADEK_TEAR_TEST_NAME,
			"Unpressured Reconfiguration was marked blocked."
		)

	if int(
		event.get(
			"personal_tear_gain",
			0
		)
	) != 1:
		return _fail(
			ODRADEK_TEAR_TEST_NAME,
			"Reconfiguration event did not record its Tear."
		)

	return _pass(
		ODRADEK_TEAR_TEST_NAME
	)


static func _test_odradek_strict_denial(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			ODRADEK_DENIAL_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var odradek = fixture["p0"]

	_prepare_game(
		game
	)

	odradek.lord = "Odradek"
	odradek.alive = true
	odradek.odradek_guards_defeated = 1

	game.set_meta(
		"odradek_reconfig_tokens",
		rules.reconfig_tokens_needed - 1
	)

	var result: Dictionary = (
		ResolutionFinaleEngineData.resolve(
			game,
			rules
		)
	)

	if odradek.tears != 0:
		return _fail(
			ODRADEK_DENIAL_TEST_NAME,
			"Strict denial still granted a Tear."
		)

	if int(
		game.get_meta(
			"odradek_reconfig_tokens",
			-1
		)
	) != rules.reconfig_tokens_needed - 1:
		return _fail(
			ODRADEK_DENIAL_TEST_NAME,
			"Strict denial changed token count."
		)

	var events: Array = result.get(
		"reconfiguration_events",
		[]
	)

	if events.size() != 1:
		return _fail(
			ODRADEK_DENIAL_TEST_NAME,
			"Expected one denied Reconfiguration event."
		)

	var event: Dictionary = events[0]

	if not bool(
		event.get(
			"blocked",
			false
		)
	):
		return _fail(
			ODRADEK_DENIAL_TEST_NAME,
			"Strict Reconfiguration denial was not recorded."
		)

	if int(
		event.get(
			"denial_threshold",
			-1
		)
	) != 1:
		return _fail(
			ODRADEK_DENIAL_TEST_NAME,
			"Strict denial used the wrong threshold."
		)

	return _pass(
		ODRADEK_DENIAL_TEST_NAME
	)


static func _test_ward_and_patient_state(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			STATE_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var humbaba = fixture["p0"]
	var opponent = fixture["p1"]

	_prepare_game(
		game
	)

	humbaba.lord = "Humbaba"
	humbaba.alive = true
	humbaba.action = "Ward"
	humbaba.ward_target = "Castle"
	humbaba.prev_ward_target = "Lord"
	humbaba.humbaba_patient = false

	opponent.lord = "Valak"
	opponent.action = "Hunt"
	opponent.ward_target = "Lord"
	opponent.prev_ward_target = "Castle"

	var result: Dictionary = (
		ResolutionFinaleEngineData.resolve(
			game,
			rules
		)
	)

	if humbaba.prev_ward_target != "Castle":
		return _fail(
			STATE_TEST_NAME,
			"Ward history did not retain Humbaba's Castle target."
		)

	if not humbaba.humbaba_patient:
		return _fail(
			STATE_TEST_NAME,
			"Passive Humbaba did not become Patient."
		)

	if not opponent.prev_ward_target.is_empty():
		return _fail(
			STATE_TEST_NAME,
			"Attacking player retained a previous Ward target."
		)

	var state_events: Array = result.get(
		"state_events",
		[]
	)

	if state_events.size() != 2:
		return _fail(
			STATE_TEST_NAME,
			"Expected one Finale state event per player."
		)

	var humbaba_event: Dictionary = (
		state_events[0]
	)

	if String(
		humbaba_event.get(
			"previous_ward_after",
			""
		)
	) != "Castle":
		return _fail(
			STATE_TEST_NAME,
			"State event recorded the wrong Ward history."
		)

	if not bool(
		humbaba_event.get(
			"patient_after",
			false
		)
	):
		return _fail(
			STATE_TEST_NAME,
			"State event did not record Patient Hunger."
		)

	return _pass(
		STATE_TEST_NAME
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

	if game.has_meta(
		"odradek_reconfig_tokens"
	):
		game.remove_meta(
			"odradek_reconfig_tokens"
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

		player.action = ""
		player.ward_target = ""
		player.prev_ward_target = ""

		player.hand.clear()
		player.garrison.clear()
		player.castle_guards.clear()
		player.lord_guards.clear()
		player.committed.clear()

		player.kroni_hunger = 0
		player.kroni_consume_done = false
		player.kroni_tear_milestone_fired = false

		player.odradek_guards_defeated = 0

		player.humbaba_patient = false

		player.gremory_veil_draw_done = false

	game.refresh_derived_values()


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
