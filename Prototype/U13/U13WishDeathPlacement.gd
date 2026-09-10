extends "res://Prototype/U13/U13GravityPlacement.gd"
func _ready() -> void:
	super._ready()
	radius_fp = preload("res://Scripts/Sim/U13Wishmaster.gd").DEATH_RADIUS
	confirm_button.text = "WISH FOR DEATH"
func _draw() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(24, 45), "WISH FOR DEATH · Destroys BOTH armies inside the circle after combat.", HORIZONTAL_ALIGNMENT_CENTER, size.x - 48, 20, Color("dab8ef"))
	for lane in ["Lord", "Castle"]:
		draw_rect(lane_rect(lane), Color("bc8ede"), false, 2)
	if placed:
		var area: Rect2 = Visuals.region_rect(lane_rect(target.lane), target.field_position, radius_fp)
		var points := PackedVector2Array()
		for index in range(65):
			var angle: float = TAU * index / 64.0
			points.append(area.get_center() + Vector2(cos(angle), sin(angle)) * area.size * 0.5)
		draw_colored_polygon(points, Color(0.5, 0.15, 0.7, 0.35))
		draw_polyline(points, Color("ce94ef"), 2, true)
