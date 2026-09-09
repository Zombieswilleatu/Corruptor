extends SceneTree

const Alpha = preload("res://Scripts/Sim/U13AlphaBatch.gd")
var options: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _fail(reason: String) -> void:
	print("ALPHA ERROR: ", reason)
	quit(1)


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
		var parts: PackedStringArray = arg.split("=", true, 1)
		if (
			parts.size() != 2
			or parts[0] not in ["--pair", "--seed", "--rounds", "--output", "--manifest"]
			or options.has(parts[0])
		):
			_fail("Invalid/duplicate argument: " + arg)
			return
		options[parts[0]] = parts[1]
	if not options.has("--output"):
		_fail("Missing output path")
		return
	if options.has("--manifest"):
		_aggregate()
		return
	var pair: Array = Array(String(options.get("--pair", "")).split(","))
	var round_text: String = options.get("--rounds", "6")
	var seed_value: String = options.get("--seed", "")
	if (
		not round_text.is_valid_int()
		or not Alpha.Scenario.pair_valid(pair)
		or seed_value.is_empty()
	):
		_fail("Invalid pair, seed or rounds")
		return
	var rounds: int = int(round_text)
	var baseline_times: Dictionary = {}
	var replay_times: Dictionary = {}
	var started: int = Time.get_ticks_msec()
	print("ALPHA BASELINE ", pair, " seed=", seed_value)
	var first: Dictionary = Alpha.trial(
		pair, seed_value, rounds, false, baseline_times, Callable(self, "_progress")
	)
	if first.action == "invalid":
		_fail(JSON.stringify(first))
		return
	var baseline_ms: int = Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	print("ALPHA RESTORED REPLAY ", pair)
	var replay: Dictionary = Alpha.trial(
		pair, seed_value, rounds, true, replay_times, Callable(self, "_progress")
	)
	var checked: Dictionary = Alpha.compare(first, replay)
	if checked.action == "invalid":
		_fail(JSON.stringify(checked))
		return
	var result: Dictionary = {
		"schema_version": Alpha.VERSION,
		"fixture": Alpha.Scenario.VERSION,
		"runtime": "4.7.2.stable",
		"replay_verified": true,
		"trial": first,
		"timing":
		{
			"baseline_ms": baseline_ms,
			"restored_replay_ms": Time.get_ticks_msec() - started,
			"baseline": baseline_times,
			"restored_replay": replay_times,
			"note":
			"CPU wall times, not rendering FPS. Checkpoint serialization/restoration measured separately."
		}
	}
	for mode in ["baseline", "restored_replay"]:
		var summaries: Dictionary = {}
		for category in ["planning", "hooks", "checkpoints"]:
			summaries[category] = Alpha.timing(result.timing[mode][category])
		result.timing[mode + "_summary"] = summaries
	_write(result)


func _aggregate() -> void:
	var manifest_path: String = options["--manifest"]
	var file = FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		_fail("Cannot read manifest")
		return
	var expected: Array = []
	var shards: Array = []
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.is_empty():
			continue
		var columns: PackedStringArray = line.split("\t")
		if columns.size() != 5 or not columns[4].is_valid_int() or not columns[0].is_valid_int():
			_fail("Malformed manifest")
			return
		var path: String = manifest_path.get_base_dir().path_join(columns[0] + ".json")
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not value is Dictionary:
			_fail("Missing/invalid shard: " + path)
			return
		expected.append(
			{"pair": [columns[1], columns[2]], "seed": columns[3], "rounds": int(columns[4])}
		)
		shards.append(value)
	var report: Dictionary = Alpha.report(shards, expected)
	if report.action == "invalid":
		_fail(JSON.stringify(report))
		return
	print(
		"ALPHA MATRIX ordered_pairs=",
		report.ordered_pairs,
		" verified_shards=",
		report.verified_shards
	)
	print("ALPHA POWERS WITHOUT RESOLUTION ", report.powers_without_resolution)
	_write(report)


func _write(result: Dictionary) -> void:
	var file = FileAccess.open(options["--output"], FileAccess.WRITE)
	if file == null:
		_fail("Cannot write output")
		return
	file.store_string(JSON.stringify(result, "\t", true) + "\n")
	file.flush()
	var status: int = file.get_error()
	file.close()
	if status != OK:
		_fail("Output write failed")
		return
	print("U13 alpha batch completed: OK")
	quit(0)


func _progress(seed_value: String, round_number: int) -> void:
	print("ALPHA ROUND ", seed_value, " ", round_number)
