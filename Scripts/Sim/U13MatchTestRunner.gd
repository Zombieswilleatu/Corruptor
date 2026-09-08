extends SceneTree

const EventLog = preload("res://Scripts/Sim/U13EventLog.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
var failures: int = 0
var _inject_failure: bool = false


func _init() -> void:
	if not _test_startup():
		print("U13 match foundation failures: %d" % failures)
		quit(1)
		return
	_test_submission()
	_test_fizzle_and_survival()
	_test_persistent_and_hidden_replay()
	_test_transaction()
	_test_order()
	_test_independent_persistent_slots()
	_test_joint_declaration_context()
	_test_restore_guards()
	_test_event_forks()
	_test_internal_forks()
	print("U13 match foundation failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _test_startup() -> bool:
	var rules: Dictionary = _rules()
	_check(Data.is_data(rules), "fixture_rules_use_serializable_string_keys")
	if failures > 0:
		return false
	var invalid_rules: Dictionary = rules.duplicate(true)
	invalid_rules[StringName("InvalidKey")] = rules.Zone.duplicate(true)
	var rejected: Dictionary = _owner("fixture_v1", invalid_rules).start(
		"fixture_seed", _world(), [1, 0]
	)
	_check(
		rejected.get("reason") == "match_rules_data_invalid",
		"non_string_rule_key_rejected_explicitly"
	)
	var owner = _owner()
	var started: Dictionary = owner.start("fixture_seed", _world(), [1, 0])
	_check(started.action != "invalid", "startup_precondition")
	if started.action == "invalid":
		print("MATCH START ERROR: ", started)
		return false
	var world: Dictionary = owner.snapshot().world
	_check(
		world.players.size() == 2 and world.entities.entities.size() == 4,
		"startup_installs_complete_world"
	)
	return failures == 0


func _rules() -> Dictionary:
	var base: Dictionary = {
		"lord_id": "Fixture",
		"fire_hook": Timeline.POST_RESOLUTION_DIRECT,
		"cooldown_on": "activation",
		"cooldown_rounds": 1,
		"delay_rounds": 0,
		"cost": {"souls": 2},
		"stages": [],
		"target_kind": "castle",
		"target_relation": "enemy",
		"visibility": "public"
	}
	var rules: Dictionary = {
		"Strike": base.duplicate(true),
		"Other": base.duplicate(true),
		"Delayed": base.duplicate(true),
		"Zone": base.duplicate(true),
		"Secret": base.duplicate(true)
	}
	rules.Delayed.delay_rounds = 1
	rules.Delayed.fire_hook = Timeline.ROUND_START_SCHEDULED
	rules.Zone.delay_rounds = 1
	rules.Zone.fire_hook = Timeline.PERSISTENT_ADVANCEMENT
	rules.Zone.cooldown_on = "expiration"
	rules.Zone.stages = [{"strength": 2}, {"strength": 1}]
	rules.Zone.target_kind = ""
	rules.Secret.delay_rounds = 1
	rules.Secret.fire_hook = Timeline.ROUND_START_SCHEDULED
	rules.Secret.visibility = "hidden"
	rules.Secret.target_kind = ""
	# New data keys must be String, not the StringName produced by dot insertion.
	rules["SecondZone"] = rules.Zone.duplicate(true)
	return rules


func _owner(policy: String = "fixture_v1", rules: Dictionary = {}):
	var configured: Dictionary = _rules() if rules.is_empty() else rules
	var validators: Dictionary = {}
	var resolvers: Dictionary = {}
	for power_id in configured:
		validators[power_id] = Callable(self, "_validate")
		resolvers[power_id] = Callable(self, "_resolve")
	return MatchOwner.new(
		policy,
		configured,
		validators,
		resolvers,
		Callable(self, "_project"),
		Callable(self, "_hook")
	)


func _world(settings: Dictionary = {}) -> Dictionary:
	var entities = Ids.new()
	var players: Array = []
	for player_id in [0, 1]:
		var lord: Dictionary = entities.create(
			"lord",
			"setup:p%d:Fixture" % player_id,
			0,
			player_id,
			{"lord_id": "Fixture", "alive": true}
		)
		entities.create("castle", "setup:p%d:Keep" % player_id, 0, player_id)
		players.append(
			{
				"lord_id": "Fixture",
				"lord_entity_id": lord.entity.id,
				"resources": {"souls": 10, "tears": 0}
			}
		)
	var state: Dictionary = {"hits": 0, "secrets": [], "order": [], "settings": settings}
	return {"players": players, "entities": entities.snapshot(), "data": state}


func _fixture(settings: Dictionary = {}):
	var owner = _owner()
	var started: Dictionary = owner.start("fixture_seed", _world(settings), [1, 0])
	_check(started.action != "invalid", "match_starts")
	if started.action == "invalid":
		print("MATCH START ERROR: ", started)
		return null
	_drive(owner, Timeline.SUBMISSION_LOCK)
	return owner


func _declaration(
	power: String, index: int = 0, round_number: int = 1, player_id: int = 0
) -> Dictionary:
	var rule: Dictionary = _rules()[power]
	var target: Dictionary = {}
	if not rule.target_kind.is_empty():
		target = {"entity_id": Ids.identity("castle", "setup:p%d:Keep" % (1 - player_id))}
	return Decl.create(
		MatchOwner.declaration_id(player_id, round_number, index),
		player_id,
		"Fixture",
		power,
		round_number,
		rule.fire_hook,
		round_number + int(rule.delay_rounds),
		index,
		rule.visibility,
		target,
		rule.cost,
		{"secret": "NEVER_EXPOSE"} if power == "Secret" else {}
	)


func _validate(source: Dictionary, world: Dictionary, phase: String) -> Dictionary:
	if (
		phase == "declaration"
		and world.data.settings.get("opponent_unspent", false)
		and world.players[1 - source.player_id].resources.souls != 10
	):
		return {"legal": false, "reason": "opponent_already_spent"}
	if world.data.settings.get("reject_" + phase, false):
		return {"legal": false, "reason": "fixture_rule_rejects"}
	# Reference parameters deliberately remain data, without Node lookups.
	return {"legal": not source.parameters.get("invalid_choice", false), "reason": "invalid_choice"}


func _resolve(record: Dictionary, context: Dictionary) -> Dictionary:
	if _inject_failure and record.declaration.power_id == "Other":
		return {"action": "invalid", "reason": "injected_engine_failure"}
	var world: Dictionary = context.world
	world.data.hits += 1
	world.data.order.append(str(record.declaration.player_id) + ":" + record.declaration.power_id)
	if record.declaration.power_id == "Secret":
		var roll: Dictionary = Rng.draw(context.seed, record.effect_id, "FIXTURE_SECRET", 0, 100)
		world.data.secrets.append({"outcome": "NEVER_EXPOSE", "roll": roll.value})
	return {
		"action": "resolved",
		"world": world,
		"events":
		[
			{
				"type": "FIXTURE_REWARD",
				"text": "",
				"data": {"power_id": record.declaration.power_id, "reward": 1}
			}
		]
	}


func _hook(hook: String, round_number: int, world: Dictionary) -> Dictionary:
	if hook == Timeline.COMBAT_RESOLUTION and round_number == 1:
		var entities = Ids.new()
		entities.restore(world.entities)
		if world.data.settings.get("banish", false):
			var lord: Dictionary = entities.get_entity(world.players[0].lord_entity_id)
			lord.attributes.alive = false
			entities.update(lord.id, lord.owner, lord.attributes)
		if world.data.settings.get("destroy", false):
			entities.retire(Ids.identity("castle", "setup:p1:Keep"))
			entities.create("castle", "rebuild:round1", 0, 1)
		world.entities = entities.snapshot()
	return {"action": "resolved", "world": world, "events": []}


func _project(world: Dictionary, player_id: int) -> Dictionary:
	# A deliberate allowlist. Internal data/secrets/seed never enter a view.
	return {
		"own_resources": world.players[player_id].resources.duplicate(true), "hits": world.data.hits
	}


func _test_submission() -> void:
	var owner = _fixture()
	if owner == null:
		return
	var before: Dictionary = owner.snapshot()
	_check(
		owner.run_next_hook().action == "invalid" and owner.snapshot() == before,
		"lock_requires_both_submissions_atomic"
	)
	var source: Dictionary = _declaration("Strike")
	_check(
		owner.preview_submission(0, [source]).action == "legal" and owner.snapshot() == before,
		"ui_bot_preview_has_no_side_effects"
	)
	var invalid: Dictionary = source.duplicate(true)
	invalid.cost.souls = 0
	_check(
		(
			owner.preview_submission(0, [invalid]).action == "invalid"
			and owner.submit(0, [invalid]).action == "invalid"
		),
		"preview_and_submit_reject_forged_cost"
	)
	invalid = source.duplicate(true)
	invalid.fire_round = 9
	_check(
		owner.submit(0, [invalid]).action == "invalid", "client_cannot_choose_arbitrary_fire_time"
	)
	invalid = source.duplicate(true)
	invalid.declaration_id = "forged"
	_check(owner.submit(0, [invalid]).action == "invalid", "declaration_identity_owned_by_match")
	var duplicate: Dictionary = _declaration("Strike", 1)
	_check(
		owner.submit(0, [source, duplicate]).action == "invalid" and owner.snapshot() == before,
		"whole_submission_cooldown_reservation_atomic"
	)
	_check(owner.submit(0, [source]).action != "invalid", "legal_submission_accepted")
	_check(owner.submit(0, []).action == "invalid", "one_complete_submission_per_player")
	_check(
		owner.snapshot().world.players[0].resources.souls == 10,
		"cost_not_publicly_spent_before_joint_lock"
	)
	owner.submit(1, [])
	_check(
		(
			owner.run_next_hook().action != "invalid"
			and owner.snapshot().world.players[0].resources.souls == 8
		),
		"joint_lock_spends_once"
	)
	_check(owner.submit(1, []).action == "invalid", "no_post_lock_prompt")
	_drive(owner)
	_check(owner.snapshot().world.data.hits == 1, "accepted_power_resolves")
	var poor = _owner()
	var world: Dictionary = _world()
	world.players[0].resources.souls = 3
	poor.start("seed", world, [0, 1])
	_drive(poor, Timeline.SUBMISSION_LOCK)
	_check(
		(
			poor.submit(0, [_declaration("Strike"), _declaration("Other", 1)]).action == "invalid"
			and poor.snapshot().world.players[0].resources.souls == 3
		),
		"combined_cost_cannot_double_spend"
	)


func _test_fizzle_and_survival() -> void:
	var owner = _fixture({"destroy": true})
	if owner == null:
		return
	owner.submit(0, [_declaration("Strike")])
	owner.submit(1, [])
	_drive(owner)
	_check(
		(
			owner.snapshot().world.data.hits == 0
			and owner.snapshot().world.players[0].resources.souls == 8
		),
		"fizzle_spent_cost_no_reward"
	)
	_check(
		_count(owner.player_view(0).events, "FIZZLE_INVALID_TARGET") == 1,
		"destroyed_rebuilt_target_fizzles_once"
	)
	_check(owner.snapshot().pending.pending.is_empty(), "fizzle_consumes_pending_instance")
	owner = _fixture({"banish": true})
	if owner == null:
		return
	owner.submit(0, [_declaration("Delayed")])
	owner.submit(1, [])
	_drive(owner)
	owner.begin_next_round([1, 0])
	_check(
		owner.run_next_hook().action != "invalid" and owner.snapshot().world.data.hits == 1,
		"armed_delayed_power_survives_banishment"
	)
	_drive(owner, Timeline.SUBMISSION_LOCK)
	_check(
		owner.preview_submission(0, [_declaration("Other", 0, 2)]).action == "invalid",
		"banished_source_cannot_declare_new_power"
	)
	owner = _fixture({"reject_firing": true})
	if owner == null:
		return
	owner.submit(0, [_declaration("Strike")])
	owner.submit(1, [])
	_drive(owner)
	_check(
		(
			_count(owner.player_view(0).events, "FIZZLE_INVALID_TARGET") == 1
			and owner.snapshot().world.data.hits == 0
		),
		"shared_power_specific_firing_legality"
	)


func _test_persistent_and_hidden_replay() -> void:
	var owner = _fixture()
	if owner == null:
		return
	owner.submit(0, [_declaration("Zone"), _declaration("Secret", 1)])
	owner.submit(1, [])
	_drive(owner)
	for player_id in [0, 1]:
		var view: Dictionary = owner.player_view(player_id)
		_check(
			not JSON.stringify(view).contains("NEVER_EXPOSE") and not view.has("seed"),
			"match_view_hides_secrets_%d" % player_id
		)
		_check(
			view.pending.size() == 2 and view.pending[0].fire_round == 2,
			"hidden_due_round_is_public"
		)
	var resumed = _owner()
	_check(
		resumed.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action != "invalid",
		"match_json_restored"
	)
	for round_number in [2, 3, 4, 5]:
		for match_owner in [owner, resumed]:
			_check(
				match_owner.begin_next_round([0, 1]).action != "invalid", "consecutive_match_round"
			)
			_drive(match_owner, Timeline.SUBMISSION_LOCK)
			if round_number == 2:
				_check(
					match_owner.snapshot().persistent.active[0].stage_index == 0,
					"prepared_step_two_creation_starts_at_stage_zero"
				)
			if round_number == 4:
				_check(
					match_owner.snapshot().persistent.active.is_empty(),
					"persistent_expires_before_submission"
				)
				_check(
					(
						match_owner.preview_submission(0, [_declaration("Zone", 0, 4)]).action
						== "invalid"
					),
					"expiry_round_is_cooldown_round"
				)
			if round_number == 5:
				_check(
					(
						match_owner.preview_submission(0, [_declaration("Zone", 0, 5)]).action
						== "legal"
					),
					"persistent_power_ready_after_expiration_cooldown"
				)
			match_owner.submit(0, [])
			match_owner.submit(1, [])
			_drive(match_owner)
		_check(
			owner.snapshot() == resumed.snapshot(), "aggregate_replay_exact_round_%d" % round_number
		)
	_check(owner.snapshot().world.data.secrets.size() == 1, "hidden_rng_outcome_resolves_once")
	_check(
		(
			not JSON.stringify(owner.player_view(0)).contains("NEVER_EXPOSE")
			and not JSON.stringify(owner.player_view(1)).contains("NEVER_EXPOSE")
		),
		"resolved_hidden_outcome_stays_hidden_from_both"
	)


func _test_transaction() -> void:
	var owner = _fixture()
	if owner == null:
		return
	owner.submit(0, [_declaration("Strike"), _declaration("Other", 1)])
	owner.submit(1, [])
	_drive(owner, Timeline.POST_RESOLUTION_DIRECT)
	var before: Dictionary = owner.snapshot()
	_inject_failure = true
	_check(
		owner.run_next_hook().action == "invalid" and owner.snapshot() == before,
		"later_resolver_error_rolls_back_whole_hook"
	)
	_inject_failure = false
	_check(
		owner.run_next_hook().action != "invalid" and owner.snapshot().world.data.hits == 2,
		"retry_resolves_each_effect_once"
	)
	_check(
		_count(owner.player_view(0).events, "POWER_RESOLVED") == 2,
		"retry_does_not_duplicate_events"
	)


func _test_order() -> void:
	var owner = _fixture()
	if owner == null:
		return
	owner.submit(0, [_declaration("Strike"), _declaration("Other", 1)])
	owner.submit(1, [_declaration("Strike", 0, 1, 1)])
	_drive(owner)
	_check(
		owner.snapshot().world.data.order == ["1:Strike", "0:Strike", "0:Other"],
		"match_uses_explicit_reflex_then_queue_order"
	)


func _test_independent_persistent_slots() -> void:
	var owner = _fixture()
	if owner == null:
		return
	_check(
		owner.submit(0, [_declaration("Zone"), _declaration("SecondZone", 1)]).action != "invalid",
		"independent_persistent_powers_can_be_declared"
	)
	owner.submit(1, [])
	_drive(owner)
	owner.begin_next_round([0, 1])
	_drive(owner, Timeline.SUBMISSION_LOCK)
	_check(owner.snapshot().persistent.active.size() == 2, "persistent_slots_are_per_named_power")
	var resumed = _owner()
	_check(
		resumed.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action != "invalid",
		"multiple_persistent_slots_restore"
	)


func _test_joint_declaration_context() -> void:
	var owner = _fixture({"opponent_unspent": true})
	if owner == null:
		return
	_check(
		owner.submit(0, [_declaration("Strike")]).action != "invalid",
		"first_submission_uses_presented_world"
	)
	_check(
		owner.submit(1, [_declaration("Strike", 0, 1, 1)]).action != "invalid",
		"second_submission_uses_presented_world"
	)
	_check(
		owner.run_next_hook().action != "invalid",
		"joint_lock_does_not_change_opponent_declaration_context"
	)


func _test_restore_guards() -> void:
	var owner = _fixture()
	if owner == null:
		return
	var before: Dictionary = owner.snapshot()
	for key in ["policy_id", "rng_version", "engine_version", "rules_hash"]:
		var corrupt: Dictionary = before.duplicate(true)
		corrupt[key] = "wrong"
		_check(
			owner.restore(corrupt).action == "invalid" and owner.snapshot() == before,
			"snapshot_version_rejected_" + key
		)
	var corrupt: Dictionary = before.duplicate(true)
	corrupt.runtime.next_hook_index = 4.5
	_check(
		owner.restore(corrupt).action == "invalid" and owner.snapshot() == before,
		"fractional_match_cursor_restore_atomic"
	)
	corrupt = before.duplicate(true)
	corrupt.cooldowns.round = 0
	_check(
		owner.restore(corrupt).action == "invalid" and owner.snapshot() == before,
		"cross_component_round_mismatch_rejected"
	)
	var changed: Dictionary = _rules()
	changed.Strike.cost.souls = 1
	_check(
		_owner("fixture_v1", changed).restore(before).action == "invalid",
		"rule_content_change_requires_matching_snapshot"
	)
	_check(owner.begin_next_round([0, 1]).action == "invalid", "cannot_skip_unfinished_round")
	var resumed = _owner()
	owner.submit(0, [_declaration("Strike")])
	_check(
		resumed.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action != "invalid",
		"save_after_one_submission"
	)
	_check(resumed.submit(0, []).action == "invalid", "submission_lock_survives_restore")
	resumed.submit(1, [])
	_check(
		resumed.run_next_hook().action != "invalid", "restored_submission_can_complete_joint_lock"
	)


func _test_event_forks() -> void:
	var original = EventLog.new()
	var event: Dictionary = {"type": "FORK_FIXTURE", "text": "", "data": {"nested": {"value": 1}}}
	original.append(event, [event, null])
	var before: Dictionary = original.snapshot()
	var fork = original._fork()
	var public_rows: Array = fork.for_player(0)
	public_rows[0].data.nested.value = 99
	var exported: Dictionary = fork.snapshot()
	exported.rows[0].event.data.nested.value = 88
	exported.rows[0].views[0].data.nested.value = 77
	_check(
		original.snapshot() == before and fork.snapshot() == before,
		"fork_history_exports_are_deep_copies"
	)
	_check(fork.for_player(1).is_empty(), "fork_history_keeps_hidden_views_hidden")
	fork.append(event, [event, event])
	_check(
		original.snapshot() == before and fork.snapshot().rows.size() == 2,
		"fork_event_append_isolated"
	)
	original.append(event, [null, event])
	_check(
		fork.for_player(0).size() == 2 and original.for_player(0).size() == 1,
		"parent_event_append_isolated_from_fork"
	)
	var replacement: Dictionary = before.duplicate(true)
	replacement.rows[0].event.data.nested.value = 5
	_check(fork.restore(replacement).action != "invalid", "fork_event_restore_validated")
	_check(
		original.snapshot().rows[0].event.data.nested.value == 1,
		"fork_restore_does_not_replace_parent_history"
	)
	var stable: Dictionary = fork.snapshot()
	replacement.rows[0].event.text = 123
	_check(
		fork.restore(replacement).action == "invalid" and fork.snapshot() == stable,
		"fork_external_event_restore_still_rejects_bad_data"
	)


func _test_internal_forks() -> void:
	var owner = _fixture()
	if owner == null:
		return
	owner.submit(
		0,
		[
			_declaration("Zone"),
			_declaration("Secret", 1),
			_declaration("Delayed", 2),
			_declaration("Strike", 3)
		]
	)
	owner.submit(1, [])
	for round_number in [1, 2, 3]:
		if round_number > 1:
			owner.begin_next_round([0, 1])
		for boundary in range(21):
			if owner.next_hook().is_empty():
				break
			if owner.next_hook() == Timeline.SUBMISSION_LOCK and round_number > 1:
				owner.submit(0, [])
				owner.submit(1, [])
			var before: Dictionary = owner.snapshot()
			var fork = owner._clone()
			if fork == null:
				_check(false, "internal_fork_available")
				return
			_check(
				(
					fork.snapshot() == before
					and fork._entities.snapshot() == owner._entities.snapshot()
				),
				"internal_fork_exact_state_r%d_hook%d" % [round_number, boundary]
			)
			var restored = _owner()
			if restored.restore(before).action == "invalid":
				_check(false, "reference_restore_available")
				return
			var fast_result: Dictionary = fork.run_next_hook()
			var restored_result: Dictionary = restored.run_next_hook()
			_check(
				(
					fast_result == restored_result
					and fast_result.action != "invalid"
					and fork.snapshot() == restored.snapshot()
				),
				"fork_matches_validated_restore_r%d_hook%d" % [round_number, boundary]
			)
			_check(owner.snapshot() == before, "discarded_fork_does_not_advance_parent")
			_probe_mutable_fork(owner)
			if owner.run_next_hook().action == "invalid":
				_check(false, "fork_reference_hook_succeeds")
				return
		_check(owner.next_hook().is_empty(), "fork_reference_round_completes")


func _probe_mutable_fork(owner) -> void:
	var before: Dictionary = owner.snapshot()
	var registry: Dictionary = owner._entities.snapshot()
	var fork = owner._clone()
	fork._world.players[0].resources.souls = 999
	fork._world.data.order.append("fork_only")
	fork._presentation_world.data.hits = 999
	fork._combat_orders[0]["fork_only"] = [1]
	fork._order.reverse()
	for submission in fork._submissions:
		if submission != null and not submission.is_empty():
			submission[0].parameters["fork_only"] = [1]
	for records in [fork._pending._pending, fork._persistent._active, fork._cooldowns._locks]:
		for record in records.values():
			record.declaration.parameters["fork_only"] = [1]
	for used in [
		fork._pending._used_ids,
		fork._persistent._used_ids,
		fork._cooldowns._used_ids,
		fork._entities._used
	]:
		used["fork_only"] = true
	if not fork._runtime.execution_log.is_empty():
		fork._runtime.execution_log[0]["fork_only"] = true
	fork._runtime.completed = not fork._runtime.completed
	var lord: Dictionary = fork._entities.get_entity(fork._world.players[0].lord_entity_id)
	lord.attributes.alive = false
	fork._entities.update(lord.id, lord.owner, lord.attributes)
	_check(
		owner.snapshot() == before and owner._entities.snapshot() == registry,
		"fork_nested_mutable_state_isolated"
	)


func _drive(owner, stop_before: String = "") -> void:
	for _index in range(21):
		if owner.next_hook().is_empty() or owner.next_hook() == stop_before:
			return
		var result: Dictionary = owner.run_next_hook()
		if result.action == "invalid":
			print("MATCH ERROR: ", result)
			_check(false, "match_drive_" + owner.next_hook())
			return
	_check(false, "match_drive_iteration_limit")


func _count(events: Array, event_type: String) -> int:
	var result: int = 0
	for event in events:
		if event.type == event_type:
			result += 1
	return result


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)
