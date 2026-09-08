extends SceneTree

const Pending = preload("res://Scripts/Sim/U13PendingEffects.gd")
const Declaration = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")

var failures: int = 0


func _init() -> void:
	_test_order_and_rounds()
	_test_fizzle_and_identity()
	_test_hidden_snapshot()
	_test_invalid_inputs()
	_test_follow_up_and_reentrancy()
	print("U13 pending effects failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _declaration(id: String, player: int = 0, queue: int = 0, due: int = 3) -> Dictionary:
	return Declaration.create(
		id,
		player,
		"FixtureLord",
		"FixturePower",
		2,
		Timeline.POST_RESOLUTION_SPAWNS,
		due,
		queue,
		Declaration.VISIBILITY_PUBLIC,
		{"castle_id": "fixture_stable_castle"},
		{"discard_card_ids": ["Butcher:2", "Vulture:3"]}
	)


func _resolved(_effect: Dictionary) -> Dictionary:
	return {"action": "resolved"}


func _fizzle(_effect: Dictionary) -> Dictionary:
	return {"action": "fizzle", "reason": "target_no_longer_standing"}


func _test_order_and_rounds() -> void:
	var manager = Pending.new()
	manager.schedule(_declaration("p0_second", 0, 1))
	manager.schedule(_declaration("p1_first", 1, 0))
	manager.schedule(_declaration("p0_first", 0, 0))
	manager.schedule(_declaration("later_round", 1, 0, 4))
	var later_hook: Dictionary = _declaration("later_hook")
	later_hook.fire_hook = Timeline.POST_RESOLUTION_DIRECT
	manager.schedule(later_hook)
	var before: Dictionary = manager.due_effects(2, Timeline.POST_RESOLUTION_SPAWNS, [1, 0])
	_check(before.effects.is_empty(), "does_not_fire_early")
	var selected: Dictionary = manager.due_effects(3, Timeline.POST_RESOLUTION_SPAWNS, [1, 0])
	var ids: Array = []
	for row in selected.effects:
		ids.append(row.declaration.declaration_id)
	_check(ids == ["p1_first", "p0_first", "p0_second"], "reflex_then_submitted_queue")
	var before_query_mutation: Dictionary = manager.snapshot()
	selected.effects[0].payload["changed"] = true
	_check(manager.snapshot() == before_query_mutation, "query_returns_copies")
	var result: Dictionary = manager.resolve_hook(
		3, Timeline.POST_RESOLUTION_SPAWNS, [1, 0], _resolved
	)
	_check(result.events.size() == 3, "same_hook_batch_resolves")
	_check(manager.snapshot().pending.size() == 2, "other_hook_and_round_remain_pending")
	_check(
		(
			manager
			. resolve_hook(3, Timeline.POST_RESOLUTION_SPAWNS, [1, 0], _resolved)
			. events
			. is_empty()
		),
		"one_shot"
	)
	_check(
		manager.due_effects(4, Timeline.ROUND_START_SCHEDULED, [1, 0]).action == "invalid",
		"overdue_is_visible_error"
	)
	manager.resolve_hook(3, Timeline.POST_RESOLUTION_DIRECT, [1, 0], _resolved)
	_check(
		(
			(
				manager
				. resolve_hook(4, Timeline.POST_RESOLUTION_SPAWNS, [1, 0], _resolved)
				. events
				. size()
			)
			== 1
		),
		"later_round_resolves"
	)
	_check(
		manager.due_effects(5, Timeline.POST_RESOLUTION_SPAWNS, []).action == "invalid",
		"requires_explicit_player_order"
	)
	# Identical inputs in different insertion orders produce identical results.
	var a = Pending.new()
	var b = Pending.new()
	for id: String in ["z", "a"]:
		a.schedule(_declaration(id))
	for id: String in ["a", "z"]:
		b.schedule(_declaration(id))
	_check(
		(
			a.resolve_hook(3, Timeline.POST_RESOLUTION_SPAWNS, [0, 1], _resolved)
			== b.resolve_hook(3, Timeline.POST_RESOLUTION_SPAWNS, [0, 1], _resolved)
		),
		"stable_tie_break_independent_of_insertion"
	)


func _test_fizzle_and_identity() -> void:
	var manager = Pending.new()
	var source: Dictionary = _declaration("spent")
	manager.schedule(source)
	var result: Dictionary = manager.resolve_hook(
		3, Timeline.POST_RESOLUTION_SPAWNS, [0, 1], _fizzle
	)
	_check(result.events[0].type == "FIZZLE_INVALID_TARGET", "fizzle_emits_existing_event_shape")
	_check(manager.snapshot().pending.is_empty(), "fizzle_consumes_effect")
	_check(
		source.cost.discard_card_ids == ["Butcher:2", "Vulture:3"], "cost_declaration_not_rewritten"
	)
	var restored = Pending.new()
	_check(
		restored.restore(JSON.parse_string(JSON.stringify(manager.snapshot()))).action != "invalid",
		"spent_snapshot_restores"
	)
	_check(
		restored.schedule(source).reason == "effect_id_already_used",
		"spent_identity_survives_restore"
	)
	_check(
		Data.instance_id("pending", "a:b", "c") != Data.instance_id("pending", "a", "b:c"),
		"length_prefixed_identity_is_unambiguous"
	)


func _test_hidden_snapshot() -> void:
	var manager = Pending.new()
	var source: Dictionary = _declaration("hidden_price")
	source.visibility = Declaration.VISIBILITY_HIDDEN
	source.target = {"secret": "private_target", "x_fp": 1375, "y_fp": -240}
	manager.schedule(source, "price", {"secret": "private_outcome"}, {"notice": "Price due"})
	var visible: String = JSON.stringify(manager.public_state())
	_check(
		not visible.contains("private_target") and not visible.contains("private_outcome"),
		"hidden_payload_not_public_even_to_owner"
	)
	_check(manager.public_state()[0].fire_round == 3, "hidden_due_round_public")
	var restored = Pending.new()
	var result: Dictionary = restored.restore(JSON.parse_string(JSON.stringify(manager.snapshot())))
	_check(result.action != "invalid", "hidden_snapshot_restores")
	var saved: Dictionary = restored.snapshot()
	_check(
		saved.pending[0].payload.secret == "private_outcome",
		"authoritative_snapshot_retains_secret"
	)
	_check(
		typeof(saved.pending[0].declaration.target.x_fp) == TYPE_INT, "json_fixed_point_normalized"
	)
	_check(typeof(saved.pending[0].fire_round) == TYPE_INT, "json_round_normalized")
	_check(
		(
			manager.resolve_hook(3, Timeline.POST_RESOLUTION_SPAWNS, [0, 1], _resolved)
			== restored.resolve_hook(3, Timeline.POST_RESOLUTION_SPAWNS, [0, 1], _resolved)
		),
		"restored_events_match"
	)


func _test_invalid_inputs() -> void:
	var manager = Pending.new()
	manager.schedule(_declaration("valid"))
	var original: Dictionary = manager.snapshot()
	var bad: Dictionary = original.duplicate(true)
	bad.pending[0].fire_round = 3.5
	_check(
		manager.restore(bad).action == "invalid" and manager.snapshot() == original,
		"fractional_restore_rejected_atomically"
	)
	bad = original.duplicate(true)
	bad.pending.append(bad.pending[0].duplicate(true))
	_check(
		manager.restore(bad).action == "invalid" and manager.snapshot() == original,
		"duplicate_restore_rejected_atomically"
	)
	var invalid_source: Dictionary = _declaration("bad_integer")
	invalid_source.queue_index = "2"
	_check(manager.schedule(invalid_source).action == "invalid", "numeric_strings_rejected")
	_check(
		(
			(
				manager
				. schedule(
					_declaration("bad_object"), "main", {"object": Callable(self, "_resolved")}
				)
				. action
			)
			== "invalid"
		),
		"object_payload_rejected"
	)
	_check(
		manager.schedule(_declaration("bad_fp"), "main", {"radius_fp": 1.5}).action == "invalid",
		"fractional_fixed_point_rejected"
	)
	_check(
		manager.schedule(_declaration("bad_nan"), "main", {"value": NAN}).action == "invalid",
		"nonfinite_payload_rejected"
	)
	var result: Dictionary = manager.resolve_hook(
		3, Timeline.POST_RESOLUTION_SPAWNS, [0, 1], Callable()
	)
	_check(
		result.action == "invalid" and manager.snapshot() == original,
		"missing_resolver_preserves_queue"
	)
	result = manager.resolve_hook(
		3, Timeline.POST_RESOLUTION_SPAWNS, [0, 1], func(_row): return {"action": "invalid"}
	)
	_check(
		result.action == "invalid" and manager.snapshot() == original,
		"engine_error_is_not_gameplay_fizzle"
	)


func _test_follow_up_and_reentrancy() -> void:
	var manager = Pending.new()
	var source: Dictionary = _declaration("parent")
	manager.schedule(source)
	var observations: Dictionary = {}
	# Bind outside the lambda; avoid implicit instance-method lookup inside
	# the anonymous callback on Godot 4.2.
	var resolved_callback: Callable = Callable(self, "_resolved")
	var resolver: Callable = func(_row: Dictionary) -> Dictionary:
		observations["nested"] = manager.resolve_hook(
			3, Timeline.POST_RESOLUTION_SPAWNS, [0, 1], resolved_callback
		)
		observations["same_hook"] = manager.schedule(source, "same_hook")
		observations["future"] = manager.schedule(
			source, "price", {}, {}, 5, Timeline.ROUND_START_SCHEDULED
		)
		return {"action": "resolved"}
	var result: Dictionary = manager.resolve_hook(
		3, Timeline.POST_RESOLUTION_SPAWNS, [0, 1], resolver
	)
	_check(result.action == "u13_effects_resolved", "follow_up_resolver_completed")
	if result.action != "u13_effects_resolved":
		return
	_check(
		observations.nested.reason == "effect_resolution_reentrant", "reentrant_resolution_blocked"
	)
	_check(observations.same_hook.action == "invalid", "same_hook_insertion_blocked")
	_check(observations.future.action == "u13_effect_scheduled", "resolver_can_arm_future_price")
	_check(
		(
			manager.resolve_hook(5, Timeline.ROUND_START_SCHEDULED, [0, 1], _resolved).events.size()
			== 1
		),
		"future_child_fires_once"
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  %s" % label)
	else:
		failures += 1
		print("FAIL  %s" % label)
