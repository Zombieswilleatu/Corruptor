extends SceneTree

const Runtime = preload("res://Scripts/Sim/U13RoundRuntime.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Declaration = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const Pending = preload("res://Scripts/Sim/U13PendingEffects.gd")
const Persistent = preload("res://Scripts/Sim/U13PersistentEffects.gd")
const EffectData = preload("res://Scripts/Sim/U13EffectData.gd")

var failures: int = 0


func _init() -> void:
	var original: Dictionary = _fixture()
	_drive(original, Timeline.SUBMISSION_LOCK)
	var resumed: Dictionary = _restore_fixture(_save(original))
	_check(resumed.runtime.next_hook() == Timeline.SUBMISSION_LOCK, "resume_at_submission_lock")
	_drive(original)
	_drive(resumed)
	original.runtime.begin_round(4)
	resumed.runtime.begin_round(4)
	_drive(original, Timeline.PERSISTENT_ADVANCEMENT)
	_drive(resumed, Timeline.PERSISTENT_ADVANCEMENT)
	# Save after the fizzle, before prepared creation at Step 2.
	resumed = _restore_fixture(_save(resumed))
	_drive(original)
	_drive(resumed)
	_check(_save(original) == _save(resumed), "timeline_and_effects_resume_identically")
	_check(original.pending.snapshot().pending.is_empty(), "delayed_effects_consumed")
	_check(
		original.persistent.snapshot().active.size() == 1, "armed_effect_survives_source_banishment"
	)
	var active: Dictionary = original.persistent.snapshot().active[0]
	_check(active.stage_index == 0, "step_two_creation_keeps_first_active_round")
	var fizzles: int = 0
	for event in original.events:
		if event.type == "FIZZLE_INVALID_TARGET":
			fizzles += 1
	_check(fizzles == 1, "missing_target_fizzles_once_across_resume")
	original.runtime.begin_round(5)
	resumed.runtime.begin_round(5)
	_drive(original)
	_drive(resumed)
	_check(_save(original) == _save(resumed), "following_round_replay_matches")
	_check(
		original.persistent.snapshot().active[0].stage_index == 1, "following_round_advances_once"
	)
	print("U13 effects integration failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _fixture() -> Dictionary:
	var fixture: Dictionary = {
		"runtime": Runtime.new(),
		"pending": Pending.new(),
		"persistent": Persistent.new(),
		"events": [],
		"source_alive": false,
	}
	fixture.runtime.begin_round(3)
	var prepared: Dictionary = Declaration.create(
		"fixture_prepared",
		0,
		"FixtureLord",
		"FixturePrepared",
		3,
		Timeline.PERSISTENT_ADVANCEMENT,
		4,
		0,
		Declaration.VISIBILITY_PUBLIC,
		{"lane": "Castle", "x_fp": 800}
	)
	fixture.pending.schedule(
		prepared, "prepared_zone", {"stages": [{"intensity": 1}, {"intensity": 2}]}
	)
	var doomed: Dictionary = Declaration.create(
		"fixture_missing_target",
		1,
		"FixtureLord",
		"FixtureDelayed",
		3,
		Timeline.ROUND_START_SCHEDULED,
		4,
		0,
		Declaration.VISIBILITY_PUBLIC,
		{"castle_id": "already_destroyed"}
	)
	fixture.pending.schedule(doomed)
	return fixture


func _drive(fixture: Dictionary, stop_before: String = "") -> void:
	while not fixture.runtime.completed and fixture.runtime.next_hook() != stop_before:
		var hook: String = fixture.runtime.next_hook()
		var round_number: int = fixture.runtime.round_number
		var handler: Callable = func(_context: Dictionary) -> Dictionary:
			if hook == Timeline.PERSISTENT_ADVANCEMENT:
				var advanced: Dictionary = fixture.persistent.advance(round_number, hook)
				if advanced.action == "invalid":
					return advanced
				fixture.events.append_array(advanced.events)
			var resolver: Callable = func(record: Dictionary) -> Dictionary:
				if record.effect_key == "prepared_zone":
					var started: Dictionary = fixture.persistent.activate(
						record.declaration, "zone", record.payload.stages, {}, {}, record.fire_round
					)
					if started.action == "invalid":
						return started
					fixture.events.append_array(started.events)
					return {"action": "resolved"}
				return {"action": "fizzle", "reason": "target_no_longer_standing"}
			var resolved: Dictionary = fixture.pending.resolve_hook(
				round_number, hook, [1, 0], resolver
			)
			if resolved.action != "invalid":
				fixture.events.append_array(resolved.events)
			return resolved
		var result: Dictionary = fixture.runtime.run_hook(hook, handler)
		if result.action == "invalid" or result.result.get("action") == "invalid":
			_check(false, "fixture_hook_failed_%s" % hook)
			return


func _save(fixture: Dictionary) -> Dictionary:
	return {
		"runtime": fixture.runtime.snapshot(),
		"pending": fixture.pending.snapshot(),
		"persistent": fixture.persistent.snapshot(),
		"events": fixture.events.duplicate(true),
		"source_alive": fixture.source_alive,
	}


func _restore_fixture(snapshot: Dictionary) -> Dictionary:
	# The U13 match-load boundary canonicalizes the complete JSON envelope,
	# including runtime history and event metadata outside the effect managers.
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	if not EffectData.is_data(decoded):
		_check(false, "fixture_snapshot_data_invalid")
		return {}
	var raw: Dictionary = EffectData.copy_data(decoded)
	var fixture: Dictionary = {
		"runtime": Runtime.new(),
		"pending": Pending.new(),
		"persistent": Persistent.new(),
		"events": raw.events,
		"source_alive": raw.source_alive,
	}
	_check(fixture.runtime.restore(raw.runtime).action != "invalid", "fixture_runtime_restored")
	_check(fixture.pending.restore(raw.pending).action != "invalid", "fixture_pending_restored")
	_check(
		fixture.persistent.restore(raw.persistent).action != "invalid",
		"fixture_persistent_restored"
	)
	return fixture


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  %s" % label)
	else:
		failures += 1
		print("FAIL  %s" % label)
