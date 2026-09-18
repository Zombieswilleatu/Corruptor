extends "res://Scripts/Sim/U13KalliganTestRunner.gd"

const Registry = preload("res://Scripts/Sim/U13PersistentEffects.gd")


func _run() -> void:
	_lane_pulse()
	_castle_pulse()
	print("U13 hazards failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _active(target: Dictionary, intensity: int = 1) -> Dictionary:
	var registry = Registry.new()
	var declaration: Dictionary = Candidates.source(0, 1, Content.INFERNO, target)
	var created: Dictionary = registry.activate(
		declaration, Content.INFERNO, [{"intensity": intensity}], {"hazard": "scorch"}
	)
	return created.effect


func _unit(world: Dictionary, pid: int, lane: String, hp: int, armor: int) -> String:
	var ids = Ids.new()
	ids.restore(world.entities)
	var attributes: Dictionary = Marching.profile("Vulture", lane, pid, 1, 1)
	attributes.hp = hp
	attributes.armor = armor
	attributes.waiting = true
	attributes.waiting_since_round = 1
	var created: Dictionary = ids.create(
		"marcher", "hazard-fixture", ids.snapshot().used_ids.size(), pid, attributes
	)
	world.entities = ids.snapshot()
	return created.entity.id


func _lane_pulse() -> void:
	var content = Content.new()
	var world: Dictionary = Scenario.world()
	var left: String = _unit(world, 0, "Lord", 2, 1)
	var right: String = _unit(world, 1, "Lord", 2, 0)
	var other: String = _unit(world, 1, "Castle", 2, 0)
	var active: Dictionary = _active({"kind": "lane", "lane": "Lord"})
	var result: Dictionary = Content.Hazards.pulse(
		_context(world, 2, Timeline.POST_RESOLUTION_DIRECT),
		active,
		"pyro-fixture",
		Callable(content._humbaba, "react")
	)
	if not _check(result.action != "invalid", "hazard_pulse_resolves"):
		return
	_check(
		(
			_entity(result.world, left).attributes.hp == 2
			and _entity(result.world, left).attributes.armor == 0
		),
		"hazard_armor_absorbs_first"
	)
	_check(_entity(result.world, right).attributes.hp == 1, "hazard_hits_both_owners_and_waiters")
	_check(_entity(result.world, other).attributes.hp == 2, "hazard_other_lane_untouched")
	_check(_entity(world, left).attributes.armor == 1, "hazard_input_isolated")
	var normal: Dictionary = Content.Hazards.pulse(
		_context(result.world, 2, Timeline.MARCHING_START),
		active,
		"normal-fixture",
		Callable(content._humbaba, "react")
	)
	_check(
		_entity(normal.world, right).is_empty() and _entity(normal.world, left).attributes.hp == 1,
		"extra_then_normal_pulse_consumes_remaining_armor_and_hp"
	)
	_check(normal.world.data.neutral_tears == 0, "hazard_kill_does_not_award_vulture_combat_reward")
	_check(
		(
			(
				Content
				. Hazards
				. pulse(
					_context(normal.world, 2, Timeline.MARCHING_START),
					active,
					"normal-fixture",
					Callable(content._humbaba, "react")
				)
				. action
			)
			== "invalid"
		),
		"duplicate_hit_identity_rejected"
	)


func _castle_pulse() -> void:
	var content = Content.new()
	var world: Dictionary = Scenario.world()
	var castle_id: String = Slots.castle_id(1, 0)
	_put(world, castle_id, {"integrity": 8})
	var guards: Array = world.entities.entities.filter(func(e): return e.kind == "card" and e.attributes.get("role") == "guard")
	var untouched: Dictionary = _entity(world, Slots.castle_id(1, 1)).duplicate(true)
	var active: Dictionary = _active({"kind": "castle", "entity_id": castle_id}, 2)
	var result: Dictionary = Content.Hazards.pulse(_context(world, 2, Timeline.PERSISTENT_ADVANCEMENT), active, "castle-fixture", Callable(content._humbaba, "react"))
	if not _check(result.action != "invalid", "castle_hazard_resolves"):
		return
	var victim: Dictionary = _entity(result.world, castle_id)
	_check(victim.attributes.integrity == 6 and not Content.Structures.operational(victim), "castle_fire_crosses_operational_floor")
	_check(victim.attributes.repair_lock_until_round == 3, "castle_fire_sets_normal_repair_lock")
	_check(_entity(result.world, untouched.id) == untouched, "castle_fire_only_hits_selected_instance")
	_check(result.world.entities.entities.filter(func(e): return e.kind == "card" and e.attributes.get("role") == "guard") == guards, "castle_fire_never_changes_guards")
	_check(Content.Hazards.pulse(_context(result.world, 2, Timeline.PERSISTENT_ADVANCEMENT), active, "castle-fixture", Callable(content._humbaba, "react")).action == "invalid", "duplicate_castle_hit_rejected")
	_put(result.world, castle_id, {"integrity": 1})
	var souls: int = result.world.players[0].resources.souls
	var lethal: Dictionary = Content.Hazards.pulse(_context(result.world, 2, Timeline.POST_RESOLUTION_DIRECT), active, "castle-finisher", Callable(content._humbaba, "react"))
	_check(lethal.action != "invalid" and _entity(lethal.world, castle_id).attributes.status == "ruined", "castle_fire_can_ruin_selected_castle")
	_check(lethal.world.data.neutral_tears == 1 and lethal.world.players[0].resources.souls == souls, "environmental_castle_ruin_normal_tear_without_siege_souls")
	var empty: Dictionary = Content.Hazards.pulse(_context(lethal.world, 3, Timeline.PERSISTENT_ADVANCEMENT), active, "castle-empty", Callable(content._humbaba, "react"))
	_check(empty.action != "invalid" and empty.events[-1].event.data.affected_ids.is_empty(), "destroyed_castle_stays_bound_without_spill_or_retarget")
	for target in [{"kind": "guard", "lane": "Castle", "player_id": 1}, {"kind": "guard", "lane": "Lord", "player_id": 1}, {"kind": "castle", "entity_id": Slots.castle_id(0, 0)}, {"kind": "lane", "lane": "Lord", "player_id": 1}, {"kind": "castle", "entity_id": world.players[1].lord_entity_id}]:
		_check(not Content.Hazards.target_valid(target, 0, world), "non_castle_or_lane_target_rejected")
