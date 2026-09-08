extends SceneTree

const U13RoundTimelineData = preload(
	"res://Scripts/Sim/U13RoundTimeline.gd"
)

var failures: int = 0


func _init() -> void:
	_test_contract_shape()
	_test_post_resolution_order()
	_test_top_level_mapping()

	print("U13 round timeline failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _test_contract_shape() -> void:
	var result: Dictionary = U13RoundTimelineData.validate_contract()
	if not bool(result.get("valid", false)):
		_fail("contract_shape", str(result.get("errors", [])))
		return
	if U13RoundTimelineData.TOP_LEVEL_STEPS.size() != 14:
		_fail("contract_shape", "top-level step count changed")
		return
	if U13RoundTimelineData.EXECUTION_HOOKS.size() != 20:
		_fail("contract_shape", "expanded execution hook count changed")
		return
	_pass("contract_shape")


func _test_post_resolution_order() -> void:
	var expected: Array[String] = [
		U13RoundTimelineData.POST_RESOLUTION_SPAWNS,
		U13RoundTimelineData.POST_RESOLUTION_POSITION,
		U13RoundTimelineData.POST_RESOLUTION_ALLEGIANCE,
		U13RoundTimelineData.POST_RESOLUTION_MOVEMENT_STATE,
		U13RoundTimelineData.POST_RESOLUTION_HAZARDS,
		U13RoundTimelineData.POST_RESOLUTION_DIRECT,
		U13RoundTimelineData.POST_RESOLUTION_SPECIAL_ACTORS,
	]
	if U13RoundTimelineData.POST_RESOLUTION_HOOKS != expected:
		_fail(
			"post_resolution_order",
			"10A-10G order differs from canonical contract"
		)
		return
	_pass("post_resolution_order")


func _test_top_level_mapping() -> void:
	for hook: String in U13RoundTimelineData.POST_RESOLUTION_HOOKS:
		if U13RoundTimelineData.top_level_step_number(hook) != 10:
			_fail("top_level_mapping", "%s did not map to Step 10" % hook)
			return

	var expected_steps: Dictionary = {
		U13RoundTimelineData.ROUND_START_SCHEDULED: 1,
		U13RoundTimelineData.PERSISTENT_ADVANCEMENT: 2,
		U13RoundTimelineData.ROUND_START_AUTOMATIC: 3,
		U13RoundTimelineData.PRESENT_PUBLIC_STATE: 4,
		U13RoundTimelineData.SUBMISSION_LOCK: 5,
		U13RoundTimelineData.DEVELOPMENT: 6,
		U13RoundTimelineData.POST_REPAIR_ARTILLERY: 7,
		U13RoundTimelineData.COMMITMENT_REVEAL: 8,
		U13RoundTimelineData.COMBAT_RESOLUTION: 9,
		U13RoundTimelineData.MARCHING_START: 11,
		U13RoundTimelineData.MARCHING: 12,
		U13RoundTimelineData.END_MARCHING_CHECKS: 13,
		U13RoundTimelineData.AFTERMATH: 14,
	}

	for hook: String in expected_steps:
		var actual: int = U13RoundTimelineData.top_level_step_number(hook)
		if actual != int(expected_steps[hook]):
			_fail(
				"top_level_mapping",
				"%s expected Step %d, got %d"
				% [hook, int(expected_steps[hook]), actual]
			)
			return

	_pass("top_level_mapping")


func _pass(name: String) -> void:
	print("PASS  %s" % name)


func _fail(name: String, reason: String) -> void:
	failures += 1
	print("FAIL  %s: %s" % [name, reason])
