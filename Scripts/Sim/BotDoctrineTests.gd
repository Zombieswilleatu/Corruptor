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
	"unit_bot_reflex_bid_selection"
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
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has("error"):
		return _fail(
			VALAK_GUARD_COMMIT_TEST_NAME,
			String(fixture["error"])
		)

	if not rules.fog_of_war:
		return _fail(
			VALAK_GUARD_COMMIT_TEST_NAME,
			"Regression requires the canonical Fog-of-War profile."
		)

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

	if BotDoctrineData.pick_siege_target(
		game,
		0,
		1
	) != "SiegeEngine":
		return _fail(
			TARGET_TEST_NAME,
			"Deimos did not prioritize Siege Engine."
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
		"game"
	)

	var random_source = session.get(
		"rng"
	)

	if game == null:
		return _fail(
			MARKET_TEST_NAME,
			"Seeded setup returned no GameState."
		)

	if random_source == null:
		return _fail(
			MARKET_TEST_NAME,
			"Seeded setup returned no RNG."
		)

	RoundEngineData.advance_to_round_draw(
		game,
		1,
		rules
	)

	var choices: Dictionary = (
		BotDoctrineData.market_choices(
			game,
			random_source
		)
	)

	var player_one_choice: Dictionary = (
		_decision_for_player(
			choices,
			1
		)
	)

	if String(
		player_one_choice.get(
			"take",
			""
		)
	) != "Wright:5":
		return _fail(
			MARKET_TEST_NAME,
			"Player one did not take the best Market card."
		)

	if String(
		player_one_choice.get(
			"give",
			""
		)
	) != "Vulture:2":
		return _fail(
			MARKET_TEST_NAME,
			"Player one did not give the weakest hand card."
		)

	var player_zero_choice: Dictionary = (
		_decision_for_player(
			choices,
			0
		)
	)

	if String(
		player_zero_choice.get(
			"take",
			""
		)
	) != "Vulture:2":
		return _fail(
			MARKET_TEST_NAME,
			"Player zero did not evaluate the updated shadow Market."
		)

	if String(
		player_zero_choice.get(
			"give",
			""
		)
	) != "Vulture:1":
		return _fail(
			MARKET_TEST_NAME,
			"Player zero selected the wrong outgoing card."
		)

	RoundEngineData.resolve_market(
		game,
		choices
	)

	if _card_ids(
		game.market
	) != [
		"Wright:1",
		"Penitent:1",
		"Vulture:1",
	]:
		return _fail(
			MARKET_TEST_NAME,
			"Resolved deterministic Market reached the wrong order."
		)

	var next_random: float = (
		random_source.random_float()
	)

	if next_random != 0.9497192655214912:
		return _fail(
			MARKET_TEST_NAME,
			"Deterministic Market consumed RNG."
		)

	return _pass(
		MARKET_TEST_NAME
	)


static func _test_reflex_bid_selection(
	rules: RuleConfig
) -> Dictionary:
	var fixture: Dictionary = _build_fixture(
		rules
	)

	if fixture.has(
		"error"
	):
		return _fail(
			BID_TEST_NAME,
			String(
				fixture["error"]
			)
		)

	var game = fixture["game"]
	var player_zero = fixture["p0"]
	var player_one = fixture["p1"]

	game.round = 2

	player_zero.lord = "Odradek"
	player_zero.souls = 0
	player_zero.tears = 0

	player_zero.hand = _cards_from_ids([
		"Vulture:3",
		"Butcher:1",
		"Penitent:2",
	])

	player_one.lord = "Valak"
	player_one.souls = 0
	player_one.tears = 0

	player_one.hand = _cards_from_ids([
		"Butcher:4",
		"Wright:1",
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

	var choices: Dictionary = (
		BotDoctrineData.bid_choices(
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

	if _string_array(
		player_zero_choice.get(
			"bid",
			[]
		)
	) != [
		"Butcher:1",
		"Penitent:2",
	]:
		return _fail(
			BID_TEST_NAME,
			"Odradek chose the wrong controlled bid."
		)

	var player_one_choice: Dictionary = (
		_decision_for_player(
			choices,
			1
		)
	)

	if _string_array(
		player_one_choice.get(
			"bid",
			[]
		)
	) != [
		"Wright:1",
	]:
		return _fail(
			BID_TEST_NAME,
			"Valak chose the wrong baseline bid."
		)

	if _card_ids(
		player_zero.hand
	) != player_zero_before:
		return _fail(
			BID_TEST_NAME,
			"Bid evaluation mutated player zero's hand."
		)

	if _card_ids(
		player_one.hand
	) != player_one_before:
		return _fail(
			BID_TEST_NAME,
			"Bid evaluation mutated player one's hand."
		)

	var next_random: float = (
		random_source.random_float()
	)

	if next_random != 0.13436424411240122:
		return _fail(
			BID_TEST_NAME,
			"Golden Bid selection consumed RNG."
		)

	var bid_result: Dictionary = (
		ReflexBidEngineData.resolve(
			game,
			rules,
			choices
		)
	)

	if int(
		bid_result.get(
			"winner",
			-1
		)
	) != 0:
		return _fail(
			BID_TEST_NAME,
			"Resolved doctrine bid produced the wrong winner."
		)

	return _pass(
		BID_TEST_NAME
	)


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

	if String(
		player_zero_choice.get(
			"target_castle",
			""
		)
	) != "Stockpile":
		return _fail(
			COMMITMENT_TEST_NAME,
			"Deimos selected the wrong Siege target."
		)

	if _string_array(
		player_zero_choice.get(
			"cards",
			[]
		)
	) != [
		"Butcher:4",
		"Butcher:1",
		"Wright:5",
	]:
		return _fail(
			COMMITMENT_TEST_NAME,
			"Deimos committed the wrong cards."
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
	) != "Hunt":
		return _fail(
			COMMITMENT_TEST_NAME,
			"Valak argmax did not choose Hunt."
		)

	if _string_array(
		player_one_choice.get(
			"cards",
			[]
		)
	) != [
		"Butcher:4",
		"Butcher:3",
		"Butcher:2",
		"Vulture:2",
	]:
		return _fail(
			COMMITMENT_TEST_NAME,
			"Valak committed the wrong cards."
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
	) != [
		"Butcher:4",
		"Butcher:1",
		"Wright:5",
	]:
		return _fail(
			COMMITMENT_TEST_NAME,
			"Deimos sealed the wrong cards."
		)

	if player_one.action != "Hunt":
		return _fail(
			COMMITMENT_TEST_NAME,
			"Valak action was not sealed."
		)

	if _card_ids(
		player_one.committed
	) != [
		"Butcher:4",
		"Butcher:3",
		"Butcher:2",
		"Vulture:2",
	]:
		return _fail(
			COMMITMENT_TEST_NAME,
			"Valak sealed the wrong cards."
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
