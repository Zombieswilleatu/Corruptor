extends SceneTree

const Content = preload("res://Scripts/Sim/U13Humbaba.gd")
const Scenario = preload("res://Scripts/Sim/U13HumbabaScenario.gd")
const Stats = preload("res://Scripts/Sim/U13LordStats.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_stats()
	_endurance()
	_breach()
	print("U13 Humbaba failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok


func _entity(world: Dictionary, id: String) -> Dictionary:
	for row in world.entities.entities:
		if row.id == id:
			return row
	return {}


func _lord(world: Dictionary, pid: int) -> Dictionary:
	return _entity(world, world.players[pid].lord_entity_id)


func _context(world: Dictionary, hook: String, round_number: int = 1) -> Dictionary:
	return {
		"world": world,
		"hook": hook,
		"round": round_number,
		"seed": "humbaba-focused",
		"player_order": [0, 1],
		"combat_orders": [{}, {}]
	}


func _count(events: Array, type: String) -> int:
	var count: int = 0
	for envelope in events:
		if envelope.event.type == type:
			count += 1
	return count


func _stats() -> void:
	var world: Dictionary = Scenario.world()
	var content = Content.new()
	_check(content.valid_world(world), "humbaba_world_valid")
	_check(not Deimos.new(true, true, true).valid_world(world), "humbaba_requires_own_policy")
	var lord: Dictionary = _lord(world, 0)
	_check(
		not lord.attributes.has("threat") and Stats.threat_value(lord) == null,
		"humbaba_has_no_threat_stat"
	)
	_check(
		not Stats.threat_at_least(lord, 0) and not Stats.threat_at_least(lord, 4),
		"humbaba_cannot_satisfy_even_zero_threat_threshold"
	)
	_check(
		Stats.defense(world, lord) == 4,
		"woven_counts_both_standing_instances_below_operational_floor"
	)
	world.data.castle_loadouts[0][1] = "Keep"
	_entity(world, Slots.castle_id(0, 1)).attributes.castle_type = "Keep"
	_check(Stats.defense(world, lord) == 4, "woven_duplicate_types_count_as_two_instances")
	var protected: Dictionary = _entity(world, Slots.castle_id(0, 2))
	protected.attributes.integrity = 21
	protected.attributes.status = "standing"
	protected.attributes.construction_state = "ready"
	_check(Stats.defense(world, lord) == 4, "woven_excludes_full_uncommissioned_build")
	protected.attributes.construction_state = "active"
	_check(Stats.defense(world, lord) == 5, "woven_counts_commissioned_instance")
	protected.attributes.status = "ruined"
	protected.attributes.integrity = 0
	_check(Stats.defense(world, lord) == 4, "woven_updates_after_ruination")
	for slot in [0, 1]:
		var castle: Dictionary = _entity(world, Slots.castle_id(0, slot))
		castle.attributes.integrity = 0
		castle.attributes.status = "defunct"
	_check(Stats.defense(world, lord) == 2, "woven_no_standing_castles_base_two")
	lord.attributes["threat"] = 0
	_check(not content.valid_world(world), "humbaba_rejects_threat_zero_in_state")
	lord.attributes.threat = 4
	_check(not content.valid_world(world), "humbaba_rejects_added_threat")
	var ordinary: Dictionary = _lord(Scenario.world("Deimos"), 1)
	ordinary.attributes.threat = 3
	_check(
		Stats.threat_at_least(ordinary, 3) and Stats.defense(world, ordinary) == 2,
		"ordinary_threat_defense_preserved"
	)


func _add_unit(world: Dictionary, pid: int, suit: String, hp: int, armor: int = 0) -> String:
	var entities = Ids.new()
	if not _check(
		entities.restore(world.entities).action != "invalid", "endurance_fixture_restores"
	):
		return ""
	var a: Dictionary = Marching.profile(suit, "Lord", pid, 1, 1)
	a.hp = hp
	a.armor = armor
	# Historical identity count cannot shrink when a fixture unit dies.
	var created: Dictionary = entities.create(
		"marcher", "endurance-test", world.entities.used_ids.size(), pid, a
	)
	if not _check(created.action != "invalid", "endurance_fixture_unit_created"):
		return ""
	world.entities = entities.snapshot()
	return created.entity.id


func _endurance() -> void:
	for hp in [1, 2]:
		var world: Dictionary = Scenario.world()
		_add_unit(world, 0, "Penitent", hp, 9)
		_add_unit(world, 0, "Penitent", hp, 0)
		_add_unit(world, 1, "Penitent", 1)
		_add_unit(world, 0, "Butcher", 1)
		var before: Dictionary = world.duplicate(true)
		var result: Dictionary = Content.endurance(_context(world, Timeline.END_MARCHING_CHECKS))
		_check(
			result.world.data.neutral_tears == (1 if hp == 1 else 0),
			"endurance_exact_final_hp_once_" + str(hp)
		)
		_check(
			_count(result.events, "ENDURANCE_CHECKED") == 1,
			"endurance_emits_opportunity_" + str(hp)
		)
		_check(world == before, "endurance_input_isolated_" + str(hp))
		_check(
			(
				Content.endurance(_context(result.world, Timeline.END_MARCHING_CHECKS)).action
				== "invalid"
			),
			"endurance_duplicate_hook_rejected_" + str(hp)
		)
	var world: Dictionary = Scenario.world()
	var unit_id: String = _add_unit(world, 0, "Penitent", 1)
	var healed: Dictionary = Marching.regenerate(_context(world, Timeline.ROUND_START_AUTOMATIC))
	if _check(healed.action == "resolved", "endurance_shared_regen_resolves"):
		_check(_entity(healed.world, unit_id).attributes.hp > 1, "penitent_regenerated_above_one")
		var result: Dictionary = Content.endurance(
			_context(healed.world, Timeline.END_MARCHING_CHECKS)
		)
		_check(result.world.data.neutral_tears == 0, "healed_penitent_does_not_qualify")
	var entities = Ids.new()
	entities.restore(world.entities)
	entities.retire(unit_id)
	world.entities = entities.snapshot()
	_check(
		(
			(
				Content
				. endurance(_context(world, Timeline.END_MARCHING_CHECKS))
				. world
				. data
				. neutral_tears
			)
			== 0
		),
		"dead_penitent_does_not_qualify"
	)
	_check(
		Content.endurance(_context(world, Timeline.MARCHING)).action == "invalid",
		"endurance_only_at_step_thirteen"
	)
	var replacement_id: String = _add_unit(world, 0, "Penitent", 1)
	if not _check(
		(
			not replacement_id.is_empty()
			and replacement_id != unit_id
			and _entity(world, replacement_id).get("attributes", {}).get("hp") == 1
			and unit_id in world.entities.used_ids
		),
		"endurance_replacement_has_new_identity_and_one_hp"
	):
		return
	_check(
		(
			(
				Content
				. endurance(_context(world, Timeline.END_MARCHING_CHECKS))
				. world
				. data
				. neutral_tears
			)
			== 1
		),
		"endurance_replacement_qualifies_before_banishment"
	)
	_lord(world, 0).attributes.alive = false
	_check(
		(
			(
				Content
				. endurance(_context(world, Timeline.END_MARCHING_CHECKS))
				. world
				. data
				. neutral_tears
			)
			== 0
		),
		"endurance_passive_requires_living_lord"
	)


func _entry(world: Dictionary, suffix: String, round_number: int = 1) -> Dictionary:
	var lord: Dictionary = _lord(world, 0)
	lord.attributes.alive = false
	return Battle.apply(
		world,
		{
			"kind": "set_breach",
			"command_id": "entry:" + suffix,
			"lord_id": "Humbaba",
			"source_id": lord.id
		},
		round_number,
		Timeline.COMBAT_RESOLUTION
	)


func _breach() -> void:
	var content = Content.new()
	var world: Dictionary = Scenario.world()
	for pid in [0, 1]:
		var protected: Dictionary = _entity(world, Slots.castle_id(pid, 2))
		protected.attributes.integrity = 21
		protected.attributes.status = "standing"
		protected.attributes.construction_state = "ready"
		var building: Dictionary = _entity(world, Slots.castle_id(pid, 3))
		building.attributes.integrity = 9
		building.attributes.status = "standing"
		building.attributes.construction_state = "building"
		world.data.construction_targets[pid] = building.id
	var entered: Dictionary = _entry(world, "first")
	if not _check(entered.action == "resolved", "stones_breach_entry_fact"):
		return
	var result: Dictionary = content.react(entered.world, entered.event, "stones", [0, 1])
	if not _check(result.action == "resolved", "stones_entry_resolves"):
		return
	for pid in [0, 1]:
		var damaged: Dictionary = _entity(result.world, Slots.castle_id(pid, 0))
		var ruined: Dictionary = _entity(result.world, Slots.castle_id(pid, 1))
		_check(
			damaged.attributes.integrity == 4 and damaged.attributes.repair_lock_until_round == 2,
			"stones_both_sides_damage_and_normal_repair_lock_" + str(pid)
		)
		_check(
			ruined.attributes.status == "ruined" and ruined.attributes.integrity == 0,
			"stones_keeps_ruined_instance_identity_" + str(pid)
		)
		_check(
			_entity(result.world, Slots.castle_id(pid, 2)).attributes.integrity == 21,
			"stones_protected_ready_castle_" + str(pid)
		)
		_check(
			(
				_entity(result.world, Slots.castle_id(pid, 3)).attributes.integrity == 9
				and result.world.data.construction_targets[pid] == Slots.castle_id(pid, 3)
			),
			"stones_protects_construction_in_progress_" + str(pid)
		)
	_check(_count(result.events, "CASTLE_DESTROYED") == 2, "stones_normal_destruction_facts")
	_check(_count(result.events, "SIFTING_THE_RUINS") == 1, "stones_gremory_reaction_once")
	_check(result.world.data.neutral_tears == 1, "stones_normal_castle_tear_once_per_round")
	_check(
		(
			result.world.players[0].resources.souls == 0
			and result.world.players[1].resources.souls == 0
		),
		"stones_no_siege_soul_credit"
	)
	_check(content.valid_world(result.world), "stones_result_world_valid")
	var duplicate: Dictionary = content.react(result.world, entered.event, "stones", [0, 1])
	_check(
		duplicate.world == result.world and duplicate.events.is_empty(),
		"stones_same_entry_not_repeated"
	)
	var later: Dictionary = content.on_hook(_context(result.world, Timeline.MARCHING_START, 2))
	_check(later.world.entities == result.world.entities, "stones_does_not_repeat_while_in_breach")
	# Fixture transition represents leaving, then a later real Banishment.
	var exited: Dictionary = Battle.apply(
		result.world,
		{"kind": "set_breach", "command_id": "leave-humbaba", "lord_id": "Gremory"},
		2,
		Timeline.COMBAT_RESOLUTION
	)
	_lord(exited.world, 0).attributes.alive = true
	var second: Dictionary = _entry(exited.world, "second", 2)
	var repeated: Dictionary = content.react(second.world, second.event, "stones", [0, 1])
	_check(
		(
			_count(repeated.events, "THE_STONES_FORGET") == 1
			and repeated.world.data.humbaba_breach_entries.size() == 2
		),
		"stones_new_entry_fires_again"
	)
	var deimos_world: Dictionary = Scenario.world("Deimos")
	var deimos_entry: Dictionary = _entry(deimos_world, "deimos")
	var hazard: Dictionary = content.react(deimos_entry.world, deimos_entry.event, "stones", [0, 1])
	_check(
		(
			hazard.world.data.deimos_spoils == [0, 0]
			and hazard.world.players[1].resources.personal_tears == 0
		),
		"stones_environmental_damage_does_not_credit_deimos_spoils"
	)
