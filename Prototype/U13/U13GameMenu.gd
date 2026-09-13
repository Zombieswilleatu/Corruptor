extends Control

signal closed
var column: VBoxContainer
var message: Label
var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 110
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(740, 760)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171511")
	style.border_color = Color("93713d")
	style.set_border_width_all(2)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 625)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	message = Label.new()
	message.custom_minimum_size.y = 40
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(message)
	close_button = Button.new()
	close_button.text = "RETURN TO BOARD"
	close_button.custom_minimum_size.y = 42
	outer.add_child(close_button)
	close_button.pressed.connect(func(): hide(); closed.emit())
	hide()

func present(title: String, description: String, dismissible: bool = true) -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	message.text = ""
	label(title, 24)
	label(description, 16)
	close_button.visible = dismissible
	show()

func label(value: String, size_value: int = 16) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", size_value)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(result)
	return result

func button(value: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size.y = 42
	result.pressed.connect(callback)
	column.add_child(result)
	return result

func option(values: Array) -> OptionButton:
	var result := OptionButton.new()
	for value in values:
		result.add_item(str(value))
	result.custom_minimum_size.y = 40
	column.add_child(result)
	return result

func checks(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var box := CheckBox.new()
		box.text = str(value)
		box.custom_minimum_size.y = 36
		column.add_child(box)
		result.append(box)
	return result
