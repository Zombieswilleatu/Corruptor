extends "res://Scripts/Sim/U13BoardTestRunner.gd"


# Separate process/budget for dense integration; reuse assertions and worker
# waiting, but do not rerun the parent's regular UI suites or art catalog census.
func _run() -> void:
	var started: int = Time.get_ticks_msec()
	_stage("dense_board", started)
	await _dense_board()
	_stage("dense_complete", started)
	print("U13 dense board failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _dense_board() -> void:
	var _dense_started: int = Time.get_ticks_msec()
	_stage("dense_opening_setup", _dense_started)
	var board = Scene.instantiate()
	board.dense_mode = true
	root.add_child(board)
	await process_frame
	board.set_process(false)
	_stage("dense_opening_ready", _dense_started)
	var initial: Dictionary = board.session.checkpoint()
	var reference = board.session._fork_for_job()
	var counts: Array = [0, 0]
	var suits: Array = [{}, {}]
	var positions: Dictionary = {}
	for entity in board.session.view().world.entities:
		if entity.kind != "marcher":
			continue
		counts[entity.owner] += 1
		suits[entity.owner][entity.attributes.suit] = true
		positions[entity.id] = entity.attributes.duplicate(true)
	_check(counts == [24, 24], "dense_board_24_per_side")
	_check(suits[0].size() == 4 and suits[1].size() == 4, "dense_board_all_four_suits_per_side")
	_check(board.status.is_visible_in_tree(), "dense_board_instructions_visible")
	_check(board.dense_button.is_visible_in_tree(), "dense_board_run_button_visible")
	board.dense_button.pressed.emit()
	var running = board._job
	_check(running != null and not board.playing, "dense_board_prepares_without_blocking")
	_check(
		board.session.checkpoint() == initial, "dense_board_worker_does_not_publish_partial_state"
	)
	board.run_dense_round()
	_check(board._job == running, "dense_board_worker_duplicate_click_ignored")
	await _wait_board_job(board)
	if not _check(board.playing, "dense_board_button_resolves_real_marching"):
		board.queue_free()
		await process_frame
		return
	_check(board.dense_button.disabled, "dense_board_cannot_double_resolve")
	_stage("dense_synchronous_reference", _dense_started)
	_check(reference.run_to_marching().action != "invalid", "dense_board_synchronous_reference")
	_check(
		board.session.checkpoint() == reference.checkpoint(),
		"dense_board_worker_exact_state_and_events"
	)
	_check(
		board.playback.sample(0).units.size() == DenseSession.COUNT,
		"dense_board_no_extra_bot_spawns"
	)
	var damaged: bool = false
	var moved: bool = false
	for index in range(1, 201):
		var frame: Dictionary = board.playback.sample(
			board.playback.duration * float(index) / 200.0
		)
		for unit in frame.units:
			damaged = damaged or unit.attributes.hp < unit.attributes.max_hp
			moved = moved or unit.attributes.x_fp != positions[unit.id].x_fp
	_check(damaged, "dense_board_visible_damage_for_health_rings")
	_check(moved, "dense_board_authoritative_positions_move")
	board.finish_playback()
	await _wait_board_job(board)
	_check(board.session.next_hook().is_empty(), "dense_board_round_completes")
	_check(not board.dense_button.disabled, "dense_board_next_round_available")
	_stage("dense_restart", _dense_started)
	board.restart()
	_check(board.session.checkpoint() == initial, "dense_board_restart_repeats_opening")
	board._start_job("invalid_fixture_operation")
	await _wait_board_job(board)
	_check(board.session.checkpoint() == initial, "dense_board_worker_failure_preserves_state")
	board.run_dense_round()
	board.restart()
	_check(board._restart_pending, "dense_board_restart_waits_without_joining")
	await _wait_board_job(board)
	_check(
		board.session.checkpoint() == initial and not board.playing,
		"dense_board_restart_discards_old_job"
	)
	board.queue_free()
	await process_frame
