class_name U13RoundRuntime
extends RefCounted

const U13RoundTimelineData = preload(
	"res://Scripts/Sim/U13RoundTimeline.gd"
)

# U13_ROUND_RUNTIME_V1
#
# Minimal authoritative cursor for the U13 timing contract.
#
# This is intentionally NOT a replacement for PlayableRoundController yet.
# U12 remains untouched. U13 callers advance this runtime one named hook at a
# time; the runtime guarantees monotonic order and produces a small execution
# record that tests/replay can inspect.

var round_number: int = 0
var next_hook_index: int = 0
var completed: bool = false
var execution_log: Array[Dictionary] = []


func begin_round(new_round_number: int) -> Dictionary:
	if new_round_number < 1:
		return _invalid("round_number_invalid", "")

	round_number = new_round_number
	next_hook_index = 0
	completed = false
	execution_log.clear()

	return {
		"action": "u13_round_begin",
		"round": round_number,
		"next_hook": next_hook(),
	}


func next_hook() -> String:
	if completed:
		return ""
	if next_hook_index < 0 or next_hook_index >= U13RoundTimelineData.EXECUTION_HOOKS.size():
		return ""
	return String(U13RoundTimelineData.EXECUTION_HOOKS[next_hook_index])


func can_run(hook: String) -> bool:
	return (
		round_number >= 1
		and not completed
		and U13RoundTimelineData.is_valid_hook(hook)
		and hook == next_hook()
	)


func run_hook(
	hook: String,
	handler: Callable = Callable(),
	context: Dictionary = {}
) -> Dictionary:
	if round_number < 1:
		return _invalid("round_not_started", hook)

	if completed:
		return _invalid("round_already_completed", hook)

	if not U13RoundTimelineData.is_valid_hook(hook):
		return _invalid("unknown_hook", hook)

	var expected: String = next_hook()
	if hook != expected:
		return {
			"action": "invalid",
			"reason": "hook_out_of_order",
			"round": round_number,
			"hook": hook,
			"expected_hook": expected,
			"next_hook": expected,
		}

	var payload: Dictionary = {}
	if handler.is_valid():
		var raw_result = handler.call(context)
		if typeof(raw_result) != TYPE_DICTIONARY:
			return {
				"action": "invalid",
				"reason": "handler_result_not_dictionary",
				"round": round_number,
				"hook": hook,
				"expected_hook": expected,
				"next_hook": expected,
			}
		payload = raw_result
		# A rules/dispatch error must not silently consume the timeline hook.
		# Handlers own their game-state transaction; this only preserves cursor
		# position. Retrying a partially completed pending batch is safe because
		# its manager has already removed each successfully resolved effect.
		if payload.get("action", "") == "invalid":
			var rejected: Dictionary = _invalid("handler_rejected_hook", hook)
			rejected["result"] = payload.duplicate(true)
			return rejected

	var row: Dictionary = {
		"round": round_number,
		"hook": hook,
		"hook_rank": U13RoundTimelineData.hook_rank(hook),
		"top_level_step": U13RoundTimelineData.top_level_step_number(hook),
		"result": payload.duplicate(true),
	}
	execution_log.append(row)

	next_hook_index += 1
	if next_hook_index >= U13RoundTimelineData.EXECUTION_HOOKS.size():
		completed = true

	return {
		"action": "u13_hook",
		"reason": "",
		"round": round_number,
		"hook": hook,
		"top_level_step": int(row.get("top_level_step", -1)),
		"result": payload,
		"completed": completed,
		"next_hook": next_hook(),
	}


func snapshot() -> Dictionary:
	return {
		"round": round_number,
		"next_hook_index": next_hook_index,
		"next_hook": next_hook(),
		"completed": completed,
		"execution_log": execution_log.duplicate(true),
		"timeline_version": U13RoundTimelineData.CONTRACT_VERSION,
	}


func restore(snapshot_data: Dictionary) -> Dictionary:
	var restored_round: int = int(snapshot_data.get("round", 0))
	var restored_index: int = int(snapshot_data.get("next_hook_index", -1))
	var restored_completed: bool = bool(snapshot_data.get("completed", false))
	var restored_version: String = String(
		snapshot_data.get("timeline_version", "")
	)
	var raw_log = snapshot_data.get("execution_log", [])

	if restored_version != U13RoundTimelineData.CONTRACT_VERSION:
		return _invalid("timeline_version_mismatch", "")
	if restored_round < 1:
		return _invalid("snapshot_round_invalid", "")
	if restored_index < 0 or restored_index > U13RoundTimelineData.EXECUTION_HOOKS.size():
		return _invalid("snapshot_hook_index_invalid", "")
	if restored_completed != (restored_index == U13RoundTimelineData.EXECUTION_HOOKS.size()):
		return _invalid("snapshot_completion_mismatch", "")
	if typeof(raw_log) != TYPE_ARRAY:
		return _invalid("snapshot_log_not_array", "")
	if raw_log.size() != restored_index:
		return _invalid("snapshot_log_size_mismatch", "")

	for index: int in range(raw_log.size()):
		var raw_row = raw_log[index]
		if typeof(raw_row) != TYPE_DICTIONARY:
			return _invalid("snapshot_log_row_not_dictionary", "")
		var row: Dictionary = raw_row
		var expected_hook: String = String(
			U13RoundTimelineData.EXECUTION_HOOKS[index]
		)
		if String(row.get("hook", "")) != expected_hook:
			return _invalid("snapshot_log_order_invalid", expected_hook)

	round_number = restored_round
	next_hook_index = restored_index
	completed = restored_completed
	execution_log.clear()
	for raw_row in raw_log:
		var row: Dictionary = raw_row
		execution_log.append(row.duplicate(true))

	return {
		"action": "u13_round_restore",
		"reason": "",
		"round": round_number,
		"completed": completed,
		"next_hook": next_hook(),
	}


func _invalid(reason: String, hook: String) -> Dictionary:
	return {
		"action": "invalid",
		"reason": reason,
		"round": round_number,
		"hook": hook,
		"expected_hook": next_hook(),
		"next_hook": next_hook(),
	}


# Internal copy of already-owned state; external data must still use restore().
func _fork():
	var candidate = get_script().new()
	candidate.round_number = round_number
	candidate.next_hook_index = next_hook_index
	candidate.completed = completed
	candidate.execution_log = execution_log.duplicate(true)
	return candidate
