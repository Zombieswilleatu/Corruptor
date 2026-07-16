class_name SeededGameSetupTests
extends RefCounted


const SeededGameSetupData = preload(
	"res://Scripts/Sim/SeededGameSetup.gd"
)

const SnapshotSerializerData = preload(
	"res://Scripts/Sim/GoldenSnapshotSerializer.gd"
)

const GoldenMasterData = preload(
	"res://Scripts/Sim/GoldenMaster.gd"
)


const AI_POLICY: String = (
	"softmax-2026.07-v1-golden"
)

const RNG_STREAM_PATH: String = (
	"res://golden/rng_stream.json"
)

const SETUP_TEST_NAME: String = (
	"game_seeded_deimos_valak_s1 game:deal"
)

const CONTINUATION_TEST_NAME: String = (
	"unit_seeded_setup_rng_continuation"
)


static func run(
	rules: RuleConfig
) -> Array:
	return [
		_test_seeded_setup(
			rules
		),
		_test_rng_continuation(
			rules
		),
	]


static func _test_seeded_setup(
	rules: RuleConfig
) -> Dictionary:
	var trace: Dictionary = (
		GoldenMasterData.load_trace(
			"game_deimos_valak_s1"
		)
	)

	if trace.has(
		"_error"
	):
		return _fail(
			SETUP_TEST_NAME,
			String(
				trace["_error"]
			)
		)

	var golden_snapshot = _find_snapshot(
		trace.get(
			"snapshots",
			[]
		),
		"game:deal"
	)

	if golden_snapshot == null:
		return _fail(
			SETUP_TEST_NAME,
			"Golden trace has no game:deal snapshot."
		)

	var session: Dictionary = (
		SeededGameSetupData
		.setup_deimos_valak_seed_one(
			rules
		)
	)

	var game = session.get(
		"game"
	)

	if game == null:
		return _fail(
			SETUP_TEST_NAME,
			"Seeded setup returned no GameState."
		)

	var engine_snapshot: Dictionary = (
		SnapshotSerializerData.snapshot_game(
			game,
			"game:deal"
		)
	)

	var deal_trace: Dictionary = (
		trace.duplicate(
			true
		)
	)

	deal_trace["name"] = SETUP_TEST_NAME

	deal_trace["snapshots"] = [
		golden_snapshot,
	]

	deal_trace["trace_hash"] = ""

	var validation_result = (
		GoldenMasterData.validate(
			deal_trace,
			[
				engine_snapshot,
			],
			rules,
			AI_POLICY
		)
	)

	if not validation_result.passed:
		return _fail(
			SETUP_TEST_NAME,
			String(
				validation_result.reason
			)
		)

	return _pass(
		SETUP_TEST_NAME
	)


static func _test_rng_continuation(
	rules: RuleConfig
) -> Dictionary:
	var fixture_result: Dictionary = (
		_load_rng_fixture()
	)

	if fixture_result.has(
		"error"
	):
		return _fail(
			CONTINUATION_TEST_NAME,
			String(
				fixture_result["error"]
			)
		)

	var fixture: Dictionary = fixture_result[
		"fixture"
	]

	var post_setup = fixture.get(
		"post_setup",
		{}
	)

	if typeof(
		post_setup
	) != TYPE_DICTIONARY:
		return _fail(
			CONTINUATION_TEST_NAME,
			"Fixture field 'post_setup' is not a Dictionary."
		)

	var post_setup_data: Dictionary = post_setup

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
			CONTINUATION_TEST_NAME,
			"Seeded setup returned no GameState."
		)

	if random_source == null:
		return _fail(
			CONTINUATION_TEST_NAME,
			"Seeded setup returned no RNG state."
		)

	var expected_first_player: int = int(
		post_setup_data.get(
			"first_player",
			-1
		)
	)

	if int(
		game.first_player
	) != expected_first_player:
		return _fail(
			CONTINUATION_TEST_NAME,
			"Expected first player %d, received %d."
			% [
				expected_first_player,
				int(
					game.first_player
				),
			]
		)

	var expected_random = post_setup_data.get(
		"random",
		[]
	)

	if typeof(
		expected_random
	) != TYPE_ARRAY:
		return _fail(
			CONTINUATION_TEST_NAME,
			"Fixture post_setup.random field is not an Array."
		)

	var expected_random_values: Array = expected_random

	for index: int in range(
		expected_random_values.size()
	):
		var expected_value: float = float(
			expected_random_values[index]
		)

		var actual_value: float = (
			random_source.random_float()
		)

		if actual_value != expected_value:
			return _fail(
				CONTINUATION_TEST_NAME,
				"Post-setup random[%d] mismatch: expected %.20e, received %.20e."
				% [
					index,
					expected_value,
					actual_value,
				]
			)

	var expected_randint: int = int(
		post_setup_data.get(
			"randint_0_1_after_random",
			-1
		)
	)

	var actual_randint: int = (
		random_source.randint(
			0,
			1
		)
	)

	if actual_randint != expected_randint:
		return _fail(
			CONTINUATION_TEST_NAME,
			"Post-setup randint mismatch: expected %d, received %d."
			% [
				expected_randint,
				actual_randint,
			]
		)

	return _pass(
		CONTINUATION_TEST_NAME
	)


static func _load_rng_fixture() -> Dictionary:
	if not FileAccess.file_exists(
		RNG_STREAM_PATH
	):
		return {
			"error": (
				"Missing RNG fixture: %s"
				% RNG_STREAM_PATH
			),
		}

	var fixture_text: String = (
		FileAccess.get_file_as_string(
			RNG_STREAM_PATH
		)
	)

	var parsed_fixture = JSON.parse_string(
		fixture_text
	)

	if typeof(
		parsed_fixture
	) != TYPE_DICTIONARY:
		return {
			"error": (
				"Unable to parse RNG fixture: %s"
				% RNG_STREAM_PATH
			),
		}

	return {
		"fixture": parsed_fixture,
	}


static func _find_snapshot(
	snapshots,
	checkpoint: String
):
	if typeof(
		snapshots
	) != TYPE_ARRAY:
		return null

	for snapshot in snapshots:
		if typeof(
			snapshot
		) != TYPE_DICTIONARY:
			continue

		if String(
			snapshot.get(
				"checkpoint",
				""
			)
		) == checkpoint:
			return snapshot

	return null


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
