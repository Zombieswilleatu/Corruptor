extends RefCounted

const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Opening = preload("res://Scripts/Sim/U13SmokeSession.gd")
const Candidates = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
const Bot = preload("res://Scripts/Sim/U13RandomLegal.gd")
const Telemetry = preload("res://Scripts/Sim/U13FrequencyTelemetry.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const Core = preload("res://Scripts/Sim/U13CoreScenario.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Construction = preload("res://Scripts/Sim/U13Construction.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Rout = preload("res://Scripts/Sim/U13Rout.gd")
const VERSION: String = "U13_RANDOM_BATCH_V1"


static func trial(
	seed_value: String,
	round_limit: int,
	progress: Callable = Callable(),
	roster_mode: String = "gremory",
	trace_times: bool = false
) -> Dictionary:
	if (
		seed_value.is_empty()
		or round_limit < 1
		or round_limit > 100
		or roster_mode not in ["gremory", "deimos", "mixed", "construction", "loadout"]
	):
		return Data.invalid("batch_limits_invalid")
	var content = (
		Gremory.new()
		if roster_mode == "gremory"
		else Deimos.new(roster_mode in ["construction", "loadout"], roster_mode == "loadout")
	)
	var roster: Array = (
		["Gremory", "Gremory"]
		if roster_mode == "gremory"
		else (["Deimos", "Deimos"] if roster_mode == "deimos" else ["Deimos", "Gremory"])
	)
	var owner = content.create_combat_match()
	var opening: Dictionary = (
		Opening._initial_world()
		if roster_mode == "gremory"
		else (
			Core.duplicate_world()
			if roster_mode == "loadout"
			else (
				Core.construction_world() if roster_mode == "construction" else Core.world(roster)
			)
		)
	)
	var provider: Callable = (
		Callable(Candidates, "enumerate")
		if roster_mode == "gremory"
		else Callable(Core, "enumerate")
	)
	var started: Dictionary = owner.start(seed_value, opening, [0, 1])
	if started.action == "invalid":
		return started
	var telemetry = Telemetry.new()
	var decisions: Array = []
	var unchanged_rounds: int = 0
	var prior_world_digest: String = ""
	for round_number in range(1, round_limit + 1):
		if progress.is_valid():
			progress.call(seed_value, round_number)
		telemetry.begin(round_number, owner.player_view(0, 0))
		var both_passed: bool = true
		var hook_count: int = 0
		while not owner.next_hook().is_empty():
			hook_count += 1
			if hook_count > 32:
				return Data.invalid("batch_hook_progress_limit")
			var hook: String = owner.next_hook()
			var cursor: int = owner._event_cursor()
			if hook == Timeline.SUBMISSION_LOCK:
				var plans: Array = []
				# Compute both complete choices before either player submits.
				for player_id in [0, 1]:
					var plan_started_ms: int = Time.get_ticks_msec() if trace_times else 0
					var plan: Dictionary = Bot.plan(owner, player_id, provider)
					if trace_times:
						print(
							"BATCH TIMING round=",
							round_number,
							" player=",
							player_id,
							" planning_ms=",
							Time.get_ticks_msec() - plan_started_ms
						)
					if plan.action == "invalid":
						return plan
					plans.append(plan)
					both_passed = both_passed and plan.powers.is_empty() and plan.order.is_empty()
					decisions.append({"round": round_number, "player_id": player_id, "plan": plan})
				for player_id in [0, 1]:
					var accepted: Dictionary = owner.submit(
						player_id, plans[player_id].powers, plans[player_id].order
					)
					if accepted.action == "invalid":
						return accepted
			var hook_started_ms: int = Time.get_ticks_msec() if trace_times else 0
			var result: Dictionary = owner.run_next_hook()
			if trace_times and hook in [Timeline.SUBMISSION_LOCK, Timeline.MARCHING]:
				print(
					"BATCH TIMING round=",
					round_number,
					" hook=",
					hook,
					" elapsed_ms=",
					Time.get_ticks_msec() - hook_started_ms
				)
			if result.action == "invalid":
				return result
			# Gremory measurement events are public. Hidden draw identities are
			# unnecessary; use the same redacted event surface as the board.
			telemetry.consume(owner._player_events_since(0, cursor))
			telemetry.observe_hook(owner.player_view(0, 0), hook)
		var row: Dictionary = telemetry.finish(both_passed)
		if (
			row.marching_start == null
			or row.marching_end == null
			or row.ticks_observed != Marching.TICKS
		):
			return Data.invalid("batch_marching_telemetry_incomplete")
		var world_digest: String = _digest(owner.player_view(0, 0).world)
		if world_digest == prior_world_digest:
			unchanged_rounds += 1
		prior_world_digest = world_digest
		if round_number < round_limit:
			var begun: Dictionary = owner.begin_next_round([0, 1])
			if begun.action == "invalid":
				return begun
	var snapshot: Dictionary = owner.snapshot()
	return {
		"action": "batch_trial_complete",
		"seed": seed_value,
		"roster": roster,
		"roster_mode": roster_mode,
		"rounds": telemetry.rounds,
		"summary": Telemetry.summarize(telemetry.rounds),
		"termination": "round_limit",
		"unchanged_public_world_rounds": unchanged_rounds,
		"decision_digest": _digest(decisions),
		"state_and_events_digest": _digest(snapshot),
		"pending_at_limit": snapshot.pending.pending.size()
	}


static func report(trials: Array, round_limit: int) -> Dictionary:
	var rows: Array = []
	var seeds: Array = []
	for item in trials:
		seeds.append(item.seed)
		rows.append_array(item.rounds)
	return {
		"schema_version": VERSION,
		"runtime": "4.7.2.stable",
		"policy": Bot.VERSION,
		"castle_policy":
		Bot.CASTLE_POLICY if trials[0].roster_mode in ["construction", "loadout"] else null,
		"construction_profile":
		Construction.VERSION if trials[0].roster_mode in ["construction", "loadout"] else null,
		"roster": trials[0].roster,
		"combat_profile":
		Combat.VERSION if trials[0].roster_mode == "gremory" else Structures.PROFILE,
		"marching_model": Marching.VERSION,
		"castle_slot_profile": Slots.VERSION if trials[0].roster_mode == "loadout" else null,
		"rout_profile": Rout.VERSION if trials[0].roster_mode != "gremory" else null,
		"opening":
		(
			"Loadout fixture: two commissioned Engines at 21/21 and three unbuilt Castles per side; one shared Castle Guard zone per side; starting economy is an exercise fixture"
			if trials[0].roster_mode == "loadout"
			else (
				"U13SmokeSession opening: four cards and two Wright guards per player; damaged plain Integrity Castles"
				if trials[0].roster_mode == "gremory"
				else (
					"Construction fixture: same cards/guards and damaged active plain Castles; ruined Deimos Engine, unbuilt Gremory Engine, two Repair tokens per side; protected builds require manual activation"
					if trials[0].roster_mode in ["construction", "loadout"]
					else "U13CoreScenario: same cards/guards; one plain Castle at 8/21 and one prebuilt Siege Engine at 12/21 per player; empty Breach"
				)
			)
		),
		"scope": "bounded combat-slice trials; frequency and reachability observations only",
		"absent_systems":
		[
			(
				"Other Development actions"
				if trials[0].roster_mode in ["construction", "loadout"]
				else "Development"
			),
			"normal round draws",
			"Hunt",
			"victory",
			(
				"personal Tear/Veil progression"
				if trials[0].roster_mode == "gremory"
				else "Veil progression (personal Tear counters only)"
			),
			(
				"Guard deployment/Summon/Profane"
				if trials[0].roster_mode in ["construction", "loadout"]
				else "Construction/Reconstruction"
			),
			"non-artillery Castle printed powers",
			"other Lords",
			"waiter spending"
		],
		"sampling":
		{
			"hooks": ["MARCHING_STARTED", "MARCHING_FINISHED"],
			"peak": "hook boundaries and all Marching ticks",
			"waiter_duration_unit": "fixed Marching ticks",
			"ticks_per_round": Marching.TICKS,
			"choice":
			"uniform legal power name, then uniform canonical complete payload; combat uniform over legal single-card/pair Siege/Ward orders",
			"castle_choice":
			(
				"uniform legal Construct/Repair/Activate action, then uniform legal target/payment; filtered against the selected power before combat selection"
				if trials[0].roster_mode in ["construction", "loadout"]
				else null
			)
		},
		"round_limit": round_limit,
		"seeds": seeds,
		"trials": trials,
		"summary": Telemetry.summarize(rows)
	}


static func _digest(value) -> String:
	return JSON.stringify(value, "", true).sha256_text()
