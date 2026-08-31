class_name BotDoctrineTests
extends RefCounted


const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const SeededGameSetupData = preload(
	"res://Scripts/Sim/SeededGameSetup.gd"
)

const PythonRandomData = preload(
	"res://Scripts/Sim/PythonRandom.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)

const ReflexBidEngineData = preload(
	"res://Scripts/Sim/ReflexBidEngine.gd"
)

const CommitmentEngineData = preload(
	"res://Scripts/Sim/CommitmentEngine.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const BotSelectorData = preload(
	"res://Scripts/Sim/BotSelector.gd"
)

const BotDoctrineData = preload(
	"res://Scripts/Sim/BotDoctrine.gd"
)


const POLICY_TEST_NAME: String = (
	"unit_bot_policy_profiles"
)

const ARGMAX_TEST_NAME: String = (
	"unit_bot_selector_argmax"
)

const SOFTMAX_TEST_NAME: String = (
	"unit_bot_selector_softmax"
)

const PLAN_TEST_NAME: String = (
	"unit_bot_plan_detector"
)

const TARGET_TEST_NAME: String = (
	"unit_bot_siege_target"
)

const MARKET_TEST_NAME: String = (
	"unit_bot_market_consistent"
)

const BID_TEST_NAME: String = (
	"unit_bot_reflex_bid_deprecated"
)

const COMMITMENT_TEST_NAME: String = (
	"unit_bot_commitment_argmax"
)

const BASTION_COMMIT_TEST_NAME: String = (
	"unit_bot_bastion_commitment_objective"
)

const VALAK_GUARD_COMMIT_TEST_NAME: String = (
	"unit_bot_valak_guarded_bastion_commitment"
)


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_forecast_driven_hunt_priority(rules),
		_test_forecast_driven_siege_target(rules),
		_test_policy_profiles(),
		_test_selector_argmax(),
		_test_selector_softmax(),
		_test_plan_detector(
			rules
		),
		_test_siege_target(
			rules
		),
		_test_consistent_market(
			rules
		),
		_test_reflex_bid_selection(
			rules
		),
		_test_commitment_argmax(
			rules
		),
		_test_bastion_commitment_objective(
			rules
		),
		_test_valak_guarded_bastion_commitment(
			rules
		),
	]


static func _test_bastion_commitment_objective(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(rules)
	if fixture.has("error"):
		return _fail(
			BASTION_COMMIT_TEST_NAME,
			String(fixture["error"])
		)

	var game = fixture["game"]
	var attacker = fixture["p0"]
	var defender = fixture["p1"]

	game.breach = ""
	attacker.lord = "Valak"
	attacker.alive = true
	attacker.castles.clear()
	attacker.hand = _cards_from_ids([
		"Butcher:5",
		"Butcher:4",
		"Vulture:5",
		"Wright:5",
		"Penitent:5",
	])

	defender.lord = "Orias"
	defender.alive = true
	defender.castles.clear()
	defender.castles.append("Bastion")
	defender.castles.append("Stockpile")
	defender.castle_integrity.clear()
	defender.castle_integrity["Bastion"] = 9
	defender.castle_integrity["Stockpile"] = 14
	defender.castle_guards.clear()
	defender.sigils["Castle"] = ""

	var committed: Array = BotDoctrineData._commit_for_attack(
		game,
		attacker,
		defender,
		"Castle",
		"neutral",
		false,
		rules
	)

	# Bastion 9 + the canonical minimum Sigil estimate 1 + normal padding 1
	# requires 11 effective Strength. Three cards clear that objective; the old
	# rear+Bastion estimator consumed all five cards trying to fund 25.
	if committed.size() != 3:
		return _fail(
			BASTION_COMMIT_TEST_NAME,
			"Bastion-screened Siege did not stop at the wall objective."
		)

	var effective_total: int = 0
	for card in committed:
		effective_total += int(
			attacker.attack_card_value(
				card,
				rules,
				true
			)
		)

	if effective_total < 11:
		return _fail(
			BASTION_COMMIT_TEST_NAME,
			"Bastion commitment no longer funds the immediate wall objective."
		)

	return _pass(BASTION_COMMIT_TEST_NAME)


static func _test_valak_guarded_bastion_commitment(
	rules: RuleConfig
) -> Dictionary:
	# STALE_GOLDEN_FIXTURE_CLEANUP_V1
	# Fog of War is the subject of this focused regression, not a required
	# canonical DE-v2 default. Isolate the dial inside the fixture.
	var test_rules: RuleConfig = rules.duplicate(true)
	test_rules.fog_of_war = true

	var fixture: Dictionary = _build_fixture(
		test_rules
	)

	if fixture.has("error"):
		return _fail(
			VALAK_GUARD_COMMIT_TEST_NAME,
			String(fixture["error"])
		)

	rules = test_rules
	var game = fixture["game"]
	var attacker = fixture["p0"]
	var defender = fixture["p1"]

	game.breach = ""

	attacker.lord = "Valak"
	attacker.alive = true
	attacker.castles.clear()
	attacker.ruined_castles.clear()
	attacker.profaned_castles.clear()
	attacker.castle_integrity.clear()

	# Same shape as the live failure: five cards total 22, but four cards
	# can reach the correct 19-point Bastion breakpoint.
	#
	# Use Butchers here so the regression isolates commitment selection
	# from Siege Engine / off-suit tax behavior.
	attacker.hand = _cards_from_ids([
		"Butcher:5",
		"Butcher:3",
		"Butcher:4",
		"Butcher:5",
		"Butcher:5",
	])

	defender.lord = "Orias"
	defender.alive = true
	defender.castles.clear()
	defender.ruined_castles.clear()
	defender.profaned_castles.clear()
	defender.castle_integrity.clear()

	defender.castles.append(
		"Bastion"
	)
	defender.castles.append(
		"Stockpile"
	)

	defender.castle_integrity[
		"Bastion"
	] = 14

	defender.castle_integrity[
		"Stockpile"
	] = 14

	defender.castle_guards = _cards_from_ids([
		"Vulture:5",
		"Wright:1",
	])

	for guard in defender.castle_guards:
		guard.guard_revealed = false

	defender.sigils["Castle"] = ""

	# Two hidden Guards estimate to 6 total. Crushing Presence ignores
	# one estimated hidden Guard (3), leaving 3 effective Guard defense.
	var normal_guard_estimate: int = (
		BotDoctrineData._estimated_guard_total(
			defender.castle_guards,
			rules
		)
	)

	var valak_guard_estimate: int = (
		BotDoctrineData._estimated_guard_total_ignoring_lowest(
			defender.castle_guards,
			rules
		)
	)

	if (
		normal_guard_estimate != 6
		or valak_guard_estimate != 3
	):
		return _fail(
			VALAK_GUARD_COMMIT_TEST_NAME,
			"Valak's hidden-Guard estimate did not remove exactly one statistical Guard."
		)

	var committed: Array = (
		BotDoctrineData._commit_for_attack(
			game,
			attacker,
			defender,
			"Castle",
			"neutral",
			false,
			rules
		)
	)

	# Bastion 14 + remaining Guard estimate 3 + minimum Sigil allowance 1
	# + normal padding 1 = 19. The five-card greedy sequence totals 22,
	# but 4+5+5+5 reaches exactly 19.
	if committed.size() != 4:
		return _fail(
			VALAK_GUARD_COMMIT_TEST_NAME,
			"Valak still dumped five cards into a guarded Bastion when four reached the breakpoint."
		)

	var effective_total: int = 0
	var committed_three: bool = false

	for card in committed:
		effective_total += int(
			attacker.attack_card_value(
				card,
				rules,
				true
			)
		)

		if int(card.value) == 3:
			committed_three = true

	if effective_total != 19:
		return _fail(
			VALAK_GUARD_COMMIT_TEST_NAME,
			"Valak's compact Bastion commitment did not land on the 19-point objective."
		)

	if committed_three:
		return _fail(
			VALAK_GUARD_COMMIT_TEST_NAME,
			"Valak conserved the wrong card; the 3 should remain in Hand."
		)

	return _pass(
		VALAK_GUARD_COMMIT_TEST_NAME
	)


static func _test_forecast_driven_hunt_priority(
	rules: RuleConfig
) -> Dictionary:
	const TEST_NAME: String = "unit_bot_forecast_driven_hunt"
	# STALE_GOLDEN_FIXTURE_CLEANUP_V1
	# This regression explicitly exercises hidden-Guard forecasting. Keep Fog
	# local to the test instead of forcing it into the canonical profile.
	var test_rules: RuleConfig = rules.duplicate(true)
	test_rules.fog_of_war = true

	var fixture: Dictionary = _build_fixture(test_rules)
	if fixture.has("error"):
		return _fail(TEST_NAME, String(fixture["error"]))

	rules = test_rules
	var game = fixture["game"]
	var attacker = fixture["p0"]
	var defender = fixture["p1"]

	attacker.lord = "Deimos"
	attacker.alive = true
	attacker.threat = 0
	attacker.hand = _cards_from_ids(["Butcher:5", "Butcher:4"])

	defender.lord = "Valak"
	defender.alive = true
	defender.threat = 0
	defender.castles.clear()
	defender.lord_guards = _cards_from_ids(["Penitent:5"])
	var guard = defender.lord_guards[0]
	guard.guard_revealed = false

	var threat_zero: float = _candidate_score(
		BotDoctrineData.evaluate_action_candidates(game, int(attacker.pid), rules),
		"Hunt"
	)
	defender.threat = 1
	var threat_one: float = _candidate_score(
		BotDoctrineData.evaluate_action_candidates(game, int(attacker.pid), rules),
		"Hunt"
	)
	if absf(threat_zero - threat_one) > 0.0001:
		return _fail(TEST_NAME, "Threat 1 changed Hunt priority without changing actual defenses.")

	defender.threat = 0
	guard.guard_revealed = false
	guard.value = 5
	var hidden_five: float = _candidate_score(
		BotDoctrineData.evaluate_action_candidates(game, int(attacker.pid), rules),
		"Hunt"
	)
	guard.value = 3
	var hidden_three: float = _candidate_score(
		BotDoctrineData.evaluate_action_candidates(game, int(attacker.pid), rules),
		"Hunt"
	)
	if absf(hidden_five - hidden_three) > 0.0001:
		return _fail(TEST_NAME, "Face-down Guard value leaked through Forecast doctrine.")

	guard.guard_revealed = true
	guard.value = 5
	var revealed_five: float = _candidate_score(
		BotDoctrineData.evaluate_action_candidates(game, int(attacker.pid), rules),
		"Hunt"
	)
	guard.value = 3
	var revealed_three: float = _candidate_score(
		BotDoctrineData.evaluate_action_candidates(game, int(attacker.pid), rules),
		"Hunt"
	)
	if revealed_three <= revealed_five:
		return _fail(TEST_NAME, "Weaker revealed Guard did not increase Forecast-driven Hunt priority.")

	return _pass(TEST_NAME)


static func _test_forecast_driven_siege_target(
	rules: RuleConfig
) -> Dictionary:
	const TEST_NAME: String = "unit_bot_forecast_driven_siege_target"
	# CURRENT_RULE_FIXTURE_CLEANUP_V1
	# This regression compares damaged-vs-healthy Castle reachability. Canonical
	# DE-v2 intentionally leaves granular Castle Integrity off, so enable only
	# the rules this focused Forecast fixture actually exercises.
	var test_rules: RuleConfig = rules.duplicate(true)
	test_rules.castle_integrity = true
	test_rules.castle_damage_mode = "arriving_strength"
	test_rules.castle_power_gate_mode = "operational"
	var fixture: Dictionary = _build_fixture(test_rules)
	if fixture.has("error"):
		return _fail(TEST_NAME, String(fixture["error"]))

	var game = fixture["game"]
	var attacker = fixture["p0"]
	var defender = fixture["p1"]
	attacker.lord = "Deimos"
	attacker.alive = true
	attacker.hand = _cards_from_ids(["Butcher:5", "Butcher:4"])

	defender.castles.clear()
	defender.castles.append("Keep")
	defender.castles.append("Stockpile")
	defender.castle_integrity.clear()
	defender.castle_integrity["Keep"] = 1
	defender.castle_integrity["Stockpile"] = 14
	defender.castle_guards.clear()
	defender.sigils["Castle"] = ""

	var target: String = BotDoctrineData.pick_siege_target(
		game,
		int(attacker.pid),
		int(defender.pid),
		test_rules
	)
	if target != "Keep":
		return _fail(TEST_NAME, "Forecast did not prefer the reachable Keep over the much harder Stockpile.")
	return _pass(TEST_NAME)


static func _candidate_score(candidates: Array, action_name: String) -> float:
	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_value
		if String(candidate.get("action", "")) == action_name:
			return float(candidate.get("score", -999.0))
	return -999.0


# FORECAST_DOCTRINE_STALE_GODOT_TESTS_V1
static func _test_policy_profiles() -> Dictionary:
	var golden = BotPolicyData.golden_core()
	var competitive = BotPolicyData.competitive()
	var standard = BotPolicyData.standard()
	var easy = BotPolicyData.easy()

	if golden.temperature != 0.0:
		return _fail(
			POLICY_TEST_NAME,
			"Golden policy is not deterministic."
		)

	if golden.error_rate != 0.0:
		return _fail(
			POLICY_TEST_NAME,
			"Golden policy has an error model."
		)

	if not (
		competitive.temperature
		< standard.temperature
		and standard.temperature
		< easy.temperature
	):
		return _fail(
			POLICY_TEST_NAME,
			"Difficulty temperatures are not ordered."
		)

	if competitive.error_rate != 0.0:
		return _fail(
			POLICY_TEST_NAME,
			"Competitive policy should not make evaluation errors."
		)

	if easy.error_rate <= 0.0:
		return _fail(
			POLICY_TEST_NAME,
			"Easy policy has no explicit error model."
		)

	return _pass(
		POLICY_TEST_NAME
	)


static func _test_selector_argmax() -> Dictionary:
	var random_source = PythonRandomData.new(
		1
	)

	var candidates: Array = [
		{
			"id": "A",
			"score": 2.0,
			"tie_rank": 0,
		},
		{
			"id": "B",
			"score": 2.0,
			"tie_rank": 5,
		},
		{
			"id": "C",
			"score": 1.0,
			"tie_rank": 20,
		},
	]

	var result: Dictionary = (
		BotSelectorData.choose(
			candidates,
			random_source,
			BotPolicyData.golden_core()
		)
	)

	if not bool(
		result.get(
			"valid",
			false
		)
	):
		return _fail(
			ARGMAX_TEST_NAME,
			"Argmax selection failed."
		)

	if String(
		result.get(
			"candidate_id",
			""
		)
	) != "B":
		return _fail(
			ARGMAX_TEST_NAME,
			"Argmax did not use the explicit tie rank."
		)

	if int(
		result.get(
			"draw_count",
			-1
		)
	) != 0:
		return _fail(
			ARGMAX_TEST_NAME,
			"Deterministic argmax consumed RNG."
		)

	var next_random: float = (
		random_source.random_float()
	)

	if next_random != 0.13436424411240122:
		return _fail(
			ARGMAX_TEST_NAME,
			"Argmax altered the RNG stream."
		)

	return _pass(
		ARGMAX_TEST_NAME
	)


static func _test_selector_softmax() -> Dictionary:
	var random_source = PythonRandomData.new(
		1
	)

	var policy = BotPolicyData.new(
		"unit-softmax",
		1.0,
		0.0
	)

	var candidates: Array = [
		{
			"id": "A",
			"score": 0.0,
		},
		{
			"id": "B",
			"score": 1.0,
		},
		{
			"id": "C",
			"score": 2.0,
		},
	]

	var result: Dictionary = (
		BotSelectorData.choose(
			candidates,
			random_source,
			policy
		)
	)

	if String(
		result.get(
			"candidate_id",
			""
		)
	) != "B":
		return _fail(
			SOFTMAX_TEST_NAME,
			"Seed-one softmax selected the wrong candidate."
		)

	if int(
		result.get(
			"draw_count",
			-1
		)
	) != 1:
		return _fail(
			SOFTMAX_TEST_NAME,
			"Softmax did not consume exactly one draw."
		)

	var probabilities = result.get(
		"probabilities",
		[]
	)

	if typeof(
		probabilities
	) != TYPE_ARRAY:
		return _fail(
			SOFTMAX_TEST_NAME,
			"Softmax returned no probability array."
		)

	var probability_total: float = 0.0

	for probability in probabilities:
		probability_total += float(
			probability
		)

	if not is_equal_approx(
		probability_total,
		1.0
	):
		return _fail(
			SOFTMAX_TEST_NAME,
			"Softmax probabilities do not total one."
		)

	var next_random: float = (
		random_source.random_float()
	)

	if next_random != 0.8474337369372327:
		return _fail(
			SOFTMAX_TEST_NAME,
			"Softmax consumed the wrong number of draws."
		)

	return _pass(
		SOFTMAX_TEST_NAME
	)


static func _test_plan_detector(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			PLAN_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player = fixture["p0"]
	var opponent = fixture["p1"]

	_reset_plan_state(
		game,
		player,
		opponent
	)

	opponent.souls = rules.win_souls - 1

	if BotDoctrineData.plan(
		game,
		0,
		rules
	) != "deny_ritual":
		return _fail(
			PLAN_TEST_NAME,
			"Failed to detect immediate Ritual denial."
		)

	_reset_plan_state(
		game,
		player,
		opponent
	)

	game.neutral_tears = (
		rules.dominion_track
		- 2
	)

	opponent.tears = 1

	if BotDoctrineData.plan(
		game,
		0,
		rules
	) != "deny_dominion":
		return _fail(
			PLAN_TEST_NAME,
			"Failed to detect Dominion denial."
		)

	_reset_plan_state(
		game,
		player,
		opponent
	)

	player.souls = 2
	opponent.souls = 1

	if BotDoctrineData.plan(
		game,
		0,
		rules
	) != "protect_souls":
		return _fail(
			PLAN_TEST_NAME,
			"Failed to protect a Soul lead."
		)

	_reset_plan_state(
		game,
		player,
		opponent
	)

	opponent.souls = 1

	if BotDoctrineData.plan(
		game,
		0,
		rules
	) != "pressure_souls":
		return _fail(
			PLAN_TEST_NAME,
			"Failed to pressure a Soul deficit."
		)

	_reset_plan_state(
		game,
		player,
		opponent
	)

	player.lord = "Kroni"
	player.kroni_hunger = 3
	player.tears = 1

	if BotDoctrineData.plan(
		game,
		0,
		rules
	) != "race_dominion":
		return _fail(
			PLAN_TEST_NAME,
			"Failed to detect Kroni's Dominion race."
		)

	_reset_plan_state(
		game,
		player,
		opponent
	)

	if BotDoctrineData.plan(
		game,
		0,
		rules
	) != "neutral":
		return _fail(
			PLAN_TEST_NAME,
			"Neutral board produced a non-neutral plan."
		)

	return _pass(
		PLAN_TEST_NAME
	)


static func _test_siege_target(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			TARGET_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var defender = fixture["p1"]

	defender.lord = "Deimos"
	defender.alive = true

	# CURRENT_RULE_FIXTURE_CLEANUP_V1
	# Without a RuleConfig this function intentionally exercises the deterministic
	# fallback order, not the newer Forecast/personality target evaluator.
	if BotDoctrineData.pick_siege_target(
		game,
		0,
		1
	) != "Stockpile":
		return _fail(
			TARGET_TEST_NAME,
			"Fallback Siege priority chose the wrong Castle."
		)

	defender.lord = "Valak"

	defender.castles.clear()
	defender.castles.append(
		"Keep"
	)
	defender.castles.append(
		"Bastion"
	)

	if BotDoctrineData.pick_siege_target(
		game,
		0,
		1
	) != "Bastion":
		return _fail(
			TARGET_TEST_NAME,
			"Normal Siege priority chose the wrong Castle."
		)

	return _pass(
		TARGET_TEST_NAME
	)


static func _test_consistent_market(
	rules: RuleConfig
) -> Dictionary:
	var session: Dictionary = (
		SeededGameSetupData
		.setup_deimos_valak_seed_one(
			rules
		)
	)

	var game = session.get(
		"game",
		null
	)

	if game == null:
		return _fail(
			MARKET_TEST_NAME,
			"Seed-one Market fixture did not produce a game."
		)

	RoundEngineData.advance_to_round_draw(
		game,
		1,
		rules
	)

	var player_zero = game.get_player(0)
	var player_one = game.get_player(1)

	var player_zero_before: Array[String] = _card_ids(
		player_zero.hand
	)
	var player_one_before: Array[String] = _card_ids(
		player_one.hand
	)

	var expected_take = null
	for card in game.market:
		if (
			expected_take == null
			or int(card.value) > int(expected_take.value)
		):
			expected_take = card

	var expected_give = null
	for card in player_one.hand:
		if (
			expected_give == null
			or int(card.value) < int(expected_give.value)
		):
			expected_give = card

	if expected_take == null or expected_give == null:
		return _fail(
			MARKET_TEST_NAME,
			"Seed-one Market fixture has no legal comparison cards."
		)

	var choices: Dictionary = BotDoctrineData.market_choices(
		game
	)

	var player_one_choice: Dictionary = _decision_for_player(
		choices,
		1
	)

	if bool(player_one_choice.get("pass", false)):
		return _fail(
			MARKET_TEST_NAME,
			"Player one passed a strictly improving Market swap."
		)

	if String(player_one_choice.get("take", "")) != String(expected_take.card_id()):
		return _fail(
			MARKET_TEST_NAME,
			"Player one did not take the strongest Market card."
		)

	if String(player_one_choice.get("give", "")) != String(expected_give.card_id()):
		return _fail(
			MARKET_TEST_NAME,
			"Player one did not give the weakest hand card."
		)

	if _card_ids(player_zero.hand) != player_zero_before:
		return _fail(
			MARKET_TEST_NAME,
			"Market evaluation mutated player zero's real hand."
		)

	if _card_ids(player_one.hand) != player_one_before:
		return _fail(
			MARKET_TEST_NAME,
			"Market evaluation mutated player one's real hand."
		)

	return _pass(MARKET_TEST_NAME)


static func _test_reflex_bid_selection(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(rules)
	if fixture.has("error"):
		return _fail(BID_TEST_NAME, String(fixture["error"]))

	var game = fixture["game"]
	var choices: Dictionary = BotDoctrineData.bid_choices(
		game,
		null,
		rules,
		BotPolicyData.golden_core()
	)

	for player in game.players:
		# REFLEX_RETIREMENT_PARSER_HOTFIX_V1
		var decision_value = choices.get(
			int(player.pid),
			{}
		)
		if typeof(decision_value) != TYPE_DICTIONARY:
			return _fail(
				BID_TEST_NAME,
				"Deprecated Reflex Bid doctrine returned a non-dictionary decision."
			)
		var decision: Dictionary = decision_value
		if not bool(decision.get("pass", false)):
			return _fail(
				BID_TEST_NAME,
				"Deprecated Reflex Bid doctrine spent cards or produced a live bid."
			)
		if not bool(decision.get("deprecated", false)):
			return _fail(
				BID_TEST_NAME,
				"Deprecated Reflex Bid doctrine did not identify itself as retired."
			)

	return _pass(BID_TEST_NAME)

static func _test_commitment_argmax(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			COMMITMENT_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	player_zero.lord = "Deimos"
	player_zero.alive = true
	player_zero.souls = 0
	player_zero.tears = 0
	player_zero.threat = 0

	player_one.lord = "Valak"
	player_one.alive = true
	player_one.souls = 0
	player_one.tears = 0
	player_one.threat = 1

	player_zero.hand = _cards_from_ids([
		"Butcher:4",
		"Butcher:1",
		"Penitent:1",
		"Wright:5",
	])

	player_zero.castle_guards = _cards_from_ids([
		"Penitent:2",
		"Penitent:3",
		"Penitent:3",
	])

	player_zero.lord_guards = _cards_from_ids([
		"Wright:4",
		"Penitent:5",
	])

	player_one.hand = _cards_from_ids([
		"Vulture:2",
		"Butcher:4",
		"Butcher:2",
		"Butcher:3",
	])

	player_one.castle_guards = _cards_from_ids([
		"Wright:3",
		"Wright:3",
		"Wright:3",
	])

	player_one.lord_guards = _cards_from_ids([
		"Vulture:4",
		"Vulture:5",
	])

	var player_zero_before: Array[String] = _card_ids(
		player_zero.hand
	)

	var player_one_before: Array[String] = _card_ids(
		player_one.hand
	)

	var random_source = PythonRandomData.new(
		1
	)

	# COMMITMENT_ARGMAX_CURRENT_CANDIDATE_V1
	# Follow the current deterministic candidate scores instead of freezing a
	# historical Valak action forever. BotSelector argmax/tie behavior is
	# tested separately; here we verify commitment_choices preserves the
	# selected candidate through CommitmentEngine.
	var player_one_candidates: Array = (
		BotDoctrineData.evaluate_action_candidates(
			game,
			1,
			rules
		)
	)
	var player_one_argmax: Dictionary = (
		BotSelectorData.choose(
			player_one_candidates,
			null,
			BotPolicyData.golden_core()
		)
	)
	var player_one_expected_action: String = String(
		player_one_argmax.get(
			"candidate",
			{}
		).get(
			"action",
			""
		)
	)
	if player_one_expected_action.is_empty():
		return _fail(
			COMMITMENT_TEST_NAME,
			"Valak argmax produced no action."
		)

	var choices: Dictionary = (
		BotDoctrineData.commitment_choices(
			game,
			random_source,
			rules,
			BotPolicyData.golden_core()
		)
	)

	var player_zero_choice: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	if String(
		player_zero_choice.get(
			"action",
			""
		)
	) != "Siege":
		return _fail(
			COMMITMENT_TEST_NAME,
			"Deimos argmax did not choose Siege."
		)

	# CURRENT_RULE_FIXTURE_CLEANUP_V1
	# Exact target choice now belongs to Forecast. This test verifies that the
	# Commitment bundle carries the target chosen by the canonical target picker.
	var expected_siege_target: String = BotDoctrineData.pick_siege_target(
		game,
		0,
		1,
		rules
	)
	if expected_siege_target.is_empty():
		return _fail(
			COMMITMENT_TEST_NAME,
			"Deimos Forecast produced no legal Siege target."
		)

	if String(
		player_zero_choice.get(
			"target_castle",
			""
		)
	) != expected_siege_target:
		return _fail(
			COMMITMENT_TEST_NAME,
			"Commitment did not preserve the selected Siege target."
		)

	# FINAL_STANDALONE_FIXTURE_CLEANUP_V1
	# Forecast now owns the target breakpoint, so exact card composition is
	# intentionally not frozen here. The integration contract is that doctrine
	# produces a real bundle and CommitmentEngine seals that exact bundle.
	var deimos_cards: Array[String] = _string_array(
		player_zero_choice.get(
			"cards",
			[]
		)
	)
	if deimos_cards.is_empty():
		return _fail(
			COMMITMENT_TEST_NAME,
			"Deimos produced an empty Siege commitment."
		)

	var player_one_choice: Dictionary = (
		_decision_for_player(
			choices,
			1
		)
	)

	if String(
		player_one_choice.get(
			"action",
			""
		)
	) != player_one_expected_action:
		return _fail(
			COMMITMENT_TEST_NAME,
			"Commitment choice did not preserve Valak's current argmax action."
		)

	var valak_cards: Array[String] = _string_array(
		player_one_choice.get(
			"cards",
			[]
		)
	)
	if (
		player_one_expected_action in ["Hunt", "Siege"]
		and valak_cards.is_empty()
	):
		return _fail(
			COMMITMENT_TEST_NAME,
			"Valak produced an empty attack commitment."
		)

	if _card_ids(
		player_zero.hand
	) != player_zero_before:
		return _fail(
			COMMITMENT_TEST_NAME,
			"Commitment evaluation mutated player zero's hand."
		)

	if _card_ids(
		player_one.hand
	) != player_one_before:
		return _fail(
			COMMITMENT_TEST_NAME,
			"Commitment evaluation mutated player one's hand."
		)

	var next_random: float = (
		random_source.random_float()
	)

	if next_random != 0.13436424411240122:
		return _fail(
			COMMITMENT_TEST_NAME,
			"Golden Commitment selection consumed RNG."
		)

	var commitment_result: Dictionary = (
		CommitmentEngineData.resolve(
			game,
			choices
		)
	)

	if String(
		commitment_result.get(
			"action",
			""
		)
	) != "commit":
		return _fail(
			COMMITMENT_TEST_NAME,
			"Doctrine decisions were rejected by CommitmentEngine."
		)

	if player_zero.action != "Siege":
		return _fail(
			COMMITMENT_TEST_NAME,
			"Deimos action was not sealed."
		)

	if _card_ids(
		player_zero.committed
	) != deimos_cards:
		return _fail(
			COMMITMENT_TEST_NAME,
			"Deimos did not seal the doctrine-selected cards."
		)

	if player_one.action != player_one_expected_action:
		return _fail(
			COMMITMENT_TEST_NAME,
			"Valak argmax action was not sealed."
		)

	if _card_ids(
		player_one.committed
	) != valak_cards:
		return _fail(
			COMMITMENT_TEST_NAME,
			"Valak did not seal the doctrine-selected cards."
		)

	return _pass(
		COMMITMENT_TEST_NAME
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


static func _reset_plan_state(
	game,
	player,
	opponent
) -> void:
	game.neutral_tears = 0

	player.lord = "Deimos"
	player.alive = true
	player.souls = 0
	player.tears = 0
	player.kroni_hunger = 0

	opponent.lord = "Valak"
	opponent.alive = true
	opponent.souls = 0
	opponent.tears = 0

	game.refresh_derived_values()


static func _cards_from_ids(
	card_ids: Array
) -> Array:
	var cards: Array = []

	for raw_card_id in card_ids:
		var card_identifier: String = String(
			raw_card_id
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


static func _card_ids(
	cards: Array
) -> Array[String]:
	var result: Array[String] = []

	for card in cards:
		result.append(
			_card_id(
				card
			)
		)

	return result


static func _card_id(
	card
) -> String:
	if card == null:
		return ""

	if card.has_method(
		"card_id"
	):
		return String(
			card.card_id()
		)

	return str(
		card
	)


static func _string_array(
	values
) -> Array[String]:
	var result: Array[String] = []

	if typeof(
		values
	) != TYPE_ARRAY:
		return result

	for value in values:
		result.append(
			String(
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
