extends SceneTree

const Content = preload("res://Scripts/Sim/U13Kalligan.gd")
const Scenario = preload("res://Scripts/Sim/U13KalliganScenario.gd")
const Candidates = preload("res://Scripts/Sim/U13KalliganCandidates.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok


func _entity(world: Dictionary, entity_id: String) -> Dictionary:
	for entity in world.entities.entities:
		if entity.id == entity_id:
			return entity
	return {}


func _put(world: Dictionary, entity_id: String, changes: Dictionary) -> void:
	var ids = Ids.new()
	ids.restore(world.entities)
	var entity: Dictionary = ids.get_entity(entity_id)
	entity.attributes.merge(changes, true)
	ids.update(entity_id, entity.owner, entity.attributes)
	world.entities = ids.snapshot()


func _context(world: Dictionary, round_number: int, hook: String) -> Dictionary:
	return {
		"world": world,
		"round": round_number,
		"hook": hook,
		"seed": "kalligan-gate",
		"player_order": [0, 1],
		"combat_orders": [{}, {}],
		"persistent_effects": []
	}


func _owner(world: Dictionary = {}):
	var owner = Content.new().create_combat_match()
	var result: Dictionary = owner.start(
		"kalligan-gate", Scenario.world() if world.is_empty() else world, [0, 1]
	)
	if not _check(
		result.action != "invalid", "kalligan_owner_starts_" + str(result.get("reason", "ok"))
	):
		return null
	return owner


func _to_submission(owner) -> bool:
	for _attempt in range(20):
		if owner.next_hook() == Timeline.SUBMISSION_LOCK:
			return true
		var result: Dictionary = owner.run_next_hook()
		if not _check(
			result.action != "invalid", "kalligan_opening_" + str(result.get("reason", "ok"))
		):
			return false
	return _check(false, "kalligan_submission_window_missing")


func _run() -> void:
	_upkeep_and_rekindle()
	_breach_repair()
	print("U13 Kalligan failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _upkeep_and_rekindle() -> void:
	var content = Content.new()
	var world: Dictionary = Scenario.world()
	for slot in [0, 1]:
		_put(world, Slots.castle_id(0, slot), {"status": "defunct", "integrity": 0})
	_put(
		world,
		Slots.castle_id(0, 2),
		{"status": "standing", "integrity": 7, "construction_state": "building"}
	)
	_put(
		world,
		Slots.castle_id(0, 3),
		{"status": "ruined", "integrity": 0, "construction_state": "active"}
	)
	world.data.construction_targets[0] = Slots.castle_id(0, 2)
	var original: Dictionary = world.duplicate(true)
	for round_number in range(1, 5):
		var context: Dictionary = _context(world, round_number, Timeline.ROUND_START_AUTOMATIC)
		var result: Dictionary = content._upkeep(
			context, {"action": "resolved", "world": world.duplicate(true), "events": []}
		)
		result = content._rekindle(context, result)
		if not _check(result.action != "invalid", "forge_upkeep_round_" + str(round_number)):
			return
		world = result.world
		_check(
			_entity(world, Slots.castle_id(0, 0)).attributes.integrity == round_number * 2,
			"forge_two_integrity"
		)
		_check(
			world.data.neutral_tears == (1 if round_number == 4 else 0),
			"rekindle_waits_for_operational_and_caps_two_revivals"
		)
	_check(world.data.rekindle_defunct_ids.is_empty(), "rekindle_consumes_both_revival_episodes")
	_check(
		_entity(world, Slots.castle_id(0, 2)).attributes.integrity == 7,
		"forge_excludes_protected_construction"
	)
	_check(
		_entity(world, Slots.castle_id(0, 3)).attributes.status == "ruined", "forge_excludes_ruined"
	)
	_check(_entity(world, Slots.castle_id(1, 0)).attributes.integrity == 8, "forge_own_only")
	_check(
		_entity(original, Slots.castle_id(0, 0)).attributes.integrity == 0, "upkeep_input_isolated"
	)
	_put(world, Slots.castle_id(0, 0), {"integrity": 20})
	var capped: Dictionary = content._upkeep(
		_context(world, 5, Timeline.ROUND_START_AUTOMATIC),
		{"action": "resolved", "world": world.duplicate(true), "events": []}
	)
	_check(
		_entity(capped.world, Slots.castle_id(0, 0)).attributes.integrity == 21,
		"forge_caps_at_current_maximum"
	)
	_check(
		(
			(
				content
				. _upkeep(_context(capped.world, 5, Timeline.ROUND_START_AUTOMATIC), capped)
				. action
			)
			== "invalid"
		),
		"forge_duplicate_upkeep_rejected"
	)
	var fresh: Dictionary = Scenario.world()
	var after: Dictionary = fresh.duplicate(true)
	_put(
		after,
		Slots.castle_id(0, 2),
		{"integrity": 7, "status": "standing", "construction_state": "active"}
	)
	var commissioned: Dictionary = content._rekindle(
		_context(fresh, 1, Timeline.DEVELOPMENT),
		{"action": "resolved", "world": after, "events": []}
	)
	_check(commissioned.world.data.neutral_tears == 0, "initial_commission_is_not_rekindle")


func _breach_repair() -> void:
	var content = Content.new()
	var world: Dictionary = Scenario.world()
	_put(world, world.players[0].lord_entity_id, {"alive": false})
	world.data.breach_lord = "Kalligan"
	_put(world, Slots.castle_id(1, 1), {"status": "profaned", "integrity": 0})
	var result: Dictionary = content._upkeep(
		_context(world, 1, Timeline.ROUND_START_AUTOMATIC),
		{"action": "resolved", "world": world.duplicate(true), "events": []}
	)
	_check(
		_entity(result.world, Slots.castle_id(0, 0)).attributes.integrity == 10,
		"rapid_construction_no_forge_double_stack"
	)
	_check(
		_entity(result.world, Slots.castle_id(1, 0)).attributes.integrity == 10,
		"rapid_construction_repairs_enemy"
	)
	_check(
		_entity(result.world, Slots.castle_id(1, 1)).attributes.status == "profaned",
		"rapid_construction_excludes_profaned"
	)
	world.data.breach_lord = "Gremory"
	var inactive: Dictionary = content._upkeep(
		_context(world, 1, Timeline.ROUND_START_AUTOMATIC),
		{"action": "resolved", "world": world.duplicate(true), "events": []}
	)
	_check(
		_entity(inactive.world, Slots.castle_id(0, 0)).attributes.integrity == 8,
		"banished_kalligan_outside_breach_has_no_upkeep"
	)
