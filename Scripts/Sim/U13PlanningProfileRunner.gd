extends SceneTree

const Scenario = preload("res://Scripts/Sim/U13AlphaScenario.gd")
const Probe = preload("res://Scripts/Sim/U13PlanningProbe.gd")
const Bot = preload("res://Scripts/Sim/U13RandomLegal.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
var failures: int = 0
var rows: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lord: String = "Humbaba"
	var output: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lord="):
			lord = arg.trim_prefix("--lord=")
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		else:
			failures += 1
	var version: Dictionary = Engine.get_version_info()
	if version.major != 4 or version.minor != 7 or version.patch != 2 or version.status != "stable":
		failures += 1
	if lord not in Scenario.LORDS or output.is_empty() or failures != 0:
		print("FAIL planning_profile_arguments_or_runtime")
		quit(1)
		return
	var pair: Array = [lord, "Gremory" if lord == "Humbaba" else "Humbaba"]
	var owner = Scenario.create_owner()
	if not _check(
		owner.start("u13-alpha-v1:0", Scenario.world(pair), [0, 1]).action != "invalid",
		"profile_start"
	):
		quit(1)
		return
	for round_number in [1, 2]:
		while owner.next_hook() != Timeline.SUBMISSION_LOCK:
			if not _check(owner.run_next_hook().action != "invalid", "profile_reach_choice"):
				quit(1)
				return
		var raw: Dictionary = owner.snapshot()
		var expected: Dictionary = {}
		var expected_domains: Array = []
		# ABBA reduces first-run/order bias. Timings exclude restore and disk IO.
		for mode in [false, true, true, false]:
			var probe = Probe.new(
				owner._policy_id,
				owner._rules,
				owner._validators,
				owner._resolvers,
				owner._projector,
				owner._hook_handler,
				owner._context_hook,
				owner._content_owner,
				owner._world_validator,
				owner._order_handler,
				owner._order_screen,
				owner._order_validator
			)
			if not _check(
				probe.restore(JSON.parse_string(JSON.stringify(raw))).action != "invalid",
				"profile_json_restore"
			):
				quit(1)
				return
			probe.reference_mode = mode
			print(
				"PLANNING ",
				lord,
				" round=",
				round_number,
				" mode=",
				"reference" if mode else "optimized"
			)
			var before: Dictionary = probe.snapshot()
			var started: int = Time.get_ticks_usec()
			var plan: Dictionary = Bot.plan(probe, 0, Callable(Scenario, "enumerate"))
			var elapsed: float = (Time.get_ticks_usec() - started) / 1000.0
			if not _check(plan.action == "bot_plan", "profile_plan_legal"):
				quit(1)
				return
			if expected.is_empty():
				expected = plan.duplicate(true)
				expected_domains = probe.domains.duplicate(true)
			_check(plan == expected, "profile_same_keyed_plan")
			_check(probe.domains == expected_domains, "profile_same_complete_legal_domains")
			_check(probe.snapshot() == before, "profile_owner_unchanged")
			var row: Dictionary = {
				"lord": lord,
				"round": round_number,
				"mode": "reference" if mode else "optimized",
				"ms": elapsed,
				"stages": probe.samples.duplicate(true),
				"plan_digest": JSON.stringify(plan, "", true).sha256_text()
			}
			rows.append(row)
			print("PLANNING SAMPLE ", JSON.stringify(row))
		if failures != 0:
			break
		if round_number == 1:
			if (
				not _check(
					owner.submit(0, expected.powers, expected.order).action != "invalid",
					"profile_submit"
				)
				or not _check(owner.submit(1, [], {}).action != "invalid", "profile_opponent_pass")
			):
				break
			while not owner.next_hook().is_empty():
				if not _check(owner.run_next_hook().action != "invalid", "profile_round_progress"):
					break
			if (
				failures != 0
				or not _check(
					owner.begin_next_round([1, 0]).action != "invalid", "profile_next_round"
				)
			):
				break
	var report: Dictionary = {
		"schema_version": "U13_PLANNING_PROFILE_V1",
		"runtime": version.string,
		"fixture": Scenario.VERSION,
		"pair": pair,
		"seed": "u13-alpha-v1:0",
		"samples": rows,
		"failures": failures,
		"equivalent": failures == 0,
		"note":
		"ABBA total planning wall time; restore excluded; reference uses pre-optimization enumeration and full transactions. No FPS inference."
	}
	var file = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		failures += 1
	else:
		file.store_string(JSON.stringify(report, "\t", true) + "\n")
		file.close()
	print("U13 planning profile completed: OK" if failures == 0 else "FAIL planning_profile")
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL ", label)
	return ok
