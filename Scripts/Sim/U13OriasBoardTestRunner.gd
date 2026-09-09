extends "res://Scripts/Sim/U13DirectBoardTestRunner.gd"

const OriasContent = preload("res://Scripts/Sim/U13Orias.gd")
const Picker = preload("res://Prototype/U13/U13LoadoutPicker.gd")


func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	_check("Orias" in Picker.LORDS, "orias_in_main_and_quickstart_roster")
	board.start_loadout(["Orias", "Gremory"], [Slots.TYPES, Slots.TYPES], true)
	await _settle()
	if not _check(
		board.match_started and board._development_enabled(), "orias_playable_content_owner"
	):
		board.queue_free()
		await process_frame
		_finish()
		return
	var initial: Dictionary = board.session.checkpoint()
	var card: String = board.session.board_view().world.hand[0]
	board._select_direct_action("Guard")
	var target: Dictionary = {"id": "", "kind": "zone", "owner": 0, "lane": "Lord", "slot": 2}
	board._choose_target(target)
	await _settle()
	board.hand_view.select_card_id(card)
	await _settle()
	_check(
		board.guard_plan.size() == 1 and board._order().guard_moves[0].card_id == card,
		"orias_guard_slot_card_staged"
	)
	_check(card not in board._available_ids(), "orias_guard_card_reserved")
	_check(board.session.checkpoint() == initial, "orias_guard_draft_no_simulation_change")
	board._return_card("guard", card)
	await _settle()
	_check(
		board.guard_plan.is_empty() and card in board._available_ids(), "orias_guard_card_returned"
	)
	board.enter_powers()
	await _settle()
	board.web_button.pressed.emit()
	await _settle()
	_check(board.placement.visible and board.queued.is_empty(), "orias_web_waits_for_confirmation")
	var motion := InputEventMouseMotion.new()
	motion.position = board.placement.lane_rect("Castle").get_center()
	board.placement._gui_input(motion)
	_check(
		not board.placement.placed and board.placement.confirm_button.disabled,
		"orias_hover_cannot_place_or_confirm"
	)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = motion.position
	board.placement._gui_input(click)
	_check(
		(
			board.placement.placed
			and not board.placement.dragging
			and not board.placement.confirm_button.disabled
		),
		"orias_first_click_places_without_dragging"
	)
	var preview: Dictionary = board.placement.target.duplicate(true)
	_check(
		preview.lane == "Castle" and preview.field_position == {"x_fp": 1200, "y_fp": 300},
		"orias_web_two_lane_pointer_projection"
	)
	_check(
		board.session.checkpoint() == initial and board.queued.is_empty(),
		"orias_web_motion_draft_only"
	)
	_check(
		board.placement.confirm_button.text == "SET THE SNARE", "orias_web_thematic_confirmation"
	)
	motion.position = board.placement.lane_rect("Lord").get_center()
	board.placement._gui_input(motion)
	_check(board.placement.target == preview, "orias_placed_web_ignores_unheld_motion")
	# Grab slightly off center: dragging preserves that grip across lanes.
	click.position = board.placement.lane_rect("Castle").get_center() + Vector2(5, 0)
	board.placement._gui_input(click)
	motion.position += Vector2(5, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	board.placement._gui_input(motion)
	_check(
		(
			board.placement.target.lane == "Lord"
			and board.placement.target.field_position == {"x_fp": 1200, "y_fp": 300}
		),
		"orias_drag_moves_web_and_preserves_grip"
	)
	click.pressed = false
	click.position = board.placement.confirm_button.get_global_rect().get_center()
	board.placement._input(click)
	preview = board.placement.target.duplicate(true)
	motion.position = board.placement.lane_rect("Castle").get_center()
	motion.button_mask = 0
	board.placement._gui_input(motion)
	_check(
		not board.placement.dragging and board.placement.target == preview,
		"orias_release_over_button_stops_drag"
	)
	board.placement.cancel_button.pressed.emit()
	await _settle()
	_check(
		not board.placement.visible and board.queued.is_empty(), "orias_web_cancel_queues_nothing"
	)
	board.web_button.pressed.emit()
	await _settle()
	_check(
		not board.placement.placed and board.placement.confirm_button.disabled,
		"orias_reopen_requires_new_placement"
	)
	click.pressed = true
	click.position = board.placement.lane_rect("Lord").get_center()
	board.placement._gui_input(click)
	click.pressed = false
	board.placement._gui_input(click)
	board.placement.confirm_button.pressed.emit()
	await _settle()
	_check(
		not board.placement.visible and board.queued.size() == 1, "orias_set_the_snare_queues_once"
	)
	if not board.queued.is_empty():
		_check(
			board.queued[0].power_id == OriasContent.WEB and board.queued[0].target == preview,
			"orias_web_confirmed_target_preserved"
		)
	_check(board.session.checkpoint() == initial, "orias_web_confirm_does_not_resolve")
	board.snare_button.pressed.emit()
	await _settle()
	_check(board.queued.size() == 2, "orias_snare_prepared_with_web")
	board.session._opponent = {"powers": [], "order": {}}
	board.resolve_round()
	var deadline: int = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	if _check(board._job == null and board.playing, "orias_board_worker_resolves"):
		board.finish_playback()
		deadline = Time.get_ticks_msec() + 15000
		while board._job != null and Time.get_ticks_msec() < deadline:
			await process_frame
		board.next_round()
		deadline = Time.get_ticks_msec() + 15000
		while board._job != null and Time.get_ticks_msec() < deadline:
			await process_frame
		await _settle()
		_check(board.session.round_number() == 2, "orias_board_next_round")
		_check(
			board._visible_world.guard_placement_limits[1] == 1,
			"orias_board_snare_next_round_guard_cap"
		)
		_check(board.lanes.active_webs.size() == 1, "orias_board_renders_persistent_web")
	await _resummon_ui(board)
	board.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("U13 Orias board failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _resummon_ui(board) -> void:
	var world: Dictionary = board.session.OriasScenario.loadout_world(
		["Orias", "Gremory"], [Slots.TYPES, Slots.TYPES]
	)
	var entities = OriasContent.Ids.new()
	entities.restore(world.entities)
	var actor: Dictionary = entities.get_entity(world.players[0].lord_entity_id)
	actor.attributes.alive = false
	entities.update(actor.id, 0, actor.attributes)
	world.entities = entities.snapshot()
	var owner = OriasContent.new().create_combat_match()
	if not _check(
		owner.start("orias-return-ui", world, [0, 1]).action != "invalid", "orias_return_ui_fixture"
	):
		return
	board.session._owner = owner
	board.session._to_planning()
	board._reset_direct()
	board.powers_step = false
	board._refresh()
	board._select_direct_action("Resummon")
	await _settle()
	var cards: Array = board._available_ids()
	var before: Dictionary = board.session.checkpoint()
	for id in cards:
		board.hand_view.select_card_id(id)
		await _settle()
	_check(
		board.summon_plan.card_ids == cards and board._available_ids().is_empty(),
		"orias_return_ui_reserves_payment"
	)
	_check(board.session.checkpoint() == before, "orias_return_ui_draft_preserves_absence")
	_check(
		board.session.choose([], board._order()).action != "invalid",
		"orias_return_ui_legal_payment"
	)
	board.enter_powers()
	await _settle()
	_check(
		board.web_button.disabled and board.snare_button.disabled,
		"orias_return_ui_no_powers_while_absent"
	)
	board.session._opponent = {"powers": [], "order": {}}
	board.resolve_round()
	var deadline: int = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(
		board._job == null and board._human_alive(), "orias_return_ui_lord_returns_in_development"
	)
