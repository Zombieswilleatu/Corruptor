extends "res://Scripts/Sim/U13OdradekBoardTestRunner.gd"

func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	board.start_loadout(["Odradek", "Gremory"], [Slots.TYPES, Slots.TYPES], true)
	await _settle()
	if not _check(board.match_started, "Sigil board starts"):
		quit(1)
		return
	var world: Dictionary = board._visible_world.duplicate(true)
	var side = board.sides[1]
	for state in ["fresh", "flipped", ""]:
		world.sigils[0].Lord = state
		world.sigils[0].Castle = state
		side.bind_world(world, 0, true)
		await _settle()
		for pair in [[side.lord_sigil_visual, side.lord_group], [side.castle_sigil_visual, side.castle_guard_drop_area]]:
			var overlay = pair[0]
			_check(overlay.state == state and overlay.visible == (state != ""), "overlay follows public Sigil state")
			_check(overlay.get_parent() == pair[1] and overlay.zone_size == pair[1].size, "overlay covers affected zone")
			if state != "":
				_check(overlay.texture != null and overlay.texture.get_width() > 0, "original Sigil PNG loads")
		_check(side.lord_sigil.text == ("◈ Fresh" if state == "fresh" else ("◈ Decaying" if state == "flipped" else "")), "readout names fresh and decaying")
	# Native mouse events must still reach the card with the foreground visible.
	side.lord_sigil_visual.set_state("fresh")
	var presses: Array = [0]
	side.lord_card.input_surface.pressed.connect(func(): presses[0] += 1)
	var point: Vector2 = side.lord_card.input_surface.get_global_rect().get_center()
	_mouse(point, true)
	_mouse(point, false)
	await _settle()
	_check(presses[0] == 1, "Sigil allows real card click")
	board.queue_free()
	await process_frame
	print("U13 Sigil board failures: %d" % failures)
	quit(failures)

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)
