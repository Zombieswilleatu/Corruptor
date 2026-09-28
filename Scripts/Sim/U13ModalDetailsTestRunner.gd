extends SceneTree

const Menu = preload("res://Prototype/U13/U13GameMenu.gd")
var failures: int = 0
var checks: int = 0
var actions: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + description)

func click(button: Button) -> void:
	if button.toggle_mode: button.set_pressed_no_signal(not button.button_pressed)
	button.pressed.emit()

func run() -> void:
	var board_script = load("res://Prototype/U13/U13TutorialBoard.gd")
	check(board_script != null and board_script.can_instantiate(), "playable tutorial board compiles")
	var menu = Menu.new()
	root.add_child(menu)
	menu.present("RITES", "Choose a rite.")
	var first: Button = menu.details("FIRST", "First explanation", "CONFIRM", func(): actions += 1)
	var second: Button = menu.details("SECOND", "Second explanation")
	var first_body: Control = menu._detail_rows[0].body
	var second_body: Control = menu._detail_rows[1].body
	check(not first_body.visible and not second_body.visible, "explanations start collapsed")
	click(first)
	check(first_body.visible and first.button_pressed and actions == 0, "opening details selects the row without executing its action")
	click(second)
	check(not first_body.visible and second_body.visible and not first.button_pressed, "selecting another row closes the previous explanation")
	click(second)
	check(not second_body.visible and actions == 0, "clicking the selected row collapses it without an action")
	click(first)
	click(first_body.get_child(1))
	check(actions == 1, "explicit confirmation executes its callback exactly once")
	menu.pending_selection = func(): return true
	menu.present("NEXT", "")
	check(menu._detail_rows.is_empty() and not menu.pending_selection.is_valid(), "opening another menu clears detail state and pending selection")
	check(menu.column.get_child_count() == 1, "an empty introduction creates no blank label")
	var host := VBoxContainer.new()
	root.add_child(host)
	menu.embed_in(host)
	menu.present("EMBEDDED", "Choose.")
	var embedded: Button = menu.details("ITEM", "Embedded details")
	click(embedded)
	check(menu._detail_rows[0].body.visible, "details also open in the embedded decision menu")
	host.queue_free()
	await process_frame
	print("U13 Modal Details: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
