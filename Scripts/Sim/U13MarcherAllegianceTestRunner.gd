extends "res://Scripts/Sim/U13MarchingIntegrationTestRunner.gd"

const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Queries = preload("res://Scripts/Sim/U13SpatialQueries.gd")
const Space = preload("res://Scripts/Sim/U13SpatialSpace.gd")
const Rout = preload("res://Scripts/Sim/U13Rout.gd")
const Fields = preload("res://Scripts/Sim/U13SpatialFields.gd")


func _init() -> void:
	_positions_and_replay()
	_interrupted_fight()
	_rout_and_web()
	_invalid()
	print("U13 Marcher allegiance failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _convert(
	world: Dictionary, id: String, owner_id: int, key: String = "convert", round_number: int = 1
) -> Dictionary:
	return Battle.apply(
		world,
		{
			"kind": "change_marcher_allegiance",
			"command_id": key,
			"target_id": id,
			"new_owner": owner_id
		},
		round_number,
		Timeline.POST_RESOLUTION_ALLEGIANCE
	)


func _positions_and_replay() -> void:
	for owner_id in [0, 1]:
		for x in [0, 1200, 2400]:
			var world: Dictionary = _world()
			var id: String = _spawn(world, "conversion", owner_id, "Butcher", x)
			_edit(
				world,
				id,
				{"hp": 3, "armor": 7, "attack": 9, "regen": 2, "step_fp": 3, "contact_tick": 7}
			)
			if x == (2400 if owner_id == 0 else 0):
				_edit(world, id, {"waiting": true, "waiting_since_round": 1})
			var before: Dictionary = world.duplicate(true)
			var result: Dictionary = _convert(world, id, 1 - owner_id)
			if not _check(result.action == "resolved", "allegiance_at_each_gate_and_center"):
				return
			_check(world == before, "allegiance_input_not_mutated")
			_check(
				result == _convert(JSON.parse_string(JSON.stringify(world)), id, 1 - owner_id),
				"allegiance_json_replay_exact"
			)
			var unit: Dictionary = _entity(result.world, id)
			var expected: Dictionary = _entity(world, id).duplicate(true)
			expected.owner = 1 - owner_id
			expected.attributes.direction = 1 if expected.owner == 0 else -1
			expected.attributes.waiting = false
			expected.attributes.waiting_since_round = 0
			expected.attributes.contact_tick = -1
			_check(unit == expected, "allegiance_preserves_identity_position_health_armor_buffs")
			_check(Marching.valid(result.world), "converted_world_passes_marching_validator")
			var query = Queries.new()
			query.capture(result.world.entities)
			_check(
				(
					query.members(Space.lane_region("Castle"), owner_id).ids.is_empty()
					and query.members(Space.lane_region("Castle"), 1 - owner_id).ids == [id]
				),
				"queries_use_new_allegiance"
			)
			_check(
				(
					result.event.type == "MARCHER_ALLEGIANCE_CHANGED"
					and result.event.data.before.owner == owner_id
					and result.event.data.after.owner == 1 - owner_id
				),
				"public_event_carries_before_and_after_ownership"
			)
			_check(
				_convert(result.world, id, owner_id).action == "invalid",
				"duplicate_command_cannot_convert_twice"
			)
			var twice: Dictionary = _convert(result.world, id, owner_id, "convert-back")
			_check(
				twice.action == "resolved" and _entity(twice.world, id).owner == owner_id,
				"two_distinct_effects_can_convert_twice"
			)
			var movement: Dictionary = _run_marching(result.world)
			if _check(movement.action == "resolved", "converted_body_marches"):
				var final: Dictionary = _entity(movement.world, id)
				_check(
					final.attributes.x_fp <= x if unit.owner == 1 else final.attributes.x_fp >= x,
					"converted_body_travels_toward_new_enemy"
				)


func _interrupted_fight() -> void:
	var world: Dictionary = _world()
	var left: String = _spawn(world, "duel-left", 0, "Wright", 1200)
	var right: String = _spawn(world, "duel-right", 1, "Wright", 1200)
	for id in [left, right]:
		_edit(world, id, {"hp": 500, "max_hp": 500, "armor": 0, "attack": 1})
	var fought: Dictionary = _run_marching(world)
	if not _check(
		fought.action == "resolved" and not fought.world.data.marching_duels.is_empty(),
		"allegiance_fixture_has_real_unfinished_duel"
	):
		return
	var converted: Dictionary = _convert(fought.world, left, 1, "duel-switch", 2)
	if not _check(converted.action == "resolved", "fighting_body_converts"):
		return
	_check(
		(
			converted.world.data.marching_duels.is_empty()
			and converted.event.data.interrupted_duels.size() == 1
		),
		"old_enemy_encounter_is_ended"
	)
	_check(
		_entity(converted.world, right).attributes.contact_tick == -1,
		"former_opponent_contact_ticket_cleared"
	)
	var moved: Dictionary = _run_marching(converted.world, 2)
	_check(
		moved.action == "resolved" and _events(moved.events, "MARCHER_DEFEATED").is_empty(),
		"former_enemies_do_not_keep_fighting"
	)
	# Subsequent combat attribution belongs to the new owner, not the birth ID.
	var victim_world: Dictionary = converted.world.duplicate(true)
	var victim: String = _spawn(victim_world, "new-enemy", 0, "Vulture", 1200, 2)
	var killed: Dictionary = Battle.apply(
		victim_world,
		{
			"kind": "marcher_damage",
			"command_id": "converted-kill",
			"target_id": victim,
			"attacker_id": left,
			"damage": 5,
			"cause": "combat"
		},
		2,
		Timeline.MARCHING
	)
	_check(
		killed.action == "resolved" and killed.event.data.attacker.owner == 1,
		"future_kill_credit_uses_new_owner"
	)


func _rout_and_web() -> void:
	var world: Dictionary = _world()
	world.data["rout_profile"] = Rout.VERSION
	var id: String = _spawn(world, "routed", 0, "Wright", 1200)
	var declaration: Dictionary = {
		"player_id": 1,
		"declaration_id": "rout-first",
		"power_id": "Rout",
		"target": {"lane": "Castle"}
	}
	var routed: Dictionary = Rout.apply(
		{"declaration": declaration}, _context(world, Timeline.POST_RESOLUTION_MOVEMENT_STATE)
	)
	var converted: Dictionary = _convert(routed.world, id, 1)
	if converted.action == "invalid":
		print("DETAIL ", converted)
		_check(false, "routed_conversion_accepted")
		return
	_check(
		(
			converted.action == "resolved"
			and (
				_entity(converted.world, id).attributes.rout_effect_id
				== _entity(routed.world, id).attributes.rout_effect_id
			)
		),
		"conversion_preserves_existing_rout_state"
	)
	var moving: Dictionary = _run_marching(converted.world)
	_check(
		moving.action == "resolved" and _entity(moving.world, id).attributes.x_fp > 1200,
		"rout_retreat_uses_new_owners_home"
	)
	var changed_first: Dictionary = _convert(world, id, 1)
	declaration.player_id = 0
	var routed_second: Dictionary = Rout.apply(
		{"declaration": declaration},
		_context(changed_first.world, Timeline.POST_RESOLUTION_MOVEMENT_STATE)
	)
	_check(routed_second.persistent_payload.affected_ids == [id], "later_rout_targets_new_enemy")
	var unit: Dictionary = _entity(changed_first.world, id)
	var field: Dictionary = {
		"Lord": [],
		"Castle":
		[{"owner": 0, "region": Space.circle_region("Castle", {"x_fp": 1200, "y_fp": 300}, 300)}]
	}
	_check(
		not Fields.slowed(field, 0, unit.attributes) and Fields.slowed(field, 1, unit.attributes),
		"web_hostility_follows_new_owner"
	)


func _invalid() -> void:
	var world: Dictionary = _world()
	var id: String = _spawn(world, "invalid", 0, "Butcher", 100)
	var before: Dictionary = world.duplicate(true)
	for owner_id in [-1, 0, 2]:
		_check(
			_convert(world, id, owner_id).action == "invalid",
			"allegiance_invalid_or_unchanged_owner_rejected"
		)
	_check(_convert(world, "missing", 1).action == "invalid", "allegiance_missing_body_rejected")
	_check(
		_convert(world, world.players[0].lord_entity_id, 1).action == "invalid",
		"allegiance_cannot_convert_lord"
	)
	var command: Dictionary = {
		"kind": "change_marcher_allegiance",
		"command_id": "bad-hook",
		"target_id": id,
		"new_owner": 1
	}
	_check(
		Battle.apply(world, command, 1, Timeline.MARCHING).action == "invalid",
		"allegiance_rejects_live_buffer_mutation"
	)
	_check(world == before, "rejected_conversions_are_atomic")
