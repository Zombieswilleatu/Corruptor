extends SceneTree

const Wheel = preload("res://Prototype/U13/U13VeilWheel.gd")
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var wheel = Wheel.new()
	root.add_child(wheel)
	wheel.size = Vector2(460, 104)
	var world: Dictionary = {"veil_total": 6, "neutral_tears": 3, "personal_tears": [1, 2]}
	var before: Dictionary = world.duplicate(true)
	wheel.bind_world(world, 3)
	await process_frame
	check(wheel.visible_values() == [3, 4, 5, 6, 7, 8, 9], "seven numbers surround the current Veil")
	wheel.next_button.pressed.emit()
	wheel._process(1)
	check(wheel.selected_value == 7 and wheel.current_value == 6 and world == before, "turning the wheel never changes the match")
	wheel.bind_world(world, 3)
	check(wheel.selected_value == 7, "board refresh preserves browsing position")
	check(wheel.stamp_owners(5) == [0, 1] and wheel.stamp_owners(9) == [1] and wheel.stamp_owners(13).is_empty(), "public Tears stamp the covered arrivals for each player")
	world.personal_tears = [5, 4]
	wheel.bind_world(world, 3)
	check(wheel.stamp_owners(17) == [0, 1] and wheel.stamp_owners(12) == [0] and wheel.stamp_owners(21).is_empty(), "fifth Tear earns Dominion stamp; cascade never gets protection")
	wheel.select_value(0)
	wheel._process(1)
	check(wheel.visible_values() == [0, 1, 2, 3, 4, 5, 6] and wheel.previous_button.disabled, "start of track stays bounded with seven numbers")
	var scroll := InputEventMouseButton.new()
	scroll.button_index = MOUSE_BUTTON_WHEEL_DOWN
	scroll.pressed = true
	wheel._gui_input(scroll)
	check(wheel.visible_values() == [1, 2, 3, 4, 5, 6, 7], "scrolling turns the rim immediately at the beginning")
	wheel.select_value(26)
	check(wheel.visible_values() == [20, 21, 22, 23, 24, 25, 26] and wheel.next_button.disabled, "end never wraps into the beginning")
	wheel.current_button.pressed.emit()
	check(wheel.selected_value == 6 and wheel.following_current, "current-Veil button returns to the live position")
	world.veil_total = 10
	wheel.bind_world(world, 4)
	check(wheel.selected_value == 10, "wheel follows later Veil changes after returning to now")
	wheel._process(1)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(230, 55)
	wheel._gui_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(80, 55)
	wheel._gui_input(drag)
	press.pressed = false
	press.position = drag.position
	wheel._gui_input(press)
	check(not wheel._dragging and wheel.selected_value > 10 and wheel.current_value == 10, "dragging turns and snaps the wheel without changing the Veil")
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	wheel._gui_input(key)
	check(wheel.selected_value == 10 and wheel.following_current, "Enter returns keyboard navigation to the current Veil")
	check(wheel.milestone(5).planned and wheel.milestone(21).tooltip.contains("BOTH") and wheel.milestone(21).tooltip.contains("pending") and not wheel.milestone(12).planned, "proposed Breaches and round gate are distinct from live victory rules")
	wheel.bind_world(world, 21)
	check(wheel.milestone(21).tooltip.contains("Round gate reached"), "cascade tooltip reflects the public round gate")
	for width in [460, 800, 1100]:
		wheel.size = Vector2(width, 104)
		wheel._layout()
		check(wheel.current_button.get_rect().end.x <= wheel.neutral_label.position.x and wheel.detail.get_rect().end.y <= wheel.size.y, "wheel text and controls fit banner width " + str(width))
	wheel.free()
	print("U13 Veil wheel failures: ", failures)
	quit(1 if failures else 0)
