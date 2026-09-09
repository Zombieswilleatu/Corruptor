extends "res://Scripts/Sim/U13DirectBoardTestRunner.gd"

const Odradek = preload("res://Scripts/Sim/U13Odradek.gd")
const Picker = preload("res://Prototype/U13/U13LoadoutPicker.gd")


func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	_check("Odradek" in Picker.LORDS, "odradek_in_picker")
	board.start_loadout(["Odradek", "Gremory"], [Slots.TYPES, Slots.TYPES], true)
	await _settle()
	if not _check(
		board.match_started and board._development_enabled(), "odradek_main_runner_starts"
	):
		board.queue_free()
		await process_frame
		_finish()
		return
	_check(board._visible_world.reconfiguration[0] == 1, "odradek_first_planning_has_one_resource")
	board.enter_powers()
	await _settle()
	_check(
		board.odradek_box.visible and not board.redirect_button.disabled, "redirect_control_ready"
	)
	var before: Dictionary = board.session.checkpoint()
	board.redirect_button.pressed.emit()
	await _settle()
	var placement = board.redirect_placement
	_check(
		placement.visible and placement.confirm_button.disabled, "redirect_requires_first_placement"
	)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = placement.lane_rect("Lord").get_center()
	placement._gui_input(click)
	_check(
		placement.placed and not placement.dragging, "redirect_click_places_without_following_mouse"
	)
	var motion := InputEventMouseMotion.new()
	motion.position = placement.lane_rect("Castle").get_center()
	placement._gui_input(motion)
	_check(placement.target.lane == "Lord", "redirect_hover_does_not_move_placed_circle")
	placement._gui_input(click)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	placement._gui_input(motion)
	click.pressed = false
	placement._gui_input(click)
	_check(
		placement.target.lane == "Castle" and not placement.dragging, "redirect_drag_crosses_lanes"
	)
	placement.confirm_button.pressed.emit()
	await _settle()
	_check(
		board.queued.size() == 1 and board.redirect_button.disabled,
		"redirect_reserves_resource_without_overspending"
	)
	_check(board.session.checkpoint() == before, "redirect_ui_draft_does_not_spend_bank")
	board._remove_redirect(0)
	await _settle()
	_check(
		board.queued.is_empty() and not board.redirect_button.disabled,
		"remove_redirect_returns_draft_budget"
	)
	board.redirect_button.pressed.emit()
	click.pressed = true
	click.position = placement.lane_rect("Lord").get_center()
	placement._gui_input(click)
	placement.confirm_button.pressed.emit()
	board.session._opponent = {"powers": [], "order": {}}
	board.resolve_round()
	var deadline: int = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(board._job == null and board.playing, "odradek_worker_resolves_redirect")
	_check(
		board.session.checkpoint().match.world.players[0].resources.reconfiguration == 0,
		"runner_spends_at_submission"
	)
	board.finish_playback()
	deadline = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	board.next_round()
	deadline = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	await _settle()
	_check(
		board.session.round_number() == 2 and board._visible_world.reconfiguration[0] == 1,
		"runner_next_round_recharges"
	)
	var fixture: Dictionary = board.session.OdradekScenario.world()
	fixture.players[0].resources.reconfiguration = 3
	var owner = Odradek.new().create_combat_match()
	owner.start("queue-edit", fixture, [0, 1])
	board.session._owner = owner
	board.session._to_planning()
	board._reset_direct()
	board.powers_step = false
	board._refresh()
	board.enter_powers()
	await _settle()
	for lane in ["Lord", "Castle"]:
		board._confirm_redirect({"lane": lane, "field_position": {"x_fp": 1200, "y_fp": 300}})
	await _settle()
	board._move_redirect(1, -1)
	await _settle()
	_check(
		(
			board.queued.size() == 2
			and board.queued[0].target.lane == "Castle"
			and board.queued[0].queue_index == 0
			and board.queued[1].queue_index == 1
		),
		"queue_reorder_rebuilds_declaration_identity"
	)
	_check(
		board.session.choose(board.queued, board._order()).action != "invalid",
		"reordered_queue_passes_authoritative_legality"
	)
	board._remove_redirect(0)
	await _settle()
	_check(
		(
			board.queued.size() == 1
			and board.queued[0].target.lane == "Lord"
			and board.queued[0].queue_index == 0
		),
		"queue_removal_renumbers_remaining_declarations"
	)
	board.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("U13 Odradek board failures: %d" % failures)
	quit(0 if failures == 0 else 1)
