extends Control

signal confirmed
signal cancelled
var panel: VBoxContainer
var note: Label
var confirm_button: Button
var frame: PanelContainer
var heading: Label
var markers: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 122
	frame = PanelContainer.new()
	preload("res://Prototype/U13/U13ReconfigurationStyle.gd").apply(frame)
	frame.position = Vector2(400, 310)
	frame.custom_minimum_size.x = 360
	add_child(frame)
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 14)
	frame.add_child(panel)
	heading = Label.new()
	heading.text = "RECONFIGURATION"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color("e6d2a3"))
	panel.add_child(heading)
	note = Label.new()
	note.custom_minimum_size.x = 0
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(note)
	confirm_button = Button.new()
	confirm_button.text = "QUEUE ORDER"
	confirm_button.pressed.connect(func() -> void: confirmed.emit())
	panel.add_child(confirm_button)
	var cancel := Button.new()
	cancel.text = "CANCEL · BACK TO POWERS"
	cancel.pressed.connect(func() -> void: cancelled.emit())
	panel.add_child(cancel)
	hide()

func display(message: String, ready: bool, _zones: Array, outlines: Array) -> void:
	note.text = message
	confirm_button.disabled = not ready
	markers = outlines
	show()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancelled.emit()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	for marker in markers:
		if not is_instance_valid(marker.control):
			continue
		var control: Control = marker.control
		var rect: Rect2
		if control is Container and control.get_child_count() > 0:
			var first: bool = true
			for child in control.get_children():
				if not child is Control:
					continue
				var child_rect: Rect2 = get_global_transform_with_canvas().affine_inverse() * child.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, child.size)
				rect = child_rect if first else rect.merge(child_rect)
				first = false
		else:
			rect = get_global_transform_with_canvas().affine_inverse() * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		draw_rect(rect.grow(4), Color("efc968") if marker.selected else Color("8b8069"), false, 2)
