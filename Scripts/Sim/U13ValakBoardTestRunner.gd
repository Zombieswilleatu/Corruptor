extends "res://Scripts/Sim/U13DirectBoardTestRunner.gd"

const Valak = preload("res://Scripts/Sim/U13Valak.gd")

func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	# Explicit test-only compatibility exercise; never changes the board's
	# production runtime gate. Normal runs require its pinned Godot version.
	if OS.get_cmdline_user_args().has("--compatibility-check") and DisplayServer.get_name() == "headless":
		board._runtime_ok = true
		board.open_setup()
	board.start_loadout(["Valak", "Gremory"], [Slots.TYPES, Slots.TYPES], true)
	await _settle()
	if not _check(board.match_started and board._visible_world.lord_ids[0] == "Valak", "main board starts Valak"):
		board.queue_free()
		_finish_valak()
		return
	board.enter_powers()
	await _settle()
	_check(board.valak_box.visible and board.projection_button.disabled and not board.gravity_button.disabled, "zero Essence disables Projection only")
	_check(board.session.debug_action("essence", 0, "Lord").action != "invalid", "debug fills Valak Essence through validated match state")
	var fixture: Dictionary = board.session.checkpoint()
	board._refresh()
	await _settle()
	board.projection_zone.select(1)
	board.projection_spend.value = 3
	board.projection_button.pressed.emit()
	await _settle()
	_check(board.queued.size() == 1 and board.queued[0].target == {"kind": "guard_zone", "player_id": 1, "zone": "Castle"} and board.queued[0].parameters.spend == 3, "Projection declares enemy Castle guard zone and exact spend")
	_check(board.session.checkpoint() == fixture, "queueing spends no authoritative Essence")
	board.gravity_button.pressed.emit()
	await _settle()
	_check(board.gravity_placement.visible and not board.phase_prompt.visible and board.confirm.disabled, "Gravity placement owns targeting without advancing")
	var rect: Rect2 = board.gravity_placement.lane_rect("Lord")
	board.gravity_placement._place_at(rect.get_center())
	board.gravity_placement._confirm()
	await _settle()
	_check(board.queued.size() == 2 and not board.gravity_placement.visible, "Orb queues separately and closes placement")
	board._remove_valak(1)
	_check(board.queued.size() == 1 and board.queued[0].parameters.spend == 3, "removing Orb preserves Projection spend")
	board.gravity_button.pressed.emit()
	board.gravity_placement._place_at(rect.get_center())
	board.gravity_placement._confirm()
	board.session._opponent = {"powers": [], "order": {}}
	board._start_job("marching", board.queued, {})
	var deadline: int = Time.get_ticks_msec() + 20000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	if _check(board._job == null and board.playing, "Valak board worker resolves"):
		board.set_process(false)
		_check(board.session.valak_events.any(func(e: Dictionary) -> bool: return e.type == "VALAK_PROJECTION_RESOLVED") and board.session.valak_events.any(func(e: Dictionary) -> bool: return e.type == "GRAVITY_ORB_STARTED"), "both powers supply board animation events")
		var checkpoint: Dictionary = board.session.checkpoint()
		for index in range(50):
			board.valak_effects.advance(0.1)
		_check(not board.valak_effects.active() and board.session.checkpoint() == checkpoint, "animations finish without changing authoritative state")
		var visual = board.valak_effects.energy[0]
		var card: Rect2 = board.valak_effects._rect(board.sides[1].lord_card.art)
		var radius: float = (visual.energy_size + 4 * visual.energy_step) * sqrt(2.0) * 0.5
		_check(visual.hover_position.x + radius + visual.hover_amount * 0.4 < card.end.x and visual.hover_position.y - radius - visual.hover_amount > card.position.y + card.size.y * 0.22, "all five rotating layers stay inside art and below stat numbers")
		_check(visual.charges == 2, "on-card orb retains two unspent charges")
		board.finish_playback()
	board.queue_free()
	await process_frame
	_finish_valak()

func _finish_valak() -> void:
	print("U13 Valak board failures: %d" % failures)
	quit(0 if failures == 0 else 1)
