extends SceneTree

const Content = preload("res://Scripts/Sim/U13Orias.gd")
const Scenario = preload("res://Scripts/Sim/U13OriasScenario.gd")
const Candidates = preload("res://Scripts/Sim/U13OriasCandidates.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Persistent = preload("res://Scripts/Sim/U13PersistentEffects.gd")
const RandomLegal = preload("res://Scripts/Sim/U13RandomLegal.gd")
const Timeline = Content.Timeline
const Ids = Content.Ids
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok


func _run() -> void:
	_damage()
	_admission()
	print("U13 Orias Web failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _target() -> Dictionary:
	return {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}}


func _context(
	world: Dictionary, hook: String, round_number: int = 1, effects: Array = []
) -> Dictionary:
	return {
		"world": world,
		"hook": hook,
		"round": round_number,
		"seed": "orias-web",
		"player_order": [0, 1],
		"combat_orders": [{}, {}],
		"persistent_effects": effects
	}


func _entity(world: Dictionary, entity_id: String) -> Dictionary:
	for row in world.entities.entities:
		if row.id == entity_id:
			return row
	return {}


func _add(
	world: Dictionary,
	ordinal: int,
	owner: int,
	lane: String,
	x: int,
	y: int,
	armor: int = 0,
	hp: int = 5
) -> String:
	var ids = Ids.new()
	ids.restore(world.entities)
	var a: Dictionary = Marching.profile("Penitent", lane, owner, 1, 1)
	a.x_fp = x
	a.y_fp = y
	a.armor = armor
	a.hp = hp
	var result: Dictionary = ids.create("marcher", "web-fixture", ordinal, owner, a)
	world.entities = ids.snapshot()
	return result.entity.id


func _active() -> Dictionary:
	var registry = Persistent.new()
	return (
		registry
		. activate(
			Candidates.source(0, 1, _target()),
			Content.WEB,
			Content.rules()[Content.WEB].stages,
			{"spatial_field": Content.rules()[Content.WEB].spatial_field},
			{},
			1
		)
		. effect
	)


func _damage() -> void:
	var world: Dictionary = Scenario.world()
	var allied: String = _add(world, 0, 0, "Lord", 1200, 300)
	var bare: String = _add(world, 1, 1, "Lord", 1200, 300)
	var armored: String = _add(world, 2, 1, "Lord", 1200, 300, 2)
	var edge: String = _add(world, 3, 1, "Lord", 1470, 300)
	var outside: String = _add(world, 4, 1, "Lord", 1471, 300)
	var other_lane: String = _add(world, 5, 1, "Castle", 1200, 300)
	var doomed: String = _add(world, 6, 1, "Lord", 1200, 300, 0, 1)
	var before: Dictionary = world.duplicate(true)
	var source: Dictionary = Candidates.source(0, 1, _target())
	var record: Dictionary = Content.Data.make_record("pending", source, "main", {}, {})
	var content = Content.new()
	var fire_context: Dictionary = _context(world, Timeline.POST_RESOLUTION_HAZARDS)
	fire_context.erase("hook")
	var result: Dictionary = content.resolve(record, fire_context)
	if not _check(result.action == "resolved", "web_fires_at_10e"):
		return
	_check(world == before, "web_activation_leaves_input_untouched")
	_check(_entity(result.world, bare).attributes.hp == 4, "web_single_damage_pulse")
	_check(
		(
			_entity(result.world, armored).attributes.armor == 1
			and _entity(result.world, armored).attributes.hp == 5
		),
		"web_uses_standard_armor_first_damage"
	)
	_check(_entity(result.world, edge).attributes.hp == 4, "web_includes_radius_boundary")
	_check(
		(
			_entity(result.world, allied).attributes.hp == 5
			and _entity(result.world, outside).attributes.hp == 5
			and _entity(result.world, other_lane).attributes.hp == 5
		),
		"web_excludes_allies_outside_and_other_lane"
	)
	_check(_entity(result.world, doomed).is_empty(), "web_lethal_hit_retires_stable_identity")
	_check(
		content.resolve(record, _context(world, Timeline.MARCHING)).action == "invalid",
		"web_damage_not_a_per_tick_call"
	)
	_check(
		(
			content.resolve(record, _context(result.world, Timeline.POST_RESOLUTION_HAZARDS)).action
			== "invalid"
		),
		"web_damage_command_cannot_repeat"
	)
	var affected: Array = result.events.back().event.data.affected_ids
	_check(affected == [bare, armored, edge, doomed], "web_damage_order_is_stable_id")


func _owner():
	var owner = Content.new().create_combat_match()
	if not _check(
		owner.start("orias-web", Scenario.world(), [0, 1]).action != "invalid",
		"orias_web_owner_starts"
	):
		return null
	return owner


func _to_submission(owner) -> bool:
	while owner.next_hook() != Timeline.SUBMISSION_LOCK and not owner.next_hook().is_empty():
		if not _check(owner.run_next_hook().action != "invalid", "web_opening_hook"):
			return false
	return owner.next_hook() == Timeline.SUBMISSION_LOCK


func _admission() -> void:
	var owner = _owner()
	if owner == null or not _to_submission(owner):
		return
	var source: Dictionary = Candidates.source(0, 1, _target())
	var before: Dictionary = owner.snapshot()
	_check(
		owner.preview_submission(0, [source], {}).action != "invalid",
		"web_shared_legality_accepts_position"
	)
	for field in ["fractional", "outside", "radius", "duplicate"]:
		var bad: Dictionary = source.duplicate(true)
		if field == "fractional":
			bad.target.field_position.x_fp = 1200.5
		elif field == "outside":
			bad.target.field_position.y_fp = 601
		elif field == "radius":
			bad.parameters.radius_fp = 999
		var powers: Array = [bad]
		if field == "duplicate":
			powers.append(Candidates.source(0, 1, _target(), 1))
		_check(owner.preview_submission(0, powers, {}).action == "invalid", "web_rejects_" + field)
	var plan: Dictionary = RandomLegal.plan(owner, 0, Callable(Candidates, "enumerate"))
	_check(plan.action != "invalid" and plan.powers.size() == 1, "web_random_legal_path_declares")
	_check(
		plan == RandomLegal.plan(owner, 0, Callable(Candidates, "enumerate")),
		"web_random_plan_replays"
	)
	_check(owner.snapshot() == before, "web_planning_is_pure")
	_check(
		(
			(
				Content
				. Base
				. new()
				. create_combat_match()
				. start("wrong-policy", Scenario.world(), [0, 1])
				. action
			)
			== "invalid"
		),
		"old_policy_rejects_partial_orias"
	)


func _lifetime_replay(round_number: int) -> void:
	var owner = _owner()
	if owner == null:
		return
	var started: int = Time.get_ticks_msec()
	for warmup in range(1, round_number):
		while not owner.next_hook().is_empty():
			if owner.next_hook() == Timeline.SUBMISSION_LOCK:
				if (
					(
						(
							owner
							. submit(
								0, [Candidates.source(0, 1, _target())] if warmup == 1 else [], {}
							)
							. action
						)
						== "invalid"
					)
					or owner.submit(1, [], {}).action == "invalid"
				):
					_check(false, "web_warmup_submission")
					return
			if owner.run_next_hook().action == "invalid":
				_check(false, "web_warmup_hook")
				return
		if owner.begin_next_round([0, 1]).action == "invalid":
			_check(false, "web_warmup_boundary")
			return
	var replay = Content.new().create_combat_match()
	if not _check(
		(
			replay.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action != "invalid"
			and replay.snapshot() == owner.snapshot()
		),
		"web_round_start_json_restore"
	):
		return
	while not owner.next_hook().is_empty():
		var hook: String = owner.next_hook()
		if hook == Timeline.SUBMISSION_LOCK:
			var source: Dictionary = Candidates.source(0, round_number, _target())
			# Central immediate-fire sentinel must be valid as well.
			source.fire_round = -1
			var ready: bool = owner.preview_submission(0, [source], {}).action != "invalid"
			_check(ready == (round_number in [1, 4]), "web_readiness_round_" + str(round_number))
			for match_owner in [owner, replay]:
				if not _check(
					(
						(
							(
								match_owner
								. submit(0, [source] if round_number in [1, 4] else [], {})
								. action
							)
							!= "invalid"
						)
						and match_owner.submit(1, [], {}).action != "invalid"
					),
					"web_lifetime_submission"
				):
					return
		if not _check(
			(
				owner.run_next_hook().action != "invalid"
				and replay.run_next_hook().action != "invalid"
			),
			"web_lifetime_hook_" + hook
		):
			return
		var snapshot: Dictionary = owner.snapshot()
		_check(snapshot == replay.snapshot(), "web_lifetime_replay_" + hook)
		if (
			hook
			in [
				Timeline.PERSISTENT_ADVANCEMENT,
				Timeline.POST_RESOLUTION_HAZARDS,
				Timeline.AFTERMATH
			]
		):
			var restored = Content.new().create_combat_match()
			_check(
				(
					(
						restored.restore(JSON.parse_string(JSON.stringify(snapshot))).action
						!= "invalid"
					)
					and restored.snapshot() == snapshot
				),
				"web_checkpoint_json_" + hook
			)
		if hook == Timeline.POST_RESOLUTION_HAZARDS:
			_check(
				snapshot.persistent.active.size() == (0 if round_number == 3 else 1),
				"web_active_lifetime_" + str(round_number)
			)
			if round_number == 1:
				_corrupt_web_snapshots(owner)
			elif round_number == 2:
				_check(snapshot.persistent.active[0].stage_index == 1, "web_next_round_is_fading")
		if hook == Timeline.PERSISTENT_ADVANCEMENT and round_number == 3:
			_check(
				(
					snapshot.cooldowns.locks.size() == 1
					and snapshot.cooldowns.locks[0].first_blocked_round == 3
					and snapshot.cooldowns.locks[0].ready_round == 4
				),
				"web_expiration_starts_one_round_cooldown"
			)
	print("WEB lifetime round=", round_number, " elapsed_ms=", Time.get_ticks_msec() - started)


func _corrupt_web_snapshots(owner) -> void:
	var before: Dictionary = owner.snapshot()
	for condition in ["radius", "stage", "target", "clock", "parameters", "profile"]:
		var bad: Dictionary = before.duplicate(true)
		var active: Dictionary = bad.persistent.active[0]
		match condition:
			"radius":
				active.payload.spatial_field.radius_fp += 1
			"stage":
				active.stages.append({"fresh": false})
			"target":
				active.target.field_position.x_fp += 1
			"clock":
				bad.cooldowns.locks.clear()
			"parameters":
				active.declaration.parameters["radius_fp"] = 999
			"profile":
				bad.world.data.erase("spatial_field_profile")
		_check(
			owner.restore(bad).action == "invalid" and owner.snapshot() == before,
			"web_corrupt_restore_atomic_" + condition
		)
