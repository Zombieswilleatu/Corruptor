extends Control

signal requested(action: String, player_id: int, lane: String)
signal closed
var player: OptionButton
var lane: OptionButton
var message: Label
var buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 160
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(490, 440)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "DEBUG CONTROLS"
	title.add_theme_font_size_override("font_size", 23)
	column.add_child(title)
	var selectors := HBoxContainer.new()
	column.add_child(selectors)
	player = OptionButton.new()
	player.add_item("YOU", 0)
	player.add_item("OPPONENT", 1)
	selectors.add_child(player)
	lane = OptionButton.new()
	lane.add_item("Lord lane / Guards")
	lane.add_item("Castle lane / Guards")
	selectors.add_child(lane)
	for pair in [["guard", "ADD RANDOM GUARD"], ["cards", "DRAW 2 HAND CARDS"], ["marcher", "ADD RANDOM MARCHER"], ["banish", "KILL LORD · MOVE TO BREACH"], ["defeat_guard", "DEFEAT FIRST GUARD"], ["reconfiguration", "FILL ODRADEK RECONFIGURATION"], ["hunger", "ADD 1 KRONI HUNGER"]]:
		var button := Button.new()
		button.text = pair[1]
		button.pressed.connect(_request.bind(pair[0]))
		column.add_child(button)
		buttons[pair[0]] = button
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.text = "Planning only. Successful changes clear staged orders. Draws respect hand capacity; Guards respect zone capacity."
	column.add_child(message)
	var close := Button.new()
	close.text = "BACK TO BOARD"
	close.pressed.connect(dismiss)
	column.add_child(close)
	hide()


func _request(action: String) -> void:
	requested.emit(action, player.selected, "Lord" if lane.selected == 0 else "Castle")


func dismiss() -> void:
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		dismiss()
