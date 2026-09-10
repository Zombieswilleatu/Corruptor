extends "res://Scripts/Sim/U13OdradekBoardTestRunner.gd"


func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	board.start_loadout(["Odradek", "Gremory"], [Slots.TYPES, Slots.TYPES], true)
	await _settle()
	var fixture: Dictionary = board.session.OdradekScenario.world()
	fixture.players[0].resources.reconfiguration = 3
	var owner = Odradek.new().create_combat_match()
	owner.start("complete-board", fixture, [0, 1])
	board.session._owner = owner
	board.session._to_planning()
	board._reset_direct()
	board.powers_step = false
	board._refresh()
	board.enter_powers()
	await _settle()
	_check(not board.inversion_button.disabled, "four_point_bank_unlocks_all_controls")
	var before: Dictionary = board.session.checkpoint()
	board.false_orders_button.pressed.emit()
	await _settle()
	board.sides[0].castle_guard_box.get_child(0).input_surface.pressed.emit()
	await _settle()
	_check(
		not board.guard_source.is_empty() and board.queued.is_empty(),
		"false_orders_first_click_selects_guard"
	)
	board.sides[1].lord_guard_box.get_child(0).input_surface.pressed.emit()
	_check(board.queued.is_empty(), "false_orders_rejects_other_owner_destination")
	board.sides[0].lord_guard_box.get_child(0).input_surface.pressed.emit()
	await _settle()
	_check(
		(
			board.queued.size() == 1
			and board.queued[0].power_id == Odradek.FALSE_ORDERS
			and board.queued[0].target.owner_id == 1
			and board.queued[0].target.lane == "Lord"
		),
		"false_orders_second_click_queues_destination"
	)
	_check(
		board.shift_button.disabled and not board.false_orders_button.disabled,
		"guard_order_reserves_two_points"
	)
	_check(board.session.checkpoint() == before, "guard_selection_preserves_authoritative_world")
	board.clear_powers()
	board.shift_button.pressed.emit()
	await _settle()
	var placement = board.redirect_placement
	_check(
		(
			placement.visible
			and placement.allegiance_mode
			and placement.radius_fp < Odradek.REDIRECT_RADIUS_FP
		),
		"shift_opens_smaller_circle_preview"
	)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = placement.lane_rect("Lord").get_center()
	placement._gui_input(click)
	placement.confirm_button.pressed.emit()
	await _settle()
	_check(
		(
			board.queued.size() == 1
			and board.queued[0].power_id == Odradek.SHIFT
			and not board.redirect_button.disabled
		),
		"shift_queues_three_points_leaving_one"
	)
	board.redirect_button.pressed.emit()
	placement._gui_input(click)
	placement.confirm_button.pressed.emit()
	await _settle()
	board._move_redirect(1, -1)
	_check(
		(
			board.queued.size() == 2
			and board.queued[0].power_id == Odradek.REDIRECT
			and board.session.choose(board.queued, board._order()).action != "invalid"
		),
		"mixed_cart_reorders_with_valid_identity"
	)
	board.clear_powers()
	board.inversion_button.pressed.emit()
	await _settle()
	board.sides[0].castle_guard_box.get_child(0).input_surface.pressed.emit()
	await _settle()
	_check(
		(
			board.queued.size() == 1
			and board.queued[0].power_id == Odradek.INVERSION
			and board.redirect_button.disabled
		),
		"inversion_zone_click_reserves_four_points"
	)
	board.session._opponent = {"powers": [], "order": {}}
	board.resolve_round()
	await _worker(board)
	_check(board._job == null and board.playing, "prepared_inversion_worker_resolves")
	board.finish_playback()
	await _worker(board)
	var tears: int = board.session.checkpoint().match.world.data.neutral_tears
	board.next_round()
	await _worker(board)
	await _settle()
	var world: Dictionary = board.session.checkpoint().match.world
	var guards: Array = world.entities.entities.filter(
		func(e: Dictionary) -> bool:
			return (
				e.kind == "card"
				and e.owner == 0
				and e.attributes.get("role") == "guard"
				and e.attributes.lane == "Castle"
			)
	)
	_check(
		(
			board.session.round_number() == 2
			and guards.size() == 3
			and world.data.neutral_tears == tears + 1
		),
		"runner_next_round_transfers_guard_and_grants_tear"
	)
	board.queue_free()
	await process_frame
	print("U13 Odradek complete board failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _worker(board) -> void:
	var deadline: int = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
