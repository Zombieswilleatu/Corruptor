extends RefCounted

const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const VERSION: String = "U13_FULL_MATCH_BATCH_V2"
const PREFIX: String = "u13-full-match-v1:"

static func setup(index: int) -> Dictionary:
	# First 81 games cover every ordered pairing, including mirrors.
	var lords: Array = [Game.LORDS[index % 9], Game.LORDS[int(index / 9.0) % 9]]
	var castles: Array = []
	for pid in [0, 1]:
		var loadout: Array = ["Keep"]
		for slot in range(1, 5):
			loadout.append(Game.Slots.TYPES[1 + ((slot - 1 + index + pid) % 4)])
		if index % 3 == 2:
			loadout[4] = Game.Slots.TYPES[1 + ((index + pid) % 4)]
		castles.append(loadout)
	return {"seed": PREFIX + str(index), "lords": lords, "castles": castles}

static func count_key(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1

static func trial(index: int, round_limit: int, checkpoint: Callable) -> Dictionary:
	var chosen: Dictionary = setup(index)
	var game = Game.new()
	var replay = Game.new()
	var result: Dictionary = game.start(chosen.seed, chosen.lords, chosen.castles, true)
	var mirror: Dictionary = replay.start(chosen.seed, chosen.lords, chosen.castles, true)
	var coverage: Dictionary = {"actions": {}, "powers": {}, "development": {}, "events": {}}
	var rounds: Array = []
	if result.action == "invalid" or mirror != result or replay.snapshot() != game.snapshot():
		return failed(game, "opening", result)
	for round_number in range(1, round_limit + 1):
		var round_started: int = Time.get_ticks_usec()
		var phase_started: int = round_started
		var timings: Dictionary = {}
		if not checkpoint.call(game.snapshot(), round_number):
			return failed(game, "checkpoint_write", {})
		timings.checkpoint = (Time.get_ticks_usec() - phase_started) / 1000.0
		phase_started = Time.get_ticks_usec()
		result = game.to_planning(true)
		mirror = replay.to_planning(true)
		if result.action != "game_planning" or mirror != result or replay.snapshot() != game.snapshot():
			return failed(game, "planning_replay", {"first": result, "replay": mirror, "replay_snapshot": replay.snapshot()})
		var before: Dictionary = game.snapshot()
		timings.to_planning = (Time.get_ticks_usec() - phase_started) / 1000.0
		phase_started = Time.get_ticks_usec()
		var plans: Array = [game.plan(0), game.plan(1)]
		var repeated: Array = [replay.plan(0), replay.plan(1)]
		if plans.any(func(p): return p.action == "invalid") or plans != repeated or before != game.snapshot() or before != replay.snapshot():
			return failed(game, "plan_legality_or_replay", {"plans": plans, "replay": repeated})
		timings.bot_planning = (Time.get_ticks_usec() - phase_started) / 1000.0
		phase_started = Time.get_ticks_usec()
		# Every round resumes through the public JSON save boundary.
		var restored: Dictionary = replay.restore_json(game.snapshot_json())
		if restored.action == "invalid":
			return failed(game, "planning_restore", restored)
		timings.planning_save_restore = (Time.get_ticks_usec() - phase_started) / 1000.0
		phase_started = Time.get_ticks_usec()
		for pid in [0, 1]:
			var lord: String = chosen.lords[pid]
			var order: Dictionary = plans[pid].order
			count_key(coverage.actions, lord + ":" + str(order.get("action", "Pass")))
			for power in plans[pid].powers:
				count_key(coverage.powers, lord + ":" + str(power.get("power_id", power.get("power", "unknown"))))
			for key in ["rites", "summon", "castle_action", "guard_moves"]:
				if order.has(key):
					count_key(coverage.development, key)
		result = game.submit(plans)
		mirror = replay.submit(repeated)
		if result.action == "invalid" or mirror != result:
			return failed(game, "submission", {"first": result, "replay": mirror, "plans": plans})
		timings.submission = (Time.get_ticks_usec() - phase_started) / 1000.0
		phase_started = Time.get_ticks_usec()
		result = game.finish_round()
		mirror = replay.finish_round()
		var after: Dictionary = game.snapshot()
		if result.action == "invalid" or mirror != result or replay.snapshot() != after:
			return failed(game, "resolution_replay", {"first": result, "replay": mirror, "plans": plans})
		timings.resolution_and_compare = (Time.get_ticks_usec() - phase_started) / 1000.0
		phase_started = Time.get_ticks_usec()
		if replay.restore_json(game.snapshot_json()).action == "invalid":
			return failed(game, "round_end_restore", {})
		for row in after.events.rows.slice(before.events.rows.size()):
			count_key(coverage.events, row.event.type)
		var state_hash: String = JSON.stringify(after, "", true, true).sha256_text()
		timings.round_end_save_and_hash = (Time.get_ticks_usec() - phase_started) / 1000.0
		timings.total = (Time.get_ticks_usec() - round_started) / 1000.0
		rounds.append({"round": round_number, "state_hash": state_hash, "plans": plans, "timings_ms": timings})
		print("GAME ", index, " ROUND ", round_number, " ", result.action, " | ", snappedf(timings.total / 1000.0, 0.01), "s; planning ", snappedf(timings.bot_planning / 1000.0, 0.01), "s; resolution+compare ", snappedf(timings.resolution_and_compare / 1000.0, 0.01), "s")
		if game.is_finished():
			var expected: Dictionary = Game.Content.Victory.evaluate(after.world)
			var outcome: Dictionary = game.outcome()
			if expected.winner != outcome.winner or expected.win_by != outcome.win_by or replay.outcome() != outcome or replay.next_round().action != "invalid" or replay.snapshot() != after:
				return failed(game, "terminal_outcome", outcome)
			return {"status": "won", "outcome": outcome, "rounds": rounds, "coverage": coverage, "replay_verified": true}
		if round_number < round_limit:
			result = game.next_round()
			mirror = replay.next_round()
			if result.action == "invalid" or mirror != result:
				return failed(game, "next_round", {"first": result, "replay": mirror})
	return {"status": "censored", "reason": "round_limit", "outcome": game.outcome(), "rounds": rounds, "coverage": coverage, "replay_verified": true, "snapshot": game.snapshot(), "save_json": game.snapshot_json()}

static func failed(game, stage: String, detail: Dictionary) -> Dictionary:
	return {"status": "failed", "stage": stage, "detail": detail, "snapshot": game.snapshot(), "save_json": game.snapshot_json()}
