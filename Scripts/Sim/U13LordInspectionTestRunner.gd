extends "res://Scripts/Sim/U13OdradekBoardTestRunner.gd"


func _run() -> void:
	var board = Scene.instantiate()
	root.add_child(board)
	await _settle()
	board.start_loadout(["Odradek", "Gremory"], [Slots.TYPES, Slots.TYPES], true)
	await _settle()
	var card = board.sides[1].lord_card
	var preview = card.preview
	var small: Vector2 = card.input_surface.get_global_rect().get_center()
	var presses: Array = [0]
	card.input_surface.pressed.connect(func(): presses[0] += 1)
	var before: Dictionary = board.session.checkpoint()
	_mouse(small, true)
	_check(preview._down, "real_lord_mouse_down_starts_hold")
	preview._on_hold_timeout()
	_mouse(small, false)
	await _settle()
	_check(preview.preview_root.visible and not preview.showing_back, "hold_opens_front_and_release_keeps_it_open")
	_check(presses[0] == 0 and board.session.checkpoint() == before, "hold_does_not_select_lord_or_declare_action")
	_check(card.lord_preview_stats.get_parent() == preview.preview_art, "enlarged_front_keeps_live_stat_numbers")
	var big: Vector2 = preview.frame.get_global_rect().get_center()
	_mouse(big, true)
	_mouse(big, false)
	await _settle()
	_check(preview.showing_back and preview.back.visible and not preview.preview_art.visible, "big_card_click_flips_to_rules")
	_check(preview.passive_label.modulate == Color.WHITE and preview.breach_label.modulate != Color.WHITE, "active_lord_passives_bright_breach_dim")
	_check("PSYCHIC INTERLOCK" in preview.passive_label.text and "PARADOX GEOMETRY" in preview.breach_label.text and "REDIRECT" not in preview.passive_label.text, "back_contains_passives_and_breach_without_active_menu")
	_mouse(big, true)
	_mouse(big, false)
	_check(not preview.showing_back, "second_big_click_returns_front")
	_mouse(big, true)
	preview._on_hold_timeout()
	_mouse(big, false)
	_check(not preview.preview_root.visible, "big_card_hold_dismisses_without_flipping")
	_mouse(small, true)
	preview._on_hold_timeout()
	_mouse(small, false)
	_mouse(small, true)
	preview._on_hold_timeout()
	_mouse(small, false)
	_check(not preview.preview_root.visible, "original_small_card_hold_dismisses_inspection")
	# Ordinary short clicks on Lord cards must still perform board targeting.
	_mouse(small, true)
	_mouse(small, false)
	await _settle()
	_check(not preview.preview_root.visible and presses[0] == 1, "short_lord_click_preserves_board_action")
	var world: Dictionary = board.session.board_view().world.duplicate(true)
	world.breach_lord = "Odradek"
	board.header.bind_world(world, 1)
	var breach = board.header.breach_preview
	var breach_point: Vector2 = board.header.breach_art.get_global_rect().get_center()
	_mouse(breach_point, true)
	breach._on_hold_timeout()
	_mouse(breach_point, false)
	var breach_big: Vector2 = breach.frame.get_global_rect().get_center()
	_mouse(breach_big, true)
	_mouse(breach_big, false)
	_check(breach.preview_root.visible and breach.showing_back and breach.in_breach, "breach_slot_supports_hold_and_flip")
	_check(breach.passive_label.modulate != Color.WHITE and breach.breach_label.modulate == Color("ffe4a0"), "breach_card_highlights_breach_and_dims_passives")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	_check(not breach.preview_root.visible, "escape_closes_inspection")
	preview.bind_lord("Odradek", false, false)
	_check(preview.passive_label.modulate != Color.WHITE and preview.breach_label.modulate != Color("ffe4a0"), "banished_outside_breach_has_no_active_rules")
	for lord_name in Picker.LORDS:
		_check(preview.Rules.RULES.has(lord_name), "rules_back_available_" + lord_name)
	board.queue_free()
	await process_frame
	print("U13 Lord inspection failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)
