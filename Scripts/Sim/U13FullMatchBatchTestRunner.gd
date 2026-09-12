extends "res://Scripts/Sim/U13FullMatchBatchRunner.gd"
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func run() -> void:
	revision = "harness-test-only"
	var pairs: Dictionary = {}
	var seats: Dictionary = {}
	for i in range(100):
		var chosen: Dictionary = Batch.setup(i)
		check(chosen.castles.all(func(c): return Batch.Game.Slots.selection_valid(c) and c[0] == "Keep"), "legal Keep-first loadouts " + str(i))
		pairs[str(chosen.lords)] = true
		for lord in chosen.lords:
			Batch.count_key(seats, lord)
	check(pairs.size() == 81 and seats.size() == 9 and seats.values().all(func(n): return n >= 18), "100-game schedule covers every ordered pairing and all nine Lords")
	# Report-only fixtures: never used as simulation results or written to disk.
	var row: Dictionary = {"identity": identity(0), "status": "won", "replay_verified": true, "rounds": [{"round": 1, "state_hash": "a".repeat(64), "plans": [{}, {}]}], "outcome": {"action": "game_finished", "round": 1, "winner": 0, "win_by": "Ritual"}, "elapsed_seconds": 1.0, "coverage": {"actions": {}, "powers": {}, "development": {}, "events": {"MATCH_FINISHED": 1}}}
	check(valid_result(row, 0), "complete report shape accepted")
	check(valid_result(JSON.parse_string(JSON.stringify(row)), 0), "report identity survives JSON numeric normalization")
	check(not valid_result(row, 1), "wrong seed/index report cannot be reused")
	for key in ["identity", "rounds", "outcome", "coverage", "elapsed_seconds", "replay_verified"]:
		var corrupt: Dictionary = row.duplicate(true)
		corrupt.erase(key)
		check(not valid_result(corrupt, 0), "incomplete report rejected " + key)
	var corrupt: Dictionary = row.duplicate(true)
	corrupt.outcome.winner = -1
	check(not valid_result(corrupt, 0), "unfinished outcome cannot count as won")
	corrupt = row.duplicate(true)
	corrupt.identity.revision = "stale"
	check(not valid_result(corrupt, 0), "stale code revision rejected")
	corrupt = row.duplicate(true)
	corrupt.coverage.events.MATCH_FINISHED = 2
	check(not valid_result(corrupt, 0), "duplicate finish event rejected")
	round_limit = 1
	row.identity = identity(0)
	row.status = "censored"
	row["reason"] = "round_limit"
	row.outcome = {"action": "game_in_progress", "round": 1, "winner": -1, "win_by": ""}
	row.coverage.events = {}
	check(valid_result(row, 0), "censored report is valid evidence but not a victory")
	row.status = "won"
	check(not valid_result(row, 0), "censored report cannot be relabeled a victory")
	var game = Batch.Game.new()
	var configured: Dictionary = Batch.setup(6)
	check(game.start(configured.seed, configured.lords, configured.castles).action != "invalid", "Kroni save regression starts real conductor")
	# Representative fractional carry from Kroni's fleeing actor event history.
	var event: Dictionary = {"type": "KRONI_SAVE_PRECISION_PROBE", "text": "precision regression", "data": {"carry_x": -0.44044004896019095, "carry_y": 0.06155200588210752}}
	check(game._owner._events.append(event, [event, event]).action != "invalid", "fractional event accepted")
	var lossy = Batch.Game.new()
	check(lossy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid" and lossy.snapshot() != game.snapshot(), "default abbreviated JSON reproduces original precision loss")
	var replay = Batch.Game.new()
	check(replay.restore_json(game.snapshot_json()).action != "invalid" and replay.snapshot() == game.snapshot(), "lossless JSON save preserves exact fractional event history")
	var unchanged: Dictionary = replay.snapshot()
	check(replay.restore_json("[]").action == "invalid" and replay.snapshot() == unchanged, "invalid JSON root cannot replace live game")
	compact_history_parity()
	print("U13 full match harness failures: ", failures)
	quit(failures)

func compact_history_parity() -> void:
	var chosen: Dictionary = Batch.setup(6)
	var full = Batch.Game.new()
	var compact = Batch.Game.new()
	full.start(chosen.seed, chosen.lords, chosen.castles)
	compact.start(chosen.seed, chosen.lords, chosen.castles, true)
	for round_number in range(1, 3):
		check(full.to_planning(true).action == "game_planning" and compact.to_planning(true).action == "game_planning", "both history modes reach planning")
		var plans: Array = [full.plan(0), full.plan(1)]
		check(plans == [compact.plan(0), compact.plan(1)], "history mode preserves complete seeded plans")
		check(full.submit(plans).action != "invalid" and compact.submit(plans).action != "invalid", "both history modes submit")
		check(full.finish_round().action != "invalid" and compact.finish_round().action != "invalid", "both history modes resolve")
		var expected: Dictionary = full.snapshot()
		check(expected.events.rows.any(func(row): return row.event.type == "MARCHING_TICK"), "normal mode keeps presentation ticks")
		expected.policy_id += ":" + Batch.Game.Content.BATCH_EVENTS_VERSION
		expected.events.rows = expected.events.rows.filter(func(row): return row.event.type not in Batch.Game.Content.BATCH_SAMPLE_EVENTS)
		check(expected == compact.snapshot(), "batch differs only by declared profile and tick samples")
		var restored = Batch.Game.new()
		check(restored.restore_json(compact.snapshot_json()).action != "invalid" and restored.snapshot() == expected and restored._owner._content_owner.batch_events, "batch save restores exact state and mode")
		compact = restored
		if round_number < 2:
			check(full.next_round().action != "invalid" and compact.next_round().action != "invalid", "restored batch continues")
