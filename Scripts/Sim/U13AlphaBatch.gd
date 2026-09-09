extends RefCounted

const Scenario = preload("res://Scripts/Sim/U13AlphaScenario.gd")
const Batch = preload("res://Scripts/Sim/U13RandomBatch.gd")
const Telemetry = preload("res://Scripts/Sim/U13FrequencyTelemetry.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const VERSION: String = "U13_FOUR_LORD_ALPHA_V1"


static func trial(
	pair: Array,
	seed_value: String,
	rounds: int,
	resume: bool,
	performance: Dictionary,
	progress: Callable = Callable()
) -> Dictionary:
	if not Scenario.pair_valid(pair) or seed_value.is_empty() or rounds < 1 or rounds > 100:
		return Data.invalid("alpha_limits_invalid")
	var owner = Scenario.create_owner()
	var started: Dictionary = owner.start(seed_value, Scenario.world(pair), [0, 1])
	if started.action == "invalid":
		return started
	return Batch.run_started(
		owner,
		Callable(Scenario, "enumerate"),
		{
			"seed": seed_value,
			"rounds": rounds,
			"roster": pair,
			"mode": "alpha",
			"audit": true,
			"performance": performance,
			"progress": progress,
			"restore_factory": Callable(Scenario, "create_owner") if resume else Callable()
		}
	)


static func compare(first: Dictionary, replay: Dictionary) -> Dictionary:
	if (
		first.get("action") != "batch_trial_complete"
		or replay.get("action") != "batch_trial_complete"
	):
		return {
			"action": "invalid", "reason": "alpha_trial_failed", "first": first, "replay": replay
		}
	if first != replay:
		var left: Array = first.get("hook_trace", [])
		var right: Array = replay.get("hook_trace", [])
		for index in range(mini(left.size(), right.size())):
			if left[index] != right[index]:
				return {
					"action": "invalid",
					"reason": "alpha_hook_diverged",
					"first": left[index],
					"replay": right[index]
				}
		return Data.invalid("alpha_replay_diverged_outside_hook_trace")
	return {"action": "alpha_replay_verified"}


static func shard_valid(shard: Dictionary, pair: Array, seed_value: String, rounds: int) -> bool:
	var run: Dictionary = shard.get("trial", {})
	return (
		shard.get("schema_version") == VERSION
		and shard.get("fixture") == Scenario.VERSION
		and shard.get("runtime") == "4.7.2.stable"
		and shard.get("replay_verified") == true
		and run.get("action") == "batch_trial_complete"
		and run.get("roster") == pair
		and run.get("seed") == seed_value
		and run.get("rounds", []).size() == rounds
		and run.get("checkpoints", []).size() == rounds
		and not run.get("hook_trace", []).is_empty()
		and run.get("termination") == "round_limit"
	)


static func report(shards: Array, expected: Array) -> Dictionary:
	if expected.is_empty() or shards.size() != expected.size():
		return Data.invalid("alpha_manifest_incomplete")
	var seen: Dictionary = {}
	var pairs: Dictionary = {}
	var rows: Array = []
	var coverage: Dictionary = {}
	for lord in Scenario.LORDS:
		coverage[lord] = {}
		for power in Scenario.POWERS[lord]:
			coverage[lord][power] = {"declared": 0, "resolved": 0, "fizzled": 0}
	for index in range(expected.size()):
		var entry: Dictionary = expected[index]
		var pair: Array = entry.pair
		var key: String = JSON.stringify([pair, entry.seed])
		if (
			seen.has(key)
			or not Scenario.pair_valid(pair)
			or not shard_valid(shards[index], pair, entry.seed, int(entry.rounds))
		):
			return Data.invalid("alpha_manifest_mismatch_or_duplicate")
		seen[key] = true
		pairs[JSON.stringify(pair)] = true
		var run: Dictionary = shards[index].trial
		rows.append_array(run.rounds)
		for pid in [0, 1]:
			for power in Scenario.POWERS[pair[pid]]:
				var counts: Dictionary = run.summary.powers.get(str(pid) + ":" + power, {})
				for counter in ["declared", "resolved", "fizzled"]:
					coverage[pair[pid]][power][counter] += int(counts.get(counter, 0))
	var missing: Array = []
	for lord in coverage:
		for power in coverage[lord]:
			if coverage[lord][power].resolved == 0:
				missing.append(lord + ":" + power)
	return {
		"action": "alpha_report_complete",
		"schema_version": VERSION,
		"fixture": Scenario.VERSION,
		"runtime": "4.7.2.stable",
		"scope": "bounded rules exercise; frequency and replay evidence, not win rates or balance",
		"matrix_complete": pairs.size() == 16,
		"ordered_pairs": pairs.size(),
		"verified_shards": shards.size(),
		"manifest": expected,
		"powers_by_lord": coverage,
		"powers_without_resolution": missing,
		"coverage_note":
		"A successful replay does not prove every power or interaction was exercised. Review missing powers and run focused interaction gates.",
		"summary_by_seat": Telemetry.summarize(rows),
		"sampling_note":
		"Only baseline rounds counted; seat 0/1 changes Lord across pairings. Examine individual shards for per-pair density distributions. Finite starting hands; no normal draws. Pending effects at the round limit are censored.",
		"absent_systems":
		[
			"normal draws",
			"victory",
			"full Veil progression",
			"Guard deployment/Summon/Profane",
			"non-artillery Castle printed effects",
			"later Lords"
		],
		"trials": shards
	}


static func timing(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {"n": 0}
	var values: Array = []
	var total: float = 0.0
	var slowest: Dictionary = {}
	for sample in samples:
		values.append(int(sample.ms))
		total += float(sample.ms)
		if slowest.is_empty() or int(sample.ms) > int(slowest.ms):
			slowest = sample
	values.sort()
	return {
		"n": values.size(),
		"mean_ms": total / float(values.size()),
		"p95_ms": values[maxi(0, int(ceil(float(values.size()) * 0.95)) - 1)],
		"max_ms": values.back(),
		"slowest": slowest
	}
