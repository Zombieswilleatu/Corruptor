extends SceneTree

const Clock = preload("res://Scripts/Sim/U13Cooldowns.gd")
const Persistent = preload("res://Scripts/Sim/U13PersistentEffects.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
var failures: int = 0


func _init() -> void:
	_test_activation()
	_test_expiration()
	_test_restore()
	print("U13 cooldowns failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _declaration(
	id_value: String, round_number: int = 3, player_id: int = 0, power: String = "Power"
) -> Dictionary:
	return Decl.create(
		id_value, player_id, "Fixture", power, round_number, Timeline.POST_RESOLUTION_DIRECT
	)


func _test_activation() -> void:
	for duration in [0, 1, 2]:
		var clock = Clock.new()
		_check(not clock.is_ready(0, "Fixture", "Power"), "not_ready_before_round")
		clock.advance(3, Timeline.PERSISTENT_ADVANCEMENT)
		var source: Dictionary = _declaration("instant_" + str(duration))
		_check(
			clock.start_on_activation(source, duration).action != "invalid",
			"activation_registered_%d" % duration
		)
		_check(not clock.is_ready(0, "Fixture", "Power"), "activation_round_locked_%d" % duration)
		_check(
			clock.is_ready(1, "Fixture", "Power") and clock.is_ready(0, "Fixture", "Other"),
			"independent_owner_and_power"
		)
		for round_number in range(4, 5 + duration):
			clock.advance(round_number, Timeline.PERSISTENT_ADVANCEMENT)
			_check(
				clock.is_ready(0, "Fixture", "Power") == (round_number >= 4 + duration),
				"instant_ready_boundary_%d_%d" % [duration, round_number]
			)
		_check(
			clock.start_on_activation(source, duration).action == "invalid",
			"spent_declaration_cannot_restart_clock"
		)
	var clock = Clock.new()
	clock.advance(3, Timeline.PERSISTENT_ADVANCEMENT)
	clock.start_on_activation(_declaration("first"), 1)
	var before: Dictionary = clock.snapshot()
	_check(
		(
			clock.start_on_activation(_declaration("second"), 1).action == "invalid"
			and clock.snapshot() == before
		),
		"active_clock_cannot_be_overwritten"
	)
	_check(
		(
			clock.advance(5, Timeline.PERSISTENT_ADVANCEMENT).action == "invalid"
			and clock.snapshot() == before
		),
		"skipped_round_atomic"
	)
	_check(clock.advance(4, Timeline.DEVELOPMENT).action == "invalid", "only_step_two_advances")


func _test_expiration() -> void:
	for duration in [0, 1, 2]:
		var clock = Clock.new()
		var persistent = Persistent.new()
		clock.advance(3, Timeline.PERSISTENT_ADVANCEMENT)
		persistent.advance(3, Timeline.PERSISTENT_ADVANCEMENT)
		var source: Dictionary = _declaration("persistent_" + str(duration))
		persistent.activate(source, "main", [{"strength": 2}, {"strength": 1}])
		var effect_id: String = persistent.snapshot().active[0].effect_id
		clock.wait_for_expiration(source, duration, effect_id)
		persistent.advance(4, Timeline.PERSISTENT_ADVANCEMENT)
		clock.advance(4, Timeline.PERSISTENT_ADVANCEMENT)
		_check(not clock.is_ready(0, "Fixture", "Power"), "active_lifetime_blocks_reuse")
		var expired: Dictionary = persistent.advance(5, Timeline.PERSISTENT_ADVANCEMENT)
		var before: Dictionary = clock.snapshot()
		var wrong_owner: Dictionary = expired.events[0].duplicate(true)
		wrong_owner.data.player_id = 1
		_check(
			clock.accept_expiration(wrong_owner).action == "invalid" and clock.snapshot() == before,
			"wrong_expiration_owner_atomic"
		)
		_check(
			clock.accept_expiration(expired.events[0]).action != "invalid",
			"real_expiration_starts_clock"
		)
		_check(
			clock.accept_expiration(expired.events[0]).action == "invalid",
			"duplicate_expiration_rejected"
		)
		var resumed = Clock.new()
		_check(
			(
				resumed.restore(JSON.parse_string(JSON.stringify(clock.snapshot()))).action
				!= "invalid"
			),
			"restore_between_expiration_and_clock_advance"
		)
		for round_number in range(5, 6 + duration):
			var first: Dictionary = clock.advance(round_number, Timeline.PERSISTENT_ADVANCEMENT)
			var second: Dictionary = resumed.advance(round_number, Timeline.PERSISTENT_ADVANCEMENT)
			_check(
				first == second and clock.snapshot() == resumed.snapshot(),
				"expiration_replay_%d_%d" % [duration, round_number]
			)
			_check(
				clock.is_ready(0, "Fixture", "Power") == (round_number >= 5 + duration),
				"expiration_ready_boundary_%d_%d" % [duration, round_number]
			)
	var clock = Clock.new()
	clock.advance(3, Timeline.PERSISTENT_ADVANCEMENT)
	var source: Dictionary = _declaration("fizzle")
	clock.wait_for_expiration(source, 1, "never_created")
	_check(
		clock.fizzle_waiting(source, 4).action != "invalid",
		"round_start_fizzle_still_spends_cooldown"
	)
	var resumed = Clock.new()
	_check(resumed.restore(clock.snapshot()).action != "invalid", "round_start_fizzle_snapshot")
	for round_number in [4, 5, 6]:
		clock.advance(round_number, Timeline.PERSISTENT_ADVANCEMENT)
	_check(clock.is_ready(0, "Fixture", "Power"), "fizzled_persistent_does_not_lock_forever")


func _test_restore() -> void:
	var clock = Clock.new()
	clock.advance(3, Timeline.PERSISTENT_ADVANCEMENT)
	clock.wait_for_expiration(_declaration("waiting"), 2, "bound")
	var before: Dictionary = clock.snapshot()
	var resumed = Clock.new()
	_check(
		(
			resumed.restore(JSON.parse_string(JSON.stringify(before))).action != "invalid"
			and resumed.snapshot() == before
		),
		"waiting_json_roundtrip"
	)
	for field in ["phase", "persistent_effect_id", "ready_round"]:
		var corrupt: Dictionary = before.duplicate(true)
		corrupt.locks[0].erase(field)
		_check(
			clock.restore(corrupt).action == "invalid" and clock.snapshot() == before,
			"missing_clock_field_atomic_" + field
		)
	var corrupt: Dictionary = before.duplicate(true)
	corrupt.locks[0].cooldown_rounds = 1.5
	_check(
		clock.restore(corrupt).action == "invalid" and clock.snapshot() == before,
		"fractional_clock_atomic"
	)
	var hidden: Dictionary = _declaration("hidden", 3, 1)
	hidden.visibility = "hidden"
	hidden.parameters = {"secret": "DO_NOT_REVEAL"}
	clock.wait_for_expiration(hidden, 2, "hidden_bound")
	_check(
		(
			not JSON.stringify(clock.public_state()).contains("DO_NOT_REVEAL")
			and not JSON.stringify(clock.public_state()).contains("hidden_bound")
		),
		"hidden_clock_redacted"
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)
