extends SceneTree

const Batch = preload("res://Scripts/Sim/U13RandomBatch.gd")
var trials: int = 4
var rounds: int = 6
var seed_prefix: String = "u13-frequency-v1"
var output: String = ""
var roster_mode: String = "gremory"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var version: Dictionary = Engine.get_version_info()
	if (
		int(version.major) != 4
		or int(version.minor) != 7
		or int(version.patch) != 2
		or String(version.status) != "stable"
	):
		_fail("Requires Godot 4.7.2 stable")
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--trials=") and arg.trim_prefix("--trials=").is_valid_int():
			trials = int(arg.trim_prefix("--trials="))
		elif arg.begins_with("--rounds=") and arg.trim_prefix("--rounds=").is_valid_int():
			rounds = int(arg.trim_prefix("--rounds="))
		elif arg.begins_with("--seed-prefix="):
			seed_prefix = arg.trim_prefix("--seed-prefix=")
		elif arg.begins_with("--roster="):
			roster_mode = arg.trim_prefix("--roster=")
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		else:
			_fail("Unknown/invalid argument: " + arg)
			return
	if (
		trials < 1
		or trials > 100
		or rounds < 1
		or rounds > 100
		or seed_prefix.is_empty()
		or output.is_empty()
		or roster_mode not in ["gremory", "deimos", "mixed"]
	):
		_fail("Use 1..100 trials/rounds, a seed prefix, and --output=report.json")
		return
	var results: Array = []
	for index in range(trials):
		var seed_value: String = seed_prefix + ":" + str(index)
		print("BATCH TRIAL ", index + 1, "/", trials)
		var first: Dictionary = Batch.trial(
			seed_value, rounds, Callable(self, "_progress"), roster_mode
		)
		if first.action == "invalid":
			_fail(JSON.stringify(first))
			return
		print("BATCH REPLAY ", seed_value)
		var replay: Dictionary = Batch.trial(
			seed_value, rounds, Callable(self, "_progress"), roster_mode
		)
		if first != replay:
			_fail("Replay diverged for " + seed_value)
			return
		first["replay_verified"] = true
		results.append(first)
	var report: Dictionary = Batch.report(results, rounds)
	var file = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write report: " + output)
		return
	file.store_string(JSON.stringify(report, "\t", true) + "\n")
	file.flush()
	var write_error: int = file.get_error()
	file.close()
	if write_error != OK:
		_fail("Report write failed")
		return
	print("BATCH SUMMARY ", JSON.stringify(report.summary))
	print("Report: ", output)
	print("U13 random-legal batch completed: OK")
	quit(0)


func _progress(seed_value: String, round_number: int) -> void:
	print("BATCH ROUND ", seed_value, " ", round_number, "/", rounds)


func _fail(reason: String) -> void:
	print("BATCH ERROR: ", reason)
	quit(1)
