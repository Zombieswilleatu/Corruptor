extends RefCounted

const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
var texture: Texture2D
# Only the knife in frame zero. Reward/coin frames are never sampled.
const KNIFE_CROP: Rect2 = Rect2(0, 245, 409, 160)


static func point(rect: Rect2, attributes: Dictionary) -> Vector2:
	return Vector2(rect.position.x + rect.size.x * float(attributes.y_fp) / 600.0,
		lerpf(rect.end.y, rect.position.y, float(attributes.x_fp) / 2400.0))


func draw(canvas: Control, shots: Array) -> void:
	if shots.is_empty():
		return
	if texture == null:
		texture = Art.texture("res://ConceptImages/Sprites/GemDagger/GemDagger.png")
	for shot in shots:
		var rect: Rect2 = canvas.travel_rect(shot.lane)
		var source: Vector2 = point(rect, shot.source)
		var target: Vector2 = point(rect, shot.target)
		var center: Vector2 = source.lerp(target, float(shot.weight))
		var direction: Vector2 = (target - source).normalized()
		canvas.draw_line(center - direction * 12, center, Color(0.85, 0.92, 1.0, 0.5), 1.5, true)
		canvas.draw_set_transform(center, direction.angle())
		if texture != null:
			canvas.draw_texture_rect_region(texture, Rect2(-10, -4, 20, 8), KNIFE_CROP)
		else:
			canvas.draw_line(Vector2(-7, 0), Vector2(7, 0), Color.WHITE, 2.0, true)
		canvas.draw_set_transform(Vector2.ZERO)
