extends SceneTree

const Core = preload("res://Scripts/Sim/U13CoreScenario.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Construction = preload("res://Scripts/Sim/U13Construction.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_setup()
	_artillery_and_commission()
	_guard_zones()
	_sealed_identity()
	print("U13 Castle loadout failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok


func _selection() -> Array:
	return ["SiegeEngine", "SiegeEngine", "Keep", "Bastion", "Stockpile"]


func _entity(world: Dictionary, id: String) -> Dictionary:
	var ids = Ids.new()
	ids.restore(world.entities)
	return ids.get_entity(id)


func _patch(world: Dictionary, id: String, values: Dictionary) -> void:
	var ids = Ids.new()
	ids.restore(world.entities)
	var row: Dictionary = ids.get_entity(id)
	row.attributes.merge(values, true)
	ids.update(id, row.owner, row.attributes)
	world.entities = ids.snapshot()


func _setup() -> void:
	_check(Slots.selection_valid(_selection()), "two_copies_legal")
	_check(not Slots.selection_valid(["Keep", "Keep", "Bastion", "Stockpile", "SiegeEngine"]), "duplicate_keep_rejected")
	_check(Slots.selection_valid(["Bastion", "Bastion", "Stockpile", "SiegeEngine", "SummoningCircle"]), "optional_keep_accepted")
	_check(Slots.selection_valid(Slots.TYPES), "five_distinct_types_legal")
	_check(
		not Slots.selection_valid(["SiegeEngine", "SiegeEngine", "SiegeEngine", "Keep", "Keep"]),
		"third_copy_rejected"
	)
	_check(not Slots.selection_valid(_selection().slice(0, 4)), "missing_slot_rejected")
	var extra: Array = _selection()
	extra.append("Keep")
	_check(not Slots.selection_valid(extra), "sixth_slot_rejected")
	extra = _selection()
	extra[4] = "Forge"
	_check(not Slots.selection_valid(extra), "unknown_castle_type_rejected")
	var selected: Array = _selection()
	var world: Dictionary = Core.loadout_world(["Deimos", "Gremory"], [selected, selected])
	var content = Deimos.new(true, true)
	_check(content.valid_world(world), "chosen_lords_and_castles_valid")
	selected[0] = "Keep"
	_check(world.data.castle_loadouts[0][0] == "SiegeEngine", "setup_does_not_alias_picker_draft")
	var first: Dictionary = _entity(world, Slots.castle_id(0, 0))
	var second: Dictionary = _entity(world, Slots.castle_id(0, 1))
	_check(first.id != second.id, "duplicate_castle_instances_distinct")
	_check(
		not Structures.targetable(first) and not Structures.operational(first),
		"setup_shell_is_unbuilt_and_protected"
	)
	var swapped: Array = ["Keep", "SiegeEngine", "SiegeEngine", "Bastion", "Stockpile"]
	var draft: Dictionary = Core.loadout_world(["Gremory", "Deimos"], [swapped, swapped])
	_check(
		_entity(draft, first.id).attributes.castle_type == "Keep",
		"slot_identity_independent_of_type_and_lord"
	)
	_check(
		(
			Core.loadout_world(["Humbaba", "Deimos"], [_selection(), _selection()]).get("action")
			== "invalid"
		),
		"unimplemented_lord_not_silently_enabled"
	)
	var started: Dictionary = Core.start_loadout(
		"picker-contract", ["Deimos", "Gremory"], [_selection(), _selection()]
	)
	_check(started.action == "loadout_match_started", "picker_setup_starts_matching_owner")


func _artillery_and_commission() -> void:
	var world: Dictionary = Core.duplicate_world()
	var content = Deimos.new(true, true)
	var a: String = Slots.castle_id(0, 0)
	var b: String = Slots.castle_id(0, 1)
	var target: String = Slots.castle_id(1, 0)
	for id in [a, b]:
		_patch(world, id, {"artillery_target": target})
	var source: Dictionary = Decl.create(
		MatchOwner.declaration_id(0, 1, 0),
		0,
		"Deimos",
		Deimos.WAR_MACHINE,
		1,
		Timeline.POST_REPAIR_ARTILLERY,
		1,
		0,
		"public",
		{"entity_id": b},
		{},
		{}
	)
	var owner = content.create_combat_match()
	if not _check(
		owner.start("double-engine", world, [0, 1]).action != "invalid",
		"double_engine_owner_starts"
	):
		return
	if not _drive(owner, Timeline.SUBMISSION_LOCK):
		return
	_check(
		owner.preview_submission(0, [source]).action != "invalid",
		"war_machine_selects_second_engine"
	)
	var duplicate: Dictionary = source.duplicate(true)
	duplicate.queue_index = 1
	duplicate.declaration_id = MatchOwner.declaration_id(0, 1, 1)
	duplicate.target.entity_id = a
	_check(
		owner.preview_submission(0, [source, duplicate]).action == "invalid",
		"second_engine_does_not_grant_second_war_machine"
	)
	owner.submit(0, [source])
	owner.submit(1, [])
	if not _drive(owner, Timeline.COMMITMENT_REVEAL):
		return
	var counts: Dictionary = {a: 0, b: 0}
	for event in owner.player_view(0).events:
		if event.type == "ARTILLERY_FIRED" and event.data.player_id == 0:
			counts[event.data.engine_id] += 1
	_check(counts[a] == 1 and counts[b] == 2, "two_normal_shots_plus_one_selected_extra")
	_check(
		_entity(owner.snapshot().world, target).attributes.integrity == 15,
		"double_engine_plus_war_machine_six_damage"
	)
	# Protection and construction are per copy, even beside a live same-type Engine.
	world = Core.duplicate_world()
	_patch(world, b, {"integrity": 7, "construction_state": "building"})
	world.data.construction_targets[0] = b
	_check(
		not Structures.operational(_entity(world, b)) and Structures.operational(_entity(world, a)),
		"protected_duplicate_not_operational"
	)
	_check(
		not content.validate(source, world, "declaration").legal,
		"war_machine_rejects_uncommissioned_copy"
	)
	var choice: Dictionary = {
		"action": "Activate", "target_id": b, "card_ids": [], "use_repair_token": false
	}
	_check(
		Construction.validate_choice(world, 0, choice).action != "invalid",
		"commission_second_copy_at_seven"
	)
	var command: Dictionary = {
		"command_id": "protected", "kind": "ruin_castle", "target_id": b, "player_id": 1
	}
	_check(
		Battle.apply(world, command, 1, Timeline.COMBAT_RESOLUTION).action == "invalid",
		"protected_duplicate_cannot_be_ruined"
	)
	_patch(world, b, {"integrity": 0, "status": "ruined", "construction_state": "active"})
	world.data.construction_targets[0] = ""
	choice.action = "Construct"
	_check(
		Construction.validate_choice(world, 0, choice).action != "invalid",
		"war_foundry_reconstructs_selected_duplicate"
	)
	_check(
		_entity(world, a).attributes.integrity == 21,
		"sibling_engine_survives_reconstruction_choice"
	)


func _guard_zones() -> void:
	var content = Deimos.new(true, true)
	var world: Dictionary = Core.duplicate_world()
	var first: String = Slots.castle_id(1, 0)
	var second: String = Slots.castle_id(1, 1)
	var fact: Dictionary = {
		"type": "SIEGE_STARTED", "data": {"player_id": 0, "round": 1, "target_id": second}
	}
	var reacted: Dictionary = content.react(world, fact, "shared-guards", [0, 1])
	var low_guard: String = Ids.identity("card", "smoke:guard:1", 1)
	_check(
		reacted.world.data.card_zones.hands[1].has(low_guard),
		"fear_uses_shared_guard_zone_when_sieging_second_copy"
	)
	var other_fact: Dictionary = fact.duplicate(true)
	other_fact.data.target_id = first
	var other: Dictionary = content.react(world, other_fact, "shared-guards", [0, 1])
	_check(other.world == reacted.world, "fear_guard_selection_independent_of_castle_target")
	# A Gremory attack avoids Fear: the same shared Guards screen both copies.
	world = Core.loadout_world(["Gremory", "Deimos"], [_selection(), _selection()])
	for slot in [0, 1]:
		_patch(
			world,
			Slots.castle_id(1, slot),
			{"integrity": 21, "status": "standing", "construction_state": "active"}
		)
	for target in [first, second]:
		var order: Dictionary = {
			"action": "Siege",
			"lane": "Castle",
			"target_id": target,
			"card_ids": world.data.card_zones.hands[0].slice(0, 1)
		}
		var result: Dictionary = Combat._siege(
			world.duplicate(true),
			{
				"round": 1,
				"hook": Timeline.COMBAT_RESOLUTION,
				"seed": "shared-guards",
				"player_order": [0, 1],
				"combat_orders": [order, {}]
			},
			0,
			order,
			Callable(content, "react")
		)
		_check(
			(
				result.action == "resolved"
				and _entity(result.world, target).attributes.integrity == 21
			),
			"shared_guards_screen_castle_" + target
		)
	var ids = Ids.new()
	ids.restore(world.entities)
	ids.create(
		"card",
		"duplicate:guard:slot",
		0,
		1,
		{"suit": "Wright", "value": 3, "role": "guard", "lane": "Castle", "slot": 0}
	)
	world.entities = ids.snapshot()
	_check(not content.valid_world(world), "duplicate_shared_guard_slot_rejected")


func _sealed_identity() -> void:
	var content = Deimos.new(true, true)
	var owner = content.create_combat_match()
	if not _check(
		owner.start("sealed-loadout", Core.duplicate_world(), [0, 1]).action != "invalid",
		"sealed_loadout_starts"
	):
		return
	var before: Dictionary = owner.snapshot()
	var restored = content.create_combat_match()
	_check(
		(
			restored.restore(JSON.parse_string(JSON.stringify(before))).action != "invalid"
			and restored.snapshot() == before
		),
		"loadout_json_restore_exact"
	)
	var bad: Dictionary = before.duplicate(true)
	_patch(bad.world, Slots.castle_id(0, 0), {"castle_slot": 0.5})
	_check(
		owner.restore(bad).action == "invalid" and owner.snapshot() == before,
		"fractional_slot_restore_atomic"
	)
	bad = before.duplicate(true)
	_patch(bad.world, Slots.castle_id(0, 0), {"castle_type": "Keep"})
	_check(
		owner.restore(bad).action == "invalid" and owner.snapshot() == before,
		"instance_type_must_match_sealed_selection"
	)
	var changed: Dictionary = Core.loadout_world(["Deimos", "Gremory"], [Slots.TYPES, Slots.TYPES])
	_check(
		(
			(
				(
					owner
					. _apply_transform({"action": "resolved", "world": changed, "events": []})
					. action
				)
				== "invalid"
			)
			and owner.snapshot() == before
		),
		"live_transform_cannot_replace_loadout"
	)
	var legacy = Deimos.new(true).create_combat_match()
	_check(
		legacy.restore(before).action == "invalid", "loadout_policy_separate_from_legacy_fixture"
	)


func _drive(owner, stop: String) -> bool:
	for step in range(24):
		if owner.next_hook() == stop:
			return true
		var result: Dictionary = owner.run_next_hook()
		if not _check(result.action != "invalid", "loadout_hook_" + owner.next_hook()):
			print(result)
			return false
	return _check(false, "loadout_hook_limit")
