extends RefCounted

const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")

static func footprint(canvas: Control, row: Dictionary) -> Rect2:
	var a: Dictionary = row.attributes
	var p: Vector2 = canvas._monster_point(a)
	var width: float = canvas.travel_rect(a.lane).size.x * 0.5 - 4 if a.structure == "Wall" else 26.0
	return Rect2(p - Vector2(width * 0.5, 23 if a.structure == "Wall" else 40), Vector2(width, 30 if a.structure == "Wall" else 47))

func draw(canvas: Control, lane: String, structures: Array, units: Array) -> void:
	for unit in units:
		var a: Dictionary = unit.attributes
		if a.lane != lane or not a.has("wright_site") or a.get("wright_built", false): continue
		var point: Dictionary = Fort.site_point(unit.owner, a.wright_site)
		point["lane"] = lane
		point["structure"] = "Tower" if a.wright_site == 2 else "Wall"
		var rect: Rect2 = footprint(canvas, {"attributes": point})
		var tint: Color = canvas.BLUE if unit.owner == 0 else canvas.RED
		canvas.draw_rect(rect, Color(0.12, 0.11, 0.09, 0.45))
		canvas.draw_rect(rect, Color(tint, 0.35), false, 1)
		var progress: float = float(a.get("wright_progress", 0)) / float(Fort.BUILD_TICKS)
		canvas.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 4), Vector2(rect.size.x * progress, 3)), Color("c8af74"))
	for row in structures:
		var a: Dictionary = row.attributes
		if a.lane != lane: continue
		var rect: Rect2 = footprint(canvas, row)
		var tint: Color = canvas.BLUE if row.owner == 0 else canvas.RED
		canvas.draw_rect(rect.grow(2), Color(0.02, 0.02, 0.02, 0.75))
		if a.structure == "Wall":
			canvas.draw_rect(rect, Color("393631"))
			for course in range(3):
				for block in range(4):
					var width: float = rect.size.x * 0.25
					var stone := Rect2(rect.position + Vector2(block * width + 1, course * 8 + 1), Vector2(width - 2, 7))
					canvas.draw_rect(stone, Color("696150") if (course + block) % 2 == 0 else Color("514b40"))
			canvas.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("aaa087"), 2)
		else:
			canvas.draw_rect(Rect2(rect.position + Vector2(3, 10), Vector2(20, 31)), Color("514b40"))
			canvas.draw_rect(Rect2(rect.position + Vector2(5, 12), Vector2(5, 25)), Color("817760"))
			canvas.draw_rect(Rect2(rect.position, Vector2(26, 12)), Color("756950"))
			for tooth in range(3): canvas.draw_rect(Rect2(rect.position + Vector2(tooth * 10, -5), Vector2(6, 6)), Color("afa082"))
			canvas.draw_rect(Rect2(rect.position + Vector2(10, 2), Vector2(6, 7)), Color("171919"))
			canvas.draw_circle(rect.position + Vector2(13, 5), 2.5, Color("d4e6ea"))
		# Same HP/Armor palette as the unit rings; ownership stays a quiet baseline.
		canvas.draw_line(rect.position + Vector2(0, rect.size.y - 1), rect.end - Vector2(0, 1), Color(tint, 0.7), 2)
		canvas.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y + 3), Vector2(rect.size.x * float(a.hp) / float(a.max_hp), 2)), canvas.HEALTH_RING_COLOR)
		if a.armor > 0: canvas.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y + 6), Vector2(rect.size.x * float(a.armor) / float(a.max_armor), 2)), canvas.ARMOR_RING_COLOR)
