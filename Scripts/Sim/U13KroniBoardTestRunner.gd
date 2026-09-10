extends "res://Scripts/Sim/U13DirectBoardTestRunner.gd"

const Kroni = preload("res://Scripts/Sim/U13Kroni.gd")
const Visual = preload("res://Prototype/U13/U13KroniVisual.gd")

func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	board.start_loadout(["Kroni", "Odradek"], [Slots.TYPES, Slots.TYPES], true)
	await _settle()
	_check(board.match_started and board._visible_world.lord_ids[0] == "Kroni", "Kroni main runner starts")
	_check(board.guard_chomp.active() and board.guard_chomp.rows[0].event.data.cause == "Cannibal Hunger", "opening Cannibal Hunger plays Guard chomp")
	var opening_state: Dictionary = board.session.checkpoint()
	board._process(1.0)
	_check(not board.guard_chomp.active() and board.session.checkpoint() == opening_state, "Guard chomp completion changes no game state")
	board.enter_powers()
	await _settle()
	_check(board.kroni_box.visible and not board.consume_button.disabled and not board.ravenous_button.disabled, "both active powers available")
	var checkpoint: Dictionary = board.session.checkpoint()
	board.consume_button.pressed.emit()
	await _settle()
	_check(board.consume_targeting.visible and not board.phase_prompt.visible, "Consume opens clean board targeting")
	var enemy: Dictionary = {}
	for row in board._visible_world.entities:
		if row.kind == "card" and row.owner == 1 and row.attributes.get("role") == "guard":
			enemy = row
			break
	board._guard_selected({"kind": "zone", "owner": 1, "lane": enemy.attributes.lane, "slot": enemy.attributes.slot})
	await _settle()
	_check(board.queued.size() == 1 and board.queued[0].target.entity_id == enemy.id, "single Guard click queues exact Consume target")
	_check(not board.consume_targeting.visible and board.phase_prompt.visible, "target dialogue dismisses automatically")
	board.ravenous_button.pressed.emit()
	await _settle()
	_check(board.ravenous_placement.visible and board.queued.size() == 1 and not board.phase_prompt.visible, "Ravenous requires starting placement before queuing")
	_check(board.ravenous_placement.confirm_button.disabled and board.confirm.disabled, "cannot confirm or submit an unplaced start")
	board._cancel_ravenous()
	_check(board.queued.size() == 1 and not board.ravenous_placement.visible, "cancel leaves no Ravenous declaration")
	board.ravenous_button.pressed.emit()
	await _settle()
	var chosen_rect: Rect2 = board.ravenous_placement.lane_rect("Castle")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = chosen_rect.position + chosen_rect.size * Vector2(0.75, 0.75)
	board.ravenous_placement._gui_input(click)
	var start: Dictionary = board.ravenous_placement.target.duplicate(true)
	_check(start.lane == "Castle" and start.field_position.x_fp == 0 and start.field_position.y_fp == 450, "field click selects exact start across lanes")
	board.ravenous_placement.dragging = false
	board.ravenous_placement.confirm_button.pressed.emit()
	await _settle()
	_check(board.queued.size() == 2 and board.ravenous_button.disabled and board.queued[1].target == start, "Ravenous queues only selected position alongside Consume")
	_check(not board.ravenous_placement.visible and board.phase_prompt.visible, "placement closes on confirmation")
	_check(board.session.checkpoint() == checkpoint, "UI planning leaves authoritative state unchanged")
	board._remove_kroni(0)
	await _settle()
	_check(board.queued.size() == 1 and board.queued[0].power_id == Kroni.RAVENOUS, "queue removal retains Ravenous with valid index")
	# Put real Marchers on the activation path through the debug edit boundary.
	board.session.debug_action("hunger", 0, "Lord")
	board.session.debug_action("hunger", 0, "Lord")
	board.session.debug_action("hunger", 0, "Lord")
	_check(board.session.board_view().world.hunger[0] == 3 and board.session.board_view().world.personal_tears[0] == 1, "debug Hunger follows milestone rules")
	board._refresh()
	board.queued = []
	board._queue_kroni(Kroni.RAVENOUS, start)
	board._queue_kroni(Kroni.CONSUME, {"entity_id": enemy.id})
	board.session._opponent = {"powers": [], "order": {}}
	board.resolve_round()
	var deadline: int = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(board._job == null and board.playing, "Kroni worker resolves")
	_check(not board.kroni_visual.frames.is_empty(), "authoritative actor tape reaches board playback")
	var launched: Dictionary = board.kroni_visual.frames[0].actors[0]
	_check(launched.x_fp == 0 and launched.y_fp == 1050, "worker and playback preserve player starting position")
	board.finish_playback()
	_check(board.kroni_visual.frames.is_empty() and not board.kroni_visual.busy(), "skip clears actor and chomp state")
	deadline = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	board.next_round()
	deadline = Time.get_ticks_msec() + 15000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(board.session.round_number() == 2, "runner continues after Ravenous")
	_check(board.guard_chomp.active() and board.guard_chomp.rows[0].event.data.cause == "Consume", "next-round Consume plays Guard chomp")
	_check(not board._planning() and not board.phase_prompt.visible, "decisions wait for Guard consumption playback")
	var meal_state: Dictionary = board.session.checkpoint()
	board.guard_chomp.advance(0.35)
	_check(board.guard_chomp.active(), "double chomp remains active midway")
	board.finish_playback()
	_check(not board.guard_chomp.active() and board.session.checkpoint() == meal_state, "skipping Guard chomp restores slots without replaying Devour")
	var banished: Dictionary = board.session.debug_action("banish", 0, "Lord")
	_check(banished.action != "invalid", "Kroni banishes into Breach")
	board.session.choose([], {})
	board.session._opponent = {"powers": [], "order": {}}
	var breach_round: Dictionary = board.session.run_to_marching()
	_check(breach_round.action != "invalid" and board.session.marching_events().any(func(e: Dictionary) -> bool: return e.type == "KRONI_ACTORS_STARTED" and e.data.actors.any(func(a: Dictionary) -> bool: return a.breach)), "Breach manifestation wired into actual match")
	var card = board.sides[1].lord_card
	card.preview._show_preview()
	card.preview.showing_back = true
	card.preview._render()
	await _settle()
	_check(card.preview.back_art.texture != null and card.preview.back_art.visible and not card.preview.preview_art.visible, "Lord flip displays back artwork")
	_check(card.art.stretch_mode == TextureRect.STRETCH_SCALE and card.lord_stats_overlay.artwork_rect().size == card.art.size, "card art fills container and stats track its geometry")
	card.preview._hide_preview()
	board.queue_free()
	await process_frame
	var preview = load("res://Prototype/U13/U13KroniPreview.tscn").instantiate()
	root.add_child(preview)
	await _settle()
	_check(not preview.visual.bites.is_empty() and preview.visual.sheet != null, "standalone preview has real consumption events and sprite")
	preview.set_process(false)
	var visual = preview.visual
	var at: float = visual.bites[0].at
	visual.show_time(at)
	_check(visual.busy(), "consumption starts presentation pause")
	visual.advance_bite(visual.chomp_seconds * 0.5)
	_check(visual.busy() and visual.clock == at, "chomp animates without advancing field clock")
	_check(Visual.facing(Vector2(1, 0)) == 2 and Visual.facing(Vector2(-1, 0)) == 1 and Visual.facing(Vector2(0, 1)) == 0 and Visual.facing(Vector2(0, -1)) == 3, "all four supplied directions supported")
	var preview_click := InputEventMouseButton.new()
	preview_click.button_index = MOUSE_BUTTON_LEFT
	preview_click.pressed = true
	preview_click.position = preview.visual.field_rect.position + preview.visual.field_rect.size * Vector2(0.875, 0.75)
	preview._gui_input(preview_click)
	_check(preview.visual.frames[0].actors[0].x_fp == 0 and preview.visual.frames[0].actors[0].y_fp == 1050, "preview click uses same chosen-position mapping")
	var directions: Dictionary = {}
	for i in range(8):
		preview._restart()
		directions[preview.visual.frames[0].actors[0].vy_fp] = true
	_check(directions.size() > 1, "preview fresh launches vary the trajectory")
	preview.breach = true
	preview._restart()
	_check(preview.visual.frames[0].actors[0].breach, "preview switches to real Breach actor")
	preview.queue_free()
	await process_frame
	print("U13 Kroni board failures: %d" % failures)
	quit(0 if failures == 0 else 1)
