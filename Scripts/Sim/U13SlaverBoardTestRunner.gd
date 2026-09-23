extends SceneTree

# Run directly in a fresh checkout, before --editor/--import. The production
# launcher likewise must not depend on .godot/global_script_class_cache.cfg.
const Board = preload("res://Prototype/U13/U13ActionFlowBoard.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	return ok

func click(button: Button) -> void:
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	check(root.gui_get_hovered_control() == button, "Slaver action receives mouse input")
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame

func run() -> void:
	for action in ["Swap", "Pass"]:
		var board = Board.new()
		root.add_child(board)
		board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# The diagnostic engine can exercise UI; production's version gate stays intact.
		board._runtime_ok = true
		board.open_setup()
		await process_frame
		board.start_loadout(["Deimos", "Gremory"], [Slots.TYPES, Slots.TYPES], false)
		for frame in range(5): await process_frame
		check(board._slaver_pending(), action + " starts at Slaver")
		var before: Dictionary = board.session.board_view().world
		var taken: String = ""
		var given: String = ""
		if action == "Swap":
			var options: Array = board.game_menu.column.get_children().filter(func(n): return n is OptionButton)
			if check(options.size() == 2, "Slaver exposes both card choices"):
				options[0].select(options[0].item_count - 1)
				options[1].select(options[1].item_count - 1)
				taken = before.market[options[0].selected]
				given = before.hand[options[1].selected]
			check(not board.confirm.disabled and board.slaver_swap.is_valid(), "Swap is enabled and bound")
			await click(board.confirm)
		else:
			check(not board.pass_button.disabled, "Pass is enabled")
			await click(board.pass_button)
		var deadline: int = Time.get_ticks_msec() + 30000
		while board._job != null and Time.get_ticks_msec() < deadline:
			await process_frame
		check(board._job == null, action + " worker completes")
		for frame in range(3): await process_frame
		check(board.choice_error.is_empty(), action + " has no economy error")
		check(board.session.pending_choice.is_empty() and board._planning(), action + " leaves Slaver")
		check(board._flow_title() == "Work Target" and not board.game_menu.visible, action + " advances modal to Work Target")
		var after: Dictionary = board.session.board_view().world
		if action == "Swap":
			var expected: Array = before.hand.duplicate()
			expected.erase(given)
			expected.append(taken)
			expected.sort()
			var actual: Array = after.hand.duplicate()
			actual.sort()
			check(actual == expected, "Swap exchanges exactly the selected cards")
		else:
			check(after.hand == before.hand, "Pass preserves the human hand")
		board.queue_free()
		await process_frame
	print("U13 Slaver board: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
