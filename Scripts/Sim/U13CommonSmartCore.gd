extends RefCounted

# Run the same CommonSmartCore source used by the Python comparison runner.
# Native admission stays in-process; the worker never receives a saved match.
const Observation = preload("res://Scripts/Sim/U13CommonObservation.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const PROTOCOL: String = "U13_COMMON_BOT_PIPE_V1"
const WORKER: String = "res://Scripts/Sim/u13_common_bot_worker.py"
const PREVIEW_LIMIT: int = 8
const TIMEOUT_MSEC: int = 20000

class Watchdog:
	extends RefCounted
	var mutex: Mutex = Mutex.new()
	var stopped: bool = false
	var expired: bool = false
	func watch(pid: int, timeout_msec: int) -> void:
		var deadline: int = Time.get_ticks_msec() + timeout_msec
		while true:
			mutex.lock()
			var done: bool = stopped
			mutex.unlock()
			if done: return
			if Time.get_ticks_msec() >= deadline:
				expired = true
				if OS.is_process_running(pid): OS.kill(pid)
				return
			OS.delay_msec(10)
	func stop() -> void:
		mutex.lock()
		stopped = true
		mutex.unlock()

static func runtime() -> String:
	var configured: String = OS.get_environment("CORRUPTOR_BOT_PYTHON")
	var command: String = configured if not configured.is_empty() else ("python" if OS.get_name() == "Windows" else "python3")
	if command.is_absolute_path(): return command if FileAccess.file_exists(command) else ""
	var windows: bool = OS.get_name() == "Windows"
	for directory in OS.get_environment("PATH").split(";" if windows else ":"):
		var candidate: String = directory.path_join(command)
		if windows and not candidate.to_lower().ends_with(".exe"): candidate += ".exe"
		if FileAccess.file_exists(candidate): return candidate
	return ""

static func exchange(view: Dictionary, mode: String, preview: Callable) -> Dictionary:
	var encoded: Dictionary = Codec.encode({"protocol": PROTOCOL, "view": view, "mode": mode})
	if encoded.action != "encoded": return Data.invalid("common_bot_observation_invalid")
	var script: String = ProjectSettings.globalize_path(WORKER)
	if not FileAccess.file_exists(script): return Data.invalid("common_bot_worker_missing")
	var executable: String = runtime()
	if executable.is_empty(): return Data.invalid("common_bot_python_unavailable")
	var process: Dictionary = OS.execute_with_pipe(executable, ["-u", script], true)
	if process.is_empty(): return Data.invalid("common_bot_python_unavailable")
	var watchdog = Watchdog.new()
	var thread = Thread.new()
	if thread.start(Callable(watchdog, "watch").bind(process.pid, TIMEOUT_MSEC)) != OK:
		OS.kill(process.pid)
		return Data.invalid("common_bot_watchdog_unavailable")
	var pipe: FileAccess = process.stdio
	pipe.store_line(encoded.text)
	pipe.flush()
	var result: Dictionary = Data.invalid("common_bot_pipe_closed")
	var admitted: Array = []
	var calls: int = 0
	for message_index in range(PREVIEW_LIMIT + 1):
		var decoded: Dictionary = Codec.decode(pipe.get_line())
		if decoded.action != "decoded" or typeof(decoded.value) != TYPE_DICTIONARY:
			break
		var message: Dictionary = decoded.value
		if message.get("action") == "preview":
			calls += 1
			if mode != "plan" or calls > PREVIEW_LIMIT or message.get("index") != calls or not preview.is_valid() or typeof(message.get("plan")) != TYPE_DICTIONARY:
				result = Data.invalid("common_bot_preview_protocol_invalid"); break
			var checked: Dictionary = preview.call(message.plan)
			if checked.action != "invalid":
				admitted.append(message.plan.duplicate(true))
				checked = {"action": "legal"}
			pipe.store_line(Codec.encode({"action": "preview_result", "index": calls, "result": checked}).text)
			pipe.flush()
		elif message.get("action") == "decision":
			if message.get("protocol") != PROTOCOL or message.get("previews") != calls or typeof(message.get("decision")) != TYPE_DICTIONARY:
				result = Data.invalid("common_bot_decision_protocol_invalid"); break
			if mode == "plan" and not admitted.any(func(plan): return Codec.difference(plan, message.decision.get("plan")).is_empty()):
				result = Data.invalid("common_bot_unpreviewed_plan"); break
			result = message
			break
		else:
			result = message if message.get("action") == "invalid" else Data.invalid("common_bot_message_invalid")
			break
	watchdog.stop()
	thread.wait_to_finish()
	pipe.close()
	process.stderr.close()
	if not watchdog.expired and OS.is_process_running(process.pid): OS.kill(process.pid)
	return Data.invalid("common_bot_timeout") if watchdog.expired else result

static func decide(owner, pid: int) -> Dictionary:
	if pid not in [0, 1] or owner.next_hook() != "submission_lock" or owner._submissions[pid] != null:
		return Data.invalid("doctrine_not_planning")
	var view: Dictionary = Observation.read(owner, pid)
	var session = owner.planning_session(pid)
	if session == null: return Data.invalid("doctrine_not_planning")
	return exchange(view, "plan", func(plan):
		if typeof(plan.get("powers")) != TYPE_ARRAY or typeof(plan.get("order")) != TYPE_DICTIONARY:
			return Data.invalid("common_bot_plan_invalid")
		return session.preview_submission(pid, plan.powers, plan.order))

static func plan(owner, pid: int) -> Dictionary:
	var result: Dictionary = decide(owner, pid)
	if result.action == "invalid": return result
	var selected: Dictionary = result.decision.plan.duplicate(true)
	selected["action"] = "bot_plan"
	return selected

static func resolve_choice(game, pending: Dictionary) -> Dictionary:
	if pending.get("action") not in ["game_draw_choice", "game_market_choice"] or pending.get("player_id") not in [0, 1]:
		return Data.invalid("doctrine_choice_invalid")
	var pid: int = pending.player_id
	var mode: String = "stockpile" if pending.action == "game_draw_choice" else "slaver"
	var result: Dictionary = exchange(Observation.read(game._owner, pid), mode, Callable())
	if result.action == "invalid": return result
	var op: Dictionary = result.decision.operation
	if op.get("player_id") != pid: return Data.invalid("common_bot_choice_player_invalid")
	if mode == "stockpile" and op.get("kind") == "stockpile":
		return game.choose_stockpile(pid, op.keep_id)
	if mode == "slaver" and op.get("kind") == "market":
		return game.choose_market(pid, op.choice)
	return Data.invalid("common_bot_choice_invalid")
