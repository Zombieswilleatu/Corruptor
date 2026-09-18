extends "res://Scripts/Sim/U13UIFeedbackTestRunner.gd"


func fresh(lord: String) -> void:
	if is_instance_valid(board):
		board.free()
	board = Board.new()
	root.add_child(board)
	# Diagnostic fixture only; the production runtime gate remains unchanged.
	board._runtime_ok = true
	board.open_setup()
	await process_frame
	board.start_loadout([lord, "Gremory" if lord != "Gremory" else "Deimos"], [Slots.TYPES, Slots.TYPES], false)
	await process_frame
	while not board.session.pending_choice.is_empty():
		board.pass_round()
		await job_done()
	board._goto_flow(4)
	await process_frame


func install(state: Dictionary) -> void:
	state.presentation_world = state.world.duplicate(true)
	check(board.session._owner.restore(state).action != "invalid", "targeting fixture restores through validation")
	board.session._read_revision = -1
	board._refresh()


func click_at(overlay: Control, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	overlay._gui_input(event)
	event.pressed = false
	overlay._gui_input(event)


func run() -> void:
	await fresh("Orias")
	var checkpoint: Dictionary = board.session._owner.snapshot()
	board.web_button.pressed.emit()
	await process_frame
	check(board.placement.visible and not board.phase_prompt.visible, "Web opens over the game board without the decision modal")
	for overlay in [board.placement, board.redirect_placement, board.ravenous_placement, board.gravity_placement, board.wish_placement, board.resurrection_placement]:
		for lane in ["Lord", "Castle"]:
			var actual: Rect2 = overlay.get_global_transform_with_canvas() * overlay.lane_rect(lane)
			var expected: Rect2 = board.lanes.get_global_transform_with_canvas() * board.lanes.travel_rect(lane)
			check(overlay.battlefield == board.lanes and actual.is_equal_approx(expected), "%s %s targets the actual battlefield rectangle" % [overlay.get_script().resource_path.get_file(), lane])
	click_at(board.placement, Vector2(5, 5))
	check(not board.placement.placed, "Web ignores clicks outside the real lanes")
	click_at(board.placement, board.placement.lane_rect("Castle").get_center())
	check(board.placement.target == {"lane": "Castle", "field_position": {"x_fp": 1200, "y_fp": 300}}, "actual Castle lane click preserves simulation coordinates")
	board.placement.cancel_button.pressed.emit()
	check(board.queued.is_empty() and board.phase_prompt.visible, "Web cancellation restores the decision without an order")
	board.web_button.pressed.emit()
	click_at(board.placement, board.placement.lane_rect("Lord").get_center())
	board.placement.confirm_button.pressed.emit()
	check(board.queued.size() == 1 and board.queued[0].target.lane == "Lord" and not board.placement.visible, "Web confirmation queues the real lane")
	check(board.session._owner.snapshot() == checkpoint, "Web placement never changes authoritative state")

	await fresh("Valak")
	var state: Dictionary = board.session._owner.snapshot()
	state.world.players[0].resources.life_essence = 3
	install(state)
	checkpoint = board.session._owner.snapshot()
	board.projection_spend.value = 3
	board.projection_button.pressed.emit()
	check(board.power_targeting.visible and not board.phase_prompt.visible, "Projection exposes the actual Guard zones")
	board.sides[1].lord_guard_box.get_child(0).input_surface.pressed.emit()
	check(board.queued.is_empty(), "Projection rejects a friendly Guard slot")
	board.power_targeting.cancelled.emit()
	check(board.queued.is_empty() and board.phase_prompt.visible and not board.power_targeting.visible, "Projection cancellation restores the powers modal")
	board.projection_button.pressed.emit()
	board.sides[0].castle_guard_box.get_child(0).input_surface.pressed.emit()
	check(board.queued.size() == 1 and board.queued[0].target == {"kind": "guard_zone", "player_id": 1, "zone": "Castle"} and board.queued[0].parameters.spend == 3, "actual enemy Guard slot queues Projection with the chosen spend")
	check(board.session._owner.snapshot() == checkpoint, "Projection targeting spends no authoritative Essence")

	for lord in ["Kanifous", "Deimos"]:
		await fresh(lord)
		state = board.session._owner.snapshot()
		if lord == "Deimos":
			state.world.data.neutral_tears = 5
			state.world.data.veil_breaches.arrivals = [{"lord_id": "Kanifous", "round": 1, "veil": 5, "threshold": 5, "protection": 1}]
		for row in state.world.entities.entities:
			if row.id == Slots.castle_id(0, 0):
				row.attributes.integrity = 7
			if lord == "Deimos" and row.kind == "lord" and row.owner == 0:
				row.attributes.alive = false
		install(state)
		board.wish_choice.select(0)
		board._update_direct_ui()
		board.wish_button.pressed.emit()
		check(board.queued.is_empty() and board.lanes.target_lane_enabled and not board.phase_prompt.visible, "%s Power waits for a real lane click" % lord)
		board.lanes.lane_selected.emit("Castle")
		var prefix: String = "Breach" if lord == "Deimos" else ""
		check(board.queued.size() == 1 and board.queued[0].power_id == prefix + "WishPower" and board.queued[0].target == {"lane": "Castle"}, "%s Power keeps the correct normal/Breach declaration" % lord)
		board._remove_wish()
		board.wish_choice.select(1)
		board._update_direct_ui()
		board.wish_button.pressed.emit()
		check(board.power_targeting.visible and not board.phase_prompt.visible, "%s Longevity exposes Castle cards" % lord)
		board.sides[0].target_controls[Slots.castle_id(1, 0)].pressed.emit()
		board.sides[1].target_controls[Slots.castle_id(0, 1)].pressed.emit()
		board.sides[1].target_controls[Slots.castle_id(0, 4)].pressed.emit()
		check(board.queued.is_empty(), "%s Longevity rejects enemy, healthy, and unbuilt Castles" % lord)
		board.sides[1].target_controls[Slots.castle_id(0, 0)].pressed.emit()
		check(board.queued.size() == 1 and board.queued[0].power_id == prefix + "WishLongevity" and board.queued[0].target == {"entity_id": Slots.castle_id(0, 0)}, "%s Longevity queues the clicked eligible Castle" % lord)
		check(board.phase_prompt.visible and not board.power_targeting.visible, "%s completed wish returns to powers" % lord)

	await fresh("Odradek")
	state = board.session._owner.snapshot()
	state.world.players[0].resources.reconfiguration = 4
	install(state)
	board._begin_guard_power("Inversion")
	check(board.guard_targeting.visible and not board.phase_prompt.visible, "Inversion leaves the actual Guard zones accessible")
	board.sides[1].castle_guard_box.get_child(0).input_surface.pressed.emit()
	check(board.queued.is_empty() and not board.guard_targeting.confirm_button.disabled and board.guard_destination.owner == 0 and board.guard_destination.lane == "Castle", "Inversion selects a friendly zone directly and waits for confirmation")
	board.guard_targeting.confirm_button.pressed.emit()
	check(board.queued.is_empty() and board.guard_targeting.note.text.contains("Could not queue"), "an empty Inversion zone still fails authoritative validation")
	board.guard_targeting.cancelled.emit()
	check(board.reconfiguration_menu.visible and not board.guard_targeting.visible, "Inversion cancellation returns to the Reconfiguration menu")

	await fresh("Gremory")
	board.queue_predator()
	check(board.power_targeting.visible and not board.phase_prompt.visible, "existing lane powers also expose the battlefield")
	board.lanes.lane_selected.emit("Castle")
	await process_frame
	check(board.queued.size() == 1 and board.queued[0].target == {"lane": "Castle"}, "Predator still queues from the actual lane")
	board.queue_ruin()
	board._hand_selection_changed(board._available_ids().slice(0, 2))
	await process_frame
	check(board.power_targeting.visible and board._power_cost.size() == 2, "Ruin retains clickable hand payment while targeting on the board")
	board.sides[0].target_controls[Slots.castle_id(1, 0)].pressed.emit()
	await process_frame
	check(board.queued.size() == 2 and board.queued[1].target == {"entity_id": Slots.castle_id(1, 0)}, "Ruin queues the actual enemy Castle after payment")
	board.free()
	print("U13 board targeting failures: %d" % failures)
	quit(1 if failures else 0)
