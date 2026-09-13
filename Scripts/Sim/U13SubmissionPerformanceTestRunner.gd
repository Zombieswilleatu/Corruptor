extends SceneTree

const Batch = preload("res://Scripts/Sim/U13FullMatchBatch.gd")
const Game = Batch.Game
const Bot = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const Reference = preload("res://Scripts/Sim/U13SubmissionReference.gd")
var checks: int = 0
var failures: int = 0
var cases: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
	return ok

func same(a, b) -> bool:
	return var_to_bytes(a) == var_to_bytes(b)

func opening(index: int, compact: bool = true):
	var setup: Dictionary = Batch.setup(index)
	var game = Game.new()
	return game if check(game.start(setup.seed, setup.lords, setup.castles, compact).action != "invalid", "opening " + str(index)) else null

func run() -> void:
	var output: String = ""
	var checkpoints: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--checkpoint="): checkpoints.append(arg.trim_prefix("--checkpoint="))
		else:
			check(false, "unknown argument " + arg)
			quit(1)
			return
	boundaries()
	for index in [9, 19, 29, 39, 49, 59, 69, 79, 8]:
		var game = opening(index)
		if game != null: compare_round(game, "opening-%d" % index, index % 2 == 0)
	# A bounded history stress fixture separates old event volume from world
	# complexity. These valid private/public records do not change game rules.
	for compact in [true, false]:
		var game = opening(79, compact)
		if game == null: continue
		var event: Dictionary = {"type": "SUBMISSION_HISTORY_PROBE", "text": "history fixture", "data": {"private_value": 5}}
		for index in range(2000):
			game._owner._events.append(event, [event, null] if index % 2 == 0 else [event, event])
		compare_round(game, "history-2000-compact-%s" % compact, compact)
	for path in checkpoints:
		var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not check(typeof(raw) == TYPE_DICTIONARY and typeof(raw.get("save_json")) == TYPE_STRING, "checkpoint envelope " + path.get_file()): continue
		for repeat in range(3):
			var game = Game.new()
			if check(game.restore_json(raw.save_json).action != "invalid", "checkpoint restore"):
				compare_round(game, "%s-repeat-%d" % [path.get_file(), repeat], repeat % 2 == 0)
	var totals: Dictionary = {"reference_ms": 0.0, "transaction_ms": 0.0}
	for row in cases:
		for key in totals: totals[key] += row[key]
	var report: Dictionary = {"engine": Engine.get_version_info().string, "os": OS.get_name(), "processor": OS.get_processor_name(), "logical_processors": OS.get_processor_count(), "reference_commit": "e680d28673a7a30d26cf8f2ff3c5de97b807adbe", "scope": "joint submission only; replay, planning, save and comparisons untimed", "checks": checks, "failures": failures, "totals": totals, "cases": cases}
	if not output.is_empty():
		var file = FileAccess.open(output, FileAccess.WRITE)
		if check(file != null, "submission report opened"): file.store_string(JSON.stringify(report, "\t"))
	print("Submission totals (commit only): ", JSON.stringify(totals))
	print("U13 submission performance failures: %d" % failures)
	quit(1 if failures else 0)

func compare_round(game, label: String, reference_first: bool) -> void:
	var reference = Reference.new()
	if not check(reference.restore(game.snapshot()).action != "invalid", label + " reference restore"): return
	var planning: Dictionary = Bot.to_planning(game)
	if not check(planning.action == "game_planning" and same(planning, Bot.to_planning(reference)) and same(game.snapshot(), reference.snapshot()), label + " exact planning boundary"): return
	var before: Dictionary = game.snapshot()
	var plans: Array = [Bot.plan(game._owner, 0), Bot.plan(game._owner, 1)]
	if not check(plans.all(func(p): return p.action == "bot_plan") and same(plans, [Bot.plan(reference._owner, 0), Bot.plan(reference._owner, 1)]) and same(before, game.snapshot()) and same(before, reference.snapshot()), label + " exact read-only plans"): return
	var parent = game._owner
	var old: Dictionary
	var fast: Dictionary
	if reference_first:
		old = measured_submit(reference, plans)
		fast = measured_submit(game, plans)
	else:
		fast = measured_submit(game, plans)
		old = measured_submit(reference, plans)
	if not check(fast.result.action == "game_submitted" and same(fast.result, old.result) and same(game.snapshot(), reference.snapshot()), label + " exact joint submission"): return
	check(game._owner != parent and same(parent.snapshot(), before), label + " accepted transaction isolates original owner")
	var accepted: Dictionary = game.snapshot()
	plans[0].order["mutation_probe"] = true
	check(same(game.snapshot(), accepted) and same(reference.snapshot(), accepted), label + " submitted inputs remain caller owned")
	var hooks: int = 0
	while not game._owner.next_hook().is_empty():
		var hook: String = game._owner.next_hook()
		var result: Dictionary = game.step()
		if not check(result.action != "invalid" and same(result, reference.step()) and same(game.snapshot(), reference.snapshot()), label + " exact hook " + hook): return
		hooks += 1
	for pid in [0, 1]:
		check(same(game.player_view(pid), reference.player_view(pid)), label + " exact visible history " + str(pid))
	var restored = Game.new()
	check(restored.restore_json(game.snapshot_json()).action != "invalid" and same(restored.snapshot(), game.snapshot()) and same(game.outcome(), reference.outcome()), label + " exact external save and outcome")
	check(same(parent.snapshot(), before), label + " resolving child leaves original untouched")
	cases.append({"case": label, "round": before.runtime.round, "history_rows": before.events.rows.size(), "compact_events": game._owner._content_owner.batch_events, "reference_ms": old.ms, "transaction_ms": fast.ms, "hooks_verified": hooks})
	print("PROFILE ", label, " reference=", snappedf(old.ms, 0.1), "ms transaction=", snappedf(fast.ms, 0.1), "ms history=", before.events.rows.size())

func measured_submit(game, plans: Array) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = game.submit(plans)
	return {"result": result, "ms": (Time.get_ticks_usec() - started) / 1000.0}

func boundaries() -> void:
	var game = opening(79)
	if game == null or not check(Bot.to_planning(game).action == "game_planning", "boundary planning"): return
	var event: Dictionary = {"type": "SUBMISSION_PRIVATE_PROBE", "text": "private", "data": {"value": 5}}
	game._owner._events.append(event, [event, null])
	var reference = Reference.new()
	if not check(reference.restore(game.snapshot()).action != "invalid", "boundary reference restore"): return
	var before: Dictionary = game.snapshot()
	var original_owner = game._owner
	var valid: Array = [Bot.plan(game._owner, 0), Bot.plan(game._owner, 1)]
	if not check(valid.all(func(p): return p.action == "bot_plan"), "boundary legal pair"): return
	var invalids: Array = [[], [valid[0]], [null, valid[1]], [valid[0], null]]
	for pid in [0, 1]:
		var malformed: Array = valid.duplicate(true)
		malformed[pid].powers = "invalid"
		invalids.append(malformed)
		var illegal: Array = valid.duplicate(true)
		illegal[pid].order = {"action": "Ward", "lane": "Lord", "card_ids": ["missing-card"]}
		invalids.append(illegal)
	for index in range(invalids.size()):
		var result: Dictionary = game.submit(invalids[index])
		check(result.action == "invalid" and same(result, reference.submit(invalids[index])) and same(game.snapshot(), before) and same(reference.snapshot(), before) and game._owner == original_owner, "invalid pair rolls back both seats " + str(index))
	# Old history remains isolated through all public reads of the fork.
	var child = original_owner._clone()
	var snapshot: Dictionary = child.snapshot()
	snapshot.events.rows[-1].event.data.value = 100
	var visible: Dictionary = child.player_view(0)
	visible.events[-1].data.value = 200
	child._events.append(event, [event, null])
	check(same(original_owner.snapshot(), before) and child._event_cursor() == original_owner._event_cursor() + 1, "fork snapshots, projections and append cannot change original history")
	check(not child.player_view(1).events.any(func(e): return e.type == "SUBMISSION_PRIVATE_PROBE"), "private history remains private after fork")
	for corruption in ["resource", "history", "clock"]:
		var bad: Dictionary = before.duplicate(true)
		if corruption == "resource": bad.world.players[0].resources.souls = -1
		elif corruption == "history": bad.events.rows[-1].views = [event]
		else: bad.cooldowns.round += 1
		check(game.restore(bad).action == "invalid" and same(game.snapshot(), before) and game._owner == original_owner, "external restore still rejects " + corruption + " atomically")
	original_owner._cooldowns._round_number += 1
	var inconsistent: Dictionary = game.snapshot()
	check(game.submit(valid).action == "invalid" and same(game.snapshot(), inconsistent) and game._owner == original_owner, "internal transaction still rejects inconsistent temporal state")
	original_owner._cooldowns._round_number -= 1
	check(same(game.submit(valid), reference.submit(valid)) and same(game.snapshot(), reference.snapshot()), "valid retry after rejections matches original path")
	var sealed: Dictionary = game.snapshot()
	check(game.submit(valid).action == "invalid" and reference.submit(valid).action == "invalid" and same(game.snapshot(), sealed) and same(reference.snapshot(), sealed), "already sealed plans cannot be committed again")
