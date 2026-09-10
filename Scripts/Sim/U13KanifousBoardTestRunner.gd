extends "res://Scripts/Sim/U13DirectBoardTestRunner.gd"
func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	if OS.get_cmdline_user_args().has("--compatibility-check") and DisplayServer.get_name() == "headless":
		board._runtime_ok = true
		board.open_setup()
	board.start_loadout(["Kanifous", "Valak"], [Slots.TYPES, Slots.TYPES], true)
	await _settle()
	if _check(board.match_started and board._visible_world.lord_ids[0] == "Kanifous", "Kanifous starts on main board"):
		board.enter_powers()
		await _settle()
		_check(board.wish_box.visible and not board.wish_button.disabled, "Wish controls available")
		_check(board.wish_visual.objects.size() == 1 and board.wish_visual.objects[0].phase == "smoke", "visible first-round smoke")
		board.wish_choice.select(0)
		board._wish_targets()
		board._queue_wish()
		_check(board.queued.size() == 1 and board.queued[0].power_id == "WishPower", "Power queues")
		_check(board.wish_button.disabled, "one Wish UI limit")
		board._remove_wish()
		board.wish_choice.select(3)
		board._wish_targets()
		board._queue_wish()
		_check(board.wish_placement.visible, "Death field targeting opens")
		board.wish_placement._place_at(board.wish_placement.lane_rect("Lord").get_center())
		board.wish_placement._confirm()
		_check(board.queued.size() == 1 and board.queued[0].power_id == "WishDeath" and not board.wish_placement.visible, "Death queues and closes")
		board._remove_wish()
		board.wish_choice.select(4)
		board._wish_targets()
		board._queue_wish()
		board.session._opponent = {"powers": [], "order": {}}
		board._start_job("marching", board.queued, {})
		var deadline: int = Time.get_ticks_msec() + 60000
		while board._job != null and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(board._job == null and board.playing, "Wish resolves through board worker")
		_check(not board.session.board_view().world.wish_prices.is_empty(), "Price due round available")
		board.finish_playback()
		var before: Dictionary = board.session.checkpoint()
		var obscured: Dictionary = board.session.board_view()
		obscured.world.void_active = true
		board._refresh(obscured)
		_check(board.void_overlay.visible and board.lanes.void_active and board.sides[0].void_active and board.sides[1].void_active, "Void presentation on both sides")
		_check(before == board.session.checkpoint(), "Void presentation never changes rules state")
	board.queue_free()
	await process_frame
	print("U13 Kanifous board failures: %d" % failures)
	quit(0 if failures == 0 else 1)
