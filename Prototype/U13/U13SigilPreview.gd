extends Control

signal close_requested
signal main_menu_requested
var embedded: bool = false
const Overlay = preload("res://Prototype/U13/U13SigilOverlay.gd")
var overlays: Array = []
var status: Label

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("171b23")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 30
	column.offset_top = 25
	column.offset_right = -30
	column.offset_bottom = -25
	column.add_theme_constant_override("separation", 24)
	add_child(column)
	var title := Label.new()
	title.text = "Sigils · Fresh / Decaying"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	for entry in [["Fresh", "fresh"], ["Decaying", "flipped"], ["Expired", ""]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(_set_state.bind(entry[1]))
		buttons.add_child(button)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func():
		if embedded:
			close_requested.emit()
		else:
			get_tree().quit())
	buttons.add_child(close)
	status = Label.new()
	status.text = "Click a card through either overlay. Resize the window to check the zone fit."
	column.add_child(status)
	var zones := HBoxContainer.new()
	zones.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zones.add_theme_constant_override("separation", 36)
	column.add_child(zones)
	for lane in ["Lord", "Castle guards"]:
		var zone := PanelContainer.new()
		zone.custom_minimum_size = Vector2(240, 280)
		zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zones.add_child(zone)
		var center := CenterContainer.new()
		zone.add_child(center)
		var card := Button.new()
		card.text = lane + "\nClick to inspect"
		card.custom_minimum_size = Vector2(140, 180)
		card.pressed.connect(func(): status.text = lane + " card clicked through Sigil.")
		center.add_child(card)
		var overlay = Overlay.new()
		zone.add_child(overlay)
		overlays.append(overlay)
	_set_state("fresh")

func _set_state(value: String) -> void:
	for overlay in overlays:
		overlay.set_state(value)
