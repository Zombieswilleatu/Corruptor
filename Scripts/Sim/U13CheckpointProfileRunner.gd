extends SceneTree

const Reference = preload("res://Scripts/Sim/U13PowerPlanningReference.gd")
const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
var report: Dictionary = {"version": "U13_CHECKPOINT_PROFILE_V1", "samples": [], "failures": []}
var output: String = ""
var phase: String = ""
var started: int = 0

func _initialize() -> void:
	call_deferred("run")

func begin(label: String) -> void:
	phase = label
	print("PROFILE START ", label)
	started = Time.get_ticks_usec()

func end() -> void:
	var ms: float = (Time.get_ticks_usec() - started) / 1000.0
	report.samples.append({"phase": phase, "ms": ms})
	print("PROFILE ", phase, " ", snappedf(ms, 0.001), " ms")
	write_report()

func write_report() -> void:
	if output.is_empty():
		return
	var file = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		print("FAIL cannot write profile report: ", output)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	file.flush()
	if file.get_error() != OK:
		print("FAIL cannot finish profile report: ", output)
		quit(1)
	file.close()

func require(ok: bool, label: String) -> bool:
	if not ok:
		report.failures.append(label)
		print("FAIL ", label)
		write_report()
		quit(1)
	return ok

func run() -> void:
	var checkpoint: String = ""
	var compact_events: bool = false
	var compare_reference: bool = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--checkpoint="):
			checkpoint = arg.trim_prefix("--checkpoint=")
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg == "--compact-events":
			compact_events = true
		elif arg == "--compare-reference":
			compare_reference = true
		else:
			if not require(false, "unknown argument " + arg):
				return
	if not require(not checkpoint.is_empty() and not output.is_empty() and FileAccess.file_exists(checkpoint), "checkpoint and output required"):
		return
	report["runtime"] = Engine.get_version_info().string
	begin("checkpoint_read")
	var raw = JSON.parse_string(FileAccess.get_file_as_string(checkpoint))
	end()
	if not require(typeof(raw) == TYPE_DICTIONARY and typeof(raw.get("save_json")) == TYPE_STRING, "valid checkpoint envelope"):
		return
	report["identity"] = raw.get("identity", {})
	report["checkpoint_round"] = raw.get("round", 0)
	var game = Game.new()
	begin("checkpoint_restore")
	var result: Dictionary = game.restore_json(raw.save_json)
	end()
	if not require(result.action != "invalid", "checkpoint restore " + str(result)):
		return
	if compact_events:
		begin("batch_history_conversion")
		var converted: Dictionary = game.snapshot()
		if not converted.policy_id.ends_with(":" + Game.Content.BATCH_EVENTS_VERSION):
			converted.policy_id += ":" + Game.Content.BATCH_EVENTS_VERSION
		converted.events.rows = converted.events.rows.filter(func(row): return row.event.type not in Game.Content.BATCH_SAMPLE_EVENTS)
		result = game.restore(converted)
		end()
		if not require(result.action != "invalid", "batch history conversion"):
			return
	report["compact_events"] = game._owner._content_owner.batch_events
	begin("opening_snapshot")
	var initial: Dictionary = game.snapshot()
	end()
	report["size"] = {"save_chars": raw.save_json.length(), "event_rows": initial.events.rows.size(), "entities": initial.world.entities.entities.size(), "world_bytes": var_to_bytes(initial.world).size(), "event_bytes": var_to_bytes(initial.events).size()}
	begin("to_planning")
	result = game.to_planning(true)
	end()
	if not require(result.action == "game_planning", "reach planning " + str(result)):
		return
	begin("planning_snapshot")
	var before: Dictionary = game.snapshot()
	end()
	var plans: Array = []
	for pid in [0, 1]:
		begin("plan_%d" % pid)
		var plan: Dictionary = game.plan(pid)
		end()
		if not require(plan.action != "invalid", "legal plan " + str(plan)):
			return
		plans.append(plan)
	begin("planning_unchanged")
	var same: bool = game.snapshot() == before
	end()
	if not require(same, "planning is read only"):
		return
	report["plans"] = plans
	if compare_reference:
		begin("reference_restore")
		var reference = Reference.from_owner(game._owner)
		end()
		if not require(reference != null, "reference owner restore"):
			return
		for pid in [0, 1]:
			var sources: Array = Game.Scenario.enumerate(game._owner, pid).powers
			begin("reference_power_domain_%d" % pid)
			var expected: Array = reference.legal_power_candidates(pid, sources)
			end()
			begin("optimized_power_domain_%d" % pid)
			var actual: Array = game._owner.legal_power_candidates(pid, sources)
			end()
			if not require(actual == expected, "same complete power domain " + str(pid)):
				return
		if not require(reference.snapshot() == before and game.snapshot() == before, "domain checks are read only"):
			return
		report["reference_domains_equal"] = true
	begin("save_encode")
	var encoded: String = game.snapshot_json()
	end()
	var replay = Game.new()
	begin("save_restore")
	result = replay.restore_json(encoded)
	end()
	if not require(result.action != "invalid", "planning restore"):
		return
	for entry in [["submit", game], ["replay_submit", replay]]:
		begin(entry[0])
		result = entry[1].submit(plans)
		end()
		if not require(result.action != "invalid", entry[0] + " " + str(result)):
			return
	while not game._owner.next_hook().is_empty():
		var hook: String = game._owner.next_hook()
		begin("hook:" + hook)
		result = game.step()
		end()
		if not require(result.action != "invalid", hook + " " + str(result)):
			return
	begin("replay_resolution")
	result = replay.finish_round()
	end()
	if not require(result.action != "invalid", "replay resolution " + str(result)):
		return
	begin("final_snapshots")
	var final_state: Dictionary = game.snapshot()
	var replay_state: Dictionary = replay.snapshot()
	end()
	begin("final_compare")
	same = final_state == replay_state
	end()
	if not require(same, "exact replay"):
		return
	begin("final_hash")
	report["final_hash"] = JSON.stringify(final_state, "", true, true).sha256_text()
	var gameplay: Dictionary = final_state.duplicate(true)
	gameplay.policy_id = gameplay.policy_id.trim_suffix(":" + Game.Content.BATCH_EVENTS_VERSION)
	gameplay.events.rows = gameplay.events.rows.filter(func(row): return row.event.type not in Game.Content.BATCH_SAMPLE_EVENTS)
	report["gameplay_hash"] = JSON.stringify(gameplay, "", true, true).sha256_text()
	report["final_save_chars"] = game.snapshot_json().length()
	end()
	report["outcome"] = game.outcome()
	report["success"] = true
	write_report()
	print("U13 checkpoint profile failures: 0")
	quit(0)
