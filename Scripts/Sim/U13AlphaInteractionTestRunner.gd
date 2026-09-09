extends "res://Scripts/Sim/U13KalliganTestRunner.gd"

const AlphaScenario = preload("res://Scripts/Sim/U13AlphaScenario.gd")
const HChoices = preload("res://Scripts/Sim/U13HumbabaCandidates.gd")
const DChoices = preload("res://Scripts/Sim/U13DeimosCandidates.gd")
const Batch = preload("res://Scripts/Sim/U13RandomBatch.gd")


func _run() -> void:
	_interaction("Humbaba")
	print("U13 alpha Scorch Breath failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _body(
	world: Dictionary, pid: int, x: int, lane: String = "Lord", waiting: bool = false
) -> String:
	var ids = Ids.new()
	ids.restore(world.entities)
	var a: Dictionary = Marching.profile("Butcher", lane, pid, 1, 1)
	a.hp = 2
	a.armor = 0 if waiting else 1
	a.step_fp = 0
	a.x_fp = x
	a.y_fp = 200
	a.waiting = waiting
	a.waiting_since_round = 1 if waiting else 0
	var created: Dictionary = ids.create(
		"marcher", "alpha-overlap", ids.snapshot().used_ids.size(), pid, a
	)
	world.entities = ids.snapshot()
	return created.entity.id


# A handful of stationary, separated bodies isolates phase semantics. Movement
# composition is covered separately by U13LaneAuras and the random full phases.
func _interaction(opponent: String) -> void:
	var world: Dictionary = AlphaScenario.world(["Kalligan", opponent])
	var own: String = _body(world, 0, 600)
	var enemy: String = _body(world, 1, 1600)
	var waiter: String = _body(world, 0, Marching.LANE_FP, "Lord", true)
	var other_lane: String = _body(world, 1, 800, "Castle")
	var owner = AlphaScenario.create_owner()
	var replay = AlphaScenario.create_owner()
	for match_owner in [owner, replay]:
		if not _check(
			match_owner.start("alpha-overlap", world, [0, 1]).action != "invalid",
			"alpha_overlap_starts_" + opponent
		):
			return
	for round_number in [1, 2]:
		var hooks: int = 0
		while not owner.next_hook().is_empty():
			hooks += 1
			if not _check(hooks <= 32, "alpha_overlap_hook_progress"):
				return
			var hook: String = owner.next_hook()
			if hook == Timeline.SUBMISSION_LOCK:
				var powers: Array = (
					[
						Candidates.source(
							0, round_number, Content.INFERNO, {"kind": "lane", "lane": "Lord"}
						)
					]
					if round_number == 1
					else [Candidates.source(0, round_number, Content.PYROCLASM)]
				)
				var opponent_powers: Array = []
				if opponent == "Humbaba" and round_number == 1:
					opponent_powers = [HChoices.source(1, 1, "Lord", "BreathOfLife")]
				elif opponent == "Deimos" and round_number == 2:
					opponent_powers = [DChoices._source(1, 2, "Rout", {"lane": "Lord"})]
				for match_owner in [owner, replay]:
					if not _check(
						(
							match_owner.submit(0, powers, {}).action != "invalid"
							and match_owner.submit(1, opponent_powers, {}).action != "invalid"
						),
						"alpha_overlap_legal_submissions"
					):
						return
			var left: Dictionary = owner.run_next_hook()
			var right: Dictionary = replay.run_next_hook()
			if not _check(
				left.action != "invalid" and right.action != "invalid", "alpha_overlap_hook_" + hook
			):
				return
			var snapshot: Dictionary = owner.snapshot()
			_check(
				Batch._digest(snapshot) == Batch._digest(replay.snapshot()),
				"alpha_overlap_replay_" + hook
			)
			if hook == Timeline.POST_RESOLUTION_MOVEMENT_STATE:
				var replacement = AlphaScenario.create_owner()
				if not _check(
					(
						(
							replacement
							. restore(JSON.parse_string(JSON.stringify(replay.snapshot())))
							. action
						)
						!= "invalid"
					),
					"alpha_overlap_restores_aura_or_rout_before_hazard"
				):
					return
				replay = replacement
				if round_number == 1:
					_check(
						(
							_entity(snapshot.world, own).attributes.hp == 3
							and _entity(snapshot.world, enemy).attributes.hp == 3
						),
						"new_breath_does_not_retroactively_heal"
					)
				if round_number == 2:
					_check(
						(
							_entity(snapshot.world, own).attributes.hp == 4
							and (
								_entity(snapshot.world, enemy).attributes.hp
								== (5 if opponent == "Humbaba" else 4)
							)
						),
						"step_three_breath_heals_only_its_owner"
					)
					_check(
						_entity(snapshot.world, waiter).attributes.hp == 2,
						"waiting_body_did_not_regenerate"
					)
					if opponent == "Deimos":
						_check(
							(
								_entity(snapshot.world, own).attributes.get("rout_round") == 2
								and not _entity(snapshot.world, waiter).attributes.waiting
							),
							"rout_applies_before_pyroclasm_and_releases_waiter"
						)
			if round_number == 2 and hook == Timeline.POST_RESOLUTION_DIRECT:
				_check(
					(
						_entity(snapshot.world, own).attributes.hp == 4
						and _entity(snapshot.world, own).attributes.armor == 0
					),
					"pyroclasm_consumes_armor_before_normal_pulse"
				)
				_check(
					_entity(snapshot.world, waiter).attributes.hp == 1,
					"pyroclasm_hits_waiter_or_routed_body"
				)
			if round_number == 2 and hook == Timeline.MARCHING_START:
				_check(
					(
						_entity(snapshot.world, own).attributes.hp == 3
						and (
							_entity(snapshot.world, enemy).attributes.hp
							== (4 if opponent == "Humbaba" else 3)
						)
					),
					"normal_scorch_damages_both_owners_after_pyroclasm"
				)
				_check(
					_entity(snapshot.world, waiter).is_empty(),
					"second_pulse_kills_waiter_or_routed_body"
				)
				_check(
					(
						_entity(snapshot.world, other_lane).attributes.hp == 4
						and _entity(snapshot.world, other_lane).attributes.armor == 1
					),
					"other_lane_unchanged_by_aura_and_hazard"
				)
				return
		if round_number == 1:
			if not _check(
				(
					owner.begin_next_round([0, 1]).action != "invalid"
					and replay.begin_next_round([0, 1]).action != "invalid"
				),
				"alpha_overlap_next_round"
			):
				return
	_check(false, "alpha_overlap_reached_second_scorch_pulse")
