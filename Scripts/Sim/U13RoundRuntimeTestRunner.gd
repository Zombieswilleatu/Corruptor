extends SceneTree

const U13RoundRuntimeData = preload(
	"res://Scripts/Sim/U13RoundRuntime.gd"
)
const U13RoundTimelineData = preload(
	"res://Scripts/Sim/U13RoundTimeline.gd"
)

var failures: int = 0


func _init() -> void:
	_test_requires_begin_round()
	_test_rejects_out_of_order_hook()
	_test_full_order()
	_test_snapshot_restore()

	print("U13 round runtime failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _test_requires_begin_round() -> void:
	var runtime = U13RoundRuntimeData.new()
	var result: Dictionary = runtime.run_hook(
		U13RoundTimelineData.ROUND_START_SCHEDULED
	)
	if String(result.get("reason", "")) != "round_not_started":
		_fail("requires_begin_round", str(result))
		return
	_pass("requires_begin_round")


func _test_rejects_out_of_order_hook() -> void:
	var runtime = U13RoundRuntimeData.new()
	runtime.begin_round(3)
	var result: Dictionary = runtime.run_hook(
		U13RoundTimelineData.DEVELOPMENT
	)
	if (
		String(result.get("reason", "")) != "hook_out_of_order"
		or String(result.get("expected_hook", ""))
			!= U13RoundTimelineData.ROUND_START_SCHEDULED
	):
		_fail("rejects_out_of_order", str(result))
		return
	_pass("rejects_out_of_order")


func _test_full_order() -> void:
	var runtime = U13RoundRuntimeData.new()
	var begin_result: Dictionary = runtime.begin_round(4)
	if String(begin_result.get("next_hook", "")) != U13RoundTimelineData.ROUND_START_SCHEDULED:
		_fail("full_order", str(begin_result))
		return

	for hook: String in U13RoundTimelineData.EXECUTION_HOOKS:
		var result: Dictionary = runtime.run_hook(hook)
		if String(result.get("action", "")) != "u13_hook":
			_fail("full_order", "%s -> %s" % [hook, str(result)])
			return

	if not runtime.completed:
		_fail("full_order", "runtime did not complete after final hook")
		return
	if not runtime.next_hook().is_empty():
		_fail("full_order", "completed runtime still exposes a next hook")
		return
	if runtime.execution_log.size() != U13RoundTimelineData.EXECUTION_HOOKS.size():
		_fail("full_order", "execution log size mismatch")
		return

	_pass("full_order")


func _test_snapshot_restore() -> void:
	var original = U13RoundRuntimeData.new()
	original.begin_round(7)

	var stop_before: String = U13RoundTimelineData.SUBMISSION_LOCK
	while original.next_hook() != stop_before:
		var hook: String = original.next_hook()
		var result: Dictionary = original.run_hook(hook)
		if String(result.get("action", "")) != "u13_hook":
			_fail("snapshot_restore", str(result))
			return

	var saved: Dictionary = original.snapshot()
	var restored = U13RoundRuntimeData.new()
	var restore_result: Dictionary = restored.restore(saved)
	if String(restore_result.get("action", "")) != "u13_round_restore":
		_fail("snapshot_restore", str(restore_result))
		return
	if restored.next_hook() != stop_before:
		_fail(
			"snapshot_restore",
			"expected %s after restore, got %s"
			% [stop_before, restored.next_hook()]
		)
		return
	if restored.execution_log != original.execution_log:
		_fail("snapshot_restore", "execution log changed across restore")
		return

	_pass("snapshot_restore")


func _pass(name: String) -> void:
	print("PASS  %s" % name)


func _fail(name: String, reason: String) -> void:
	failures += 1
	print("FAIL  %s: %s" % [name, reason])
