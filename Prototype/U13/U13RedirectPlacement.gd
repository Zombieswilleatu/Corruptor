extends "res://Prototype/U13/U13WebPlacement.gd"

const Content = preload("res://Scripts/Sim/U13Odradek.gd")
var marchers: Array = []


func _ready() -> void:
	super._ready()
	radius_fp = Content.REDIRECT_RADIUS_FP
	confirm_button.text = "REWRITE THE PATH"


func _process(_delta: float) -> void:
	queue_redraw()


func _point(lane: String, a: Dictionary) -> Vector2:
	var rect: Rect2 = lane_rect(lane)
	return (
		rect.position
		+ Vector2(float(a.y_fp) / 600.0 * rect.size.x, (1.0 - float(a.x_fp) / 2400.0) * rect.size.y)
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101019"))
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(25, 36),
		"REDIRECT · REWRITE THE PATH",
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 50,
		24,
		Color("d9ccf2")
	)
	draw_string(
		font,
		Vector2(25, 68),
		"Click to place, drag to adjust, then confirm. Both sides move to the opposite lane.",
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 50,
		16
	)
	for lane in Content.Space.LANES:
		var rect: Rect2 = lane_rect(lane)
		draw_rect(rect, Color("222235"))
		draw_rect(rect, Color("9380b3"), false, 2)
		draw_string(
			font,
			rect.position - Vector2(0, 12),
			lane.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			16
		)
		for progress in [0, 600, 1200, 1800, 2400]:
			var y: float = rect.end.y - float(progress) / 2400.0 * rect.size.y
			draw_line(
				Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.7, 0.65, 0.9, 0.15)
			)
	var affected: int = 0
	for unit in marchers:
		var a: Dictionary = unit.attributes
		var point: Vector2 = _point(a.lane, a)
		var color: Color = Color("79d5ff") if unit.owner == 0 else Color("f39b91")
		draw_circle(point, 7, color)
		var inside: bool = (
			placed
			and (
				Content
				. Space
				. contains(
					Content.Space.circle_region(target.lane, target.field_position, radius_fp),
					a.lane,
					{"x_fp": a.x_fp, "y_fp": a.y_fp}
				)
				. inside
			)
		)
		if inside:
			affected += 1
			var other: String = "Castle" if a.lane == "Lord" else "Lord"
			var destination: Vector2 = _point(other, a)
			draw_line(point, destination, Color(color, 0.45), 2)
			draw_arc(destination, 9, 0, TAU, 32, color, 2)
	if placed:
		var area: Rect2 = Visuals.region_rect(
			lane_rect(target.lane), target.field_position, radius_fp
		)
		draw_circle(area.get_center(), area.size.x * 0.5, Color(0.66, 0.46, 1.0, 0.16))
		draw_arc(area.get_center(), area.size.x * 0.5, 0, TAU, 96, Color("d9b6ff"), 3, true)
	draw_string(
		font,
		Vector2(25, size.y - 86),
		"%d currently inside · Blue: yours · Coral: enemy · Outlines: destinations" % affected,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 50,
		15
	)
	draw_string(
		font,
		Vector2(25, size.y - 108),
		"Preview includes earlier queued Redirects. Membership is checked again after combat.",
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 50,
		14,
		Color("b8b0ca")
	)
