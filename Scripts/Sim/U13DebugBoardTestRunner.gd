extends "res://Scripts/Sim/U13OdradekBoardTestRunner.gd"


func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	board.start_loadout(["Odradek", "Gremory"], [Slots.TYPES, Slots.TYPES], true)
	await _settle()
	board.debug_button.pressed.emit()
	var debug = board.debug_panel
	_check(debug.visible, "debug_panel_opens_from_header")
	debug.buttons.reconfiguration.pressed.emit()
	_check(board._visible_world.reconfiguration[0] == 4, "debug_fills_reconfiguration_and_refreshes_board")
	var hand: int = board._visible_world.hand.size()
	debug.buttons.cards.pressed.emit()
	_check(board._visible_world.hand.size() == hand + 2, "debug_draws_two_real_hand_cards")
	debug.buttons.guard.pressed.emit()
	_check(_guard_count(board._visible_world, 0, "Lord") == 1, "debug_random_guard_uses_selected_zone")
	debug.buttons.guard.pressed.emit()
	debug.buttons.guard.pressed.emit()
	var full: Dictionary = board.session.checkpoint()
	debug.buttons.guard.pressed.emit()
	_check(board.session.checkpoint() == full and "full" in debug.message.text.to_lower(), "debug_full_zone_rejected_atomically")
	debug.buttons.marcher.pressed.emit()
	debug.player.select(1)
	debug.buttons.marcher.pressed.emit()
	debug.dismiss()
	board.enter_powers()
	await _settle()
	board.redirect_button.pressed.emit()
	await _settle()
	var placement = board.redirect_placement
	_check(placement.battlefield == board.lanes and board.lanes.visible, "redirect_targets_actual_battlefield")
	for lane in ["Lord", "Castle"]:
		var local_rect: Rect2 = placement.lane_rect(lane)
		var expected: Rect2 = board.lanes.get_global_transform() * board.lanes.travel_rect(lane)
		var actual: Rect2 = placement.get_global_transform() * local_rect
		_check(actual.is_equal_approx(expected), "live_target_rect_matches_drawn_chit_axes_" + lane)
	var unit: Dictionary = placement.marchers[0]
	var point: Vector2 = placement._point(unit.attributes.lane, unit.attributes)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	placement._gui_input(click)
	_check(placement.placed and placement.affected().any(func(e: Dictionary) -> bool: return e.id == unit.id), "click_on_real_chit_captures_that_marcher")
	_check(abs(int(placement.target.field_position.x_fp) - int(unit.attributes.x_fp)) <= 1 and abs(int(placement.target.field_position.y_fp) - int(unit.attributes.y_fp)) <= 1, "live_pointer_maps_back_to_game_coordinates")
	_check(not placement.instruction_panel.get_global_rect().intersects(board.lanes.get_global_rect()), "targeting_controls_do_not_cover_live_lanes")
	placement.confirm_button.pressed.emit()
	await _settle()
	_check(board.queued.size() == 1, "live_target_confirmation_queues_power")
	board.debug_button.pressed.emit()
	debug.player.select(1)
	debug.buttons.banish.pressed.emit()
	_check(board._visible_world.breach_lord == "Gremory" and board.queued.is_empty(), "debug_banishes_lord_into_breach_and_clears_draft")
	var hand_before: int = board._visible_world.hand.size()
	debug.lane.select(1)
	debug.buttons.defeat_guard.pressed.emit()
	_check(board._visible_world.hand.size() == hand_before + 1, "debug_guard_defeat_triggers_gem_dagger")
	var restored = board.session.get_script().new()
	_check(restored.restore_checkpoint(board.session.checkpoint()).action != "invalid", "debug_modified_match_restores")
	debug.dismiss()
	board.session._opponent = {"powers": [], "order": {}}
	board.resolve_round()
	var deadline: int = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(board._job == null and board.playing, "debug_modified_match_runs_normal_round_worker")
	var sealed: Dictionary = board.session.checkpoint()
	_check(board.session.debug_action("cards", 0, "Lord").action == "invalid" and board.session.checkpoint() == sealed, "debug_edits_rejected_during_resolution")
	board.queue_free()
	await process_frame
	for lord_name in Picker.LORDS:
		var session = preload("res://Scripts/Sim/U13LoadoutBoardSession.gd").new()
		session.hunt_enabled = true
		session.configure([lord_name, "Gremory"], [Slots.TYPES, Slots.TYPES], true)
		var result: Dictionary = session.debug_action("banish", 0, "Lord")
		if not _check(result.action == "debug_applied", "debug_banishment_valid_" + lord_name):
			print(result)
	print("U13 debug board failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _guard_count(world: Dictionary, pid: int, lane: String) -> int:
	var count: int = 0
	for entity in world.entities:
		if entity.kind == "card" and entity.owner == pid and entity.attributes.get("role") == "guard" and entity.attributes.lane == lane:
			count += 1
	return count
