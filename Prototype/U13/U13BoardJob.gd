extends RefCounted

const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const Feedback = preload("res://Prototype/U13/U13MarcherFeedback.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
var _thread: Thread


func start(source, operation: String, powers: Array = [], order: Dictionary = {}) -> Dictionary:
	if _thread != null:
		return Data.invalid("board_job_already_started")
	var candidate = source._fork_for_job()
	if candidate == null:
		return Data.invalid("match_clone_failed")
	_thread = Thread.new()
	var error: int = _thread.start(
		Callable(self, "_run").bind(
			candidate, operation, powers.duplicate(true), order.duplicate(true)
		)
	)
	if error != OK:
		_thread = null
		return Data.invalid("board_worker_start_failed")
	return {"action": "board_job_started"}


func ready() -> bool:
	return _thread != null and not _thread.is_alive()


func take() -> Dictionary:
	if not ready():
		return Data.invalid("board_job_not_ready")
	var result = _thread.wait_to_finish()
	_thread = null
	if typeof(result) != TYPE_DICTIONARY:
		return Data.invalid("board_worker_failed")
	return result


# Only destruction may join a still-running task. Normal completion is polled.
func join_on_exit() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


func _run(candidate, operation: String, powers: Array, order: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var event_cursor: int = candidate._owner._event_cursor()
	var result: Dictionary
	var playback = null
	if operation == "marching":
		result = candidate.choose(powers, order)
		if result.action == "invalid":
			return result
		result = candidate.run_to_marching()
		if result.action == "invalid":
			return result
		playback = Playback.new()
		if not playback.build(candidate.marching_events()):
			return Data.invalid("board_playback_tape_invalid")
	elif operation == "aftermath":
		for index in range(3):
			if candidate.next_hook().is_empty():
				break
			result = candidate.step()
			if result.action == "invalid":
				return result
		if not candidate.next_hook().is_empty():
			return Data.invalid("board_aftermath_incomplete")
		result = {"action": "board_aftermath_complete"}
	elif operation == "next_round":
		result = candidate.next_round()
		if result.action == "invalid":
			return result
	else:
		return Data.invalid("board_job_operation_invalid")
	var presented: Dictionary = (
		result.before_marching if result.has("before_marching") else candidate.board_view()
	)
	var feedback: Array = Feedback.outside_marching(
		candidate._owner._player_selected_events_since(
			0, event_cursor, Feedback.TYPES, Timeline.MARCHING
		),
		presented.world.entities
	)
	return {
		"action": "board_job_complete",
		"feedback": feedback,
		"gem_dagger_events": candidate._owner._player_selected_events_since(0, event_cursor, ["GUARD_DEFEATED", "GEM_DAGGER"], Timeline.MARCHING),
		"operation": operation,
		"session": candidate,
		"playback": playback,
		"artillery_events": candidate.artillery_events() if operation == "marching" else [],
		"presented": presented,
		"worker_ms": float(Time.get_ticks_usec() - started) / 1000.0
	}
