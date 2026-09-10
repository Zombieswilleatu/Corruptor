extends "res://Scripts/Sim/U13OdradekBoardTestRunner.gd"


func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	board.start_loadout(["Odradek", "Gremory"], [Slots.TYPES, Slots.TYPES], true)
	await _settle()
	board._debug_action("reconfiguration", 0, "Lord")
	board._debug_action("marcher", 1, "Lord")
	board.debug_panel.hide()
	board.enter_powers()
	await _settle()
	var unit: Dictionary = {}
	for entity in board._visible_world.entities:
		if entity.kind == "marcher":
			unit = entity
	var position_value: Dictionary = {"x_fp": unit.attributes.x_fp, "y_fp": unit.attributes.y_fp}
	board.redirect_button.pressed.emit()
	board.redirect_placement._place_at(board.redirect_placement._point("Lord", unit.attributes))
	board.redirect_placement._process(0.1)
	var aiming = board.redirect_placement.vortex
	_check(aiming.visible and aiming.strength < 0.5, "live_aiming_uses_subtle_oil_vortex")
	var screen_rect: Rect2 = board.redirect_placement.get_global_transform_with_canvas() * board.redirect_placement.Visuals.region_rect(board.redirect_placement.lane_rect("Lord"), board.redirect_placement.target.field_position, Odradek.REDIRECT_RADIUS_FP)
	_check(aiming.circle.is_equal_approx(screen_rect), "shader_radius_uses_same_canonical_aiming_circle")
	board.redirect_placement.confirm_button.pressed.emit()
	board.area_power = Odradek.SHIFT
	board._confirm_redirect({"lane": "Castle", "field_position": position_value})
	board.session._opponent = {"powers": [], "order": {}}
	board.resolve_round()
	var deadline: int = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	var effects = board.odradek_effects
	_check(board.playing and effects.records.size() == 2, "runner_captures_redirect_and_shift_visuals_in_order")
	var before: Dictionary = board.session.checkpoint()
	if effects.records.size() == 2:
		_check(effects.records[0].type == "REDIRECT_RESOLVED" and effects.records[1].type == "ALLEGIANCE_SHIFT_RESOLVED", "visual_order_matches_authoritative_hook_order")
		effects.advance(effects.EFFECT_DURATION * 0.51)
		_check(board.lanes.paradox_glitches.get(unit.id, {}).get("amount", 0.0) > 0.0, "redirect_glitches_affected_marcher_at_transfer")
		_check(_unit(board.lanes._units, unit.id).attributes.lane == "Castle", "redirect_blinks_chit_to_other_lane_at_peak")
		effects.advance(effects.EFFECT_DURATION * 0.51)
		effects.advance(effects.EFFECT_DURATION * 0.51)
		_check(board.lanes.paradox_glitches.get(unit.id, {}).get("amount", 0.0) > 0.0, "shift_glitches_affected_marcher_at_color_change")
		_check(_unit(board.lanes._units, unit.id).owner == 0, "shift_emerges_with_changed_ownership_color")
		effects.advance(effects.EFFECT_DURATION * 0.51)
	_check(not effects.active() and not effects.vortex.visible, "resolution_vortex_collapses_cleanly")
	_check(board.session.checkpoint() == before and board.clock == 0.0, "visual_animation_does_not_mutate_match_or_advance_marching")
	var paradox: Dictionary = board.session.odradek_visuals[1].duplicate(true)
	paradox.data.player_id = -1
	effects.play([paradox], board.lanes, board.sides)
	effects.advance(0.5)
	_check(effects.vortex.swirl == 8.0 and effects.vortex.chaos > 0.0, "paradox_has_stronger_distortion_without_inflating_game_radius")
	board.finish_playback()
	_check(not effects.active() and board.lanes.paradox_glitches.is_empty(), "skip_animation_clears_vortex_and_chit_glitches")
	while board._job != null:
		await process_frame
	board.queue_free()
	await process_frame
	print("U13 Odradek visual failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _unit(rows: Array, id: String) -> Dictionary:
	for unit in rows:
		if unit.id == id:
			return unit
	return {}
