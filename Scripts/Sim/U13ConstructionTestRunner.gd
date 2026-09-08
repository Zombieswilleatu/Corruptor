extends SceneTree

const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Construction = preload("res://Scripts/Sim/U13Construction.gd")
const Core = preload("res://Scripts/Sim/U13CoreScenario.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Opening = preload("res://Scripts/Sim/U13SmokeSession.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const GremoryCandidates = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Bot = preload("res://Scripts/Sim/U13RandomLegal.gd")
const Legality = preload("res://Scripts/Sim/U13Legality.gd")
const Batch = preload("res://Scripts/Sim/U13RandomBatch.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for test in [
		Callable(self, "_progress_and_payments"),
		Callable(self, "_admission"),
		Callable(self, "_activation_lifecycle"),
		Callable(self, "_completion_and_repair"),
		Callable(self, "_atomic_plans"),
		Callable(self, "_replay_and_timing"),
		Callable(self, "_random_path")
	]:
		test.call()
		if failures > 0:
			break
	print("U13 Construction failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _engine(player_id: int) -> String:
	return Ids.identity("castle", "core:engine:" + str(player_id))


func _entity(world: Dictionary, id: String) -> Dictionary:
	var entities = Ids.new()
	entities.restore(world.entities)
	return entities.get_entity(id)


func _patch_attributes(world: Dictionary, id: String, patch: Dictionary) -> void:
	var entities = Ids.new()
	entities.restore(world.entities)
	var entity: Dictionary = entities.get_entity(id)
	entity.attributes.merge(patch, true)
	entities.update(id, entity.owner, entity.attributes)
	world.entities = entities.snapshot()


func _choice(
	action: String, target_id: String, cards: Array = [], token: bool = false
) -> Dictionary:
	return {"action": action, "target_id": target_id, "card_ids": cards, "use_repair_token": token}


# Exercise the same reservation and Development code used by the match owner.
func _develop(raw: Dictionary, choices: Array) -> Dictionary:
	var world: Dictionary = raw.duplicate(true)
	var round_number: int = int(world.data.construction_round) + 1
	world.data.castle_orders = [null, null]
	for player_id in [0, 1]:
		var accepted: Dictionary = Construction.accept(
			{
				"phase": "commit",
				"player_id": player_id,
				"round": round_number,
				"world": world,
				"order": {"castle_action": choices[player_id]}
			}
		)
		if accepted.action == "invalid":
			return accepted
		world = accepted.world
	return Construction.resolve(
		{
			"hook": Timeline.DEVELOPMENT,
			"world": world,
			"round": round_number,
			"player_order": [0, 1]
		}
	)


func _progress_and_payments() -> void:
	var world: Dictionary = Core.construction_world()
	var content = Deimos.new(true)
	if not _check(content.valid_world(world), "construction_fixture_valid"):
		return
	_check(not Deimos.new().valid_world(world), "old_content_rejects_unhandled_development")
	var ids: Array = world.entities.used_ids.duplicate()
	var free: Dictionary = _develop(
		world, [_choice("Construct", _engine(0)), _choice("Construct", _engine(1))]
	)
	if not _resolved(free, "free_build_and_war_foundry_resolve"):
		return
	for player_id in [0, 1]:
		_check(
			_entity(free.world, _engine(player_id)).attributes.integrity == 3,
			"free_construction_passive_three_" + str(player_id)
		)
	_check(free.world.entities.used_ids == ids, "reconstruction_preserves_stable_identity")
	_check(
		free.events[0].event.data.reconstruction and not free.events[1].event.data.reconstruction,
		"ordinary_build_and_reconstruction_share_progress"
	)
	_check(
		not Structures.operational(_entity(free.world, _engine(0))),
		"three_integrity_not_operational"
	)
	var cards: Array = world.data.card_zones.hands[0].slice(0, 2)
	_patch_attributes(world, cards[0], {"value": 5})
	_patch_attributes(world, cards[1], {"value": 2})
	var accelerated: Dictionary = _develop(world, [_choice("Construct", _engine(0), cards), {}])
	if not _resolved(accelerated, "accelerated_construction_resolves"):
		return
	_check(
		_entity(accelerated.world, _engine(0)).attributes.integrity == 5,
		"printed_value_seven_gives_two_plus_passive_three"
	)
	_check(
		accelerated.events[0].event.data.passive_bonus == 3,
		"card_spending_keeps_full_passive_bonus"
	)
	_check(
		accelerated.world.players[0].resources.repair_tokens == 2, "construction_requires_no_token"
	)
	_check(
		accelerated.world.data.card_zones.discard == cards,
		"construction_discards_exact_physical_payment"
	)
	var pass_result: Dictionary = _develop(free.world, [{}, {}])
	if _resolved(pass_result, "construction_pass_resolves"):
		_check(
			_entity(pass_result.world, _engine(0)).attributes.integrity == 3,
			"pass_does_not_perform_castle_action"
		)
		_check(
			pass_result.world.data.construction_targets[0] == _engine(0),
			"unfinished_target_survives_pass"
		)
	_check(
		(
			(
				Construction
				. resolve(
					{
						"hook": Timeline.DEVELOPMENT,
						"world": free.world,
						"round": 1,
						"player_order": [0, 1]
					}
				)
				. action
			)
			== "invalid"
		),
		"duplicate_development_rejected"
	)


func _admission() -> void:
	var world: Dictionary = Core.construction_world()
	_check(
		(
			Construction.validate_choice(world, 0, _choice("Construct", _engine(1))).action
			== "invalid"
		),
		"cannot_construct_enemy_castle"
	)
	_check(
		(
			(
				Construction
				. validate_choice(world, 0, _choice("Construct", _engine(0), [], true))
				. action
			)
			== "invalid"
		),
		"repair_token_not_construction_currency"
	)
	_patch_attributes(world, _engine(0), {"status": "profaned"})
	_check(
		(
			Construction.validate_choice(world, 0, _choice("Construct", _engine(0))).action
			== "invalid"
		),
		"war_foundry_excludes_profaned_engine"
	)
	world = Core.construction_world()
	_patch_attributes(world, _engine(1), {"status": "ruined", "construction_state": "active"})
	_check(
		(
			Construction.validate_choice(world, 1, _choice("Construct", _engine(1))).action
			== "invalid"
		),
		"gremory_cannot_reconstruct_ruined_engine"
	)
	_patch_attributes(world, world.players[0].lord_entity_id, {"alive": false})
	_check(
		(
			Construction.validate_choice(world, 0, _choice("Construct", _engine(0))).action
			== "invalid"
		),
		"banished_deimos_has_no_war_foundry"
	)
	world = Core.construction_world()
	_patch_attributes(world, Opening._castle_id(0), {"status": "ruined", "integrity": 0})
	_check(
		(
			(
				Construction
				. validate_choice(world, 0, _choice("Construct", Opening._castle_id(0)))
				. action
			)
			== "invalid"
		),
		"war_foundry_only_siege_engines"
	)
	_check(not Structures.targetable(_entity(world, _engine(1))), "unbuilt_slot_not_targetable")
	var bad: Dictionary = Core.construction_world()
	_patch_attributes(bad, _engine(1), {"integrity": 0.5})
	_check(not Construction.valid(bad), "fractional_construction_integrity_rejected")
	bad = Core.construction_world()
	bad.players[0].resources.repair_tokens = 0.5
	_check(not Construction.valid(bad), "fractional_repair_tokens_rejected")


func _activation_lifecycle() -> void:
	var world: Dictionary = Core.construction_world()
	_patch_attributes(
		world, _engine(0), {"status": "standing", "integrity": 7, "construction_state": "building"}
	)
	world.data.construction_targets[0] = _engine(0)
	var content = Deimos.new(true)
	_check(
		(
			not Structures.targetable(_entity(world, _engine(0)))
			and not Structures.operational(_entity(world, _engine(0)))
		),
		"seven_integrity_build_is_protected_and_inactive"
	)
	var invalid_command: Dictionary = {
		"kind": "ruin_castle",
		"command_id": "protected-test",
		"target_id": _engine(0),
		"player_id": 1
	}
	_check(
		Battle.apply(world, invalid_command, 1).action == "invalid",
		"protected_build_rejects_ruination_transition"
	)
	_patch_attributes(
		world,
		_engine(1),
		{
			"status": "standing",
			"integrity": 12,
			"construction_state": "active",
			"artillery_target": _engine(0)
		}
	)
	var shot: Dictionary = Structures.fire(
		world, _engine(1), "protection", 1, "normal", Callable(content, "react"), [0, 1]
	)
	if not _resolved(shot, "artillery_rechecks_protected_target"):
		return
	_check(
		(
			_entity(shot.world, _engine(0)).attributes.integrity == 7
			and _entity(shot.world, Opening._castle_id(0)).attributes.integrity == 6
		),
		"artillery_ignores_protected_build"
	)
	_check(
		(
			(
				Construction
				. validate_choice(
					world,
					0,
					_choice("Activate", _engine(0), world.data.card_zones.hands[0].slice(0, 1))
				)
				. action
			)
			== "invalid"
		),
		"activation_cannot_also_spend_on_build"
	)
	_check(
		(
			Construction.validate_choice(world, 0, _choice("Repair", _engine(0), [], true)).action
			== "invalid"
		),
		"protected_build_cannot_repair"
	)
	var owner = _ready_owner(world)
	if owner == null:
		return
	_check(
		(
			(
				owner
				. preview_submission(
					1,
					[],
					{"action": "Siege", "lane": "Castle", "target_id": _engine(0), "card_ids": []}
				)
				. action
			)
			== "invalid"
		),
		"protected_build_excluded_from_siege"
	)
	var source: Dictionary = GremoryCandidates._source(
		1,
		1,
		Gremory.RUIN,
		{"entity_id": _engine(0)},
		{"discard_ids": world.data.card_zones.hands[1].slice(0, 2)}
	)
	_check(
		owner.preview_submission(1, [source]).action == "invalid",
		"protected_build_excluded_from_inevitable_ruin"
	)
	if not _resolved(
		owner.submit(0, [], {"castle_action": _choice("Activate", _engine(0))}),
		"early_activation_seals"
	):
		return
	owner.submit(1, [], {})
	if not _drive(owner, Timeline.POST_REPAIR_ARTILLERY):
		return
	var active_world: Dictionary = owner.snapshot().world
	_check(
		(
			_entity(active_world, _engine(0)).attributes.integrity == 7
			and Structures.operational(_entity(active_world, _engine(0)))
		),
		"activation_at_seven_grants_effect_without_free_integrity"
	)
	_check(active_world.data.construction_targets[0] == "", "activation_ends_passive_build")
	_check(
		(
			Construction.validate_choice(active_world, 0, _choice("Construct", _engine(0))).action
			== "invalid"
		),
		"activated_castle_cannot_resume_protected_build"
	)
	_check(
		(
			Construction.validate_choice(active_world, 0, _choice("Activate", _engine(0))).action
			== "invalid"
		),
		"activation_is_one_way"
	)
	if not _resolved(owner.run_next_hook(), "activation_round_artillery_resolves"):
		return
	active_world = owner.snapshot().world
	_check(
		(
			_entity(active_world, _engine(0)).attributes.integrity == 5
			and Structures.targetable(_entity(active_world, _engine(0)))
		),
		"early_active_castle_can_take_damage_immediately"
	)
	_check(
		not Structures.operational(_entity(active_world, _engine(0))),
		"damaged_active_castle_still_needs_operational_floor"
	)
	world = Core.construction_world()
	_patch_attributes(
		world, _engine(0), {"status": "standing", "integrity": 6, "construction_state": "building"}
	)
	_check(
		Construction.validate_choice(world, 0, _choice("Activate", _engine(0))).action == "invalid",
		"activation_below_seven_rejected"
	)


func _completion_and_repair() -> void:
	var world: Dictionary = Core.construction_world()
	_patch_attributes(
		world, _engine(0), {"status": "standing", "integrity": 20, "construction_state": "building"}
	)
	world.data.construction_targets[0] = _engine(0)
	var built: Dictionary = _develop(world, [_choice("Construct", _engine(0)), {}])
	if not _resolved(built, "construction_completion_resolves"):
		return
	_check(
		(
			_entity(built.world, _engine(0)).attributes.integrity == 21
			and _entity(built.world, _engine(0)).attributes.construction_state == "ready"
		),
		"completion_caps_at_twenty_one"
	)
	_check(
		built.world.data.construction_targets[0] == "",
		"completion_does_not_auto_select_next_castle"
	)
	_check(
		(
			not Structures.targetable(_entity(built.world, _engine(0)))
			and not Structures.operational(_entity(built.world, _engine(0)))
		),
		"full_build_awaits_player_activation"
	)
	var activated: Dictionary = _develop(built.world, [_choice("Activate", _engine(0)), {}])
	if not _resolved(activated, "full_castle_activation_resolves"):
		return
	built = activated
	_patch_attributes(built.world, _engine(0), {"integrity": 10})
	_check(
		(
			Construction.validate_choice(built.world, 0, _choice("Construct", _engine(0))).action
			== "invalid"
		),
		"activated_damaged_castle_must_repair"
	)
	var repaired: Dictionary = _develop(built.world, [_choice("Repair", _engine(0), [], true), {}])
	if not _resolved(repaired, "repair_token_resolves"):
		return
	_check(
		(
			_entity(repaired.world, _engine(0)).attributes.integrity == 13
			and repaired.world.players[0].resources.repair_tokens == 1
		),
		"repair_token_gives_three_and_is_consumed"
	)
	_check(repaired.events[0].event.data.passive_bonus == 0, "repair_does_not_also_build")
	world = Core.construction_world()
	var cards: Array = world.data.card_zones.hands[0].slice(0, 2)
	_patch_attributes(world, cards[0], {"suit": "Wright", "value": 3})
	_patch_attributes(world, cards[1], {"suit": "Butcher", "value": 3})
	repaired = _develop(world, [_choice("Repair", Opening._castle_id(0), cards), {}])
	if _resolved(repaired, "card_repair_resolves"):
		_check(
			_entity(repaired.world, Opening._castle_id(0)).attributes.integrity == 13,
			"repair_wright_full_other_suit_minus_one"
		)
	_check(
		(
			Construction.validate_choice(world, 0, _choice("Repair", Opening._castle_id(0))).action
			== "invalid"
		),
		"repair_requires_payment"
	)
	var damaged: Dictionary = _entity(world, Opening._castle_id(0))
	damaged.attributes.integrity = 6
	Structures.note_integrity_loss(damaged, 8, 1)
	_patch_attributes(world, damaged.id, damaged.attributes)
	world.data.construction_round = 1
	_check(
		(
			Construction.validate_choice(world, 0, _choice("Repair", damaged.id, [], true)).action
			== "invalid"
		),
		"below_seven_locks_following_round_repair"
	)
	world.data.construction_round = 2
	_check(
		(
			Construction.validate_choice(world, 0, _choice("Repair", damaged.id, [], true)).action
			!= "invalid"
		),
		"repair_lock_expires_after_following_round"
	)

	world = Core.construction_world()
	var source: Dictionary = GremoryCandidates._source(
		1,
		1,
		Gremory.RUIN,
		{"entity_id": Opening._castle_id(0)},
		{"discard_ids": world.data.card_zones.hands[1].slice(0, 2)}
	)
	var content = Deimos.new(true)
	var doomed: Dictionary = content.resolve(
		Data.make_record("pending", source, "main", {}, {}), {"world": world, "round": 2}
	)
	if _resolved(doomed, "ruin_applies_in_development_profile"):
		_check(
			(
				_entity(doomed.world, Opening._castle_id(0)).attributes.get(
					"repair_lock_until_round", 0
				)
				== 3
			),
			"ruin_retains_following_round_repair_lock"
		)
	world = Core.construction_world()
	_patch_attributes(
		world, _engine(0), {"status": "standing", "integrity": 20, "construction_state": "building"}
	)
	world.data.construction_targets[0] = _engine(0)
	world.data.breach_lord = "Deimos"
	var ceiling: Dictionary = Structures.sync_breach(world)
	_check(
		(
			_entity(ceiling.world, _engine(0)).attributes.construction_state == "ready"
			and ceiling.world.data.construction_targets[0] == ""
		),
		"reduced_ceiling_finishes_protected_build_without_activation"
	)


func _ready_owner(world: Dictionary):
	var content = Deimos.new(true)
	var owner = content.create_combat_match()
	if not _resolved(owner.start("construction-tests", world, [0, 1]), "construction_owner_starts"):
		return null
	if not _drive(owner, Timeline.SUBMISSION_LOCK):
		return null
	return owner


func _drive(owner, stop: String) -> bool:
	while owner.next_hook() != stop:
		if owner.next_hook().is_empty():
			return _check(false, "construction_hook_missing")
		var result: Dictionary = owner.run_next_hook()
		if result.action == "invalid":
			return _resolved(result, "construction_hook_" + owner.next_hook())
	return true


func _atomic_plans() -> void:
	var world: Dictionary = Core.construction_world()
	var owner = _ready_owner(world)
	if owner == null:
		return
	var cards: Array = world.data.card_zones.hands[0]
	var order: Dictionary = {
		"action": "Ward",
		"lane": "Castle",
		"card_ids": [cards[0]],
		"castle_action": _choice("Construct", _engine(0), [cards[0]])
	}
	var before: Dictionary = owner.snapshot()
	_check(
		owner.submit(0, [], order).action == "invalid" and owner.snapshot() == before,
		"construction_combat_double_spend_rejected_atomically"
	)
	order = {"castle_action": _choice("Construct", _engine(0), [cards[0], cards[0]])}
	_check(
		owner.submit(0, [], order).action == "invalid" and owner.snapshot() == before,
		"duplicate_construction_card_rejected_atomically"
	)
	order = {
		"castle_action":
		[_choice("Construct", _engine(0)), _choice("Repair", Opening._castle_id(0), [], true)]
	}
	_check(
		owner.submit(0, [], order).action == "invalid" and owner.snapshot() == before,
		"multiple_castle_actions_rejected_atomically"
	)
	cards = world.data.card_zones.hands[1]
	var source: Dictionary = GremoryCandidates._source(
		1, 1, Gremory.RUIN, {"entity_id": Opening._castle_id(0)}, {"discard_ids": cards.slice(0, 2)}
	)
	order = {"castle_action": _choice("Construct", _engine(1), [cards[0]])}
	_check(
		owner.submit(1, [source], order).action == "invalid" and owner.snapshot() == before,
		"power_construction_double_spend_rejected_atomically"
	)
	_check(
		(
			(
				owner
				. preview_submission(
					0,
					[],
					{"action": "Siege", "lane": "Castle", "target_id": _engine(1), "card_ids": []}
				)
				. action
			)
			== "invalid"
		),
		"unbuilt_slot_excluded_from_siege"
	)
	_check(
		Legality.legal_castle_groups(owner, 0, [], [{}, {"action": "Repair"}]).is_empty(),
		"malformed_castle_candidates_skipped"
	)


func _replay_and_timing() -> void:
	var world: Dictionary = Core.construction_world()
	_patch_attributes(
		world,
		_engine(0),
		{
			"integrity": 6,
			"status": "standing",
			"construction_state": "active",
			"artillery_target": Opening._castle_id(1)
		}
	)
	var owner = _ready_owner(world)
	if owner == null:
		return
	var presented: Dictionary = owner.snapshot().world
	var orders: Array = [
		{"castle_action": _choice("Repair", _engine(0), [], true)},
		{
			"castle_action":
			_choice("Construct", _engine(1), world.data.card_zones.hands[1].slice(0, 1))
		}
	]
	for player_id in [0, 1]:
		if not _resolved(
			owner.submit(player_id, [], orders[player_id]), "castle_plan_seals_" + str(player_id)
		):
			return
	_check(owner.snapshot().world == presented, "sealed_castle_plan_has_not_paid_or_advanced")
	var content = Deimos.new(true)
	while not owner.next_hook().is_empty():
		var hook: String = owner.next_hook()
		var saved: Dictionary = owner.snapshot()
		var restored = content.create_combat_match()
		if not _resolved(
			restored.restore(JSON.parse_string(JSON.stringify(saved))),
			"construction_json_restore_" + hook
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
			"construction_replay_" + hook
		):
			print("CONSTRUCTION REPLAY ERROR ", first, " ", second)
			return
		if hook == Timeline.SUBMISSION_LOCK:
			var locked: Dictionary = owner.snapshot()
			_check(
				(
					_entity(locked.world, _engine(0)).attributes.integrity == 6
					and locked.world.players[0].resources.repair_tokens == 1
				),
				"lock_pays_before_development_progress"
			)
			var bad: Dictionary = locked.duplicate(true)
			bad.world.data.castle_orders[1].paid_value += 1
			_check(
				owner.restore(bad).action == "invalid" and owner.snapshot() == locked,
				"tampered_construction_payment_restore_atomic"
			)
			bad = locked.duplicate(true)
			bad.world.players[0].resources.repair_tokens += 1
			_check(
				owner.restore(bad).action == "invalid" and owner.snapshot() == locked,
				"tampered_repair_token_restore_atomic"
			)
			bad = locked.duplicate(true)
			bad.world.data.construction_round += 1
			_check(
				owner.restore(bad).action == "invalid" and owner.snapshot() == locked,
				"future_development_ledger_restore_atomic"
			)
		if hook == Timeline.DEVELOPMENT:
			_check(
				_entity(owner.snapshot().world, _engine(0)).attributes.integrity == 9,
				"repair_before_artillery_restores_operational_engine"
			)
		if hook == Timeline.POST_REPAIR_ARTILLERY:
			_check(
				(
					_entity(owner.snapshot().world, Opening._castle_id(1)).attributes.get(
						"repair_lock_until_round", 0
					)
					== 2
				),
				"artillery_sets_following_round_repair_lock"
			)
			_check(
				_entity(owner.snapshot().world, Opening._castle_id(1)).attributes.integrity == 6,
				"repaired_engine_fires_same_round"
			)
	_check(
		owner.snapshot().world.data.castle_orders == [null, null],
		"castle_reservations_clear_after_round"
	)
	_check(owner.begin_next_round([1, 0]).action != "invalid", "construction_next_round_begins")
	var next_owner = content.create_combat_match()
	_check(
		next_owner.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action != "invalid",
		"construction_next_round_restore"
	)


func _random_path() -> void:
	var owner = _ready_owner(Core.construction_world())
	if owner == null:
		return
	for player_id in [0, 1]:
		var first: Dictionary = Bot.plan(owner, player_id, Callable(Core, "enumerate"))
		var second: Dictionary = Bot.plan(owner, player_id, Callable(Core, "enumerate"))
		if not _check(
			first.action == "bot_plan" and first == second,
			"castle_random_plan_replays_" + str(player_id)
		):
			print("CONSTRUCTION BOT ERROR ", first)
			return
		_check(
			first.order.has("castle_action"), "castle_random_path_produces_action_" + str(player_id)
		)
		_check(
			owner.preview_submission(player_id, first.powers, first.order).action != "invalid",
			"castle_random_full_plan_legal_" + str(player_id)
		)
	var trial: Dictionary = Batch.trial("construction-batch-test", 2, Callable(), "construction")
	if not _check(trial.action == "batch_trial_complete", "construction_random_batch_completes"):
		print("CONSTRUCTION BATCH ERROR ", trial)
		return
	var replay: Dictionary = Batch.trial("construction-batch-test", 2, Callable(), "construction")
	_check(trial == replay, "construction_random_batch_replays")
	_check(
		not trial.summary.castle_actions.is_empty(), "construction_batch_measures_castle_actions"
	)


func _resolved(result: Dictionary, label: String) -> bool:
	if result.action == "invalid":
		print("CONSTRUCTION ERROR ", result)
	return _check(result.action != "invalid", label)


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok
