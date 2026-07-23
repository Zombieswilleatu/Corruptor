class_name LordMatrixTests
extends RefCounted


const MATRIX_PATH: String = (
	"res://golden/lord_matrix.json"
)

const AI_POLICY: String = (
	"softmax-2026.07-v1-golden"
)

const EXPECTED_LORD_COUNT: int = 9
const EXPECTED_SCENARIO_COUNT: int = 81

const EXPECTED_CARD_POPULATION: int = 60


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

const ResolutionFinaleEngineData = preload(
	"res://Scripts/Sim/ResolutionFinaleEngine.gd"
)

const BotGameEngineData = preload(
	"res://Scripts/Sim/BotGameEngine.gd"
)


static func run(
	rules: RuleConfig
) -> Array:
	var matrix: Dictionary = _load_matrix()

	if matrix.has(
		"_error"
	):
		return [
			_fail(
				"golden_lord_matrix",
				String(
					matrix.get(
						"_error",
						"unable_to_load_matrix"
					)
				)
			),
		]

	var identity_gate: Dictionary = (
		GoldenMasterData.identity_matches(
			matrix,
			rules,
			AI_POLICY
		)
	)

	if not bool(
		identity_gate.get(
			"ok",
			false
		)
	):
		return [
			_fail(
				"golden_lord_matrix",
				"identity refused: %s"
				% String(
					identity_gate.get(
						"why",
						"unknown_identity_mismatch"
					)
				)
			),
		]

	var lords_raw = matrix.get(
		"lords",
		[]
	)

	if (
		typeof(
			lords_raw
		) != TYPE_ARRAY
		or lords_raw.size()
		!= EXPECTED_LORD_COUNT
	):
		return [
			_fail(
				"golden_lord_matrix",
				"Expected %d Lords in the matrix."
				% EXPECTED_LORD_COUNT
			),
		]

	var scenarios_raw = matrix.get(
		"scenarios",
		[]
	)

	if typeof(
		scenarios_raw
	) != TYPE_ARRAY:
		return [
			_fail(
				"golden_lord_matrix",
				"Matrix scenarios are not an Array."
			),
		]

	var scenarios: Array = scenarios_raw

	if scenarios.size() != EXPECTED_SCENARIO_COUNT:
		return [
			_fail(
				"golden_lord_matrix",
				"Expected %d ordered matchups, found %d."
				% [
					EXPECTED_SCENARIO_COUNT,
					scenarios.size(),
				]
			),
		]

	var results: Array = []

	for raw_scenario in scenarios:
		if typeof(
			raw_scenario
		) != TYPE_DICTIONARY:
			results.append(
				_fail(
					"golden_lord_matrix",
					"Matrix contains a non-Dictionary scenario."
				)
			)

			continue

		results.append(
			_run_scenario(
				raw_scenario,
				rules
			)
		)

	return results


static func _run_scenario(
	scenario: Dictionary,
	rules: RuleConfig
) -> Dictionary:
	var scenario_name: String = String(
		scenario.get(
			"name",
			"matrix_unknown"
		)
	)

	var player_zero_lord: String = String(
		scenario.get(
			"player_zero_lord",
			""
		)
	)

	var player_one_lord: String = String(
		scenario.get(
			"player_one_lord",
			""
		)
	)

	var seed_value: int = int(
		scenario.get(
			"seed",
			-1
		)
	)

	if (
		player_zero_lord.is_empty()
		or player_one_lord.is_empty()
		or seed_value < 0
	):
		return _fail(
			scenario_name,
			"Scenario identity is incomplete."
		)

	var setup: Dictionary = (
		SeededGameSetupData.setup_locked_game(
			player_zero_lord,
			player_one_lord,
			seed_value,
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
			scenario_name,
			"Seeded setup returned no game or RNG."
		)

	var deal_population_failure: String = _card_population_failure(game)

	if not deal_population_failure.is_empty():
		return _fail(
			scenario_name,
			"Card conservation failure at game:deal: %s"
			% deal_population_failure
		)
	var snapshots: Array = [
		GoldenSnapshotSerializerData.snapshot_game(
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
				scenario_name,
				"Invalid round %d at phase %s: %s"
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

		var round_population_failure: String = _card_population_failure(game)

		if not round_population_failure.is_empty():
			return _fail(
				scenario_name,
				"Card conservation failure at round:end: %s"
				% round_population_failure
			)
		snapshots.append(
			GoldenSnapshotSerializerData.snapshot_game(
				game,
				"round:%02d:end"
				% next_round,
				rules
			)
		)

		# Python's round-snapshot harness evaluates any victory deferred by
		# end-of-round effects only after recording round:NN:end.
		if int(game.winner) < 0:
			ResolutionFinaleEngineData.check_win(
				game,
				rules
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
				scenario_name,
				"Timeout resolution became invalid: %s"
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
			scenario_name,
			"Game did not reach game:end."
		)

	snapshots.append(
		GoldenSnapshotSerializerData.snapshot_game(
			game,
			"game:end",
			rules
		)
	)

	var terminal_population_failure: String = _card_population_failure(game)

	if not terminal_population_failure.is_empty():
		return _fail(
			scenario_name,
			"Card conservation failure at game:end: %s"
			% terminal_population_failure
		)
	# Terminal summary comparison is deferred to checkpoint hashes.
	# This preserves the earliest round/state divergence as the failure.
	var expected_checkpoints_raw = (
		scenario.get(
			"checkpoints",
			[]
		)
	)

	if typeof(
		expected_checkpoints_raw
	) != TYPE_ARRAY:
		return _fail(
			scenario_name,
			"Expected checkpoints are not an Array."
		)

	var expected_checkpoints: Array = (
		expected_checkpoints_raw
	)

	if expected_checkpoints.size() != snapshots.size():
		# Compare the shared checkpoint prefix before reporting its length.
		var shared_count: int = min(
			expected_checkpoints.size(),
			snapshots.size()
		)

		for shared_index: int in range(
			shared_count
		):
			var shared_expected_raw = expected_checkpoints[
				shared_index
			]

			if typeof(shared_expected_raw) != TYPE_DICTIONARY:
				continue

			var shared_expected: Dictionary = shared_expected_raw
			var shared_actual: Dictionary = snapshots[
				shared_index
			]
			var shared_checkpoint: String = String(
				shared_actual.get(
					"checkpoint",
					""
				)
			)
			var shared_expected_checkpoint: String = String(
				shared_expected.get(
					"checkpoint",
					""
				)
			)

			if shared_expected_checkpoint != shared_checkpoint:
				var name_result: Dictionary = _fail(
					scenario_name,
					"Checkpoint name mismatch at index %d: want=%s got=%s"
					% [
						shared_index,
						shared_expected_checkpoint,
						shared_checkpoint,
					]
				)
				name_result["checkpoint"] = shared_checkpoint
				name_result["actual_snapshot"] = shared_actual
				return name_result

			var shared_expected_hash: String = String(
				shared_expected.get(
					"hash",
					""
				)
			)
			var shared_actual_hash: String = (
				GoldenMasterData.trace_hash([
					shared_actual,
				])
			)

			if shared_expected_hash != shared_actual_hash:
				var hash_result: Dictionary = _fail(
					scenario_name,
					"State hash divergence at %s: want=%s got=%s"
					% [
						shared_checkpoint,
						shared_expected_hash.left(16),
						shared_actual_hash.left(16),
					]
				)
				hash_result["checkpoint"] = shared_checkpoint
				hash_result["actual_snapshot"] = shared_actual
				return hash_result

		# Preserve the last actual snapshot when checkpoint counts differ.
		var count_result: Dictionary = _fail(
			scenario_name,
			"Checkpoint count mismatch: want=%d got=%d"
			% [
				expected_checkpoints.size(),
				snapshots.size(),
			]
		)

		if not snapshots.is_empty():
			var actual_terminal: Dictionary = snapshots[
				snapshots.size() - 1
			]

			count_result["checkpoint"] = String(
				actual_terminal.get(
					"checkpoint",
					""
				)
			)

			count_result["actual_snapshot"] = actual_terminal

		return count_result

	for index: int in range(
		snapshots.size()
	):
		var expected_entry_raw = (
			expected_checkpoints[
				index
			]
		)

		if typeof(
			expected_entry_raw
		) != TYPE_DICTIONARY:
			return _fail(
				scenario_name,
				"Expected checkpoint %d is not a Dictionary."
				% index
			)

		var expected_entry: Dictionary = (
			expected_entry_raw
		)

		var actual_snapshot: Dictionary = (
			snapshots[index]
		)

		var expected_checkpoint: String = String(
			expected_entry.get(
				"checkpoint",
				""
			)
		)

		var actual_checkpoint: String = String(
			actual_snapshot.get(
				"checkpoint",
				""
			)
		)

		if expected_checkpoint != actual_checkpoint:
			return _fail(
				scenario_name,
				"Checkpoint name mismatch at index %d: want=%s got=%s"
				% [
					index,
					expected_checkpoint,
					actual_checkpoint,
				]
			)

		var expected_hash: String = String(
			expected_entry.get(
				"hash",
				""
			)
		)

		var actual_hash: String = (
			GoldenMasterData.trace_hash([
				actual_snapshot,
			])
		)

		if expected_hash != actual_hash:
			var hash_failure: Dictionary = _fail(
				scenario_name,
				"State hash divergence at %s: want=%s got=%s"
				% [
					actual_checkpoint,
					expected_hash.left(
						16
					),
					actual_hash.left(
						16
					),
				]
			)

			hash_failure["checkpoint"] = actual_checkpoint
			hash_failure["actual_snapshot"] = actual_snapshot

			return hash_failure

	var expected_trace_hash: String = String(
		scenario.get(
			"trace_hash",
			""
		)
	)

	var actual_trace_hash: String = (
		GoldenMasterData.trace_hash(
			snapshots
		)
	)

	if expected_trace_hash != actual_trace_hash:
		return _fail(
			scenario_name,
			"Complete trace hash divergence: want=%s got=%s"
			% [
				expected_trace_hash.left(
					16
				),
				actual_trace_hash.left(
					16
				),
			]
		)

	return _pass(
		scenario_name
	)


static func _card_population_failure(game) -> String:
	var zones: Array = [
		{"name": "deck", "cards": game.deck},
		{"name": "discard", "cards": game.discard},
		{"name": "market", "cards": game.market},
	]

	for player in game.players:
		var player_id: int = int(player.pid)
		zones.append({
			"name": "p%d.hand" % player_id,
			"cards": player.hand,
		})
		zones.append({
			"name": "p%d.garrison" % player_id,
			"cards": player.garrison,
		})
		zones.append({
			"name": "p%d.castle_guards" % player_id,
			"cards": player.castle_guards,
		})
		zones.append({
			"name": "p%d.lord_guards" % player_id,
			"cards": player.lord_guards,
		})
		zones.append({
			"name": "p%d.committed" % player_id,
			"cards": player.committed,
		})

	var seen: Dictionary = {}
	var total: int = 0

	for zone_data in zones:
		var zone_name: String = String(zone_data.get("name", ""))
		var cards: Array = zone_data.get("cards", [])

		for card_index in range(cards.size()):
			var card = cards[card_index]
			total += 1

			if card == null:
				return "null card at %s[%d]" % [zone_name, card_index]

			var instance_id: int = int(card.get_instance_id())
			var location: String = "%s[%d]" % [zone_name, card_index]

			if seen.has(instance_id):
				return "duplicate physical card %s:%d#%d first=%s second=%s" % [
					String(card.suit),
					int(card.value),
					instance_id,
					String(seen[instance_id]),
					location,
				]

			seen[instance_id] = location

	if total != EXPECTED_CARD_POPULATION:
		return "card population mismatch: want=%d got=%d" % [
			EXPECTED_CARD_POPULATION,
			total,
		]

	return ""

static func _terminal_failure(
	scenario: Dictionary,
	game
) -> String:
	var expected_round: int = int(
		scenario.get(
			"round",
			-1
		)
	)

	if int(
		game.round
	) != expected_round:
		return (
			"Terminal round mismatch: want=%d got=%d"
			% [
				expected_round,
				int(
					game.round
				),
			]
		)

	var expected_winner: int = int(
		scenario.get(
			"winner",
			-1
		)
	)

	if int(
		game.winner
	) != expected_winner:
		return (
			"Winner mismatch: want=%d got=%d"
			% [
				expected_winner,
				int(
					game.winner
				),
			]
		)

	var expected_win_by: String = String(
		scenario.get(
			"win_by",
			""
		)
	)

	if String(
		game.win_by
	) != expected_win_by:
		return (
			"Win condition mismatch: want=%s got=%s"
			% [
				expected_win_by,
				String(
					game.win_by
				),
			]
		)

	var expected_first_player: int = int(
		scenario.get(
			"first_player",
			-1
		)
	)

	if int(
		game.first_player
	) != expected_first_player:
		return (
			"First-player mismatch: want=%d got=%d"
			% [
				expected_first_player,
				int(
					game.first_player
				),
			]
		)

	return ""


static func _load_matrix() -> Dictionary:
	if not FileAccess.file_exists(
		MATRIX_PATH
	):
		return {
			"_error": (
				"Missing Lord matrix: "
				+ MATRIX_PATH
				+ ". Run py -3 lord_matrix_master.py first."
			),
		}

	var text: String = (
		FileAccess.get_file_as_string(
			MATRIX_PATH
		)
	)

	var parsed = JSON.parse_string(
		text
	)

	if (
		parsed == null
		or typeof(
			parsed
		) != TYPE_DICTIONARY
	):
		return {
			"_error": (
				"Unable to parse Lord matrix: "
				+ MATRIX_PATH
			),
		}

	return parsed


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
