extends RefCounted

const Shroud = preload("res://Scripts/Sim/U13DotraShroud.gd")
const COLOR = Color("c6b3f5")

static func active(unit: Dictionary) -> bool:
	var a: Dictionary = unit.get("attributes", {})
	return Shroud.active(a) and a.get("visual_shrouded", true) and a.get("hp", 0) > 0 and not a.get("hidden", false)

static func draw(view: Control, unit: Dictionary, center: Vector2, height: float, ceiling: float) -> void:
	if not active(unit): return
	var remaining: float = float(unit.attributes.get("visual_shroud_remaining", 1.0))
	var at: Vector2 = center + Vector2(-20.0, -height - 10.0)
	at.y = maxf(ceiling + 5.0, at.y)
	# A crossed eye and draining arc distinguish untargetability from Armor.
	view.draw_circle(at, 10.0, Color("211c30"))
	view.draw_arc(at, 10.0, -PI / 2.0, -PI / 2.0 + TAU * remaining, 32, COLOR, 1.6, true)
	view.draw_polyline(PackedVector2Array([at + Vector2(-7, 0), at + Vector2(-3, -4), at + Vector2(3, -4), at + Vector2(7, 0), at + Vector2(3, 4), at + Vector2(-3, 4), at + Vector2(-7, 0)]), COLOR, 1.4, true)
	view.draw_circle(at, 2.2, COLOR)
	view.draw_line(at + Vector2(-7, 7), at + Vector2(7, -7), Color("211c30"), 4.0, true)
	view.draw_line(at + Vector2(-7, 7), at + Vector2(7, -7), COLOR, 1.8, true)
	var mist := PackedVector2Array()
	for i in range(33):
		var angle: float = TAU * float(i) / 32.0
		mist.append(center + Vector2(cos(angle) * 19.0, sin(angle) * 7.0))
	view.draw_polyline(mist, Color(COLOR, 0.18 + remaining * 0.22), 2.0, true)
