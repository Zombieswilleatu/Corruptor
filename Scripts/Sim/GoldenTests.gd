class_name GoldenTests
extends RefCounted


const AI_POLICY := "heuristic-2025.06-doctrine"

const SnapshotSerializer = preload(
	"res://Scripts/Sim/GoldenSnapshotSerializer.gd"
)

const GameDealFixtureData = preload(
	"res://Scripts/Sim/GameDealFixture.gd"
)

const RoundTransitionTestsData = preload(
	"res://Scripts/Sim/RoundTransitionTests.gd"
)

const DominionRiteTestsData = preload(
	"res://Scripts/Sim/DominionRiteTests.gd"
)

const DeployTestsData = preload(
	"res://Scripts/Sim/DeployTests.gd"
)

const SummonTestsData = preload(
	"res://Scripts/Sim/SummonTests.gd"
)

const ReflexBidTestsData = preload(
	"res://Scripts/Sim/ReflexBidTests.gd"
)

const CommitmentTestsData = preload(
	"res://Scripts/Sim/CommitmentTests.gd"
)

const RevealTestsData = preload(
	"res://Scripts/Sim/RevealTests.gd"
)

const ResolutionPreludeTestsData = preload(
	"res://Scripts/Sim/ResolutionPreludeTests.gd"
)

const HuntResolutionTestsData = preload(
	"res://Scripts/Sim/HuntResolutionTests.gd"
)


static func run_startup_checks(
	rules: RuleConfig
) -> Array:
	var messages: Array = []

	messages.append(
		_check_manifest()
	)

	messages.append_array(
		run_unit_tests(
			rules
		)
	)

	messages.append_array(
		run_game_deal_tests(
			rules
		)
	)

	messages.append_array(
		RoundTransitionTestsData.run(
			rules
		)
	)

	messages.append_array(
		DominionRiteTestsData.run(
			rules
		)
	)

	messages.append_array(
		DeployTestsData.run(
			rules
		)
	)

	messages.append_array(
		SummonTestsData.run(
			rules
		)
	)

	messages.append_array(
		ReflexBidTestsData.run(
			rules
		)
	)

	messages.append_array(
		CommitmentTestsData.run(
			rules
		)
	)

	messages.append_array(
		RevealTestsData.run(
			rules
		)
	)

	messages.append_array(
		ResolutionPreludeTestsData.run(
			rules
		)
	)

	messages.append_array(
		HuntResolutionTestsData.run(
			rules
		)
	)

	return messages


static func run_unit_tests(
	rules: RuleConfig
) -> Array:
	var messages: Array = []

	var combat_trace_names: Array[String] = [
		"unit_combat_breakthrough",
		"unit_combat_golden_rule",
		"unit_sigil_break_survive",
		"unit_siege_engine_bypass"
	]

	for trace_name: String in combat_trace_names:
		messages.append(
			_test_combat_trace(
				trace_name,
				rules
			)
		)

	messages.append(
		_test_humbaba_defense_curve(
			rules
		)
	)

	messages.append(
		_test_humbaba_seal(
			rules
		)
	)

	return messages


static func run_game_deal_tests(
	rules: RuleConfig
) -> Array:
	var messages: Array = []

	var result: Dictionary = (
		_test_game_deal_trace(
			"game_deimos_valak_s1",
			rules
		)
	)

	messages.append(
		result
	)

	return messages


static func _check_manifest() -> Dictionary:
	var manifest: Dictionary = (
		GoldenMaster.load_trace(
			"_manifest"
		)
	)

	if manifest.has("_error"):
		return _fail(
			"Golden manifest failed: %s"
			% manifest["_error"]
		)

	var traces: Dictionary = manifest.get(
		"traces",
		{}
	)

	return _pass(
		"Golden manifest loaded: %d traces."
		% traces.size()
	)


static func _test_combat_trace(
	trace_name: String,
	rules: RuleConfig
) -> Dictionary:
	var trace: Dictionary = (
		GoldenMaster.load_trace(
			trace_name
		)
	)

	if trace.has("_error"):
		return _fail(
			"%s failed to load: %s"
			% [
				trace_name,
				trace["_error"]
			]
		)

	var golden_snapshots: Array = trace.get(
		"snapshots",
		[]
	)

	if golden_snapshots.is_empty():
		return _fail(
			"%s has no snapshots."
			% trace_name
		)

	var final_golden_snapshot: Dictionary = (
		golden_snapshots[
			golden_snapshots.size() - 1
		]
	)

	var inputs: Dictionary = (
		final_golden_snapshot.get(
			"inputs",
			{}
		)
	)

	var strength := int(
		inputs.get(
			"strength",
			0
		)
	)

	var struct_def := int(
		inputs.get(
			"struct_def",
			0
		)
	)

	var sigil_value := int(
		inputs.get(
			"sigil_value",
			0
		)
	)

	var guards_in: Array = inputs.get(
		"guards_in",
		[]
	)

	var ignore_lowest := bool(
		inputs.get(
			"ignore_lowest",
			false
		)
	)

	var has_sigil := bool(
		inputs.get(
			"has_sigil",
			false
		)
	)

	var bypass := bool(
		inputs.get(
			"bypass",
			false
		)
	)

	var combat_result: Dictionary = (
		CombatResolver.combat_layers(
			null,
			strength,
			guards_in,
			ignore_lowest,
			sigil_value,
			has_sigil,
			struct_def,
			bypass
		)
	)

	var after_snapshot: Dictionary = {
		"checkpoint": final_golden_snapshot.get(
			"checkpoint",
			"unit:after"
		),
		"op": final_golden_snapshot.get(
			"op",
			"combat_layers"
		),
		"inputs": inputs,
		"result": {
			"destroyed": combat_result[
				"destroyed"
			],
			"sigil_broken": combat_result[
				"sigil_broken"
			],
			"excess": combat_result[
				"excess"
			],
			"guards_out": combat_result[
				"guards_out"
			]
		}
	}

	var engine_snapshots: Array = []

	for index in range(
		golden_snapshots.size() - 1
	):
		engine_snapshots.append(
			golden_snapshots[index]
		)

	engine_snapshots.append(
		after_snapshot
	)

	return _validate_trace(
		trace,
		engine_snapshots,
		rules
	)


static func _test_humbaba_defense_curve(
	rules: RuleConfig
) -> Dictionary:
	var trace_name := (
		"unit_humbaba_defense_curve"
	)

	var trace: Dictionary = (
		GoldenMaster.load_trace(
			trace_name
		)
	)

	if trace.has("_error"):
		return _fail(
			"%s failed to load: %s"
			% [
				trace_name,
				trace["_error"]
			]
		)

	var golden_snapshots: Array = trace.get(
		"snapshots",
		[]
	)

	if golden_snapshots.is_empty():
		return _fail(
			"%s has no snapshots."
			% trace_name
		)

	var final_golden_snapshot: Dictionary = (
		golden_snapshots[
			golden_snapshots.size() - 1
		]
	)

	var golden_rows: Array = (
		final_golden_snapshot.get(
			"rows",
			[]
		)
	)

	var engine_rows: Array = []

	for row in golden_rows:
		var row_dict: Dictionary = row

		var castles: Array = row_dict.get(
			"castles",
			[]
		)

		var threat := int(
			row_dict.get(
				"threat",
				0
			)
		)

		engine_rows.append({
			"castles": castles,
			"threat": threat,
			"def": LordMath.lord_base_def(
				"Humbaba",
				castles,
				threat,
				rules
			)
		})

	var after_snapshot: Dictionary = {
		"checkpoint": final_golden_snapshot.get(
			"checkpoint",
			"unit:after"
		),
		"op": final_golden_snapshot.get(
			"op",
			"lord_base_def"
		),
		"rows": engine_rows
	}

	var engine_snapshots: Array = [
		after_snapshot
	]

	return _validate_trace(
		trace,
		engine_snapshots,
		rules
	)


static func _test_humbaba_seal(
	rules: RuleConfig
) -> Dictionary:
	var trace_name := "unit_humbaba_seal"

	var trace: Dictionary = (
		GoldenMaster.load_trace(
			trace_name
		)
	)

	if trace.has("_error"):
		return _fail(
			"%s failed to load: %s"
			% [
				trace_name,
				trace["_error"]
			]
		)

	var golden_snapshots: Array = trace.get(
		"snapshots",
		[]
	)

	if golden_snapshots.is_empty():
		return _fail(
			"%s has no snapshots."
			% trace_name
		)

	var final_golden_snapshot: Dictionary = (
		golden_snapshots[
			golden_snapshots.size() - 1
		]
	)

	var standing := (
		LordMath.dominion_requirement(
			[
				{
					"lord": "Humbaba",
					"alive": true
				},
				{
					"lord": "Valak",
					"alive": true
				}
			],
			rules
		)
	)

	var banished := (
		LordMath.dominion_requirement(
			[
				{
					"lord": "Humbaba",
					"alive": false
				},
				{
					"lord": "Valak",
					"alive": true
				}
			],
			rules
		)
	)

	var after_snapshot: Dictionary = {
		"checkpoint": final_golden_snapshot.get(
			"checkpoint",
			"unit:after"
		),
		"op": final_golden_snapshot.get(
			"op",
			"dominion_req"
		),
		"result": {
			"standing": standing,
			"banished": banished,
			"base": rules.dominion_requirement
		}
	}

	var engine_snapshots: Array = [
		after_snapshot
	]

	return _validate_trace(
		trace,
		engine_snapshots,
		rules
	)


static func _test_game_deal_trace(
	trace_name: String,
	rules: RuleConfig
) -> Dictionary:
	var full_trace: Dictionary = (
		GoldenMaster.load_trace(
			trace_name
		)
	)

	if full_trace.has("_error"):
		return _fail(
			"%s failed to load: %s"
			% [
				trace_name,
				full_trace["_error"]
			]
		)

	var golden_snapshots: Array = (
		full_trace.get(
			"snapshots",
			[]
		)
	)

	var golden_deal_snapshot = (
		_find_snapshot_by_checkpoint(
			golden_snapshots,
			"game:deal"
		)
	)

	if golden_deal_snapshot == null:
		return _fail(
			"%s has no game:deal snapshot."
			% trace_name
		)

	var game_state = (
		GameDealFixtureData
		.build_game_deimos_valak_s1(
			rules
		)
	)

	var engine_deal_snapshot: Dictionary = (
		SnapshotSerializer.snapshot_game(
			game_state,
			"game:deal"
		)
	)

	var deal_trace: Dictionary = (
		full_trace.duplicate(
			true
		)
	)

	deal_trace["name"] = (
		"%s game:deal"
		% trace_name
	)

	deal_trace["snapshots"] = [
		golden_deal_snapshot
	]

	deal_trace["trace_hash"] = ""

	var validation_result: Dictionary = (
		_validate_trace(
			deal_trace,
			[
				engine_deal_snapshot
			],
			rules
		)
	)

	return validation_result


static func _find_snapshot_by_checkpoint(
	snapshots: Array,
	checkpoint: String
):
	for snapshot in snapshots:
		if typeof(snapshot) != TYPE_DICTIONARY:
			continue

		var snapshot_dict: Dictionary = snapshot

		if str(
			snapshot_dict.get(
				"checkpoint",
				""
			)
		) == checkpoint:
			return snapshot_dict

	return null


static func _validate_trace(
	trace: Dictionary,
	engine_snapshots: Array,
	rules: RuleConfig
) -> Dictionary:
	var result = GoldenMaster.validate(
		trace,
		engine_snapshots,
		rules,
		AI_POLICY
	)

	if result.passed:
		return _pass(
			str(result)
		)

	return _fail(
		str(result)
	)


static func _pass(
	text: String
) -> Dictionary:
	return {
		"passed": true,
		"text": text
	}


static func _fail(
	text: String
) -> Dictionary:
	return {
		"passed": false,
		"text": text
	}
