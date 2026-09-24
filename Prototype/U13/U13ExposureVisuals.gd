extends RefCounted

const COLOR = Color("e4a275")

static func active(unit: Dictionary) -> bool:
	var a: Dictionary = unit.get("attributes", {})
	return int(a.get("dotra_exposed_until_tick", 0)) > 0 and a.get("visual_exposed", true) and a.get("hp", 0) > 0 and not a.get("hidden", false)

static func draw(view: Control, unit: Dictionary, center: Vector2, height: float, ceiling: float) -> void:
	if not active(unit): return
	var at: Vector2 = center + Vector2(20.0, -height - 10.0)
	at.y = maxf(ceiling + 5.0, at.y)
	var shield := PackedVector2Array([at + Vector2(-6, -5), at + Vector2(0, -7), at + Vector2(6, -5), at + Vector2(5, 3), at + Vector2(0, 7), at + Vector2(-5, 3), at + Vector2(-6, -5)])
	view.draw_colored_polygon(shield, Color("29140f"))
	view.draw_polyline(shield, COLOR, 1.7, true)
	view.draw_polyline(PackedVector2Array([at + Vector2(1, -6), at + Vector2(-2, -1), at + Vector2(2, 1), at + Vector2(-1, 6)]), COLOR, 1.7, true)
