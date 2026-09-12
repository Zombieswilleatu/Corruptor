extends "res://Scripts/Sim/U13FullMatchBatchRunner.gd"

const Bot = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const Counters = preload("res://Scripts/Sim/U13PlanningCounters.gd")
var verify: bool = false

func identity(game_index: int) -> Dictionary:
	var result: Dictionary = super.identity(game_index)
	result.batch_version = "U13_DOCTRINE_MATCH_V1"
	result.bot_version = Bot.VERSION
	result["verification"] = "independent_planning_save_replay" if verify else "single_conductor_legality"
	return result

func run() -> void:
	round_limit = 40
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if arg == "--verify":
			verify = true
		elif parts.size() == 2 and parts[0] in ["--index", "--round-limit"] and parts[1].is_valid_int():
			if parts[0] == "--index": index = int(parts[1])
			else: round_limit = int(parts[1])
		elif parts.size() == 2 and parts[0] == "--output": output = parts[1]
		elif parts.size() == 2 and parts[0] == "--revision": revision = parts[1]
		else:
			print("FAIL unknown doctrine match argument ", arg)
			quit(1)
			return
	if index < 0 or index >= 1000 or round_limit < 1 or round_limit > 200 or output.is_empty() or revision.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		print("FAIL doctrine configuration")
		quit(1)
		return
	started = Time.get_ticks_msec()
	var report: Dictionary = trial()
	report["identity"] = identity(index)
	report["elapsed_seconds"] = (Time.get_ticks_msec() - started) / 1000.0
	if not write_json(output.path_join("game-%03d.json" % index), report):
		print("FAIL doctrine report write")
		quit(1)
		return
	print("U13 doctrine match ", report.status, ": ", index, " ", JSON.stringify(report.get("outcome", report.get("detail", {}))))
	quit(1 if report.status == "failed" else (2 if report.status == "censored" else 0))

func trial() -> Dictionary:
	var chosen: Dictionary = Batch.setup(index)
	var game = Batch.Game.new()
	var replay = Batch.Game.new() if verify else null
	var result: Dictionary = game.start(chosen.seed, chosen.lords, chosen.castles, true)
	if result.action == "invalid": return Batch.failed(game, "opening", result)
	if verify and (replay.start(chosen.seed, chosen.lords, chosen.castles, true) != result or replay.snapshot() != game.snapshot()):
		return Batch.failed(game, "opening_replay", {})
	var rounds: Array = []
	var coverage: Dictionary = {"actions": {}, "powers": {}, "development": {}}
	for round_number in range(1, round_limit + 1):
		var begin: int = Time.get_ticks_usec()
		var timings: Dictionary = {}
		# Failure includes the exact current save; periodic checkpoints also survive
		# process termination. No full-history JSON encoding every round in fast mode.
		if round_number == 1 or round_number % 5 == 0:
			if not checkpoint(game.snapshot(), round_number): return Batch.failed(game, "checkpoint", {})
		print("DOCTRINE GAME ", index, " START ROUND ", round_number)
		var phase: int = Time.get_ticks_usec()
		result = Bot.to_planning(game)
		if result.action != "game_planning": return Batch.failed(game, "to_planning", result)
		if verify and (Bot.to_planning(replay) != result or replay.snapshot() != game.snapshot()):
			return Batch.failed(game, "planning_replay", {})
		timings.to_planning = (Time.get_ticks_usec() - phase) / 1000.0
		phase = Time.get_ticks_usec()
		var before: Dictionary = game.snapshot() if verify else {}
		var plans: Array = []
		var counters: Array = []
		for pid in [0, 1]:
			var counter = Counters.new(game._owner)
			var plan_started: int = Time.get_ticks_usec()
			plans.append(Bot.plan(counter, pid))
			counters.append(counter.summary((Time.get_ticks_usec() - plan_started) / 1000.0))
		if plans.any(func(p): return p.action == "invalid"):
			return Batch.failed(game, "plan_legality", {"plans": plans, "counters": counters})
		if verify:
			var repeated: Array = [Bot.plan(replay._owner, 0), Bot.plan(replay._owner, 1)]
			if repeated != plans or before != game.snapshot() or before != replay.snapshot():
				return Batch.failed(game, "plan_determinism", {"plans": plans, "repeated": repeated})
		timings.planning = (Time.get_ticks_usec() - phase) / 1000.0
		phase = Time.get_ticks_usec()
		if verify and replay.restore_json(game.snapshot_json()).action == "invalid":
			return Batch.failed(game, "planning_restore", {})
		timings.save_restore = (Time.get_ticks_usec() - phase) / 1000.0
		phase = Time.get_ticks_usec()
		result = game.submit(plans)
		if result.action == "invalid" or (verify and replay.submit(plans) != result):
			return Batch.failed(game, "submit", {"result": result, "plans": plans})
		timings.submission = (Time.get_ticks_usec() - phase) / 1000.0
		phase = Time.get_ticks_usec()
		result = game.finish_round()
		if result.action == "invalid": return Batch.failed(game, "resolution", result)
		if verify and (replay.finish_round() != result or replay.snapshot() != game.snapshot()):
			return Batch.failed(game, "resolution_replay", {})
		if verify and (replay.restore_json(game.snapshot_json()).action == "invalid" or replay.snapshot() != game.snapshot()):
			return Batch.failed(game, "round_end_restore", {})
		timings.resolution = (Time.get_ticks_usec() - phase) / 1000.0
		timings.total = (Time.get_ticks_usec() - begin) / 1000.0
		for pid in [0, 1]:
			var order: Dictionary = plans[pid].order
			Batch.count_key(coverage.actions, chosen.lords[pid] + ":" + str(order.get("action", "Pass")))
			for power in plans[pid].powers: Batch.count_key(coverage.powers, power.power_id)
			for key in ["rites", "summon", "castle_action", "guard_moves"]:
				if order.has(key): Batch.count_key(coverage.development, key)
		rounds.append({"round": round_number, "plans": plans, "planning_counters": counters, "timings_ms": timings})
		print("DOCTRINE GAME ", index, " ROUND ", round_number, " ", result.action, " | ", snappedf(timings.total / 1000.0, 0.01), "s; planning ", snappedf(timings.planning / 1000.0, 0.01), "s; resolution ", snappedf(timings.resolution / 1000.0, 0.01), "s; candidates ", counters[0].candidates_validated + counters[1].candidates_validated)
		if game.is_finished():
			var expected: Dictionary = Batch.Game.Content.Victory.evaluate(game.snapshot().world)
			var outcome: Dictionary = game.outcome()
			if expected.winner != outcome.winner or expected.win_by != outcome.win_by:
				return Batch.failed(game, "victory", outcome)
			return {"status": "won", "outcome": outcome, "rounds": rounds, "coverage": coverage, "replay_verified": verify, "state_hash": game.snapshot_json().sha256_text()}
		if round_number < round_limit:
			result = game.next_round()
			if result.action == "invalid" or (verify and replay.next_round() != result):
				return Batch.failed(game, "next_round", result)
	return {"status": "censored", "reason": "round_limit", "outcome": game.outcome(), "rounds": rounds, "coverage": coverage, "replay_verified": verify, "save_json": game.snapshot_json(), "state_hash": game.snapshot_json().sha256_text()}
