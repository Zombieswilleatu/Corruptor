class_name BotRoundEngineTests
extends RefCounted


const SeededGameSetupData = preload(
	"res://Scripts/Sim/SeededGameSetup.gd"
)

const GoldenMasterData = preload(
	"res://Scripts/Sim/GoldenMaster.gd"
)

const GoldenSnapshotSerializerData = preload(
	"res://Scripts/Sim/GoldenSnapshotSerializer.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const BotRoundEngineData = preload(
	"res://Scripts/Sim/BotRoundEngine.gd"
)

const BotGameEngineData = preload(
	"res://Scripts/Sim/BotGameEngine.gd"
)


const AI_POLICY: String = (
	"softmax-2026.07-v1-golden"
)

const GAME_TRACE_NAME: String = (
	"game_deimos_valak_s1"
)


const ROUND_ONE_TEST_NAME: String = (
	"unit_bot_round_one_complete"
)

const ROUND_TWO_TEST_NAME: String = (
	"unit_bot_round_two_reflex"
)

const DETERMINISM_TEST_NAME: String = (
	"unit_bot_round_seed_one_deterministic"
)

const GAME_TERMINAL_TEST_NAME: String = (
	"unit_bot_game_seed_one_terminal"
)

const TIMEOUT_TEST_NAME: String = (
	"unit_bot_game_timeout_tiebreak"
)

const GOLDEN_GAME_TEST_NAME: String = (
	"golden_bot_game_deimos_valak_s1"
)


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_round_one_complete(
			rules
		),
		_test_round_two_reflex(
			rules
		),
		_test_seed_one_determinism(
			rules
		),
		_test_full_game_terminal(
			rules
		),
		_test_timeout_tiebreak(
			rules
		),
		_test_seed_one_golden(
			rules
		),
	]


static func _test_round_one_complete(
	rules: RuleConfig
) -> Dictionary:
	var setup: Dictionary = (
		SeededGameSetupData
		.setup_deimos_valak_seed_one(
			rules
		)
	)

	var game = setup.get(
		"game"
	)

	var random_source = setup.get(
		"rng"
	)

	if (
		game == null
		or random_source == null
	):
		return _fail(
			ROUND_ONE_TEST_NAME,
			"Seeded setup returned no game or RNG."
		)

	var result: Dictionary = (
		BotRoundEngineData.resolve_round(
			game,
			rules,
			random_source,
			1,
			BotPolicyData.golden_core()
		)
	)

	if String(
		result.get(
			"action",
			""
		)
	) != "round":
		return _fail(
			ROUND_ONE_TEST_NAME,
			"Round one returned an invalid result."
		)

	if not bool(
		result.get(
			"completed",
			false
		)
	):
		return _fail(
			ROUND_ONE_TEST_NAME,
			"Round one stopped before Resolution."
		)

	if game.round != 1:
		return _fail(
			ROUND_ONE_TEST_NAME,
			"Round conductor stored the wrong round number."
		)

	var phases: Dictionary = _dictionary(
		result.get(
			"phases",
			{}
		)
	)

	var bid_phase: Dictionary = _dictionary(
		phases.get(
			"reflex_bid",
			{}
		)
	)

	var bid_result: Dictionary = _dictionary(
		bid_phase.get(
			"result",
			{}
		)
	)

	if String(
		bid_result.get(
			"action",
			""
		)
	) != "skip":
		return _fail(
			ROUND_ONE_TEST_NAME,
			"Round one did not skip Reflex Bid."
		)

	var commitment_phase: Dictionary = _dictionary(
		phases.get(
			"commitment",
			{}
		)
	)

	var commitment_result: Dictionary = _dictionary(
		commitment_phase.get(
			"result",
			{}
		)
	)

	if String(
		commitment_result.get(
			"action",
			""
		)
	) != "commit":
		return _fail(
			ROUND_ONE_TEST_NAME,
			"Round one did not resolve Commitment."
		)

	var reveal_result: Dictionary = _dictionary(
		phases.get(
			"reveal",
			{}
		)
	)

	if String(
		reveal_result.get(
			"action",
			""
		)
	) != "reveal":
		return _fail(
			ROUND_ONE_TEST_NAME,
			"Round one did not resolve Reveal."
		)

	var resolution_phase: Dictionary = _dictionary(
		phases.get(
			"resolution",
			{}
		)
	)

	var resolution_result: Dictionary = _dictionary(
		resolution_phase.get(
			"result",
			{}
		)
	)

	if String(
		resolution_result.get(
			"action",
			""
		)
	) != "resolution":
		return _fail(
			ROUND_ONE_TEST_NAME,
			"Round one did not resolve Resolution."
		)

	for player in game.players:
		if not player.committed.is_empty():
			return _fail(
				ROUND_ONE_TEST_NAME,
				"Resolution left committed cards in play."
			)

	var expected_phases: Array[String] = [
		"begin_round",
		"sigil_update",
		"veil_drift",
		"development_start",
		"draw",
		"market",
		"repair",
		"dominion_rites",
		"deploy",
		"summon",
		"reflex_bid",
		"commitment",
		"reveal",
		"resolution",
	]

	if _event_phases(
		result.get(
			"events",
			[]
		)
	) != expected_phases:
		return _fail(
			ROUND_ONE_TEST_NAME,
			"Round phases resolved in the wrong order."
		)

	return _pass(
		ROUND_ONE_TEST_NAME
	)


static func _test_round_two_reflex(
	rules: RuleConfig
) -> Dictionary:
	var setup: Dictionary = (
		SeededGameSetupData
		.setup_deimos_valak_seed_one(
			rules
		)
	)

	var game = setup.get(
		"game"
	)

	var random_source = setup.get(
		"rng"
	)

	if (
		game == null
		or random_source == null
	):
		return _fail(
			ROUND_TWO_TEST_NAME,
			"Seeded setup returned no game or RNG."
		)

	var round_one: Dictionary = (
		BotRoundEngineData.resolve_round(
			game,
			rules,
			random_source,
			1,
			BotPolicyData.golden_core()
		)
	)

	if String(
		round_one.get(
			"action",
			""
		)
	) != "round":
		return _fail(
			ROUND_TWO_TEST_NAME,
			"Round one failed before the round-two test."
		)

	if int(
		game.winner
	) >= 0:
		return _fail(
			ROUND_TWO_TEST_NAME,
			"Seed-one game ended before round two."
		)

	var round_two: Dictionary = (
		BotRoundEngineData.resolve_round(
			game,
			rules,
			random_source,
			2,
			BotPolicyData.golden_core()
		)
	)

	if String(
		round_two.get(
			"action",
			""
		)
	) != "round":
		return _fail(
			ROUND_TWO_TEST_NAME,
			"Round two returned an invalid result."
		)

	var phases: Dictionary = _dictionary(
		round_two.get(
			"phases",
			{}
		)
	)

	var bid_phase: Dictionary = _dictionary(
		phases.get(
			"reflex_bid",
			{}
		)
	)

	var bid_result: Dictionary = _dictionary(
		bid_phase.get(
			"result",
			{}
		)
	)

	if String(
		bid_result.get(
			"action",
			""
		)
	) == "skip":
		return _fail(
			ROUND_TWO_TEST_NAME,
			"Round two incorrectly skipped Reflex Bid."
		)

	if not [
		"tie",
		"resolve",
	].has(
		String(
			bid_result.get(
				"action",
				""
			)
		)
	):
		return _fail(
			ROUND_TWO_TEST_NAME,
			"Round-two Reflex Bid returned an unknown action."
		)

	if game.round != 2:
		return _fail(
			ROUND_TWO_TEST_NAME,
			"Round conductor did not advance to round two."
		)

	return _pass(
		ROUND_TWO_TEST_NAME
	)


static func _test_seed_one_determinism(
	rules: RuleConfig
) -> Dictionary:
	var setup_a: Dictionary = (
		SeededGameSetupData
		.setup_deimos_valak_seed_one(
			rules
		)
	)

	var setup_b: Dictionary = (
		SeededGameSetupData
		.setup_deimos_valak_seed_one(
			rules
		)
	)

	var game_a = setup_a.get(
		"game"
	)

	var game_b = setup_b.get(
		"game"
	)

	var rng_a = setup_a.get(
		"rng"
	)

	var rng_b = setup_b.get(
		"rng"
	)

	if (
		game_a == null
		or game_b == null
		or rng_a == null
		or rng_b == null
	):
		return _fail(
			DETERMINISM_TEST_NAME,
			"Seeded setup returned incomplete fixtures."
		)

	var result_a: Dictionary = (
		BotRoundEngineData.resolve_round(
			game_a,
			rules,
			rng_a,
			1,
			BotPolicyData.golden_core()
		)
	)

	var result_b: Dictionary = (
		BotRoundEngineData.resolve_round(
			game_b,
			rules,
			rng_b,
			1,
			BotPolicyData.golden_core()
		)
	)

	if (
		String(
			result_a.get(
				"action",
				""
			)
		) != "round"
		or String(
			result_b.get(
				"action",
				""
			)
		) != "round"
	):
		return _fail(
			DETERMINISM_TEST_NAME,
			"A deterministic round returned invalid."
		)

	if _game_signature(
		game_a
	) != _game_signature(
		game_b
	):
		return _fail(
			DETERMINISM_TEST_NAME,
			"Identical seed-one rounds diverged."
		)

	if _event_phases(
		result_a.get(
			"events",
			[]
		)
	) != _event_phases(
		result_b.get(
			"events",
			[]
		)
	):
		return _fail(
			DETERMINISM_TEST_NAME,
			"Identical rounds emitted different phase order."
		)

	var next_a: float = rng_a.random_float()
	var next_b: float = rng_b.random_float()

	if next_a != next_b:
		return _fail(
			DETERMINISM_TEST_NAME,
			"Identical rounds consumed different RNG streams."
		)

	return _pass(
		DETERMINISM_TEST_NAME
	)


static func _test_full_game_terminal(
	rules: RuleConfig
) -> Dictionary:
	var setup: Dictionary = (
		SeededGameSetupData
		.setup_deimos_valak_seed_one(
			rules
		)
	)

	var game = setup.get(
		"game"
	)

	var random_source = setup.get(
		"rng"
	)

	if (
		game == null
		or random_source == null
	):
		return _fail(
			GAME_TERMINAL_TEST_NAME,
			"Seeded setup returned no game or RNG."
		)

	var result: Dictionary = (
		BotGameEngineData.resolve_game(
			game,
			rules,
			random_source,
			BotPolicyData.golden_core()
		)
	)

	if String(
		result.get(
			"action",
			""
		)
	) == "invalid":
		return _fail(
			GAME_TERMINAL_TEST_NAME,
			"Full game became invalid in round %d, phase %s: %s"
			% [
				int(
					result.get(
						"stopped_round",
						-1
					)
				),
				String(
					result.get(
						"stopped_phase",
						""
					)
				),
				String(
					result.get(
						"reason",
						""
					)
				),
			]
		)

	if String(
		result.get(
			"action",
			""
		)
	) != "game":
		return _fail(
			GAME_TERMINAL_TEST_NAME,
			"Full game returned an unknown result."
		)

	if not bool(
		result.get(
			"terminal",
			false
		)
	):
		return _fail(
			GAME_TERMINAL_TEST_NAME,
			"Full game did not reach a terminal state."
		)

	if int(
		game.winner
	) < 0:
		return _fail(
			GAME_TERMINAL_TEST_NAME,
			"Terminal game has no winner."
		)

	if String(
		game.win_by
	).is_empty():
		return _fail(
			GAME_TERMINAL_TEST_NAME,
			"Terminal game has no victory condition."
		)

	if game.round > rules.max_rounds:
		return _fail(
			GAME_TERMINAL_TEST_NAME,
			"Full game exceeded the configured round limit."
		)

	if int(
		result.get(
			"final_round",
			-1
		)
	) != int(
		game.round
	):
		return _fail(
			GAME_TERMINAL_TEST_NAME,
			"Game result and GameState disagree on the final round."
		)

	return _pass(
		GAME_TERMINAL_TEST_NAME
	)


static func _test_timeout_tiebreak(
	rules: RuleConfig
) -> Dictionary:
	var setup: Dictionary = (
		SeededGameSetupData
		.setup_deimos_valak_seed_one(
			rules
		)
	)

	var game = setup.get(
		"game"
	)

	var random_source = setup.get(
		"rng"
	)

	if (
		game == null
		or random_source == null
	):
		return _fail(
			TIMEOUT_TEST_NAME,
			"Seeded setup returned no game or RNG."
		)

	var result: Dictionary = (
		BotGameEngineData.resolve_game(
			game,
			rules,
			random_source,
			BotPolicyData.golden_core(),
			0
		)
	)

	if String(
		result.get(
			"action",
			""
		)
	) != "game":
		return _fail(
			TIMEOUT_TEST_NAME,
			"Immediate timeout returned an invalid result."
		)

	if game.win_by != "Timeout":
		return _fail(
			TIMEOUT_TEST_NAME,
			"Round limit did not produce a Timeout result."
		)

	if game.winner != 0:
		return _fail(
			TIMEOUT_TEST_NAME,
			"Lower-Threat Deimos did not win the timeout."
		)

	if game.round != 0:
		return _fail(
			TIMEOUT_TEST_NAME,
			"Immediate timeout unexpectedly resolved a round."
		)

	var timeout_result: Dictionary = _dictionary(
		result.get(
			"timeout",
			{}
		)
	)

	if String(
		timeout_result.get(
			"tie_break",
			""
		)
	) != "threat":
		return _fail(
			TIMEOUT_TEST_NAME,
			"Timeout used the wrong tiebreak layer."
		)

	if int(
		result.get(
			"round_count",
			-1
		)
	) != 0:
		return _fail(
			TIMEOUT_TEST_NAME,
			"Immediate timeout recorded resolved rounds."
		)

	var next_random: float = (
		random_source.random_float()
	)

	if next_random != 0.9497192655214912:
		return _fail(
			TIMEOUT_TEST_NAME,
			"Non-random timeout consumed RNG."
		)

	return _pass(
		TIMEOUT_TEST_NAME
	)


static func _test_seed_one_golden(
	rules: RuleConfig
) -> Dictionary:
	var trace: Dictionary = (
		GoldenMasterData.load_trace(
			GAME_TRACE_NAME
		)
	)

	if trace.has(
		"_error"
	):
		return _fail(
			GOLDEN_GAME_TEST_NAME,
			String(
				trace.get(
					"_error",
					"unable_to_load_trace"
				)
			)
		)

	var setup: Dictionary = (
		SeededGameSetupData
		.setup_deimos_valak_seed_one(
			rules
		)
	)

	var game = setup.get(
		"game"
	)

	var random_source = setup.get(
		"rng"
	)

	if (
		game == null
		or random_source == null
	):
		return _fail(
			GOLDEN_GAME_TEST_NAME,
			"Seeded setup returned no game or RNG."
		)

	var engine_snapshots: Array = [
		GoldenSnapshotSerializerData
		.snapshot_game(
			game,
			"game:deal",
			rules
		),
	]

	while (
		int(
			game.winner
		) < 0
		and int(
			game.round
		) < int(
			rules.max_rounds
		)
	):
		var next_round: int = (
			int(
				game.round
			) + 1
		)

		var round_result: Dictionary = (
			BotRoundEngineData.resolve_round(
				game,
				rules,
				random_source,
				next_round,
				BotPolicyData.golden_core()
			)
		)

		if String(
			round_result.get(
				"action",
				""
			)
		) == "invalid":
			return _fail(
				GOLDEN_GAME_TEST_NAME,
				"Golden game became invalid in round %d, phase %s: %s"
				% [
					next_round,
					String(
						round_result.get(
							"stopped_phase",
							""
						)
					),
					String(
						round_result.get(
							"reason",
							""
						)
					),
				]
			)

		engine_snapshots.append(
			GoldenSnapshotSerializerData
			.snapshot_game(
				game,
				"round:%02d:end"
				% next_round,
				rules
			)
		)

	if int(
		game.winner
	) < 0:
		var timeout_result: Dictionary = (
			BotGameEngineData.resolve_game(
				game,
				rules,
				random_source,
				BotPolicyData.golden_core(),
				int(
					game.round
				)
			)
		)

		if String(
			timeout_result.get(
				"action",
				""
			)
		) == "invalid":
			return _fail(
				GOLDEN_GAME_TEST_NAME,
				"Golden timeout became invalid: %s"
				% String(
					timeout_result.get(
						"reason",
						""
					)
				)
			)

	if int(
		game.winner
	) < 0:
		return _fail(
			GOLDEN_GAME_TEST_NAME,
			"Golden game did not reach game:end."
		)

	engine_snapshots.append(
		GoldenSnapshotSerializerData
		.snapshot_game(
			game,
			"game:end",
			rules
		)
	)

	var validation = GoldenMasterData.validate(
		trace,
		engine_snapshots,
		rules,
		AI_POLICY
	)

	if validation.passed:
		return _pass(
			str(
				validation
			)
		)

	return _fail(
		GOLDEN_GAME_TEST_NAME,
		str(
			validation
		)
	)


static func _game_signature(
	game
) -> Dictionary:
	var player_signatures: Array[Dictionary] = []

	for player in game.players:
		player_signatures.append({
			"player_id": int(
				player.pid
			),
			"lord": String(
				player.lord
			),
			"alive": bool(
				player.alive
			),
			"souls": int(
				player.souls
			),
			"tears": int(
				player.tears
			),
			"threat": int(
				player.threat
			),
			"hand": _card_ids(
				player.hand
			),
			"garrison": _card_ids(
				player.garrison
			),
			"castle_guards": _card_ids(
				player.castle_guards
			),
			"lord_guards": _card_ids(
				player.lord_guards
			),
			"castles": (
				player.castles.duplicate()
			),
			"ruined_castles": (
				player.ruined_castles.duplicate()
			),
			"profaned_castles": (
				player.profaned_castles.duplicate()
			),
		})

	return {
		"round": int(
			game.round
		),
		"first_player": int(
			game.first_player
		),
		"breach": String(
			game.breach
		),
		"breach_owner": int(
			game.breach_owner
		),
		"neutral_tears": int(
			game.neutral_tears
		),
		"winner": int(
			game.winner
		),
		"win_by": String(
			game.win_by
		),
		"deck": _card_ids(
			game.deck
		),
		"discard": _card_ids(
			game.discard
		),
		"market": _card_ids(
			game.market
		),
		"players": player_signatures,
	}


static func _event_phases(
	raw_events
) -> Array[String]:
	var result: Array[String] = []

	if typeof(
		raw_events
	) != TYPE_ARRAY:
		return result

	var events: Array = raw_events

	for raw_event in events:
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event

		result.append(
			String(
				event.get(
					"phase",
					""
				)
			)
		)

	return result


static func _dictionary(
	value
) -> Dictionary:
	if typeof(
		value
	) != TYPE_DICTIONARY:
		return {}

	return value


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
