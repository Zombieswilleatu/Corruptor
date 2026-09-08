extends SceneTree

const Persistent = preload("res://Scripts/Sim/U13PersistentEffects.gd")
const Declaration = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")

var failures: int = 0


func _init() -> void:
	_test_lifecycle_and_relocation()
	_test_step_two_creation()
	_test_snapshot_and_visibility()
	_test_invalid_and_slots()
	print("U13 persistent effects failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _declaration(id: String, round_number: int = 3, player: int = 0) -> Dictionary:
	return Declaration.create(
		id,
		player,
		"FixtureLord",
		"FixturePower",
		round_number,
		Timeline.POST_RESOLUTION_HAZARDS,
		round_number,
		0,
		Declaration.VISIBILITY_PUBLIC,
		{"lane": "Lord", "x_fp": 100}
	)


func _test_lifecycle_and_relocation() -> void:
	var manager = Persistent.new()
	manager.advance(3, Timeline.PERSISTENT_ADVANCEMENT)
	var created: Dictionary = (
		manager
		. activate(
			_declaration("scorch"),
			"scorch",
			[
				{"intensity": 1},
				{"intensity": 2},
				{"intensity": 1},
			]
		)
	)
	var id: String = created.effect.effect_id
	_check(manager.current_stage(id).intensity == 1, "fresh_round_stage_one")
	manager.advance(4, Timeline.PERSISTENT_ADVANCEMENT)
	_check(manager.current_stage(id).intensity == 2, "next_round_stage_two")
	var before: Dictionary = manager.get_effect(id)
	manager.relocate(id, {"lane": "Castle", "x_fp": 850})
	var moved: Dictionary = manager.get_effect(id)
	_check(
		(
			moved.effect_id == id
			and moved.activated_round == before.activated_round
			and moved.stage_index == before.stage_index
		),
		"relocation_preserves_identity_and_age"
	)
	_check(
		moved.target.lane == "Castle" and moved.declaration.target.lane == "Lord",
		"relocation_preserves_original_declaration"
	)
	manager.advance(5, Timeline.PERSISTENT_ADVANCEMENT)
	_check(manager.current_stage(id).intensity == 1, "final_round_stage_one")
	var expired: Dictionary = manager.advance(6, Timeline.PERSISTENT_ADVANCEMENT)
	_check(manager.get_effect(id).is_empty(), "expires_at_step_two_after_last_active_round")
	_check(
		expired.events.size() == 1 and expired.events[0].type == "PERSISTENT_EFFECT_EXPIRED",
		"expiration_uses_existing_event_shape"
	)
	_check(
		manager.activate(_declaration("scorch"), "scorch", [{}]).action == "invalid",
		"expired_activation_cannot_be_reused"
	)


func _test_step_two_creation() -> void:
	var manager = Persistent.new()
	manager.advance(4, Timeline.PERSISTENT_ADVANCEMENT)
	var source: Dictionary = _declaration("prepared", 5)
	source.declared_round = 4
	source.fire_hook = Timeline.PERSISTENT_ADVANCEMENT
	var result: Dictionary = manager.activate(
		source, "prepared", [{"intensity": 1}, {"intensity": 2}]
	)
	var id: String = result.effect.effect_id
	manager.advance(5, Timeline.PERSISTENT_ADVANCEMENT)
	_check(
		manager.current_stage(id).intensity == 1, "created_before_step_two_does_not_age_immediately"
	)
	manager.advance(6, Timeline.PERSISTENT_ADVANCEMENT)
	_check(manager.current_stage(id).intensity == 2, "prepared_effect_ages_next_round")


func _test_snapshot_and_visibility() -> void:
	var manager = Persistent.new()
	manager.advance(3, Timeline.PERSISTENT_ADVANCEMENT)
	var source: Dictionary = _declaration("hidden")
	source.visibility = Declaration.VISIBILITY_HIDDEN
	var created: Dictionary = manager.activate(
		source, "hidden", [{"secret": "private_stage", "intensity": 1}, {}], {"kills": 2}
	)
	var id: String = created.effect.effect_id
	manager.set_payload(id, {
		"kills": 3, "position": {"x_fp": 125, "y_fp": -7},
		"samples": [2, 2.0, 0.25], "speed_multiplier": 1.25,
	})
	var visible: String = JSON.stringify(manager.public_state())
	_check(
		not visible.contains("private_stage") and not visible.contains("kills"),
		"persistent_hidden_state_redacted"
	)
	var restored = Persistent.new()
	_check(
		restored.restore(JSON.parse_string(JSON.stringify(manager.snapshot()))).action != "invalid",
		"persistent_json_restore"
	)
	var copy: Dictionary = restored.get_effect(id)
	_check(typeof(copy.payload.kills) == TYPE_INT, "json_payload_counter_is_integer")
	_check(typeof(copy.stages[0].intensity) == TYPE_INT, "json_stage_counter_is_integer")
	_check(
		typeof(copy.payload.samples[0]) == TYPE_INT
		and typeof(copy.payload.samples[1]) == TYPE_INT,
		"json_nested_whole_numbers_are_integers"
	)
	_check(
		typeof(copy.payload.speed_multiplier) == TYPE_FLOAT
		and copy.payload.speed_multiplier == 1.25
		and copy.payload.samples[2] == 0.25,
		"json_fractional_payload_values_preserved"
	)
	_check(
		typeof(manager.get_effect(id).payload.samples[1]) == TYPE_INT,
		"live_and_restored_numbers_share_canonical_types"
	)
	_check(
		typeof(copy.stage_index) == TYPE_INT and typeof(copy.payload.position.x_fp) == TYPE_INT,
		"persistent_json_control_and_spatial_integers"
	)
	copy.payload.kills = 999
	_check(restored.get_effect(id).payload.kills == 3, "persistent_getter_isolated")
	_check(
		(
			manager.advance(4, Timeline.PERSISTENT_ADVANCEMENT)
			== restored.advance(4, Timeline.PERSISTENT_ADVANCEMENT)
		),
		"persistent_replay_events_match"
	)
	var original_snapshot: Dictionary = manager.snapshot()
	var restored_snapshot: Dictionary = restored.snapshot()
	_check(original_snapshot == restored_snapshot, "persistent_replay_state_matches")
	if original_snapshot != restored_snapshot:
		print("Original persistent state: %s" % var_to_str(original_snapshot))
		print("Restored persistent state: %s" % var_to_str(restored_snapshot))
	manager.advance(5, Timeline.PERSISTENT_ADVANCEMENT)
	var expired_copy = Persistent.new()
	expired_copy.restore(JSON.parse_string(JSON.stringify(manager.snapshot())))
	_check(
		(
			expired_copy.activate(_declaration("hidden", 5), "hidden", [{}]).reason
			== "effect_id_already_used"
		),
		"persistent_spent_ids_survive_json"
	)


func _test_invalid_and_slots() -> void:
	var manager = Persistent.new()
	manager.advance(3, Timeline.PERSISTENT_ADVANCEMENT)
	manager.activate(_declaration("first"), "web", [{}, {}])
	_check(
		manager.activate(_declaration("second"), "web", [{}]).reason == "persistent_slot_occupied",
		"one_active_effect_per_owner_slot"
	)
	_check(
		manager.activate(_declaration("other_owner", 3, 1), "web", [{}]).action != "invalid",
		"opponents_have_independent_slots"
	)
	var before: Dictionary = manager.snapshot()
	_check(
		manager.advance(3, Timeline.PERSISTENT_ADVANCEMENT).action == "invalid",
		"duplicate_advancement_blocked"
	)
	_check(
		manager.advance(5, Timeline.PERSISTENT_ADVANCEMENT).action == "invalid",
		"skipped_round_blocked"
	)
	_check(
		manager.advance(4, Timeline.MARCHING_START).action == "invalid",
		"advancement_only_at_step_two"
	)
	_check(manager.snapshot() == before, "rejected_advancement_preserves_state")
	var bad: Dictionary = before.duplicate(true)
	bad.active[0].stage_index = 0.5
	_check(
		manager.restore(bad).action == "invalid" and manager.snapshot() == before,
		"fractional_stage_restore_atomic"
	)
	bad = before.duplicate(true)
	bad.active[0].stage_index = 1
	_check(
		manager.restore(bad).action == "invalid" and manager.snapshot() == before,
		"inconsistent_age_restore_atomic"
	)
	_check(
		manager.activate(_declaration("empty"), "empty", []).action == "invalid",
		"empty_lifecycle_rejected"
	)
	_check(
		(
			(
				manager
				. activate(_declaration("object"), "object", [{"node": Callable(self, "_init")}])
				. action
			)
			== "invalid"
		),
		"non_data_stage_rejected"
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  %s" % label)
	else:
		failures += 1
		print("FAIL  %s" % label)
