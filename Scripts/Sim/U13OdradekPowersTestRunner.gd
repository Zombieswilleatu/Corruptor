extends "res://Scripts/Sim/U13OdradekTestRunner.gd"

const Transfers = preload("res://Scripts/Sim/U13GuardTransfers.gd")


func _run() -> void:
	_guard_moves()
	_shift_order()
	_prepared_replay()
	_interlock_cases()
	_paradox_cases()
	_interlock_boundaries()
	print("U13 Odradek powers failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _guards(world: Dictionary, pid: int, lane: String) -> Array:
	var result: Array = []
	for e in world.entities.entities:
		if (
			e.kind == "card"
			and e.owner == pid
			and e.attributes.get("role") == "guard"
			and e.attributes.lane == lane
		):
			result.append(e)
	return result


func _fire(
	world: Dictionary, power: String, target: Dictionary, index: int = 0, round_number: int = 1
) -> Dictionary:
	var source: Dictionary = OdradekScenario.source(0, round_number, target, index, power)
	var record: Dictionary = Pending.new().schedule(source).effect
	return Odradek.new().resolve(record, _context(world, record.fire_hook, record.fire_round))


func _guard_moves() -> void:
	var world: Dictionary = OdradekScenario.world()
	var source: Dictionary = _guards(world, 1, "Castle")[0]
	var target: Dictionary = {"entity_id": source.id, "owner_id": 1, "lane": "Lord"}
	var before: Dictionary = world.duplicate(true)
	var moved: Dictionary = _fire(world, Odradek.FALSE_ORDERS, target)
	if not _check(moved.action == "resolved", "false_orders_resolves"):
		return
	var after: Dictionary = _entity(moved.world, source.id)
	var expected: Dictionary = source.duplicate(true)
	expected.attributes.lane = "Lord"
	_check(
		after == expected and Transfers.Guards.valid(moved.world),
		"false_orders_retains_owner_id_value_state"
	)
	_check(world == before, "guard_transfer_input_unchanged")
	var invalid_owner: Dictionary = target.duplicate(true)
	invalid_owner.owner_id = 0
	_check(
		not (
			Odradek
			. new()
			. validate(
				OdradekScenario.source(0, 1, invalid_owner, 0, Odradek.FALSE_ORDERS),
				world,
				"declaration"
			)
			. legal
		),
		"false_orders_cannot_forge_guard_owner"
	)
	var flipped: Dictionary = _fire(world, Odradek.INVERSION, {"owner_id": 1, "lane": "Castle"})
	if not _check(flipped.action == "resolved", "inversion_resolves"):
		return
	_check(
		(
			_guards(flipped.world, 0, "Castle").size() == 3
			and _guards(flipped.world, 1, "Castle").size() == 1
		),
		"inversion_fills_only_legal_free_slots"
	)
	_check(
		flipped.world.data.neutral_tears == world.data.neutral_tears + 1,
		"partial_inversion_grants_exactly_one_tear"
	)
	_check(Transfers.Guards.valid(flipped.world), "inversion_preserves_card_zone_invariants")
	var full: Dictionary = _fire(
		flipped.world, Odradek.INVERSION, {"owner_id": 1, "lane": "Castle"}, 1
	)
	_check(full.world == flipped.world, "full_destination_gives_no_transfer_or_tear")
	_check(
		not (
			Odradek
			. new()
			. validate(
				OdradekScenario.source(
					0, 1, {"owner_id": 1, "lane": "Castle"}, 0, Odradek.INVERSION
				),
				flipped.world,
				"declaration"
			)
			. legal
		),
		"full_inversion_rejected_at_declaration"
	)
	var changed_id: String = flipped.events[0].event.data.after.id
	var stale: Dictionary = OdradekScenario.source(
		0, 1, {"entity_id": changed_id, "owner_id": 1, "lane": "Lord"}, 0, Odradek.FALSE_ORDERS
	)
	_check(
		not Odradek.new().validate(stale, flipped.world, "firing").legal,
		"prepared_guard_order_fizzles_after_allegiance_change"
	)


func _shift_order() -> void:
	var world: Dictionary = OdradekScenario.world()
	var own: String = _add(world, 0, 0, "Lord", 1200, 300, 2, 3)
	var enemy: String = _add(world, 1, 1, "Lord", 1200, 300, 7, 4)
	var edge: String = _add(world, 2, 1, "Lord", 1380, 300)
	var outside: String = _add(world, 3, 1, "Lord", 1381, 300)
	var result: Dictionary = _fire(world, Odradek.SHIFT, _target())
	if not _check(result.action == "resolved", "allegiance_shift_resolves"):
		return
	_check(_entity(result.world, own) == _entity(world, own), "shift_does_not_touch_allies")
	_check(
		_entity(result.world, edge).owner == 0 and _entity(result.world, outside).owner == 1,
		"shift_smaller_circle_boundary"
	)
	var unit: Dictionary = _entity(result.world, enemy)
	_check(
		(
			unit.owner == 0
			and unit.attributes.direction == 1
			and unit.attributes.hp == 4
			and unit.attributes.armor == 7
		),
		"shift_uses_shared_ownership_transition"
	)
	var setup: Dictionary = OdradekScenario.world()
	setup.players[0].resources.reconfiguration = 3
	var id: String = _add(setup, 0, 1, "Lord", 1200, 300)
	var owner = Odradek.new().create_combat_match()
	owner.start("mixed-hook-order", setup, [0, 1])
	if not _advance(owner, Timeline.SUBMISSION_LOCK):
		return
	# Intentionally list Shift first: hook order still puts Redirect first.
	var draft: Array = [
		OdradekScenario.source(
			0, 1, {"lane": "Castle", "field_position": _target().field_position}, 0, Odradek.SHIFT
		),
		OdradekScenario.source(0, 1, _target(), 1)
	]
	_check(owner.submit(0, draft, {}).action != "invalid", "shift_plus_redirect_affordable")
	owner.submit(1, [], {})
	owner.run_next_hook()
	if not _advance(owner, Timeline.POST_RESOLUTION_MOVEMENT_STATE):
		return
	var converted: Dictionary = _entity(owner.snapshot().world, id)
	_check(
		converted.owner == 0 and converted.attributes.lane == "Castle",
		"10b_redirect_precedes_10c_shift_regardless_of_cart_order"
	)
	var restored = Odradek.new().create_combat_match()
	_check(
		restored.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action != "invalid",
		"mixed_allegiance_snapshot_restores"
	)


func _prepared_replay() -> void:
	var setup: Dictionary = OdradekScenario.world()
	setup.players[0].resources.reconfiguration = 3
	var guard: Dictionary = _guards(setup, 1, "Castle")[0]
	var target: Dictionary = {"entity_id": guard.id, "owner_id": 1, "lane": "Lord"}
	var owner = Odradek.new().create_combat_match()
	owner.start("prepared-orders", setup, [0, 1])
	if not _advance(owner, Timeline.SUBMISSION_LOCK):
		return
	var draft: Array = [
		OdradekScenario.source(0, 1, target, 0, Odradek.FALSE_ORDERS),
		OdradekScenario.source(0, 1, target, 1, Odradek.FALSE_ORDERS)
	]
	_check(owner.submit(0, draft, {}).action != "invalid", "repeated_false_orders_queue")
	owner.submit(1, [], {})
	owner.run_next_hook()
	_check(
		owner.snapshot().world.players[0].resources.reconfiguration == 0,
		"prepared_costs_paid_immediately"
	)
	if not _advance(owner, Timeline.AFTERMATH):
		return
	owner.run_next_hook()
	var restored = Odradek.new().create_combat_match()
	if not _check(
		restored.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action != "invalid",
		"prepared_queue_restores_between_rounds"
	):
		return
	for match_owner in [owner, restored]:
		match_owner.begin_next_round([0, 1])
		if not _advance(match_owner, Timeline.SUBMISSION_LOCK):
			return
	_check(owner.snapshot() == restored.snapshot(), "prepared_orders_replay_exactly")
	_check(
		_entity(owner.snapshot().world, guard.id).attributes.lane == "Lord",
		"false_orders_fires_before_next_deployment"
	)
	var fizzles: Array = owner.player_view(0).events.filter(
		func(e: Dictionary) -> bool: return e.type == "FIZZLE_INVALID_TARGET"
	)
	_check(not fizzles.is_empty(), "second_same_guard_order_fizzles_without_retarget")
	_check(
		owner.snapshot().world.players[0].resources.reconfiguration == 1,
		"fizzle_keeps_payment_only_normal_upkeep_restores_one"
	)


func _interlock_cases() -> void:
	var world: Dictionary = OdradekScenario.world("Odradek")
	var victim: String = _add(world, 0, 0, "Lord", 1200, 300, 0, 2)
	var attacker: String = _add(world, 1, 1, "Lord", 1200, 300, 2, 5)
	var hit: Dictionary = Content.Battle.apply(
		world,
		{
			"command_id": "kill",
			"kind": "marcher_damage",
			"target_id": victim,
			"attacker_id": attacker,
			"damage": 4,
			"cause": "combat"
		},
		1,
		Timeline.MARCHING
	)
	var content = Odradek.new()
	var result: Dictionary = content.react(hit.world, hit.event, "interlock", [0, 1])
	if not _check(result.action == "resolved", "interlock_reacts_after_kill"):
		return
	var survivor: Dictionary = _entity(result.world, attacker)
	_check(
		(
			_entity(result.world, victim).is_empty()
			and survivor.attributes.armor == 0
			and survivor.attributes.hp == 3
		),
		"interlock_reflects_resolved_attack_with_armor_first"
	)
	_check(result.world.data.interlock_rounds == [1, 0], "interlock_only_victim_owner_uses_trigger")
	var second: Dictionary = content.react(result.world, hit.event, "interlock", [0, 1])
	_check(second.world == result.world, "interlock_once_per_round_and_idempotent_fact")
	var lethal: Dictionary = world.duplicate(true)
	var ids = Ids.new()
	ids.restore(lethal.entities)
	var a: Dictionary = ids.get_entity(attacker)
	a.attributes.armor = 0
	a.attributes.hp = 3
	ids.update(a.id, a.owner, a.attributes)
	lethal.entities = ids.snapshot()
	var death: Dictionary = Content.Battle.apply(
		lethal,
		{
			"command_id": "kill2",
			"kind": "marcher_damage",
			"target_id": victim,
			"attacker_id": attacker,
			"damage": 4,
			"cause": "combat"
		},
		1,
		Timeline.MARCHING
	)
	var reflected: Dictionary = content.react(death.world, death.event, "interlock", [0, 1])
	_check(
		(
			_entity(reflected.world, attacker).is_empty()
			and reflected.world.data.interlock_rounds == [1, 0]
		),
		"reflection_can_kill_without_recursive_interlock"
	)
	var hazard: Dictionary = hit.event.duplicate(true)
	hazard.data.cause = "hazard"
	var ignored: Dictionary = content.react(hit.world, hazard, "interlock", [0, 1])
	_check(
		(
			ignored.world.data.interlock_rounds == [0, 0]
			and _entity(ignored.world, attacker) == _entity(hit.world, attacker)
			and ignored.events.is_empty()
		),
		"hazard_kills_do_not_trigger_interlock"
	)
	var fighting: Dictionary = OdradekScenario.world()
	var left: String = _add(fighting, 0, 0, "Lord", 1200, 300, 0, 1)
	var right: String = _add(fighting, 1, 1, "Lord", 1200, 300, 0, 5)
	var marched: Dictionary = Marching.resolve(
		_context(fighting, Timeline.MARCHING), Callable(content, "react")
	)
	if _check(marched.action == "resolved", "real_marching_interlock_resolves"):
		_check(
			marched.world.data.interlock_rounds[0] == 1,
			"marching_emits_killing_attack_damage_for_interlock"
		)


func _paradox_cases() -> void:
	var content = Odradek.new()
	var world: Dictionary = OdradekScenario.world()
	world.data.breach_lord = "Odradek"
	var ids = Ids.new()
	ids.restore(world.entities)
	for row in world.entities.entities:
		if row.kind == "card" and row.attributes.get("role") == "guard":
			ids.retire(row.id)
	world.entities = ids.snapshot()
	var left: String = _add(world, 0, 0, "Lord", 1200, 300)
	var right: String = _add(world, 1, 1, "Lord", 1200, 300)
	var context: Dictionary = _context(world, Timeline.POST_RESOLUTION_ALLEGIANCE)
	var result: Dictionary = content.on_hook(context)
	if not _check(result.action == "resolved", "paradox_marcher_event_resolves"):
		print(result)
		return
	_check(
		_entity(result.world, left).owner == 1 and _entity(result.world, right).owner == 0,
		"paradox_flips_both_sides_from_one_membership_snapshot"
	)
	_check(
		(
			result
			== content.on_hook(
				_context(
					JSON.parse_string(JSON.stringify(world)), Timeline.POST_RESOLUTION_ALLEGIANCE
				)
			)
		),
		"paradox_seeded_json_replay_exact"
	)
	_check(
		(
			content.on_hook(_context(result.world, Timeline.POST_RESOLUTION_ALLEGIANCE)).action
			== "invalid"
		),
		"paradox_once_per_round"
	)
	var guard_world: Dictionary = OdradekScenario.world()
	guard_world.data.breach_lord = "Odradek"
	var guard_result: Dictionary = content.on_hook(
		_context(guard_world, Timeline.POST_RESOLUTION_ALLEGIANCE)
	)
	_check(
		guard_result.action == "resolved" and Transfers.Guards.valid(guard_result.world),
		"paradox_guard_transfer_preserves_capacity"
	)
	_check(
		guard_result.world.data.neutral_tears == guard_world.data.neutral_tears,
		"paradox_is_not_an_inversion_tear"
	)


func _interlock_boundaries() -> void:
	var content = Odradek.new()
	var world: Dictionary = OdradekScenario.world("Odradek")
	var victim: String = _add(world, 0, 0, "Lord", 1200, 300, 0, 1)
	var attacker: String = _add(world, 1, 1, "Lord", 1200, 300, 8, 5)
	var hit: Dictionary = Content.Battle.apply(
		world,
		{
			"command_id": "armor-kill",
			"kind": "marcher_damage",
			"target_id": victim,
			"attacker_id": attacker,
			"damage": 4,
			"cause": "combat"
		},
		1,
		Timeline.MARCHING
	)
	var reflected: Dictionary = content.react(hit.world, hit.event, "armor", [0, 1])
	_check(
		(
			_entity(reflected.world, attacker).attributes.hp == 5
			and _entity(reflected.world, attacker).attributes.armor == 4
		),
		"interlock_can_be_fully_absorbed_by_armor"
	)
	var mutual: Dictionary = hit.world.duplicate(true)
	var ids = Ids.new()
	ids.restore(mutual.entities)
	ids.retire(attacker)
	mutual.entities = ids.snapshot()
	var absent: Dictionary = content.react(mutual, hit.event, "mutual", [0, 1])
	_check(
		(
			absent.action == "resolved"
			and absent.world.data.interlock_rounds == [1, 0]
			and _entity(absent.world, attacker).is_empty()
		),
		"mutual_kill_consumes_interlock_without_reviving_attacker"
	)
	var later: Dictionary = hit.world.duplicate(true)
	later.data.interlock_rounds = [1, 0]
	var next_fact: Dictionary = hit.event.duplicate(true)
	next_fact.data.round = 2
	next_fact.data.event_id += ":round2"
	var next: Dictionary = content.react(later, next_fact, "next", [0, 1])
	_check(
		(
			next.world.data.interlock_rounds == [2, 0]
			and _entity(next.world, attacker).attributes.armor == 4
		),
		"interlock_refreshes_on_new_round"
	)
	var banished: Dictionary = Content.Battle.apply(
		hit.world,
		{
			"command_id": "banish-interlock",
			"kind": "banish_lord",
			"target_id": hit.world.players[0].lord_entity_id
		},
		1,
		Timeline.MARCHING
	)
	if _check(banished.action == "resolved", "interlock_banishment_fixture"):
		var inactive: Dictionary = content.react(banished.world, hit.event, "inactive", [0, 1])
		_check(
			(
				inactive.world.data.interlock_rounds == [0, 0]
				and _entity(inactive.world, attacker) == _entity(hit.world, attacker)
			),
			"banished_odradek_cannot_reflect"
		)
	var empty: Dictionary = OdradekScenario.world()
	empty.data.breach_lord = "Odradek"
	ids.restore(empty.entities)
	for row in empty.entities.entities:
		if row.kind == "card" and row.attributes.get("role") == "guard":
			ids.retire(row.id)
	empty.entities = ids.snapshot()
	var no_targets: Dictionary = content.on_hook(
		_context(empty, Timeline.POST_RESOLUTION_ALLEGIANCE)
	)
	var noop: bool = false
	for row in no_targets.events:
		if row.event.type == "PARADOX_GEOMETRY" and row.event.data.kind == "none":
			noop = true
	_check(no_targets.action == "resolved" and no_targets.world.data.paradox_round == 1 and noop, "paradox_empty_board_is_explicit_noop")
