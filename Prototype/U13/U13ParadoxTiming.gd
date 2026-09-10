extends RefCounted

# Shared by the real playback and standalone tweaker. No random game state.
static func envelope(progress: float) -> float:
	if progress >= 1.0:
		return 0.0
	if progress < 0.16:
		return [0.0, 0.45, 0.0, 0.8, 0.15, 1.0][mini(5, int(progress / 0.16 * 6))]
	if progress > 0.82:
		return [0.35, 1.0, 0.0, 0.65, 0.0, 0.25][mini(5, int((progress - 0.82) / 0.18 * 6))]
	return 1.0


static func transfer(progress: float) -> float:
	return 1.0 if progress >= 0.43 and progress < 0.63 else 0.0


static func edge_glitch(progress: float) -> float:
	return 1.0 if progress < 0.16 or progress > 0.82 else 0.0


static func draw_slices(canvas: CanvasItem, texture: Texture2D, destination: Rect2, source: Rect2, amount: float, tick: int) -> void:
	if texture == null:
		return
	if amount <= 0.0:
		canvas.draw_texture_rect_region(texture, destination, source)
		return
	for strip in range(8):
		if (strip + tick) % 5 == 0:
			continue
		var offset: float = float((strip * 7 + tick * 3) % 11 - 5) * amount * destination.size.x * 0.055
		var target := Rect2(destination.position + Vector2(offset, destination.size.y * strip / 8.0), Vector2(destination.size.x, destination.size.y / 8.0))
		var sample := Rect2(source.position + Vector2(0, source.size.y * strip / 8.0), Vector2(source.size.x, source.size.y / 8.0))
		canvas.draw_texture_rect_region(texture, target, sample, Color(1, 1, 1, 0.65 if (strip + tick) % 3 == 0 else 1.0))
