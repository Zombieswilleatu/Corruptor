extends "res://Prototype/U13/U13WebPlacement.gd"

const Orbs = preload("res://Scripts/Sim/U13GravityOrbs.gd")
var battlefield: Control


func _ready() -> void:
	super._ready()
	radius_fp = Orbs.ATTRACTION_FP
	confirm_button.text = "PLACE GRAVITY ORB"


func lane_rect(lane: String) -> Rect2:
	if battlefield == null:
		return super.lane_rect(lane)
	return get_global_transform().affine_inverse() * battlefield.get_global_transform() * battlefield.travel_rect(lane)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(24, 45), "GRAVITY ORB · Click a lane, drag to adjust, then confirm. Pulls BOTH armies. Active 2 rounds.", HORIZONTAL_ALIGNMENT_CENTER, size.x - 48, 20, Color("dab8ef"))
	for lane in ["Lord", "Castle"]:
		draw_rect(lane_rect(lane), Color("bc8ede"), false, 2)
	if placed:
		for radius in [Orbs.ATTRACTION_FP, Orbs.DESTRUCTION_FP]:
			var area: Rect2 = Visuals.region_rect(lane_rect(target.lane), target.field_position, radius)
			var points := PackedVector2Array()
			for index in range(65):
				var angle: float = TAU * float(index) / 64.0
				points.append(area.get_center() + Vector2(cos(angle), sin(angle)) * area.size * 0.5)
			draw_colored_polygon(points, Color(0.6, 0.3, 0.8, 0.16 if radius == Orbs.ATTRACTION_FP else 0.65))
			draw_polyline(points, Color("ce94ef"), 2, true)
