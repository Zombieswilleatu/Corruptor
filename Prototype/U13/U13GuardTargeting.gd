extends Control

signal confirmed
signal cancelled
signal zone_selected(owner: int, lane: String)
var panel: VBoxContainer
var note: Label
var confirm_button: Button
var choices: HBoxContainer
var markers: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 122
	var frame := PanelContainer.new()
	frame.position = Vector2(400, 310)
	frame.custom_minimum_size.x = 360
	add_child(frame)
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 14)
	frame.add_child(panel)
	note = Label.new()
	note.custom_minimum_size.x = 350
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(note)
	choices = HBoxContainer.new()
	panel.add_child(choices)
	confirm_button = Button.new()
	confirm_button.text = "QUEUE ORDER"
	confirm_button.pressed.connect(func() -> void: confirmed.emit())
	panel.add_child(confirm_button)
	var cancel := Button.new()
	cancel.text = "CANCEL · BACK TO POWERS"
	cancel.pressed.connect(func() -> void: cancelled.emit())
	panel.add_child(cancel)
	hide()

func display(message: String, ready: bool, zones: Array, outlines: Array) -> void:
	note.text = message
	confirm_button.disabled = not ready
	markers = outlines
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	for zone in zones:
		var button := Button.new()
		button.text = ("ENEMY " if zone.owner == 1 else "YOUR ") + zone.lane.to_upper() + " GUARDS"
		button.pressed.connect(func() -> void: zone_selected.emit(zone.owner, zone.lane))
		choices.add_child(button)
	show()
	queue_redraw()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	for marker in markers:
		if not is_instance_valid(marker.control):
			continue
		var rect: Rect2 = get_global_transform_with_canvas().affine_inverse() * marker.control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, marker.control.size)
		draw_rect(rect.grow(4), Color("efc968") if marker.selected else Color("72cddd"), false, 3)
