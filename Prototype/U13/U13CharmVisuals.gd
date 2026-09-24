extends RefCounted

# Status comes from the displayed replay frame, never a future simulation.
const COLOR = Color("f18eaf")
var age: float = 0.0

static func active(unit: Dictionary) -> bool:
	var a: Dictionary = unit.get("attributes", {})
	return a.has("charm_owner") and int(a.charm_owner) != int(unit.owner) and a.get("hp", 0) > 0 and not a.get("hidden", false)

static func heart(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(32):
		var t: float = TAU * float(i) / 32.0
		points.append(center + Vector2(pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2*t) - 2 * cos(3*t) - cos(4*t)) / 17.0) * radius)
	return points

func particles(unit: Dictionary, center: Vector2, height: float, ceiling: float) -> Array:
	if not active(unit): return []
	var result: Array = []
	var offset: float = float(absi(str(unit.id).hash()) % 101) / 101.0
	for i in range(3):
		var phase: float = fposmod(age * 0.75 + float(i) / 3.0 + offset, 1.0)
		var point: Vector2 = center + Vector2((float(i) - 1.0) * 10.0 + sin(phase * TAU) * 3.0, -height - 7.0 - phase * 17.0)
		point.y = maxf(ceiling, point.y)
		result.append({"center": point, "radius": 5.0 + sin(phase * PI), "alpha": 0.45 + 0.55 * sin(phase * PI)})
	return result

func draw(view: Control, unit: Dictionary, center: Vector2, height: float, ceiling: float) -> void:
	for particle in particles(unit, center, height, ceiling):
		var shape: PackedVector2Array = heart(particle.center, particle.radius)
		view.draw_colored_polygon(shape, Color(COLOR, particle.alpha))
		var outline: PackedVector2Array = shape.duplicate()
		outline.append(shape[0])
		view.draw_polyline(outline, Color(0.22, 0.05, 0.11, particle.alpha), 1.5, true)
		view.draw_circle(particle.center + Vector2(-1.8, -2.2), 1.0, Color(1.0, 0.85, 0.91, particle.alpha))
