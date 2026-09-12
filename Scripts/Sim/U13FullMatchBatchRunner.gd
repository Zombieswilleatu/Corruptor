extends SceneTree
const Batch = preload("res://Scripts/Sim/U13FullMatchBatch.gd")
var index: int = 0
var games: int = 100
var round_limit: int = 80
var output: String = ""
var revision: String = ""
var summarize: bool = false
var started: int

func _initialize() -> void:
	call_deferred("run")

func write_json(path: String, value: Dictionary) -> bool:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "", true, true) + "\n")
	file.flush()
	var error: int = file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(path + ".tmp", path) == OK

func identity(game_index: int) -> Dictionary:
	return {"batch_version": Batch.VERSION, "bot_version": Batch.Game.GameBot.VERSION, "revision": revision, "runtime": Engine.get_version_info().string, "index": game_index, "setup": Batch.setup(game_index), "round_limit": round_limit}

func checkpoint(snapshot: Dictionary, round_number: int) -> bool:
	print("GAME ", index, " START ROUND ", round_number)
	return write_json(output.path_join("game-%03d-checkpoint.json" % index), {"identity": identity(index), "round": round_number, "save_json": Batch.Game.encode_snapshot(snapshot)})

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if arg == "--summarize":
			summarize = true
		elif parts.size() == 2 and parts[0] in ["--index", "--games", "--round-limit"] and parts[1].is_valid_int():
			match parts[0]:
				"--index": index = int(parts[1])
				"--games": games = int(parts[1])
				"--round-limit": round_limit = int(parts[1])
		elif parts.size() == 2 and parts[0] == "--output":
			output = parts[1]
		elif parts.size() == 2 and parts[0] == "--revision":
			revision = parts[1]
		else:
			print("FAIL invalid argument ", arg)
			quit(1)
			return
	if index < 0 or index >= 1000 or games < 1 or games > 1000 or round_limit < 1 or round_limit > 200 or output.is_empty() or revision.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		print("FAIL invalid batch configuration/output")
		quit(1)
		return
	if summarize:
		summary()
		return
	var path: String = output.path_join("game-%03d.json" % index)
	if FileAccess.file_exists(path):
		var previous = JSON.parse_string(FileAccess.get_file_as_string(path))
		if valid_result(previous, index) and previous.status == "won":
			print("U13 full match won: ", index, " (verified report reused)")
			quit(0)
			return
	started = Time.get_ticks_msec()
	var result: Dictionary = Batch.trial(index, round_limit, Callable(self, "checkpoint"))
	result["identity"] = identity(index)
	result["elapsed_seconds"] = (Time.get_ticks_msec() - started) / 1000.0
	if not write_json(path, result):
		print("FAIL result write")
		quit(1)
		return
	if result.status == "won":
		DirAccess.remove_absolute(output.path_join("game-%03d-checkpoint.json" % index))
		print("U13 full match won: ", index, " ", JSON.stringify(result.outcome))
		quit(0)
	elif result.status == "censored":
		print("U13 full match censored: ", index, " round limit ", round_limit)
		quit(2)
	else:
		print("FAIL U13 full match ", index, " ", result.get("stage"), " ", JSON.stringify(result.get("detail")))
		quit(1)

func summary() -> void:
	var report: Dictionary = {"batch_version": Batch.VERSION, "revision": revision, "runtime": Engine.get_version_info().string, "requested": games, "won": 0, "censored": 0, "failed_or_missing": 0, "wins_by": {}, "lord_seats": {}, "coverage": {}, "games": []}
	for game_index in range(games):
		var path: String = output.path_join("game-%03d.json" % game_index)
		var row = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if not valid_result(row, game_index):
			report.failed_or_missing += 1
			report.games.append({"index": game_index, "status": "failed_or_missing"})
			continue
		report[row.status] += 1
		for lord in row.identity.setup.lords:
			Batch.count_key(report.lord_seats, lord)
		if row.status == "won":
			Batch.count_key(report.wins_by, row.outcome.win_by)
		for category in row.coverage:
			if not report.coverage.has(category):
				report.coverage[category] = {}
			for key in row.coverage[category]:
				report.coverage[category][key] = int(report.coverage[category].get(key, 0)) + int(row.coverage[category][key])
		report.games.append({"index": game_index, "status": row.status, "outcome": row.outcome, "elapsed_seconds": row.elapsed_seconds})
	report["gate_passed"] = report.won == games and report.censored == 0 and report.failed_or_missing == 0
	if not write_json(output.path_join("summary.json"), report):
		print("FAIL summary write")
		quit(1)
		return
	print("U13 full match batch: ", report.won, "/", games, " won; ", report.censored, " censored; ", report.failed_or_missing, " failed/missing")
	quit(0 if report.gate_passed else 2)

# A success marker alone is insufficient for resuming or passing the gate.
func valid_result(row, game_index: int) -> bool:
	if typeof(row) != TYPE_DICTIONARY or not Batch.Game.Data.is_data(row):
		return false
	row = Batch.Game.Data.copy_data(row)
	if typeof(row) != TYPE_DICTIONARY or row.get("identity") != identity(game_index) or row.get("replay_verified") != true or row.get("status") not in ["won", "censored"]:
		return false
	if typeof(row.get("rounds")) != TYPE_ARRAY or row.rounds.is_empty() or row.rounds.size() > round_limit or typeof(row.get("outcome")) != TYPE_DICTIONARY or typeof(row.get("coverage")) != TYPE_DICTIONARY:
		return false
	if not Batch.Game.Data.is_integer(row.outcome.get("round")) or row.outcome.round != row.rounds.size() or typeof(row.get("elapsed_seconds")) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	for category in ["actions", "powers", "development", "events"]:
		if typeof(row.coverage.get(category)) != TYPE_DICTIONARY:
			return false
		for key in row.coverage[category]:
			if not Batch.Game.Data.is_integer(row.coverage[category][key]) or row.coverage[category][key] < 0:
				return false
	for r in range(row.rounds.size()):
		var record = row.rounds[r]
		if typeof(record) != TYPE_DICTIONARY or record.get("round") != r + 1 or typeof(record.get("state_hash")) != TYPE_STRING or record.state_hash.length() != 64 or typeof(record.get("plans")) != TYPE_ARRAY or record.plans.size() != 2:
			return false
	if row.status == "won":
		return row.outcome.get("action") == "game_finished" and row.outcome.get("winner") in [0, 1] and row.outcome.get("win_by") in ["Ritual", "Dominion", "FinalCollapse"] and row.coverage.events.get("MATCH_FINISHED") == 1
	return row.rounds.size() == round_limit and row.outcome.get("winner") == -1 and row.outcome.get("win_by") == "" and row.outcome.get("action") == "game_in_progress" and row.get("reason") == "round_limit" and row.coverage.events.get("MATCH_FINISHED", 0) == 0
