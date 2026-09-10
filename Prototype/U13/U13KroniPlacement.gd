extends "res://Prototype/U13/U13WebPlacement.gd"

var battlefield: Control
var owner_id: int = 0


func _ready() -> void:
	super._ready()
	confirm_button.text = "PLACE KRONI"


func lane_rect(lane: String) -> Rect2:
	if battlefield == null:
		return super.lane_rect(lane)
	return get_global_transform().affine_inverse() * battlefield.get_global_transform() * battlefield.travel_rect(lane)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Only the starting footprint is public. Never preview a launch direction.
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(15, 15, size.x - 30, 82), Color("191521"))
	draw_string(font, Vector2(30, 46), "RAVENOUS · PLACE HIS START", HORIZONTAL_ALIGNMENT_CENTER, size.x - 60, 24, Color("eac16c"))
	draw_string(font, Vector2(30, 77), "Choose a horizontal position on your edge. Drag left/right to adjust. Launch angle is random.", HORIZONTAL_ALIGNMENT_CENTER, size.x - 60, 16)
	for lane in ["Lord", "Castle"]:
		var edge: Rect2 = lane_rect(lane)
		var y: float = edge.end.y if owner_id == 0 else edge.position.y
		draw_line(Vector2(edge.position.x, y), Vector2(edge.end.x, y), Color("eac16c"), 5)
	if not placed:
		return
	var center_rect: Rect2 = Visuals.region_rect(lane_rect(target.lane), target.field_position, radius_fp)
	var center: Vector2 = center_rect.get_center()
	# Clip each half to its lane while keeping the footprint continuous across lanes.
	var lateral: float = float(target.field_position.y_fp) + (600.0 if target.lane == "Castle" else 0.0)
	for lane in ["Lord", "Castle"]:
		var rect: Rect2 = lane_rect(lane)
		var points := PackedVector2Array()
		for index in range(97):
			var angle: float = TAU * float(index) / 96.0
			var y: float = lateral + cos(angle) * radius_fp - (600.0 if lane == "Castle" else 0.0)
			var x: float = float(target.field_position.x_fp) + sin(angle) * radius_fp
			if y >= 0 and y <= 600 and x >= 0 and x <= 2400:
				points.append(rect.position + Vector2(y / 600.0 * rect.size.x, (1.0 - x / 2400.0) * rect.size.y))
			elif points.size() > 1:
				draw_polyline(points, Color("eac16c"), 3, true)
				points = PackedVector2Array()
			else:
				points = PackedVector2Array()
		if points.size() > 1:
			draw_polyline(points, Color("eac16c"), 3, true)
	draw_circle(center, 6, Color("eac16c"))


func _place_at(point: Vector2) -> bool:
	for lane in ["Lord", "Castle"]:
		var rect: Rect2 = lane_rect(lane)
		if point.y < rect.position.y - 40 or point.y > rect.end.y + 40:
			continue
		var proposed: Dictionary = SpatialInput.target_at(Vector2(point.x, rect.get_center().y), rect, lane)
		if proposed.is_empty():
			continue
		proposed.field_position.x_fp = 0 if owner_id == 0 else 2400
		target = proposed
		placed = true
		confirm_button.disabled = false
		queue_redraw()
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed and _place_at(event.position)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_place_at(event.position)
			accept_event()
		else:
			dragging = false
