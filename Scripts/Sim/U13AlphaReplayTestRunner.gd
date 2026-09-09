extends SceneTree

const Alpha = preload("res://Scripts/Sim/U13AlphaBatch.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok


func _run() -> void:
	# A single round, two owners. The full 16-pair matrix has its own bounded
	# processes; it must never be folded into one 30-second foundation suite.
	var first: Dictionary = Alpha.trial(["Kalligan", "Humbaba"], "alpha-replay-gate", 1, false, {})
	var replay: Dictionary = Alpha.trial(["Kalligan", "Humbaba"], "alpha-replay-gate", 1, true, {})
	if _check(
		Alpha.compare(first, replay).action != "invalid",
		"alpha_full_random_plan_resumes_from_json_and_replays"
	):
		_check(
			first.checkpoints.size() == 1 and first.hook_trace.size() > 10,
			"alpha_gate_captures_checkpoint_and_hook_trace"
		)
		var changed: Dictionary = replay.duplicate(true)
		changed.hook_trace[0].world = "corrupt"
		_check(
			Alpha.compare(first, changed).reason == "alpha_hook_diverged",
			"alpha_replay_localizes_divergent_hook"
		)
		var shard: Dictionary = {
			"schema_version": Alpha.VERSION,
			"fixture": Alpha.Scenario.VERSION,
			"runtime": "4.7.2.stable",
			"replay_verified": true,
			"trial": first
		}
		var expected: Dictionary = {"pair": first.roster, "seed": first.seed, "rounds": 1}
		var report: Dictionary = Alpha.report([shard], [expected])
		_check(
			(
				report.action != "invalid"
				and not report.matrix_complete
				and report.summary_by_seat.round_samples == 1
			),
			"alpha_subset_report_does_not_claim_full_matrix_or_count_replay"
		)
		_check(
			not report.powers_without_resolution.is_empty(),
			"alpha_report_exposes_unexercised_powers"
		)
		_check(
			Alpha.report([shard, shard], [expected, expected]).action == "invalid",
			"alpha_duplicate_shard_rejected"
		)
	print("U13 alpha replay failures: %d" % failures)
	quit(0 if failures == 0 else 1)
