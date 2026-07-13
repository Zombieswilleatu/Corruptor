class_name GoldenTests
extends RefCounted

const AI_POLICY := "heuristic-2025.06-doctrine"


static func run_startup_checks(rules: RuleConfig) -> Array:
	var messages: Array = []

	messages.append(_check_manifest())
	messages.append_array(run_unit_tests(rules))

	return messages


static func run_unit_tests(rules: RuleConfig) -> Array:
	var messages: Array = []

	var combat_trace_names: Array[String] = [
		"unit_combat_breakthrough",
		"unit_combat_golden_rule",
		"unit_sigil_break_survive",
		"unit_siege_engine_bypass"
	]

	for trace_name: String in combat_trace_names:
		messages.append(_test_combat_trace(trace_name, rules))

	messages.append(_test_humbaba_defense_curve(rules))
	messages.append(_test_humbaba_seal(rules))

	return messages


static func _check_manifest() -> Dictionary:
	var manifest: Dictionary = GoldenMaster.load_trace("_manifest")

	if manifest.has("_error"):
		return _fail("Golden manifest failed: %s" % manifest["_error"])

	var traces: Dictionary = manifest.get("traces", {})
	return _pass("Golden manifest loaded: %d traces." % traces.size())


static func _test_combat_trace(trace_name: String, rules: RuleConfig) -> Dictionary:
	var trace: Dictionary = GoldenMaster.load_trace(trace_name)

	if trace.has("_error"):
		return _fail("%s failed to load: %s" % [trace_name, trace["_error"]])

	var golden_snapshots: Array = trace.get("snapshots", [])

	if golden_snapshots.is_empty():
		return _fail("%s has no snapshots." % trace_name)

	# Unit combat traces validate the pure combat math only.
	# Setup/deck/player-state correctness is covered later by GAME traces.
	var final_golden_snapshot: Dictionary = golden_snapshots[golden_snapshots.size() - 1]
	var inputs: Dictionary = final_golden_snapshot.get("inputs", {})

	var strength := int(inputs.get("strength", 0))
	var struct_def := int(inputs.get("struct_def", 0))
	var sigil_value := int(inputs.get("sigil_value", 0))
	var guards_in: Array = inputs.get("guards_in", [])

	var ignore_lowest := bool(inputs.get("ignore_lowest", false))
	var has_sigil := bool(inputs.get("has_sigil", false))
	var bypass := bool(inputs.get("bypass", false))

	var combat_result: Dictionary = CombatResolver.combat_layers(
		null,
		strength,
		guards_in,
		ignore_lowest,
		sigil_value,
		has_sigil,
		struct_def,
		bypass
	)

	var after_snapshot := {
		"checkpoint": final_golden_snapshot.get("checkpoint", "unit:after"),
		"op": final_golden_snapshot.get("op", "combat_layers"),
		"inputs": inputs,
		"result": {
			"destroyed": combat_result["destroyed"],
			"sigil_broken": combat_result["sigil_broken"],
			"excess": combat_result["excess"],
			"guards_out": combat_result["guards_out"]
		}
	}

	var engine_snapshots: Array = []

	for i in range(golden_snapshots.size() - 1):
		engine_snapshots.append(golden_snapshots[i])

	engine_snapshots.append(after_snapshot)

	return _validate_trace(trace, engine_snapshots, rules)


static func _test_humbaba_defense_curve(rules: RuleConfig) -> Dictionary:
	var trace_name := "unit_humbaba_defense_curve"
	var trace: Dictionary = GoldenMaster.load_trace(trace_name)

	if trace.has("_error"):
		return _fail("%s failed to load: %s" % [trace_name, trace["_error"]])

	var golden_snapshots: Array = trace.get("snapshots", [])

	if golden_snapshots.is_empty():
		return _fail("%s has no snapshots." % trace_name)

	var final_golden_snapshot: Dictionary = golden_snapshots[golden_snapshots.size() - 1]
	var golden_rows: Array = final_golden_snapshot.get("rows", [])

	var engine_rows: Array = []

	for row in golden_rows:
		var row_dict: Dictionary = row
		var castles: Array = row_dict.get("castles", [])
		var threat := int(row_dict.get("threat", 0))

		engine_rows.append({
			"castles": castles,
			"threat": threat,
			"def": LordMath.lord_base_def("Humbaba", castles, threat, rules)
		})

	var after_snapshot := {
		"checkpoint": final_golden_snapshot.get("checkpoint", "unit:after"),
		"op": final_golden_snapshot.get("op", "lord_base_def"),
		"rows": engine_rows
	}

	var engine_snapshots := [
		after_snapshot
	]

	return _validate_trace(trace, engine_snapshots, rules)


static func _test_humbaba_seal(rules: RuleConfig) -> Dictionary:
	var trace_name := "unit_humbaba_seal"
	var trace: Dictionary = GoldenMaster.load_trace(trace_name)

	if trace.has("_error"):
		return _fail("%s failed to load: %s" % [trace_name, trace["_error"]])

	var golden_snapshots: Array = trace.get("snapshots", [])

	if golden_snapshots.is_empty():
		return _fail("%s has no snapshots." % trace_name)

	var final_golden_snapshot: Dictionary = golden_snapshots[golden_snapshots.size() - 1]

	var standing := LordMath.dominion_requirement([
		{
			"lord": "Humbaba",
			"alive": true
		},
		{
			"lord": "Valak",
			"alive": true
		}
	], rules)

	var banished := LordMath.dominion_requirement([
		{
			"lord": "Humbaba",
			"alive": false
		},
		{
			"lord": "Valak",
			"alive": true
		}
	], rules)

	var after_snapshot := {
		"checkpoint": final_golden_snapshot.get("checkpoint", "unit:after"),
		"op": final_golden_snapshot.get("op", "dominion_req"),
		"result": {
			"standing": standing,
			"banished": banished,
			"base": rules.dominion_requirement
		}
	}

	var engine_snapshots := [
		after_snapshot
	]

	return _validate_trace(trace, engine_snapshots, rules)


static func _validate_trace(trace: Dictionary, engine_snapshots: Array, rules: RuleConfig) -> Dictionary:
	var result = GoldenMaster.validate(
		trace,
		engine_snapshots,
		rules,
		AI_POLICY
	)

	if result.passed:
		return _pass(str(result))

	return _fail(str(result))


static func _pass(text: String) -> Dictionary:
	return {
		"passed": true,
		"text": text
	}


static func _fail(text: String) -> Dictionary:
	return {
		"passed": false,
		"text": text
	}
