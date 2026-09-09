extends "res://Prototype/U13/U13VisualPreview.gd"

const Visuals = preload("res://Prototype/U13/U13WebVisuals.gd")
const SpatialInput = preload("res://Prototype/U13/U13SpatialInput.gd")
var visuals = Visuals.new()
var radius_fp: int = 270
var position_fp: Dictionary = {"x_fp": 1200, "y_fp": 300}
var fading: bool = false
var snare_active: bool = true
var radius_label: Label


func _ready() -> void:
	var controls := HBoxContainer.new()
	controls.position = Vector2(25, 55)
	controls.add_theme_constant_override("separation", 14)
	add_child(controls)
	radius_label = Label.new()
	controls.add_child(radius_label)
	var slider := HSlider.new()
	slider.min_value = 60
	slider.max_value = 1200
	slider.step = 10
	slider.value = radius_fp
	slider.custom_minimum_size.x = 220
	slider.value_changed.connect(func(value: float) -> void: radius_fp = int(value))
	controls.add_child(slider)
	var stage := CheckButton.new()
	stage.text = "Fading round"
	stage.toggled.connect(func(enabled: bool) -> void: fading = enabled)
	controls.add_child(stage)
	var snare := CheckButton.new()
	snare.text = "Snare marker"
	snare.button_pressed = true
	snare.toggled.connect(func(enabled: bool) -> void: snare_active = enabled)
	controls.add_child(snare)
	var close := Button.new()
	close.text = "Back / Exit"
	close.pressed.connect(_close_preview.bind(0))
	controls.add_child(close)


func _lane_rect() -> Rect2:
	return Rect2(45, 155, 260, maxf(350.0, size.y - 190.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target: Dictionary = SpatialInput.target_at(event.position, _lane_rect(), "Lord")
		if not target.is_empty():
			position_fp = target.field_position
			accept_event()


func _process(delta: float) -> void:
	visuals.warm_next()
	visuals.advance(delta)
	if radius_label != null:
		radius_label.text = (
			"Radius %d · width %.0f%%" % [radius_fp, float(radius_fp) * 200.0 / 600.0]
		)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("111511"))
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(25, 32),
		"ORIAS · WEB & SNARE VISUAL PREVIEW",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		22,
		Color("e6d5af")
	)
	draw_string(
		font,
		Vector2(25, 125),
		"Click the lane to move Web. Radius control changes this preview only.",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16
	)
	var lane: Rect2 = _lane_rect()
	draw_rect(lane, Color("253128"))
	draw_rect(lane, Color("786a4a"), false, 2)
	var area: Rect2 = Visuals.region_rect(lane, position_fp, radius_fp)
	visuals.draw_area(self, area, lane, fading)
	for index in range(3):
		var anchor := Vector2(
			lane.position.x + 65.0 * float(index + 1), lane.get_center().y + 60.0 * float(index - 1)
		)
		draw_circle(anchor, 14, Color("324d59"))
		draw_arc(anchor, 16, 0, TAU, 32, Color("72cddd"), 2, true)
	for index in range(2):
		var guards := Rect2(370, 210 + index * 250, maxf(250.0, size.x - 410.0), 170)
		draw_string(
			font,
			guards.position - Vector2(0, 18),
			"LORD GUARDS" if index == 0 else "SHARED CASTLE GUARDS",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			18
		)
		for slot in range(3):
			var card := Rect2(
				guards.position + Vector2(float(slot) * 98.0 + 8.0, 12), Vector2(80, 138)
			)
			draw_rect(card, Color("22211b"))
			draw_rect(card, Color("72cddd"), false, 2)
		if snare_active:
			visuals.draw_area(self, guards, guards, false, float(index) * 0.3)
	draw_string(
		font,
		Vector2(370, 760),
		"Snare artwork preview; Guard-placement rules are not enabled by this scene.",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color("c9bfa7")
	)
