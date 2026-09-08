extends SceneTree

const Rout = preload("res://Scripts/Sim/U13Rout.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Core = preload("res://Scripts/Sim/U13CoreScenario.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Legality = preload("res://Scripts/Sim/U13Legality.gd")
const Candidates = preload("res://Scripts/Sim/U13DeimosCandidates.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_membership()
	_movement()
	_contact()
	_match_lifetime()
	print("U13 Rout failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok


func _source(round_number: int = 1, player_id: int = 0, lane: String = "Castle") -> Dictionary:
	return Decl.create(
		MatchOwner.declaration_id(player_id, round_number, 0),
		player_id,
		"Deimos",
		Deimos.ROUT,
		round_number,
		Timeline.POST_RESOLUTION_MOVEMENT_STATE,
		round_number,
		0,
		"public",
		{"lane": lane},
		{},
		{}
	)


func _small_world() -> Dictionary:
	return {"entities": Ids.new().snapshot(), "data": {"rout_profile": Rout.VERSION}}


func _add(
	world: Dictionary,
	name: String,
	player_id: int,
	x: int,
	suit: String = "Penitent",
	lane: String = "Castle",
	ready: int = 0
) -> String:
	var ids = Ids.new()
	ids.restore(world.entities)
	var attributes: Dictionary = Marching.profile(suit, lane, player_id, 0, ready)
	attributes.x_fp = x
	var result: Dictionary = ids.create("marcher", "rout:test:" + name, 0, player_id, attributes)
	world.entities = ids.snapshot()
	return result.entity.id


func _entity(world: Dictionary, id: String) -> Dictionary:
	var ids = Ids.new()
	ids.restore(world.entities)
	return ids.get_entity(id)


func _patch(world: Dictionary, id: String, patch: Dictionary) -> void:
	var ids = Ids.new()
	ids.restore(world.entities)
	var unit: Dictionary = ids.get_entity(id)
	unit.attributes.merge(patch, true)
	ids.update(id, unit.owner, unit.attributes)
	world.entities = ids.snapshot()


func _apply(world: Dictionary, round_number: int = 1, player_id: int = 0) -> Dictionary:
	return (
		Rout
		. apply(
			Data.make_record("pending", _source(round_number, player_id), "main", {}, {}),
			{"world": world, "round": round_number}
		)
		. world
	)


func _advance(world: Dictionary, round_number: int) -> Dictionary:
	return Rout.advance({"world": world, "round": round_number}).world


func _react(world: Dictionary, _fact: Dictionary, _seed: String, _order: Array) -> Dictionary:
	return {"action": "resolved", "world": world, "events": []}


func _march(world: Dictionary, round_number: int) -> Dictionary:
	var result: Dictionary = Marching.resolve(
		{
			"world": world,
			"round": round_number,
			"hook": Timeline.MARCHING,
			"seed": "rout-motion",
			"player_order": [0, 1]
		},
		Callable(self, "_react")
	)
	if not _check(result.action == "resolved", "rout_marching_resolves_" + str(round_number)):
		print(result)
	return result


func _membership() -> void:
	var world: Dictionary = _small_world()
	var affected: String = _add(world, "old", 1, 1200)
	var waiting: String = _add(world, "waiter", 1, 0)
	_patch(world, waiting, {"waiting": true, "waiting_since_round": 1})
	var ally: String = _add(world, "ally", 0, 0)
	var other_lane: String = _add(world, "other-lane", 1, 1200, "Penitent", "Lord")
	world = _apply(world)
	_check(_entity(world, affected).attributes.rout_round == 1, "rout_marks_existing_enemy")
	_check(
		(
			not _entity(world, waiting).attributes.waiting
			and _entity(world, waiting).attributes.waiting_since_round == 0
		),
		"rout_releases_waiters"
	)
	_check(
		(
			not _entity(world, ally).attributes.has("rout_round")
			and not _entity(world, other_lane).attributes.has("rout_round")
		),
		"rout_excludes_allies_and_other_lane"
	)
	var fresh: String = _add(world, "after-fire", 1, 2300)
	_check(
		not _entity(world, fresh).attributes.has("rout_round"), "later_spawn_does_not_inherit_rout"
	)
	world = _advance(world, 2)
	_check(Rout.recovering(_entity(world, affected).attributes, 2), "same_body_recovers_next_round")
	_check(not Rout.recovering(_entity(world, fresh).attributes, 2), "later_spawn_not_slowed")
	var bad: Dictionary = world.duplicate(true)
	_patch(bad, affected, {"rout_round": 1.5})
	_check(not Marching.valid(bad), "fractional_rout_round_rejected")
	world = _advance(world, 3)
	_check(
		not _entity(world, affected).attributes.has("rout_round"),
		"rout_state_removed_after_recovery"
	)


func _movement() -> void:
	for player_id in [0, 1]:
		var world: Dictionary = _small_world()
		var id: String = _add(world, str(player_id), player_id, 1200)
		world = _apply(world, 1, 1 - player_id)
		var result: Dictionary = _march(world, 1)
		if result.action != "resolved":
			return
		var expected: int = 600 if player_id == 0 else 1800
		_check(
			_entity(result.world, id).attributes.x_fp == expected,
			"rout_full_speed_reverse_owner_" + str(player_id)
		)
		world = _advance(result.world, 2)
		result = _march(world, 2)
		if result.action != "resolved":
			return
		expected += 300 if player_id == 0 else -300
		_check(
			_entity(result.world, id).attributes.x_fp == expected,
			"odd_speed_exact_half_over_phase_" + str(player_id)
		)
		world = _advance(result.world, 3)
		result = _march(world, 3)
		if result.action != "resolved":
			return
		expected += 600 if player_id == 0 else -600
		_check(
			_entity(result.world, id).attributes.x_fp == expected,
			"full_speed_restored_owner_" + str(player_id)
		)
	var world: Dictionary = _small_world()
	var home: String = _add(world, "home", 1, 2300)
	var result: Dictionary = _march(_apply(world), 1)
	if result.action == "resolved":
		_check(
			(
				_entity(result.world, home).attributes.x_fp == Marching.LANE_FP
				and not _entity(result.world, home).attributes.waiting
			),
			"retreat_clamps_home_without_arrival"
		)
		var arrivals: int = 0
		for envelope in result.events:
			arrivals += 1 if envelope.event.type == "MARCHER_WAITING" else 0
		_check(arrivals == 0, "retreat_home_emits_no_arrival_event")
	world = _small_world()
	var delayed: String = _add(world, "not-ready", 1, 1200, "Penitent", "Castle", 2)
	result = _march(_apply(world), 1)
	if result.action == "resolved":
		_check(
			_entity(result.world, delayed).attributes.x_fp == 1200,
			"rout_preserves_spawn_readiness_delay"
		)


func _contact() -> void:
	# High armor leaves an unfinished contact duel across the round.
	var world: Dictionary = _small_world()
	var left: String = _add(world, "fighter-left", 0, 1000)
	var right: String = _add(world, "fighter-right", 1, 1180)
	for id in [left, right]:
		_patch(world, id, {"hp": 100, "max_hp": 100, "armor": 1000, "step_fp": 0})
	var result: Dictionary = _march(world, 1)
	if result.action != "resolved":
		return
	_check(not result.world.data.marching_duels.is_empty(), "fixture_has_ongoing_duel")
	world = result.world
	_patch(world, right, {"step_fp": 6})
	world = _apply(world, 2)
	result = _march(world, 2)
	if result.action != "resolved":
		return
	_check(
		_entity(result.world, right).attributes.x_fp > 1180,
		"routed_fighter_can_physically_leave_duel"
	)
	var interrupted: bool = false
	for envelope in result.events:
		interrupted = interrupted or envelope.event.type == "MARCHER_DUEL_INTERRUPTED"
	_check(
		interrupted and result.world.data.marching_duels.is_empty(),
		"separated_fighters_do_not_exchange_ranged_damage"
	)
	_check(Marching.valid(result.world), "rout_contact_result_valid")


func _drive(owner, stop: String, replay: bool = false) -> bool:
	for index in range(24):
		if owner.next_hook() == stop:
			return true
		var before: Dictionary = owner.snapshot() if replay else {}
		var result: Dictionary = owner.run_next_hook()
		if not _check(
			result.action != "invalid", "rout_hook_" + str(owner.round_number()) + "_" + str(index)
		):
			print(result)
			return false
		if replay:
			var restored = Deimos.new().create_combat_match()
			if not _check(
				restored.restore(JSON.parse_string(JSON.stringify(before))).action != "invalid",
				"rout_json_restore_before_hook_" + str(index)
			):
				return false
			if not _check(
				(
					restored.run_next_hook().action != "invalid"
					and restored.snapshot() == owner.snapshot()
				),
				"rout_replay_hook_state_" + str(index)
			):
				return false
	return _check(false, "rout_drive_limit")


func _match_lifetime() -> void:
	var content = Deimos.new()
	var world: Dictionary = Core.world(["Deimos", "Gremory"])
	var id: String = _add(world, "match-body", 1, 1500)
	var owner = content.create_combat_match()
	if not _check(
		owner.start("rout-lifetime", world, [0, 1]).action != "invalid", "rout_owner_starts"
	):
		return
	for round_number in range(1, 6):
		if not _drive(owner, Timeline.SUBMISSION_LOCK):
			return
		var source: Dictionary = _source(round_number)
		var preview: Dictionary = owner.preview_submission(0, [source])
		_check(
			(preview.action != "invalid") == (round_number in [1, 5]),
			"rout_readiness_round_" + str(round_number)
		)
		if round_number == 1:
			var groups: Array = Legality.legal_power_groups(
				owner, 0, Candidates.enumerate(owner, 0).powers
			)
			var legal_lanes: int = 0
			for group in groups:
				if group.power == Deimos.ROUT:
					legal_lanes = group.candidates.size()
			_check(legal_lanes == 2, "rout_random_legal_path_both_lanes")
			var invalid: Dictionary = source.duplicate(true)
			invalid.target.lane = "middle"
			_check(
				owner.preview_submission(0, [invalid]).action == "invalid",
				"rout_invalid_lane_rejected"
			)
			var powers: Array = [source]
			var duplicate: Dictionary = _source()
			duplicate.queue_index = 1
			duplicate.declaration_id = MatchOwner.declaration_id(0, 1, 1)
			powers.append(duplicate)
			_check(
				owner.preview_submission(0, powers).action == "invalid",
				"duplicate_rout_submission_rejected"
			)
		owner.submit(0, [source] if round_number == 1 else [])
		# 10A spawn occurs before Rout's 10D membership capture.
		var predator: Dictionary = Decl.create(
			MatchOwner.declaration_id(1, round_number, 0),
			1,
			"Gremory",
			Gremory.PREDATOR,
			round_number,
			Timeline.POST_RESOLUTION_SPAWNS,
			round_number,
			0,
			"public",
			{"lane": "Castle"},
			{},
			{}
		)
		owner.submit(1, [predator] if round_number == 1 else [])
		if not _drive(owner, Timeline.MARCHING_START, round_number == 1):
			return
		if round_number == 1:
			var affected: int = 0
			for unit in owner.snapshot().world.entities.entities:
				if unit.kind == "marcher" and unit.attributes.has("rout_round"):
					affected += 1
			_check(affected == 4, "rout_captures_earlier_10a_spawns")
			var before: Dictionary = owner.snapshot()
			var bad: Dictionary = before.duplicate(true)
			_patch(bad.world, id, {"rout_effect_id": "forged"})
			_check(
				owner.restore(bad).action == "invalid" and owner.snapshot() == before,
				"rout_status_requires_live_effect_identity"
			)
			bad = before.duplicate(true)
			var later: String = _add(bad.world, "injected-member", 1, 1200)
			_patch(
				bad.world,
				later,
				{
					"rout_round": 1,
					"rout_effect_id": _entity(bad.world, id).attributes.rout_effect_id
				}
			)
			_check(
				owner.restore(bad).action == "invalid" and owner.snapshot() == before,
				"restore_rejects_unit_not_in_captured_membership"
			)
			bad = before.duplicate(true)
			_patch(bad.world, id, {"rout_round": 2})
			_check(
				owner.restore(bad).action == "invalid" and owner.snapshot() == before,
				"future_rout_restore_rejected_atomically"
			)
		if not _drive(owner, "", round_number in [1, 2]):
			return
		if round_number < 5:
			if not _check(owner.begin_next_round([0, 1]).action != "invalid", "rout_next_round"):
				return
