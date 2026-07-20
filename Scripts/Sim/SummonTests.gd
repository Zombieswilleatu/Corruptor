class_name SummonTests
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


const ROUND_ONE_SUMMON_TEST_NAME := "unit_round1_summon_noop"
const HAND_ONLY_TEST_NAME := "unit_summon_hand_only_payment"
const COST_AND_TEAR_TEST_NAME := "unit_summon_cost_threat_and_tear"
const VESSEL_TEST_NAME := "unit_summon_vessel_override"
const ORIAS_PURSUIT_TEST_NAME := "unit_summon_orias_relentless_pursuit"


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_round1_summon_noop(
			rules
		),
		_test_summon_hand_only_payment(
			rules
		),
		_test_summon_cost_threat_and_tear(
			rules
		),
		_test_summon_vessel_override(
			rules
		),
		_test_summon_orias_relentless_pursuit(
			rules
		),
	]


static func _test_round1_summon_noop(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			ROUND_ONE_SUMMON_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

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

	var results: Array[Dictionary] = (
		SummonEngineData.resolve(
			game,
			rules,
			_pass_choices()
		)
	)

	var error: String = _validate_round_one_noop(
		game,
		player_zero,
		player_one,
		results
	)

	return _result_from_error(
		ROUND_ONE_SUMMON_TEST_NAME,
		error
	)


static func _test_summon_hand_only_payment(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			HAND_ONLY_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]

	player_zero.alive = false
	player_zero.lord = "Deimos"
	player_zero.first_summon_done = true

	player_zero.hand = [
		CardData.new(
			"Butcher",
			2
		),
	]

	player_zero.garrison = [
		CardData.new(
			"Wright",
			5
		),
	]

	var discard_size_before: int = (
		game.discard.size()
	)

	var results: Array[Dictionary] = (
		SummonEngineData.resolve(
			game,
			rules,
			{
				0: {
					"lord": "Deimos",
					"payment": [
						"Butcher:2",
					],
				},
				1: {
					"pass": true,
				},
			}
		)
	)

	var error: String = _validate_hand_only_payment(
		game,
		player_zero,
		results,
		discard_size_before
	)

	return _result_from_error(
		HAND_ONLY_TEST_NAME,
		error
	)


static func _test_summon_cost_threat_and_tear(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			COST_AND_TEAR_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	player_zero.alive = false
	player_zero.lord = "Deimos"
	player_zero.threat = 4
	player_zero.first_summon_done = true
	player_zero.vessel_offered_lord = ""

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
			"Wright",
			5
		),
		CardData.new(
			"Vulture",
			4
		),
	]

	player_zero.garrison = [
		CardData.new(
			"Vulture",
			5
		),
	]

	player_one.lord = "Gremory"
	player_one.alive = true
	player_one.hand.clear()
	player_one.gremory_veil_draw_done = false

	game.breach = "Deimos"
	game.breach_owner = 0

	game.discard.clear()
	game.neutral_tears = 0
	game.winner = -1
	game.win_by = ""

	game.refresh_derived_values()

	var results: Array[Dictionary] = (
		SummonEngineData.resolve(
			game,
			rules,
			{
				0: {
					"lord": "Deimos",
					"payment": [
						"Butcher:1",
						"Penitent:2",
						"Wright:5",
					],
				},
				1: {
					"pass": true,
				},
			}
		)
	)

	var error: String = (
		_validate_cost_threat_and_tear(
			game,
			player_zero,
			player_one,
			results
		)
	)

	return _result_from_error(
		COST_AND_TEAR_TEST_NAME,
		error
	)


static func _test_summon_vessel_override(
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
	var player_one = fixture["p1"]

	player_one.alive = false
	player_one.lord = "Valak"
	player_one.threat = 4
	player_one.first_summon_done = true
	player_one.vessel_offered_lord = "Valak"

	player_one.hand = [
		CardData.new(
			"Butcher",
			2
		),
		CardData.new(
			"Wright",
			2
		),
	]

	player_one.garrison.clear()
	player_one.lord_guards.clear()

	game.breach = ""
	game.breach_owner = -1
	game.discard.clear()
	game.neutral_tears = 0
	game.winner = -1
	game.win_by = ""

	game.refresh_derived_values()

	var results: Array[Dictionary] = (
		SummonEngineData.resolve(
			game,
			rules,
			{
				0: {
					"pass": true,
				},
				1: {
					"lord": "Valak",
					"payment": [
						"Butcher:2",
						"Wright:2",
					],
				},
			}
		)
	)

	var error: String = _validate_vessel_override(
		game,
		player_one,
		results
	)

	return _result_from_error(
		VESSEL_TEST_NAME,
		error
	)


static func _test_summon_orias_relentless_pursuit(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			ORIAS_PURSUIT_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]

	var locked_pool: Array[String] = [
		"Orias",
	]

	player_zero.lord_pool = locked_pool
	player_zero.lord = "Orias"
	player_zero.alive = false
	player_zero.threat = 4
	player_zero.first_summon_done = true
	player_zero.vessel_offered_lord = ""

	player_zero.hand = [
		CardData.new(
			"Butcher",
			5
		),
	]

	player_zero.garrison.clear()
	player_zero.lord_guards.clear()

	game.breach = ""
	game.breach_owner = -1
	game.discard.clear()
	game.neutral_tears = 0
	game.winner = -1
	game.win_by = ""

	game.set_meta(
		"orias_marked_lord",
		"Orias"
	)

	game.refresh_derived_values()

	var results: Array[Dictionary] = (
		SummonEngineData.resolve(
			game,
			rules,
			{
				0: {
					"lord": "Orias",
					"payment": [
						"Butcher:5",
					],
				},
				1: {
					"pass": true,
				},
			}
		)
	)

	var error: String = ""

	if results.size() != 2:
		error = "Expected two Relentless Pursuit Summon results."
	elif String(
		results[0].get(
			"action",
			""
		)
	) != "summon":
		error = "Marked Orias did not resummon."
	elif player_zero.threat != 1:
		error = (
			"Marked Orias should return at Threat 1; got %d."
			% player_zero.threat
		)
	elif int(
		results[0].get(
			"threat",
			-1
		)
	) != 1:
		error = "Summon result did not report Threat 1."
	elif player_zero.derived_lord_def != 8:
		error = (
			"Marked Orias should return with derived Defense 8; got %d."
			% player_zero.derived_lord_def
		)

	return _result_from_error(
		ORIAS_PURSUIT_TEST_NAME,
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


static func _validate_round_one_noop(
	game,
	player_zero,
	player_one,
	results: Array[Dictionary]
) -> String:
	if results.size() != 2:
		return (
			"Expected two Round 1 Summon results."
		)

	for player_id: int in range(
		2
	):
		var result: Dictionary = results[
			player_id
		]

		if String(
			result.get(
				"action",
				""
			)
		) != "pass":
			return (
				"Living player %d should not summon."
				% player_id
			)

		if String(
			result.get(
				"reason",
				""
			)
		) != "already_alive":
			return (
				"Living player %d should report already_alive."
				% player_id
			)

	if (
		not player_zero.alive
		or not player_one.alive
	):
		return (
			"Round 1 Summon changed a Lord's living state."
		)

	if _card_ids(
		player_zero.hand
	) != [
		"Butcher:4",
		"Butcher:1",
		"Penitent:1",
		"Wright:5",
	]:
		return (
			"Player zero hand changed during Round 1 Summon."
		)

	if _card_ids(
		player_one.hand
	) != [
		"Butcher:4",
		"Vulture:2",
		"Butcher:2",
		"Butcher:3",
	]:
		return (
			"Player one hand changed during Round 1 Summon."
		)

	if _card_ids(
		player_zero.castle_guards
	) != [
		"Penitent:2",
		"Penitent:3",
		"Penitent:3",
	]:
		return (
			"Player zero Castle Guards changed during Summon."
		)

	if _card_ids(
		player_zero.lord_guards
	) != [
		"Wright:4",
		"Penitent:5",
	]:
		return (
			"Player zero Lord Guards changed during Summon."
		)

	if _card_ids(
		player_one.castle_guards
	) != [
		"Wright:3",
		"Wright:3",
		"Wright:3",
	]:
		return (
			"Player one Castle Guards changed during Summon."
		)

	if _card_ids(
		player_one.lord_guards
	) != [
		"Vulture:4",
		"Vulture:5",
	]:
		return (
			"Player one Lord Guards changed during Summon."
		)

	if game.discard.size() != 4:
		return (
			"Round 1 no-op Summon changed discard."
		)

	if game.neutral_tears != 0:
		return (
			"Round 1 no-op Summon added a Neutral Tear."
		)

	if game.calculate_veil_total() != 0:
		return (
			"Round 1 no-op Summon changed the Veil."
		)

	return ""


static func _validate_hand_only_payment(
	game,
	player_zero,
	results: Array[Dictionary],
	discard_size_before: int
) -> String:
	if results.size() != 2:
		return (
			"Expected two hand-only Summon results."
		)

	var result: Dictionary = results[0]

	if String(
		result.get(
			"action",
			""
		)
	) != "invalid":
		return (
			"Insufficient hand payment was not rejected."
		)

	if String(
		result.get(
			"reason",
			""
		)
	) != "insufficient_payment":
		return (
			"Hand-only rejection returned the wrong reason."
		)

	if int(
		result.get(
			"cost",
			0
		)
	) != 5:
		return (
			"Deimos should cost 5 with Summoning Circle."
		)

	if player_zero.alive:
		return (
			"Rejected Summon brought Deimos back to life."
		)

	if _card_ids(
		player_zero.hand
	) != [
		"Butcher:2",
	]:
		return (
			"Rejected Summon removed the hand card."
		)

	if _card_ids(
		player_zero.garrison
	) != [
		"Wright:5",
	]:
		return (
			"Summon incorrectly spent from Garrison."
		)

	if game.discard.size() != discard_size_before:
		return (
			"Rejected Summon changed discard."
		)

	if game.neutral_tears != 0:
		return (
			"Rejected Summon added a Neutral Tear."
		)

	return ""


static func _validate_cost_threat_and_tear(
	game,
	player_zero,
	player_one,
	results: Array[Dictionary]
) -> String:
	if results.size() != 2:
		return (
			"Expected two tuned-cost Summon results."
		)

	var result: Dictionary = results[0]

	if String(
		result.get(
			"action",
			""
		)
	) != "summon":
		return (
			"Deimos did not successfully resummon."
		)

	if int(
		result.get(
			"cost",
			0
		)
	) != 8:
		return (
			"Expected Deimos cost 8: 7 base, -2 Circle, +3 Breach."
		)

	if int(
		result.get(
			"paid_total",
			0
		)
	) != 8:
		return (
			"Deimos Summon payment should total 8."
		)

	if _string_array(
		result.get(
			"paid_cards",
			[]
		)
	) != [
		"Butcher:1",
		"Penitent:2",
		"Wright:5",
	]:
		return (
			"Deimos used the wrong Summon payment cards."
		)

	if (
		not player_zero.alive
		or player_zero.lord != "Deimos"
	):
		return (
			"Deimos was not restored as the active Lord."
		)

	if player_zero.threat != 0:
		return (
			"Deimos should return at Threat 0."
		)

	if player_zero.derived_lord_def != 6:
		return (
			"Deimos derived Defense should be 6 with intact Bastion."
		)

	if _card_ids(
		player_zero.hand
	) != [
		"Vulture:4",
	]:
		return (
			"Deimos retained the wrong hand after payment."
		)

	if _card_ids(
		player_zero.garrison
	) != [
		"Vulture:5",
	]:
		return (
			"Deimos Summon incorrectly changed Garrison."
		)

	if game.neutral_tears != 1:
		return (
			"Post-opening Summon did not add one Neutral Tear."
		)

	if game.calculate_veil_total() != 1:
		return (
			"Post-opening Summon did not advance the Veil."
		)

	if int(
		result.get(
			"neutral_tear_gain",
			0
		)
	) != 1:
		return (
			"Summon result did not record the Neutral Tear."
		)

	if String(
		result.get(
			"harvested_card",
			""
		)
	) != "Wright:5":
		return (
			"Gremory did not harvest the latest eligible payment card."
		)

	if int(
		result.get(
			"harvested_by",
			-1
		)
	) != 1:
		return (
			"Gremory harvest was credited to the wrong player."
		)

	if not player_one.gremory_veil_draw_done:
		return (
			"Gremory's Ruinous Harvest flag was not set."
		)

	if _card_ids(
		player_one.hand
	) != [
		"Wright:5",
	]:
		return (
			"Gremory received the wrong harvested card."
		)

	if _card_ids(
		game.discard
	) != [
		"Butcher:1",
		"Penitent:2",
	]:
		return (
			"Summon payment discard or Gremory harvest is incorrect."
		)

	if bool(
		result.get(
			"won",
			true
		)
	):
		return (
			"Single Neutral Tear should not end this fixture."
		)

	return ""


static func _validate_vessel_override(
	game,
	player_one,
	results: Array[Dictionary]
) -> String:
	if results.size() != 2:
		return (
			"Expected two Vessel Summon results."
		)

	var result: Dictionary = results[1]

	if String(
		result.get(
			"action",
			""
		)
	) != "summon":
		return (
			"Valak did not successfully resummon."
		)

	if int(
		result.get(
			"cost",
			0
		)
	) != 4:
		return (
			"Valak should cost 4 with Summoning Circle."
		)

	if int(
		result.get(
			"paid_total",
			0
		)
	) != 4:
		return (
			"Valak payment should total 4."
		)

	if not bool(
		result.get(
			"vessel_applied",
			false
		)
	):
		return (
			"Vessel override was not recorded."
		)

	if player_one.threat != 2:
		return (
			"Vessel-offered Valak should return at Threat 2."
		)

	if not player_one.vessel_offered_lord.is_empty():
		return (
			"Vessel offer was not consumed."
		)

	if player_one.derived_lord_def != 6:
		return (
			"Valak derived Defense should be 6 at Threat 2 with Bastion."
		)

	if not player_one.hand.is_empty():
		return (
			"Valak payment cards remained in hand."
		)

	if _card_ids(
		game.discard
	) != [
		"Butcher:2",
		"Wright:2",
	]:
		return (
			"Valak payment reached the wrong discard state."
		)

	if game.neutral_tears != 1:
		return (
			"Valak resummon did not add a Neutral Tear."
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
