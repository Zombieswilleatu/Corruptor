extends "res://Prototype/U13/U13VultureProjectile.gd"

func draw(canvas: Control, shots: Array) -> void:
	if shots.is_empty():
		return
	if texture == null:
		texture = Art.texture("res://ConceptImages/Sprites/GemDagger/GemDagger.png")
	for shot in shots:
		var source: Vector2 = canvas._attack_point(shot.source, shot.get("source_id", ""), shot.get("source_owner", 0))
		var target: Vector2 = canvas._attack_point(shot.target, shot.get("target_id", ""), shot.get("target_owner", 1))
		var impact_only: bool = shot.get("impact_only", false)
		var center: Vector2 = target if impact_only else source.lerp(target, float(shot.weight))
		var alpha: float = 1.0 - float(shot.weight) if impact_only else 1.0
		var direction: Vector2 = (target - source).normalized()
		canvas.draw_line(center - direction * 12, center, Color(0.85, 0.92, 1.0, 0.5 * alpha), 1.5, true)
		canvas.draw_set_transform(center, direction.angle())
		if texture != null:
			canvas.draw_texture_rect_region(texture, Rect2(-10, -4, 20, 8), KNIFE_CROP, Color(1, 1, 1, alpha))
		else:
			canvas.draw_line(Vector2(-7, 0), Vector2(7, 0), Color(1, 1, 1, alpha), 2.0, true)
		canvas.draw_set_transform(Vector2.ZERO)
