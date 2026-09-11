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
		var actual_view: Dictionary = board._visible_world.duplicate(true)
		board.wish_choice.select(1)
		for row in board._visible_world.entities:
			if row.kind == "castle" and row.owner == 0:
				row.attributes.construction_state = "building"
				row.attributes.integrity = 7
		board._update_direct_ui()
		_check(board.wish_target.item_count == 0 and board.wish_button.disabled, "Longevity excludes protected castles and disables empty selection")
		var damaged: Dictionary = board._visible_world.entities.filter(func(e): return e.kind == "castle" and e.owner == 0)[0]
		damaged.attributes.construction_state = "active"
		damaged.attributes.status = "standing"
		board._update_direct_ui()
		_check(board.wish_target.item_count == 1 and board.wish_target.get_item_metadata(0) == damaged.id and not board.wish_button.disabled, "Longevity offers damaged active castle")
		damaged.attributes.integrity = damaged.attributes.max_integrity
		board._update_direct_ui()
		_check(board.wish_target.item_count == 0 and board.wish_button.disabled, "Longevity removes fully repaired target on refresh")
		board._visible_world = actual_view
		board.wish_choice.select(0)
		board._update_direct_ui()

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
		_check(board.session.debug_action("marcher", 1, "Lord").action != "invalid", "Death animation victim fixture")
		board._refresh()
		var victim: Dictionary = board.session.board_view().world.entities.filter(func(e): return e.kind == "marcher")[0]
		board._confirm_wish_death({"lane": victim.attributes.lane, "field_position": {"x_fp": victim.attributes.x_fp, "y_fp": victim.attributes.y_fp}})
		board.session._opponent = {"powers": [], "order": {}}
		board._start_job("marching", board.queued, {})
		var deadline: int = Time.get_ticks_msec() + 60000
		while board._job != null and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(board._job == null and board.playing, "Wish resolves through board worker")
		_check(not board.session.board_view().world.wish_prices.is_empty(), "Price due round available")
		_check(board.death_wish_visual.active() and board.death_wish_visual.texture != null and board.lanes._units.any(func(e): return e.id == victim.id), "skull starts with victim held until impact")
		var resolved_state: Dictionary = board.session.checkpoint()
		board._process(0.45)
		_check(not board.lanes.deaths.seen.has(victim.id) and board.clock == 0, "no early chit death or Marching advance")
		board._process(0.02)
		_check(board.lanes.deaths.seen.has(victim.id) and not board.lanes._units.any(func(e): return e.id == victim.id), "skull impact starts chit flash and ghost together")
		var deaths: int = board.lanes.deaths.visible.size()
		board._process(0.4)
		_check(not board.death_wish_visual.active() and board.lanes.deaths.visible.size() == deaths and board.session.checkpoint() == resolved_state, "skull finishes once without applying damage again")
		# Replaying a presentation queue must handle a slow frame and cancellation.
		var wish_events: Array = board.session.kanifous_events.filter(func(e): return e.type == "KANIFOUS_WISH_RESOLVED" and e.data.power == "WishDeath")
		var impacts: Array = []
		board.death_wish_visual.impact.connect(func(details): impacts.append(details))
		board.death_wish_visual.play_events(wish_events + wish_events)
		board.death_wish_visual.advance(2.0)
		_check(impacts.size() == 2 and not board.death_wish_visual.active() and board.lanes.deaths.visible.size() == deaths, "slow frame drains queued skulls without duplicate chit deaths")
		board.death_wish_visual.play_events(wish_events)
		board.finish_playback()
		board.death_wish_visual.advance(1.0)
		_check(not board.death_wish_visual.active() and impacts.size() == 2 and not board.lanes._units.any(func(e): return e.id == victim.id), "skip cancels pending skull impact and restores final field")
		for attempt in range(3):
			board._start_job("next_round")
			deadline = Time.get_ticks_msec() + 60000
			while board._job != null and Time.get_ticks_msec() < deadline:
				await process_frame
			if board.price_visual.visible:
				break
			board.session._opponent = {"powers": [], "order": {}}
			board._start_job("marching", [], {})
			deadline = Time.get_ticks_msec() + 60000
			while board._job != null and Time.get_ticks_msec() < deadline:
				await process_frame
			board.finish_playback()
		_check(board.price_visual.visible and board.price_visual.copy.text.contains("THE PRICE OF WISHES"), "due Price automatically opens readable popup")
		var price_state: Dictionary = board.session.checkpoint()
		board.price_visual._next()
		_check(not board.price_visual.visible and board.session.checkpoint() == price_state, "acknowledging Price changes no game state")
		_check(board.wish_visual.lamp_texture != null, "provided lamp art loaded")
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
