extends "res://Prototype/U13/U13VisualPreview.gd"

const Visuals = preload("res://Prototype/U13/U13WebVisuals.gd")
const SpatialInput = preload("res://Prototype/U13/U13SpatialInput.gd")
var visuals = Visuals.new()
var radius_fp: int = 270
var position_fp: Dictionary = {"x_fp": 1200, "y_fp": 300}
var fading: bool = false
var snare_active: bool = true
var radius_label: Label
var selected_lane: String = "Lord"


func _ready() -> void:
	var controls := HFlowContainer.new()
	controls.position = Vector2(25, 55)
	controls.size.x = maxf(600.0, size.x - 50.0)
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


# Both lanes share one scale: 600 wide and 2400 long in canonical units.
func _lane_rect(lane: String = "Lord") -> Rect2:
	var height: float = minf(maxf(320.0, size.y - 255.0), maxf(320.0, (size.x - 420.0) * 2.0))
	var width: float = height / 4.0
	return Rect2(35.0 + (width if lane == "Castle" else 0.0), 180, width, height)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for lane in ["Lord", "Castle"]:
			var target: Dictionary = SpatialInput.target_at(event.position, _lane_rect(lane), lane)
			if not target.is_empty():
				selected_lane = lane
				position_fp = target.field_position
				accept_event()
				break


func _process(delta: float) -> void:
	visuals.warm_next()
	visuals.advance(delta)
	if radius_label != null:
		radius_label.text = (
			"Radius %d · %.0f%% of ONE lane" % [radius_fp, float(radius_fp) * 200.0 / 600.0]
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
	draw_string(font, Vector2(25, 125), "Click either lane to move Web. Radius changes this preview only.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var lord_lane: Rect2 = _lane_rect("Lord")
	var castle_lane: Rect2 = _lane_rect("Castle")
	var field: Rect2 = lord_lane.merge(castle_lane)
	for lane in ["Lord", "Castle"]:
		var rect: Rect2 = _lane_rect(lane)
		draw_rect(rect, Color("253128") if lane == "Lord" else Color("202d34"))
		draw_string(font, rect.position - Vector2(0, 12), lane.to_upper() + " LANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var area: Rect2 = Visuals.region_rect(_lane_rect(selected_lane), position_fp, radius_fp)
	# Show oversized art across both lanes for tuning, not as a gameplay claim.
	visuals.draw_area(self, area, field, fading)
	for lane in ["Lord", "Castle"]:
		var rect: Rect2 = _lane_rect(lane)
		draw_rect(rect, Color("786a4a"), false, 2)
		for index in range(3):
			var anchor: Vector2 = rect.position + Vector2(rect.size.x * float(index + 1) / 4.0, rect.size.y * (0.40 + float(index) * 0.10))
			draw_circle(anchor, 10, Color("324d59"))
			draw_arc(anchor, 12, 0, TAU, 32, Color("72cddd"), 2, true)
	draw_string(font, Vector2(field.position.x, field.end.y + 25), "Blue dots = reference Marchers (stationary)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("72cddd"))
	var guard_x: float = field.end.x + 45.0
	var row_width: float = minf(330.0, maxf(210.0, size.x - guard_x - 25.0))
	var card_width: float = row_width / 3.6
	var card_height: float = card_width * 1.6
	for index in range(2):
		var guards := Rect2(guard_x, 210 + index * (card_height + 95.0), row_width, card_height)
		draw_string(font, guards.position - Vector2(0, 42), "LORD GUARDS" if index == 0 else "SHARED CASTLE GUARDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
		var middle: Vector2 = guards.get_center()
		for slot in range(3):
			var center: Vector2 = middle + Vector2(float(slot - 1) * (card_width + 12.0), 0)
			var card := Rect2(center - Vector2(card_width, card_height) * 0.5, Vector2(card_width, card_height))
			draw_rect(card, Color("22211b"))
			draw_rect(card, Color("72cddd"), false, 2)
		if snare_active:
			# Square art centered on the middle physical card, not panel padding.
			var diameter: float = card_height + 50.0
			var snare_area := Rect2(middle - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)
			visuals.draw_area(self, snare_area, Rect2(Vector2.ZERO, size), false, 0.0, false)
	draw_string(font, Vector2(25, size.y - 20), "Cross-lane overlap is a size preview. Gameplay Web still affects its selected lane.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c9bfa7"))
