extends "res://Scripts/Sim/U13MarcherFeedbackTestRunner.gd"


# Exercise the real board controller and draw surface, replacing only the next
# worker dispatch so this presentation gate does not resolve a second match.
class FeedbackBoard:
	extends "res://Prototype/U13/U13DirectBoard.gd"
	var requested_operation: String = ""

	func _start_job(operation: String, _powers: Array = [], _order: Dictionary = {}) -> void:
		requested_operation = operation


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 60
	var board = FeedbackBoard.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(board)
	await process_frame
	await process_frame
	if OS.get_cmdline_user_args().has("--compatibility-check") and DisplayServer.get_name() == "headless":
		board._runtime_ok = true
		board.open_setup()
	board.setup_picker.start_button.pressed.emit()
	await process_frame
	await process_frame
	if not _check(board.match_started, "feedback_board_match_started"):
		board.queue_free()
		await process_frame
		_finish_feedback_board()
		return
	board.set_process(false)
	var saved: Dictionary = board.session.checkpoint()
	board.playback = Playback.new()
	if not _check(board.playback.build(_tape()), "feedback_board_tape_builds"):
		board.queue_free()
		await process_frame
		_finish_feedback_board()
		return
	board.playing = true
	board.clock = 0.0
	board.lanes.show_frame(board.playback.sample(0), 1)
	var shield: Dictionary = Feedback.row(_picture("victim", 5, 1), 0, -1, 0.0, "SCORCH")
	var hurt: Dictionary = Feedback.row(_picture("victim", 4, 0), -1, 0, 0.75, "SCORCH")
	board.lanes.bind_scorch(
		[
			{
				"id": "feedback-fire",
				"owner": 0,
				"target": {"kind": "lane", "lane": "Lord"},
				"intensity": 2,
				"remaining": 2,
				"fire_round": 0
			}
		]
	)
	board._install_impacts(
		[{"id": "", "hp": 0, "armor": 0, "at": 0.0, "pulse": "feedback-fire"}, shield, hurt]
	)
	board._process(0.1)
	_check(
		board.lanes.scorch_visuals.groups["feedback-fire"].burst_age >= 0.0,
		"resolved_pyro_marker_flashes_the_active_area"
	)
	_check(
		board.clock == 0.0 and board.lanes.feedback.visible.size() == 1,
		"scorch_feedback_precedes_marching_clock"
	)
	_check(board._busy_label.text.contains("Scorch pulse"), "scorch_impact_has_visible_phase_label")
	board._process(0.75)
	_check(
		board.clock == 0.0 and board.lanes.feedback.visible.size() == 2,
		"second_pulse_has_visible_hp_and_armor_results"
	)
	board.lanes.bind_auras([], 1)
	_check(board.lanes.is_processing(), "aura_refresh_does_not_stop_damage_animation")
	# Render at least once with both labels and an active flower group.
	board.lanes.bind_auras(
		[
			{
				"effect_id": "feedback-breath",
				"declaration": {"power_id": "BreathOfLife", "player_id": 0},
				"payload": {"lane_aura": {}},
				"target": {"lane": "Lord"},
				"activated_round": 1,
				"stages": [{}, {}]
			}
		],
		1
	)
	await process_frame
	await process_frame
	_check(not board.lanes.breath_visuals.groups.is_empty(), "numbers_coexist_with_breath_visuals")
	board.finish_playback()
	_check(
		(
			not board.playing
			and board._impact_rows.is_empty()
			and board.lanes.feedback.visible.is_empty()
			and board.requested_operation == "aftermath"
		),
		"skip_clears_pending_hits_without_dumping_round_numbers"
	)
	_check(
		board.lanes._units == board.playback.sample(board.playback.duration).units,
		"skip_keeps_exact_final_picture"
	)
	# Large frame delta crosses both exchanges; final lethal number must survive
	# normal playback completion while the aftermath worker is requested.
	board.playing = true
	board.clock = 0.0
	board._feedback_cursor = 0
	board._process(board.playback.duration)
	_check(
		(
			not board.playing
			and board.lanes.feedback.visible.size() == 1
			and board.lanes.feedback.visible[0].hp == -5
		),
		"normal_finish_retains_all_crossed_hits_and_lethal_number"
	)
	board.lanes.clear_feedback()
	board._install_impacts([Feedback.row(_picture("survivor", 5, 1), 1, 0, 0.0, "REGEN")])
	board._process(0.1)
	_check(
		(
			board.lanes.feedback.visible.size() == 1
			and board.lanes.feedback.visible[0].hp == 1
			and not board.playing
		),
		"next_round_healing_visible_during_planning"
	)
	_check(board.session.checkpoint() == saved, "all_feedback_is_cosmetic_and_save_independent")
	board._install_impacts([])
	board.lanes.reset_effects()
	_check(
		board.lanes.feedback.visible.is_empty() and board.lanes.breath_visuals.groups.is_empty(),
		"board_reset_clears_damage_and_flower_tails"
	)
	board.queue_free()
	await process_frame
	_finish_feedback_board()


func _finish_feedback_board() -> void:
	print("U13 Marcher feedback board failures: %d" % failures)
	quit(0 if failures == 0 else 1)
