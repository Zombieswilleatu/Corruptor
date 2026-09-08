extends SceneTree

const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const Core = preload("res://Scripts/Sim/U13CoreScenario.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Bot = preload("res://Scripts/Sim/U13RandomLegal.gd")
const Batch = preload("res://Scripts/Sim/U13RandomBatch.gd")
const Opening = preload("res://Scripts/Sim/U13SmokeSession.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for test in [
		Callable(self, "_artillery"),
		Callable(self, "_spoils_and_identity"),
		Callable(self, "_fear_and_breach"),
		Callable(self, "_match_and_replay"),
		Callable(self, "_firing_recheck"),
		Callable(self, "_mixed_batch")
	]:
		test.call()
		if failures > 0:
			break
	print("U13 Deimos failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _world() -> Dictionary:
	return Core.world(["Deimos", "Gremory"])


func _engine(player_id: int) -> String:
	return Ids.identity("castle", "core:engine:" + str(player_id))


func _entity(world: Dictionary, id: String) -> Dictionary:
	var entities = Ids.new()
	entities.restore(world.entities)
	return entities.get_entity(id)


func _patch_entity_attributes(world: Dictionary, id: String, patch: Dictionary) -> void:
	var entities = Ids.new()
	entities.restore(world.entities)
	var entity: Dictionary = entities.get_entity(id)
	entity.attributes.merge(patch, true)
	entities.update(id, entity.owner, entity.attributes)
	world.entities = entities.snapshot()


func _source(round_number: int = 1) -> Dictionary:
	return Decl.create(
		MatchOwner.declaration_id(0, round_number, 0),
		0,
		"Deimos",
		Deimos.WAR_MACHINE,
		round_number,
		Timeline.POST_REPAIR_ARTILLERY,
		round_number,
		0,
		"public",
		{"entity_id": _engine(0)},
		{},
		{}
	)


func _artillery() -> void:
	var content = Deimos.new()
	var world: Dictionary = _world()
	_check(content.valid_world(world), "deimos_core_world_valid")
	var old_content = Gremory.new()
	var old_owner = old_content.create_combat_match()
	_check(
		old_owner.start("wrong-profile", world, [0, 1]).action == "invalid",
		"gremory_adapter_rejects_unhandled_artillery_profile"
	)
	var target: String = Opening._castle_id(1)
	_patch_entity_attributes(world, _engine(0), {"artillery_target": target})
	var fired: Dictionary = Structures.fire(
		world, _engine(0), "artillery", 1, "normal", Callable(content, "react"), [0, 1]
	)
	_check(_entity(fired.world, target).attributes.integrity == 6, "artillery_two_damage")
	_check(
		_entity(fired.world, _engine(0)).attributes.artillery_target == target,
		"artillery_persistent_target"
	)
	world = fired.world
	_patch_entity_attributes(world, target, {"integrity": 21})
	fired = Structures.fire(
		world, _engine(0), "artillery", 2, "normal", Callable(content, "react"), [0, 1]
	)
	_check(
		_entity(fired.world, target).attributes.integrity == 19,
		"artillery_full_repair_does_not_retarget"
	)
	world = fired.world
	_patch_entity_attributes(world, _engine(0), {"integrity": 6})
	fired = Structures.fire(
		world, _engine(0), "artillery", 3, "normal", Callable(content, "react"), [0, 1]
	)
	_check(
		fired.world == world and fired.events.is_empty(),
		"artillery_below_operational_floor_does_not_fire"
	)
	_patch_entity_attributes(world, _engine(0), {"integrity": 7})
	fired = Structures.fire(
		world, _engine(0), "artillery", 3, "normal", Callable(content, "react"), [0, 1]
	)
	_check(_entity(fired.world, target).attributes.integrity == 17, "artillery_floor_seven_fires")
	_patch_entity_attributes(world, target, {"integrity": 0, "status": "ruined"})
	fired = Structures.fire(
		world, _engine(0), "artillery", 4, "normal", Callable(content, "react"), [0, 1]
	)
	_check(
		_entity(fired.world, _engine(0)).attributes.artillery_target == _engine(1),
		"artillery_reacquires_after_ruin"
	)
	_check(
		_entity(fired.world, _engine(0)).attributes.artillery_acquisitions == 1,
		"artillery_acquisition_counter_serialized"
	)
	var replay: Dictionary = Structures.fire(
		Data.copy_data(JSON.parse_string(JSON.stringify(world))),
		_engine(0),
		"artillery",
		4,
		"normal",
		Callable(content, "react"),
		[0, 1]
	)
	_check(replay == fired, "artillery_json_replays_target_and_events")
	_patch_entity_attributes(world, _engine(1), {"integrity": 0, "status": "profaned"})
	fired = Structures.fire(
		world, _engine(0), "artillery", 5, "normal", Callable(content, "react"), [0, 1]
	)
	_check(fired.events.back().event.type == "ARTILLERY_NO_TARGET", "artillery_no_target_is_finite")
	var wrong_hook: Dictionary = {"hook": Timeline.DEVELOPMENT, "world": world}
	_check(
		Structures.normal_fire(wrong_hook, Callable(content, "react")).action == "invalid",
		"artillery_only_step_seven"
	)


func _spoils_and_identity() -> void:
	var content = Deimos.new()
	var world: Dictionary = _world()
	var target: String = Opening._castle_id(1)
	_patch_entity_attributes(world, target, {"integrity": 2})
	_patch_entity_attributes(world, _engine(0), {"artillery_target": target})
	var first: Dictionary = Structures.fire(
		world, _engine(0), "spoils", 1, "normal", Callable(content, "react"), [0, 1]
	)
	_check(
		_entity(first.world, target).attributes.status == "ruined",
		"ruined_castle_retains_entity_identity"
	)
	_check(
		(
			first.world.players[0].resources.personal_tears == 1
			and first.world.data.neutral_tears == 1
		),
		"first_spoils_personal_plus_normal_neutral"
	)
	var fact: Dictionary = {}
	for envelope in first.events:
		if envelope.event.type == "CASTLE_DESTROYED":
			fact = envelope.event
	var repeated: Dictionary = content.react(first.world, fact, "spoils", [0, 1])
	_check(
		repeated.world == first.world and repeated.events.is_empty(),
		"spoils_duplicate_fact_no_second_reward"
	)
	world = first.world
	_patch_entity_attributes(world, _engine(1), {"integrity": 2})
	var second: Dictionary = Structures.fire(
		world, _engine(0), "spoils", 1, "second", Callable(content, "react"), [0, 1]
	)
	_check(
		(
			second.world.players[0].resources.personal_tears == 1
			and second.world.data.neutral_tears == 2
		),
		"later_spoils_neutral_despite_normal_round_cap"
	)
	_check(second.world.data.deimos_spoils == [2, 0], "spoils_tracks_attributed_lifetime_ruins")
	world = second.world
	# War Foundry is admission to normal Construction, never a free mutation.
	_patch_entity_attributes(
		world, _engine(0), {"integrity": 0, "status": "ruined", "artillery_target": ""}
	)
	var before: Dictionary = world.duplicate(true)
	var eligibility: Dictionary = Structures.reconstruction_eligibility(world, 0, _engine(0))
	_check(
		(
			eligibility.action == "eligible"
			and eligibility.requires_normal_construction
			and world == before
		),
		"war_foundry_eligibility_is_not_free_construction"
	)
	_patch_entity_attributes(world, _engine(0), {"status": "profaned"})
	_check(
		Structures.reconstruction_eligibility(world, 0, _engine(0)).action == "invalid",
		"war_foundry_rejects_profaned_engine"
	)
	_check(
		Structures.reconstruction_eligibility(world, 0, _engine(1)).action == "invalid",
		"war_foundry_rejects_enemy_engine"
	)
	var bad: Dictionary = _world()
	_patch_entity_attributes(bad, _engine(0), {"artillery_target": Opening._castle_id(0)})
	_check(not content.valid_world(bad), "artillery_restore_rejects_friendly_target")
	bad = _world()
	_patch_entity_attributes(bad, _engine(0), {"artillery_acquisitions": 0.5})
	_check(not content.valid_world(bad), "artillery_restore_rejects_fractional_counter")


func _fear_and_breach() -> void:
	var content = Deimos.new()
	var world: Dictionary = _world()
	var lord_id: String = world.players[0].lord_entity_id
	_patch_entity_attributes(world, lord_id, {"threat": 1})
	var entities = Ids.new()
	entities.restore(world.entities)
	var extra: Dictionary = entities.create(
		"card",
		"fear_tie",
		0,
		1,
		{"role": "guard", "suit": "Penitent", "value": 1, "slot": 2, "lane": "Castle"}
	)
	world.entities = entities.snapshot()
	var expected: Array = [extra.entity.id, Ids.identity("card", "smoke:guard:1", 1)]
	expected.sort()
	var fact: Dictionary = {
		"type": "SIEGE_STARTED", "text": "", "data": {"round": 1, "player_id": 0}
	}
	var feared: Dictionary = content.react(world, fact, "fear", [0, 1])
	_check(
		feared.events.back().event.data.returned_ids == expected,
		"fear_lowest_first_stable_identity_tie"
	)
	_check(
		feared.world.data.card_zones.hands[1].size() == 6 and Cards.valid(feared.world),
		"fear_returns_physical_cards_to_hand"
	)
	_check(feared.world.data.card_zones.discard.is_empty(), "fear_return_is_not_guard_defeat")
	var duplicate: Dictionary = content.react(feared.world, fact, "fear", [0, 1])
	_check(
		duplicate.world == feared.world and duplicate.events.is_empty(),
		"fear_duplicate_fact_does_not_return_more_guards"
	)
	world = _world()
	_patch_entity_attributes(world, Opening._castle_id(0), {"integrity": 21})
	var transition: Dictionary = Battle.apply(
		world,
		{"kind": "set_breach", "command_id": "enter-breach", "lord_id": "Deimos"},
		1,
		Timeline.COMBAT_RESOLUTION
	)
	var entered: Dictionary = content.react(transition.world, transition.event, "breach", [0, 1])
	_check(
		(
			_entity(entered.world, Opening._castle_id(0)).attributes.integrity == 16
			and _entity(entered.world, _engine(0)).attributes.integrity == 12
		),
		"cracked_foundations_caps_all_castles_without_extra_damage"
	)
	world = entered.world
	transition = Battle.apply(
		world,
		{"kind": "set_breach", "command_id": "leave-breach", "lord_id": ""},
		2,
		Timeline.COMBAT_RESOLUTION
	)
	var left: Dictionary = content.react(transition.world, transition.event, "breach", [0, 1])
	_check(
		(
			_entity(left.world, Opening._castle_id(0)).attributes.max_integrity == 21
			and _entity(left.world, Opening._castle_id(0)).attributes.integrity == 16
		),
		"ending_breach_restores_ceiling_without_healing"
	)
	_check(content.valid_world(left.world), "breach_exit_world_valid")


func _drive(owner, stop: String) -> bool:
	while owner.next_hook() != stop:
		if owner.next_hook().is_empty():
			return _check(false, "deimos_missing_hook")
		var result: Dictionary = owner.run_next_hook()
		if result.action == "invalid":
			print("DEIMOS ERROR ", result)
			return _check(false, "deimos_hook_progress")
	return true


func _match_and_replay() -> void:
	var content = Deimos.new()
	var owner = content.create_combat_match()
	var world: Dictionary = _world()
	_patch_entity_attributes(world, _engine(0), {"artillery_target": Opening._castle_id(1)})
	_patch_entity_attributes(world, _engine(1), {"artillery_target": Opening._castle_id(0)})
	if (
		not _check(
			owner.start("deimos-replay", world, [0, 1]).action != "invalid", "deimos_match_starts"
		)
		or not _drive(owner, Timeline.SUBMISSION_LOCK)
	):
		return
	var source: Dictionary = _source()
	_check(
		owner.preview_submission(0, [source]).action != "invalid", "war_machine_declaration_legal"
	)
	var twice: Dictionary = source.duplicate(true)
	twice.declaration_id = MatchOwner.declaration_id(0, 1, 1)
	twice.queue_index = 1
	_check(
		owner.preview_submission(0, [source, twice]).action == "invalid",
		"war_machine_duplicate_activation_rejected"
	)
	_check(
		(
			(
				owner
				. preview_submission(0, [], {"action": "Construction", "target_id": _engine(0)})
				. action
			)
			== "invalid"
		),
		"unfinished_construction_not_silently_accepted"
	)
	var orders: Array = [
		{
			"action": "Siege",
			"lane": "Castle",
			"target_id": Opening._castle_id(1),
			"card_ids": world.data.card_zones.hands[0].slice(0, 2)
		},
		{}
	]
	for player_id in [0, 1]:
		if not _check(
			(
				(
					owner
					. submit(player_id, [source] if player_id == 0 else [], orders[player_id])
					. action
				)
				!= "invalid"
			),
			"deimos_sealed_plan_accepted"
		):
			return
	while not owner.next_hook().is_empty():
		var hook: String = owner.next_hook()
		var saved: Dictionary = owner.snapshot()
		var restored = content.create_combat_match()
		if not _check(
			restored.restore(JSON.parse_string(JSON.stringify(saved))).action != "invalid",
			"deimos_json_restore_" + hook
		):
			return
		var first: Dictionary = owner.run_next_hook()
		var second: Dictionary = restored.run_next_hook()
		if not _check(
			(
				first.action != "invalid"
				and first == second
				and owner.snapshot() == restored.snapshot()
			),
			"deimos_replay_" + hook
		):
			print("DEIMOS REPLAY ERROR ", first, " ", second)
			return
		if hook == Timeline.POST_REPAIR_ARTILLERY:
			var shots: Array = []
			for event in owner.player_view(0).events:
				if event.type == "ARTILLERY_FIRED":
					shots.append(event.data)
			_check(shots.size() == 3, "war_machine_exactly_one_extra_shot")
			_check(
				shots[0].player_id == 0 and shots[0].shot != "normal" and shots[1].shot == "normal",
				"war_machine_pending_then_normal_hook_order"
			)
		if hook == Timeline.COMBAT_RESOLUTION:
			var events: Array = owner.player_view(0).events
			var fear_index: int = -1
			var siege_index: int = -1
			for index in range(events.size()):
				if events[index].type == "FEAR_AURA":
					fear_index = index
				if events[index].type == "SIEGE_RESOLVED":
					siege_index = index
			_check(
				fear_index >= 0 and siege_index > fear_index, "fear_runs_before_siege_resolution"
			)
	_check(owner.begin_next_round([0, 1]).action != "invalid", "deimos_next_round")
	if _drive(owner, Timeline.SUBMISSION_LOCK):
		_check(
			owner.preview_submission(0, [_source(2)]).action != "invalid",
			"war_machine_ready_next_round"
		)
	# A power-caused Ruination also triggers public discard reclamation.
	world = _world()
	world.data.breach_lord = "Gremory"
	_patch_entity_attributes(world, Opening._castle_id(1), {"integrity": 2})
	_patch_entity_attributes(world, _engine(0), {"artillery_target": Opening._castle_id(1)})
	Cards.discard(world, 0, world.data.card_zones.hands[0].slice(0, 1))
	owner = content.create_combat_match()
	if (
		not _check(
			owner.start("public-reclamation", world, [0, 1]).action != "invalid",
			"deimos_reaction_match_starts"
		)
		or not _drive(owner, Timeline.SUBMISSION_LOCK)
	):
		return
	owner.submit(0, [_source()], {})
	owner.submit(1, [], {})
	if not _drive(owner, Timeline.COMMITMENT_REVEAL):
		return
	var sifted: bool = false
	for event in owner.player_view(0).events:
		if event.type == "SIFTING_THE_RUINS":
			sifted = event.data.drawn
	_check(sifted, "war_machine_ruination_triggers_gremory_sifting")


func _firing_recheck() -> void:
	var content = Deimos.new()
	var world: Dictionary = Core.world(["Deimos", "Deimos"])
	for player_id in [0, 1]:
		_patch_entity_attributes(
			world, _engine(player_id), {"integrity": 7, "artillery_target": _engine(1 - player_id)}
		)
	var owner = content.create_combat_match()
	if (
		not _check(
			owner.start("deimos-fizzle", world, [0, 1]).action != "invalid", "deimos_mirror_starts"
		)
		or not _drive(owner, Timeline.SUBMISSION_LOCK)
	):
		return
	for player_id in [0, 1]:
		var source: Dictionary = _source()
		source.player_id = player_id
		source.declaration_id = MatchOwner.declaration_id(player_id, 1, 0)
		source.target.entity_id = _engine(player_id)
		if not _check(
			owner.submit(player_id, [source], {}).action != "invalid", "mirror_war_machine_submits"
		):
			return
	if not _drive(owner, Timeline.COMMITMENT_REVEAL):
		return
	var fizzles: int = 0
	var shots: int = 0
	for event in owner.player_view(0).events:
		if event.type == "FIZZLE_INVALID_TARGET":
			fizzles += 1
		if event.type == "ARTILLERY_FIRED":
			shots += 1
	_check(fizzles == 1 and shots == 2, "war_machine_rechecks_operational_engine_at_firing")
	var before: Dictionary = owner.snapshot()
	var bad: Dictionary = before.duplicate(true)
	bad.world.data.artillery_round += 1
	_check(
		owner.restore(bad).action == "invalid" and owner.snapshot() == before,
		"artillery_future_ledger_restore_atomic"
	)


func _mixed_batch() -> void:
	var first: Dictionary = Batch.trial("deimos-mixed-test", 2, Callable(), "mixed")
	if not _check(first.action == "batch_trial_complete", "deimos_mixed_random_trial_completes"):
		print("DEIMOS BATCH ERROR ", first)
		return
	var second: Dictionary = Batch.trial("deimos-mixed-test", 2, Callable(), "mixed")
	_check(first == second, "deimos_mixed_random_replays")
	_check(
		(
			(
				first.summary.powers.get("0:WarMachine", {}).get("declared", 0)
				+ first.summary.powers.get("0:Rout", {}).get("declared", 0)
			)
			> 0
		),
		"deimos_random_path_exercises_legal_power"
	)
	_check(first.roster == ["Deimos", "Gremory"], "deimos_batch_roster_pinned")


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok
