extends SceneTree

const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Bot = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const Counters = preload("res://Scripts/Sim/U13PlanningCounters.gd")
const Batch = preload("res://Scripts/Sim/U13FullMatchBatch.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var checkpoint: String = ""
	var output: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--checkpoint="):
			checkpoint = arg.trim_prefix("--checkpoint=")
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		else:
			print("FAIL unknown profile argument ", arg)
			quit(1)
			return
	var game = Game.new()
	var result: Dictionary
	if checkpoint.is_empty():
		var chosen: Dictionary = Batch.setup(25) # Valak / Humbaba, spatial power
		result = game.start(chosen.seed, chosen.lords, chosen.castles, true)
	else:
		var raw = JSON.parse_string(FileAccess.get_file_as_string(checkpoint))
		if typeof(raw) != TYPE_DICTIONARY or typeof(raw.get("save_json")) != TYPE_STRING:
			print("FAIL checkpoint envelope")
			quit(1)
			return
		result = game.restore_json(raw.save_json)
	if result.action == "invalid" or game.to_planning(true).action != "game_planning":
		print("FAIL profile setup ", result)
		quit(1)
		return
	var before: Dictionary = game.snapshot()
	var report: Dictionary = {"runtime": Engine.get_version_info().string, "round": game._owner.round_number(), "samples": [], "success": true}
	var phase_started: int = Time.get_ticks_usec()
	var detached: Dictionary = before.world.duplicate(true)
	report["one_world_deep_copy_ms"] = (Time.get_ticks_usec() - phase_started) / 1000.0
	phase_started = Time.get_ticks_usec()
	var baseline = game._owner._clone()
	report["one_validated_match_clone_ms"] = (Time.get_ticks_usec() - phase_started) / 1000.0
	report.success = baseline != null and detached == before.world
	for policy in [Game.GameBot, Bot]:
		for pid in [0, 1]:
			var counter = Counters.new(game._owner)
			var started: int = Time.get_ticks_usec()
			var plan: Dictionary = policy.plan(counter, pid)
			var row: Dictionary = counter.summary((Time.get_ticks_usec() - started) / 1000.0)
			row.merge({"policy": policy.VERSION, "player_id": pid, "plan": plan})
			report.samples.append(row)
			print("PLANNING ", policy.VERSION, " seat ", pid, " candidates=", row.candidates_validated, " validation_ms=", snappedf(row.validation_ms, 0.1), " total_ms=", snappedf(row.planning_ms, 0.1))
			if plan.action == "invalid" or game.snapshot() != before:
				report.success = false
	if not output.is_empty():
		var file = FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			report.success = false
		else:
			file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
			file.flush()
			report.success = report.success and file.get_error() == OK
			file.close()
	print("U13 doctrine profile success: ", report.success)
	quit(0 if report.success else 1)
