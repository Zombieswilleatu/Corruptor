extends SceneTree

const Session = preload("res://Scripts/Sim/U13SmokeSession.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const SmokeScene = preload("res://Prototype/U13/U13Smoke.tscn")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_scenarios()
	if failures == 0:
		_replay_and_checkpoint()
	if failures == 0:
		await _scene_controls()
	print("U13 smoke scene failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _scenarios() -> void:
	for scenario in range(3):
		var session = Session.new()
		if not _check(
			session.reset(scenario).action != "invalid", "smoke_scenario_starts_" + str(scenario)
		):
			return
		_check(
			session.next_hook() == Timeline.SUBMISSION_LOCK,
			"smoke_opens_at_planning_" + str(scenario)
		)
		var before: Dictionary = session.checkpoint()
		_check(
			session.preview().action == "legal" and session.checkpoint() == before,
			"smoke_preview_is_pure_" + str(scenario)
		)
		_check(
			not JSON.stringify(session.view()).contains(Session.SEED),
			"smoke_player_view_hides_seed"
		)
		if not _check(
			session.run_to_marching().action != "invalid",
			"smoke_runs_actual_marching_" + str(scenario)
		):
			return
		_check(session.next_hook() == Timeline.END_MARCHING_CHECKS, "smoke_stops_after_marching")
		var events: Array = session.view().events
		if scenario in [0, 1]:
			_check(_count(events, "MARCHER_CONTACT") > 0, "smoke_predators_reach_physical_contact")
			_check(_count(events, "MARCHING_TICK") == 200, "smoke_records_every_movement_tick")
		if scenario == 1:
			_check(_count(events, "GEM_DAGGER") == 2, "smoke_siege_triggers_gem")
			_check(_count(events, "CASTLE_DESTROYED") == 1, "smoke_siege_destroys_castle")
			_check(_count(events, "SIFTING_THE_RUINS") == 2, "smoke_siege_triggers_sifting")
			_check(session.view().world.souls == [3, 0], "smoke_public_soul_rewards")
		if scenario == 2:
			_check(session.view().pending.size() == 1, "smoke_ruin_waits_for_next_round")
			_check(_count(events, "CASTLE_DEFUNCT") == 0, "smoke_ruin_does_not_fire_early")
		if not _finish_round(session):
			return
		if not _check(
			session.next_round().action != "invalid", "smoke_next_round_" + str(scenario)
		):
			return
		_check(
			session.round_number() == 2 and session.next_hook() == Timeline.SUBMISSION_LOCK,
			"smoke_next_round_opens_planning"
		)
		if scenario == 2:
			_check(
				_count(session.view().events, "CASTLE_DEFUNCT") == 1,
				"smoke_prepared_ruin_fires_before_planning"
			)
			_check(
				_count(session.view().events, "CASTLE_DESTROYED") == 0,
				"smoke_defunct_does_not_fake_destruction"
			)
		if not _check(session.run_to_marching().action != "invalid", "smoke_second_round_runs"):
			return
		if not _finish_round(session):
			return
		if not _check(session.next_round().action != "invalid", "smoke_third_round_opens"):
			return
		_check(session.preview().action == "legal", "smoke_cooldown_recipe_legal_round_three")


func _replay_and_checkpoint() -> void:
	var session = Session.new()
	session.reset(0)
	session.set_lane("Lord")
	var before: Dictionary = session.checkpoint()
	var resumed = Session.new()
	_check(
		resumed.restore_checkpoint(JSON.parse_string(JSON.stringify(before))).action != "invalid",
		"smoke_checkpoint_json_restores"
	)
	var result: Dictionary = session.run_to_marching()
	var replay_result: Dictionary = resumed.run_to_marching()
	if not _check(
		result.action != "invalid" and replay_result.action != "invalid",
		"smoke_restored_run_succeeds"
	):
		return
	_check(session.checkpoint() == resumed.checkpoint(), "smoke_restored_run_exact")
	for event in session.view().events:
		if event.type == "MARCHER_CLASH":
			_check(event.data.lane == "Lord", "smoke_lane_choice_reaches_simulation")
	var tape: Array = session.marching_events()
	var tape_before: Array = tape.duplicate(true)
	var state_before: Dictionary = session.checkpoint()
	var playback = Playback.new()
	if not _check(playback.build(tape), "smoke_playback_builds_from_public_events"):
		return
	_check(playback.sample(0.0).units.size() == 6, "smoke_playback_starts_with_six_predators")
	var recorded_final: Array = []
	var recorded_middle: Dictionary = {}
	for event in tape:
		if event.type == "MARCHING_FINISHED":
			recorded_final = event.data.units
		if event.type == "MARCHING_TICK" and event.data.tick == 99:
			for unit in event.data.units:
				recorded_middle[unit.id] = unit.attributes
	_check(playback.final_units() == recorded_final, "smoke_playback_finishes_at_recorded_state")
	var sampled: Dictionary = playback.sample(3.0)
	for unit in sampled.units:
		_check(
			is_equal_approx(float(unit.attributes.visual_x), float(recorded_middle[unit.id].x_fp)),
			"smoke_mid_travel_matches_authoritative_tick"
		)
	for rate in [30, 60, 144]:
		for frame in range(ceili(playback.duration * rate) + 1):
			playback.sample(float(frame) / float(rate))
	_check(
		session.checkpoint() == state_before and tape == tape_before,
		"smoke_frame_rate_and_scrubbing_cannot_mutate_match"
	)
	_check(
		playback.sample(playback.duration).units.size() == recorded_final.size(),
		"smoke_final_sample_matches_recorded_field"
	)
	var bad: Dictionary = before.duplicate(true)
	bad.match.engine_version = "4.2"
	_check(
		(
			session.restore_checkpoint(bad).action == "invalid"
			and session.checkpoint() == state_before
		),
		"smoke_bad_checkpoint_rejected_atomically"
	)
	var projection: Dictionary = session.view()
	projection.world.souls[0] = 999
	_check(session.view().world.souls[0] == 0, "smoke_public_souls_are_isolated_copies")


func _scene_controls() -> void:
	var scene = SmokeScene.instantiate()
	root.add_child(scene)
	await process_frame
	if not _check(
		scene.session.next_hook() == Timeline.SUBMISSION_LOCK, "smoke_scene_boots_at_planning"
	):
		scene.queue_free()
		return
	_check(
		scene._run.disabled == false and scene._next.disabled, "smoke_initial_controls_match_phase"
	)
	scene._on_save()
	scene.run_marching()
	if not _check(
		scene._playing and scene._step.disabled and scene._run.disabled,
		"smoke_scene_starts_playback_and_locks_phase_controls"
	):
		scene.queue_free()
		return
	var before: Dictionary = scene.session.checkpoint()
	scene._on_scrub(3.0)
	_check(scene._paused, "smoke_scrub_pauses_playback")
	scene._on_pause()
	scene._process(100.0)
	_check(
		not scene._playing and scene.session.checkpoint() == before,
		"smoke_animation_finishes_without_reexecuting_combat"
	)
	scene._on_replay()
	scene.finish_playback()
	_check(scene.session.checkpoint() == before, "smoke_replay_button_does_not_duplicate_rewards")
	scene._on_restore()
	_check(
		scene.session.next_hook() == Timeline.SUBMISSION_LOCK and not scene._playing,
		"smoke_restore_button_returns_to_checkpoint"
	)
	scene.start_scenario(1)
	_check(
		scene.session.scenario() == 1 and scene._checkpoint.is_empty(),
		"smoke_scenario_restart_clears_checkpoint"
	)
	scene.run_marching()
	scene.start_scenario(2)
	_check(
		not scene._playing and scene.session.scenario() == 2,
		"smoke_restart_cancels_active_animation"
	)
	scene.queue_free()
	await process_frame


func _finish_round(session) -> bool:
	for index in range(3):
		if session.next_hook().is_empty():
			return true
		if not _check(session.step().action != "invalid", "smoke_aftermath_step"):
			return false
	return _check(false, "smoke_aftermath_limit")


static func _count(events: Array, kind: String) -> int:
	var result: int = 0
	for event in events:
		if event.type == kind:
			result += 1
	return result


func _check(condition: bool, label: String) -> bool:
	if condition:
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)
	return condition
