extends SceneTree

const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const BoardSession = preload("res://Scripts/Sim/U13BoardSession.gd")
const Session = preload("res://Scripts/Sim/U13SmokeSession.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Log = preload("res://Scripts/Sim/U13EventLog.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const SEED: String = "u13_perf_profile_v1"
var counts: Array = [6, 24, 48]
var samples: int = 3
var rounds: int = 3
var failed: bool = false
var results: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--samples="):
			samples = _positive(arg.trim_prefix("--samples="), 10)
		elif arg.begins_with("--rounds="):
			rounds = _positive(arg.trim_prefix("--rounds="), 10)
		elif arg.begins_with("--counts="):
			counts = []
			for value in arg.trim_prefix("--counts=").split(","):
				var count: int = _positive(value, 96)
				if count % 2 != 0:
					failed = true
				counts.append(count)
		else:
			failed = true
	if failed or counts.is_empty():
		print(
			"PROFILE ERROR: use --counts=6,24,48 --samples=3 --rounds=3; counts must be even, 2..96; samples/rounds 1..10"
		)
		quit(1)
		return
	var info: Dictionary = Engine.get_version_info()
	var version: String = str(info.get("string", "unknown"))
	if (
		info.get("major") != 4
		or info.get("minor") != 7
		or info.get("patch") != 2
		or info.get("status") != "stable"
	):
		print("PROFILE ERROR: requires Godot 4.7.2 stable; got ", version)
		quit(1)
		return
	print(
		"PROFILE META ",
		JSON.stringify(
			{
				"engine": version,
				"os": OS.get_name(),
				"cpu": OS.get_processor_name(),
				"threads": OS.get_processor_count(),
				"debug": OS.is_debug_build(),
				"counts": counts,
				"samples": samples,
				"rounds": rounds,
				"seed": SEED
			}
		)
	)
	print(
		"PROFILE: milliseconds, one warm-up then measured samples. No rendering/GPU timing. No performance pass threshold."
	)
	var started: int = Time.get_ticks_usec()
	for count in counts:
		for mode in ["travel", "contact"]:
			_density(int(count), mode)
			if failed:
				_finish(started)
				return
	_history()
	if not failed:
		_board_session()
	_finish(started)


func _positive(text: String, maximum: int) -> int:
	if not text.is_valid_int() or int(text) < 1 or int(text) > maximum:
		failed = true
		return 1
	return int(text)


func _world(count: int, mode: String) -> Dictionary:
	var world: Dictionary = Session._initial_world()
	var ids = Ids.new()
	ids.restore(world.entities)
	for index in range(count):
		var owner: int = index % 2
		var lane: String = "Lord" if mode == "travel" and owner == 0 else "Castle"
		var attributes: Dictionary = Marching.profile("Vulture", lane, owner, 0, 1)
		var made: Dictionary = ids.create("marcher", "perf:" + mode, index, owner, attributes)
		if not _ok(made):
			return {}
		if not _ok(Marching.place_spawn(ids, made.entity.id, SEED)):
			return {}
		if mode == "contact":
			var unit: Dictionary = ids.get_entity(made.entity.id)
			unit.attributes.x_fp += 900 if owner == 0 else -900
			ids.update(unit.id, owner, unit.attributes)
	world.entities = ids.snapshot()
	return world


func _resolve(world: Dictionary) -> Dictionary:
	var content = Gremory.new()
	return Marching.resolve(
		{
			"world": world,
			"round": 1,
			"hook": Timeline.MARCHING,
			"seed": SEED,
			"player_order": [0, 1]
		},
		Callable(content, "react")
	)


func _density(count: int, mode: String) -> void:
	var label: String = "%s/n%d" % [mode, count]
	print("PROFILE BEGIN ", label)
	var world: Dictionary = _world(count, mode)
	if failed:
		return
	var original: Dictionary = world.duplicate(true)
	var result = _measure(label, "marching_direct", Callable(self, "_resolve").bind(world))
	if failed:
		return
	if world != original:
		failed = true
		print("PROFILE ERROR: Marching mutated its input")
		return
	var events: Array = []
	var deaths: int = 0
	var contacts: int = 0
	for row in result.events:
		events.append(row.event)
		if row.event.type == "MARCHER_DEFEATED":
			deaths += 1
		if row.event.type == "MARCHER_CONTACT":
			contacts += 1
	print(
		"PROFILE SIZE ",
		JSON.stringify(
			{
				"case": label,
				"event_rows": result.events.size(),
				"event_json_bytes": JSON.stringify(result.events).to_utf8_buffer().size(),
				"contacts": contacts,
				"deaths": deaths
			}
		)
	)
	_measure(label, "event_log_append", Callable(self, "_append_events").bind(result.events))
	var playback = Playback.new()
	_measure(label, "playback_build", Callable(playback, "build").bind(events))
	_measure(label, "playback_sample_360_frames", Callable(self, "_sample_frames").bind(playback))
	if playback.final_units() != events.back().data.units:
		failed = true
		print("PROFILE ERROR: playback endpoint mismatch")


func _append_events(rows: Array) -> Dictionary:
	var log = Log.new()
	for row in rows:
		var added: Dictionary = log.append(row.event, row.views)
		if added.action == "invalid":
			return added
	return {"action": "profile_recorded"}


func _sample_frames(playback) -> bool:
	for frame in range(360):
		playback.sample(playback.duration * float(frame) / 359.0)
	return true


func _restore(snapshot: Dictionary) -> Dictionary:
	var content = Gremory.new()
	var owner = content.create_combat_match()
	return owner.restore(snapshot)


func _json_roundtrip(snapshot: Dictionary) -> Dictionary:
	var decoded = JSON.parse_string(JSON.stringify(snapshot))
	if typeof(decoded) != TYPE_DICTIONARY:
		return {"action": "invalid", "reason": "profile_json_failed"}
	return {"action": "profile_json_decoded"}


func _state_costs(owner, label: String) -> void:
	_measure(label, "internal_transaction_clone", Callable(owner, "_clone"))
	var snapshot = _measure(label, "snapshot_copy", Callable(owner, "snapshot"))
	if failed:
		return
	print(
		"PROFILE SIZE ",
		JSON.stringify(
			{
				"case": label,
				"history_rows": snapshot.events.rows.size(),
				"snapshot_json_bytes": JSON.stringify(snapshot).to_utf8_buffer().size()
			}
		)
	)
	_measure(label, "restore_validation", Callable(self, "_restore").bind(snapshot))
	_measure(label, "json_encode_decode", Callable(self, "_json_roundtrip").bind(snapshot))
	_measure(label, "player_view_with_history", Callable(owner, "player_view").bind(0))


func _history() -> void:
	print("PROFILE BEGIN owner_history/6_marchers")
	var content = Gremory.new()
	var owner = content.create_combat_match()
	if not _ok(owner.start(SEED, _world(6, "travel"), [0, 1])):
		return
	_state_costs(owner, "history/r0")
	for round_number in range(1, rounds + 1):
		var label: String = "history/r%d" % round_number
		print("PROFILE BEGIN ", label)
		var non_marching_us: int = 0
		var hook_count: int = 0
		while not owner.next_hook().is_empty():
			if hook_count >= 32:
				failed = true
				print("PROFILE ERROR: hook progress limit")
				return
			var hook: String = owner.next_hook()
			var start: int = Time.get_ticks_usec()
			if hook == Timeline.SUBMISSION_LOCK:
				if not _ok(owner.submit(0, [])) or not _ok(owner.submit(1, [])):
					return
			var changed: Dictionary = owner.run_next_hook()
			var elapsed: int = Time.get_ticks_usec() - start
			if not _ok(changed):
				return
			if hook == Timeline.MARCHING:
				_record(label, "marching_owner_transaction", [float(elapsed) / 1000.0])
			else:
				non_marching_us += elapsed
			hook_count += 1
		_record(label, "other_hooks_and_submissions_total", [float(non_marching_us) / 1000.0])
		_state_costs(owner, label)
		if failed:
			return
		if round_number < rounds and not _ok(owner.begin_next_round([0, 1])):
			return


func _board_session() -> void:
	print("PROFILE BEGIN board_session")
	var board = BoardSession.new()
	if not _ok(board.reset()):
		return
	for round_number in range(1, rounds + 1):
		var label: String = "board/r%d" % round_number
		print("PROFILE BEGIN ", label)
		if round_number % 2 == 1:
			var source: Dictionary = board.declaration(Gremory.PREDATOR, 0, {"lane": "Castle"})
			if not _ok(board.choose([source], {})):
				return
		var start: int = Time.get_ticks_usec()
		var result: Dictionary = board.run_to_marching()
		_record(label, "planning_through_marching", [float(Time.get_ticks_usec() - start) / 1000.0])
		if not _ok(result):
			return
		_measure(label, "board_view", Callable(board, "view"))
		_measure(label, "board_checkpoint", Callable(board, "checkpoint"))
		var playback = Playback.new()
		var tape: Array = board.marching_events()
		_measure(label, "board_playback_build", Callable(playback, "build").bind(tape))
		start = Time.get_ticks_usec()
		var steps: int = 0
		while not board.next_hook().is_empty():
			if steps >= 8:
				failed = true
				print("PROFILE ERROR: board aftermath progress limit")
				return
			if not _ok(board.step()):
				return
			steps += 1
		_record(label, "board_aftermath", [float(Time.get_ticks_usec() - start) / 1000.0])
		if round_number < rounds:
			start = Time.get_ticks_usec()
			result = board.next_round()
			_record(
				label,
				"board_next_round_to_planning",
				[float(Time.get_ticks_usec() - start) / 1000.0]
			)
			if not _ok(result):
				return


func _measure(label: String, metric: String, callback: Callable):
	print("PROFILE MEASURE ", label, " ", metric)
	var warm = callback.call()
	if not _ok(warm):
		return warm
	var timings: Array = []
	var last = warm
	for index in range(samples):
		var start: int = Time.get_ticks_usec()
		last = callback.call()
		timings.append(float(Time.get_ticks_usec() - start) / 1000.0)
		if not _ok(last):
			return last
	_record(label, metric, timings)
	return last


func _record(label: String, metric: String, timings: Array) -> void:
	timings.sort()
	var middle: int = timings.size() >> 1
	var median: float = float(timings[middle])
	if timings.size() % 2 == 0:
		median = (float(timings[middle - 1]) + median) / 2.0
	var row: Dictionary = {
		"case": label,
		"metric": metric,
		"samples": timings.size(),
		"min_ms": timings.front(),
		"median_ms": median,
		"max_ms": timings.back()
	}
	results.append(row)
	print("PERF ", JSON.stringify(row))


func _ok(value) -> bool:
	if value == null:
		failed = true
		print("PROFILE ERROR: unexpected null result")
		return false
	if (
		(typeof(value) == TYPE_DICTIONARY and value.get("action", "") == "invalid")
		or (typeof(value) == TYPE_BOOL and not value)
	):
		failed = true
		print("PROFILE ERROR: ", value)
		return false
	return true


func _finish(started: int) -> void:
	print("PROFILE TOTAL_MS ", float(Time.get_ticks_usec() - started) / 1000.0)
	print(
		"U13 performance profile completed: ",
		"FAILED" if failed else "OK",
		" (",
		results.size(),
		" measurements)"
	)
	quit(1 if failed else 0)
