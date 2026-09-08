extends "res://Scripts/Sim/U13HumbabaTestRunner.gd"

const Candidates = preload("res://Scripts/Sim/U13HumbabaCandidates.gd")
const Bot = preload("res://Scripts/Sim/U13RandomLegal.gd")
const Batch = preload("res://Scripts/Sim/U13RandomBatch.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Telemetry = preload("res://Scripts/Sim/U13FrequencyTelemetry.gd")


func _run() -> void:
	print("HUMBABA RANDOM chooser")
	_chooser()
	print("HUMBABA RANDOM trial")
	var trial: Dictionary = Batch.trial(
		"humbaba-random-gate", 1, Callable(self, "_progress"), "humbaba"
	)
	if _check(trial.action != "invalid", "humbaba_random_batch_completes"):
		print("HUMBABA RANDOM replay")
		var replay: Dictionary = Batch.trial(
			"humbaba-random-gate", 1, Callable(self, "_progress"), "humbaba"
		)
		_check(trial == replay, "humbaba_random_batch_replays")
		_check(
			trial.summary.powers.get("0:MusterTheFaithful", {}).get("declared", 0) == 1,
			"humbaba_random_batch_exercises_muster"
		)
		_check(
			trial.summary.endurance.get("0", {}).get("checks", 0) == 1,
			"humbaba_random_batch_measures_endurance_opportunity"
		)
		var report: Dictionary = Batch.report([trial], 1)
		_check(
			report.humbaba_profile == Content.POLICY and report.roster == ["Humbaba", "Gremory"],
			"humbaba_batch_pins_profile_and_roster"
		)
	_telemetry()
	print("U13 Humbaba random failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _progress(_seed: String, round_number: int) -> void:
	print("HUMBABA RANDOM round=", round_number)


func _chooser() -> void:
	var owner = Content.new().create_combat_match()
	if not _check(
		owner.start("humbaba-chooser", Scenario.world(), [0, 1]).action != "invalid",
		"humbaba_random_owner_starts"
	):
		return
	while owner.next_hook() != Timeline.SUBMISSION_LOCK:
		if owner.run_next_hook().action == "invalid":
			_check(false, "humbaba_random_opening")
			return
	var before: Dictionary = owner.snapshot()
	# Powers-only vocabulary keeps this check small; the actual batch below
	# separately exercises full Construction/Hunt/Siege/Ward plans.
	var provider: Callable = func(match_owner, pid: int) -> Dictionary:
		var result: Dictionary = Candidates.enumerate(match_owner, pid)
		result.orders = []
		return result
	var first: Dictionary = Bot.plan(owner, 0, provider)
	Rng.draw("humbaba-chooser", "unrelated", "UNRELATED_TEST", 0, 99)
	var again: Dictionary = Bot.plan(owner, 0, provider)
	_check(first == again and first.action != "invalid", "muster_keyed_choice_replays")
	if first.action != "invalid":
		_check(
			first.powers.size() == 1 and first.powers[0].target.lane in ["Lord", "Castle"],
			"muster_random_legal_lane"
		)
		_check(
			owner.preview_submission(0, first.powers, first.order).action != "invalid",
			"muster_random_submission_authoritatively_legal"
		)
	_check(owner.snapshot() == before, "muster_random_choice_is_pure")
	var wrong: Dictionary = Candidates.source(0, 1, "not_a_lane")
	var illegal_provider: Callable = func(_match_owner, _pid: int) -> Dictionary:
		return {"action": "candidate_vocabulary", "powers": [wrong], "orders": []}
	var refused: Dictionary = Bot.plan(owner, 0, illegal_provider)
	_check(
		refused.action != "invalid" and refused.powers.is_empty(),
		"muster_random_cannot_bypass_legality"
	)


func _telemetry() -> void:
	var owner = Content.new().create_combat_match()
	owner.start("endurance-metrics", Scenario.world(), [0, 1])
	var telemetry = Telemetry.new()
	telemetry.begin(1, owner.player_view(0, 0))
	var world: Dictionary = owner.snapshot().world
	_add_unit(world, 0, "Penitent", 1)
	_add_unit(world, 0, "Penitent", 1)
	var checked: Dictionary = Content.endurance(_context(world, Timeline.END_MARCHING_CHECKS))
	var events: Array = []
	for envelope in checked.events:
		events.append(envelope.event)
	telemetry.consume(events)
	var row: Dictionary = telemetry.finish(false)
	_check(
		row.endurance["0"] == {"checks": 1, "threshold_met": 1, "qualifying_bodies": 2},
		"endurance_counts_opportunity_and_bodies_separately"
	)
	_check(
		row.tears_by_source.get("EnduranceOfTheFaithful") == 1,
		"endurance_telemetry_tear_is_once_not_per_body"
	)
