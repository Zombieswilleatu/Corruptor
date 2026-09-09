extends SceneTree

const Alpha = preload("res://Scripts/Sim/U13AlphaBatch.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func _run() -> void:
	var pairs: Array = Alpha.Scenario.matrix()
	var seen: Dictionary = {}
	var mirrors: int = 0
	for pair in pairs:
		seen[JSON.stringify(pair)] = true
		mirrors += 1 if pair[0] == pair[1] else 0
		var world: Dictionary = Alpha.Scenario.world(pair)
		var active: Array = [0, 0]
		var engines: Array = [0, 0]
		for entity in world.entities.entities:
			if entity.kind == "castle":
				active[entity.owner] += 1 if entity.attributes.construction_state == "active" else 0
				engines[entity.owner] += 1 if entity.attributes.castle_type == "SiegeEngine" else 0
		_check(active == [3, 3] and engines == [2, 2], "alpha_symmetric_fixture_" + str(pair))
	_check(seen.size() == 16 and mirrors == 4, "alpha_all_ordered_pairs_and_mirrors")
	_check(
		not Alpha.Scenario.pair_valid(["Gremory", "Orias"]), "alpha_rejects_unimplemented_roster"
	)
	_check(Alpha.report([], []).action == "invalid", "alpha_empty_matrix_is_not_green")
	var samples: Array = [{"ms": 2}, {"ms": 9}, {"ms": 4}]
	var timing: Dictionary = Alpha.timing(samples)
	_check(
		timing.n == 3 and timing.mean_ms == 5.0 and timing.max_ms == 9 and timing.p95_ms == 9,
		"alpha_timing_summary"
	)
	var shard: Dictionary = {
		"schema_version": Alpha.VERSION,
		"fixture": Alpha.Scenario.VERSION,
		"runtime": "4.7.2.stable",
		"replay_verified": true,
		"trial":
		{
			"action": "batch_trial_complete",
			"roster": ["Kalligan", "Humbaba"],
			"seed": "test",
			"rounds": [{}],
			"checkpoints": [{}],
			"hook_trace": [{}],
			"termination": "round_limit"
		}
	}
	_check(
		Alpha.shard_valid(shard, ["Kalligan", "Humbaba"], "test", 1),
		"alpha_manifest_accepts_matching_identity"
	)
	for fault in ["pair", "seed", "rounds", "replay", "fixture", "checkpoint"]:
		var bad: Dictionary = shard.duplicate(true)
		match fault:
			"pair":
				bad.trial.roster.reverse()
			"seed":
				bad.trial.seed = "stale"
			"rounds":
				bad.trial.rounds.clear()
			"replay":
				bad.replay_verified = false
			"fixture":
				bad.fixture = "old"
			"checkpoint":
				bad.trial.checkpoints.clear()
		_check(
			not Alpha.shard_valid(bad, ["Kalligan", "Humbaba"], "test", 1),
			"alpha_rejects_mismatched_" + fault
		)
	var expected: Array = [{"pair": ["Kalligan", "Humbaba"], "seed": "test", "rounds": 1}]
	_check(Alpha.report([], expected).action == "invalid", "alpha_missing_shard_rejected")
	print("U13 alpha manifest failures: %d" % failures)
	quit(0 if failures == 0 else 1)
