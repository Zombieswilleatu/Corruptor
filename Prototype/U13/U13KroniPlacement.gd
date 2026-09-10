extends "res://Prototype/U13/U13WebPlacement.gd"

var battlefield: Control


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
	draw_string(font, Vector2(30, 77), "Click either lane, drag to adjust, then confirm. His angle is random when he launches toward the enemy.", HORIZONTAL_ALIGNMENT_CENTER, size.x - 60, 16)
	for lane in ["Lord", "Castle"]:
		draw_rect(lane_rect(lane), Color("eac16c"), false, 2)
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
