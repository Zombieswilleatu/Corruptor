extends "res://Scripts/Sim/U13KalliganTestRunner.gd"

const Registry = preload("res://Scripts/Sim/U13PersistentEffects.gd")


func _run() -> void:
	_lane_pulse()
	_guard_pulse()
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


func _guard_pulse() -> void:
	var content = Content.new()
	var world: Dictionary = Scenario.world()
	var guard_ids: Array = []
	var ids = Ids.new()
	ids.restore(world.entities)
	for slot in range(3):
		var card_id: String = world.data.card_zones.hands[1].pop_back()
		var card: Dictionary = ids.get_entity(card_id)
		card.attributes.merge(
			{"role": "guard", "lane": "Castle", "slot": slot, "value": slot + 1}, true
		)
		ids.update(card_id, 1, card.attributes)
		guard_ids.append(card_id)
	world.entities = ids.snapshot()
	var active: Dictionary = _active({"kind": "guard", "lane": "Castle", "player_id": 1}, 2)
	var result: Dictionary = Content.Hazards.pulse(
		_context(world, 2, Timeline.PERSISTENT_ADVANCEMENT),
		active,
		"guard-fixture",
		Callable(content._humbaba, "react")
	)
	_check(result.action != "invalid", "guard_hazard_resolves")
	if result.action == "invalid":
		return
	_check(
		(
			_entity(result.world, guard_ids[0]).owner == -1
			and _entity(result.world, guard_ids[1]).owner == -1
			and _entity(result.world, guard_ids[2]).owner == 1
		),
		"guard_intensity_defeats_all_at_or_below_value"
	)
	_check(
		(
			guard_ids[0] in result.world.data.card_zones.discard
			and guard_ids[1] in result.world.data.card_zones.discard
		),
		"guard_defeat_preserves_card_zone_ownership"
	)
	_check(
		not Content.Hazards.target_valid({"kind": "guard", "lane": "Castle", "player_id": 0}, 0),
		"own_guard_zone_rejected"
	)
	_check(
		not Content.Hazards.target_valid({"kind": "lane", "lane": "Lord", "player_id": 1}, 0),
		"one_sided_lane_fire_rejected"
	)
