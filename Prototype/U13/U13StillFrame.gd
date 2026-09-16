extends RefCounted

# Reuse measured sheet crops, ground anchors, polygon masks and matte keys.
# Decode once when selecting a character; never process pixels while drawing.
static func from_sheet(texture: Texture2D, dimensions: Vector2, body: float,
		region: Rect2, ground: Vector2, polygon: PackedVector2Array = PackedVector2Array(),
		key: String = "") -> Dictionary:
	if texture == null:
		return {}
	var source := texture.get_image()
	var scale := texture.get_size() / dimensions
	var rect := Rect2i((region.position * scale).round(), (region.size * scale).round())
	rect = rect.intersection(Rect2i(Vector2i.ZERO, source.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return {}
	var image := source.get_region(rect)
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if not polygon.is_empty():
				var point := (Vector2(rect.position) + Vector2(x + 0.5, y + 0.5)) / scale
				if not Geometry2D.is_point_in_polygon(point, polygon):
					color.a = 0.0
			if key == "black":
				color.a *= smoothstep(0.008, 0.035, maxf(color.r, maxf(color.g, color.b)))
			elif key == "green":
				color.a *= 1.0 - smoothstep(0.10, 0.35, color.g - maxf(color.r, color.b))
				color.g = minf(color.g, maxf(color.r, color.b) + 0.04)
			image.set_pixel(x, y, color)
	return {"texture": ImageTexture.create_from_image(image),
		"anchor": ground * scale - Vector2(rect.position), "body": body * scale.y}
