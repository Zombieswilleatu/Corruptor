extends Control

const ConstructionShader = preload(
	"res://Prototype/UI2/Shaders/CastleConstructionProgress.gdshader"
)

# Presentation only: reuse one texture, with deterministic polygon pieces.
# No physics, generated textures, RNG stream or gameplay state is involved.
var texture: Texture2D
var construction: bool = false
var display_ratio: float = 1.0:
	set(value):
		display_ratio = value
		if construction and material is ShaderMaterial:
			(material as ShaderMaterial).set_shader_parameter("build_ratio", value)
		queue_redraw()
var _transition: Tween
var _fragments: Array = []


static func damage_band(integrity: int, maximum: int) -> int:
	if integrity * 3 > maximum * 2:
		return 0
	return 1 if integrity * 3 > maximum else 2


func bind_castle(image: Texture2D, attributes: Dictionary, previous: Dictionary = {}) -> void:
	texture = image
	if _fragments.is_empty():
		_build_fragments()
	construction = attributes.construction_state != "active"
	if construction:
		var progress_material := ShaderMaterial.new()
		progress_material.shader = ConstructionShader
		material = progress_material
	else:
		material = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var ratio: float = clampf(
		float(attributes.integrity) / maxf(1.0, float(attributes.max_integrity)), 0.0, 1.0
	)
	if _transition != null:
		_transition.kill()
	var prior: float = float(previous.get("ratio", ratio))
	display_ratio = prior if previous.get("construction", construction) == construction else ratio
	if not is_equal_approx(display_ratio, ratio):
		_transition = create_tween()
		(
			_transition
			. tween_property(self, "display_ratio", ratio, 0.65)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)
	else:
		queue_redraw()
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)


func _draw() -> void:
	if texture == null or size.x <= 0 or size.y <= 0:
		return
	var source: Vector2 = texture.get_size()
	var factor: float = minf(size.x / source.x, size.y / source.y)
	var dimensions: Vector2 = source * factor
	var rect := Rect2((size - dimensions) * 0.5, dimensions)
	if construction:
		# Reuse U12's broken-masonry reveal and architectural ghost unchanged.
		draw_texture_rect(texture, rect, false)
		return
	if display_ratio > 2.0 / 3.0:
		draw_texture_rect(texture, rect, false)
		return
	var collapse: float = clampf((2.0 / 3.0 - display_ratio) * 1.5, 0.0, 1.0)
	for index in range(_fragments.size()):
		_piece(_fragments[index], rect, collapse, index)


func _build_fragments() -> void:
	# Jagged seams rather than a uniform rectangular tile grid.
	var rows: Array = [
		[Vector2(0, 0), Vector2(0.34, 0), Vector2(0.68, 0), Vector2(1, 0)],
		[Vector2(0, 0.31), Vector2(0.28, 0.26), Vector2(0.74, 0.36), Vector2(1, 0.28)],
		[Vector2(0, 0.67), Vector2(0.39, 0.72), Vector2(0.63, 0.62), Vector2(1, 0.73)],
		[Vector2(0, 1), Vector2(0.32, 1), Vector2(0.70, 1), Vector2(1, 1)]
	]
	for row in range(3):
		for column in range(3):
			var a: Vector2 = rows[row][column]
			var b: Vector2 = rows[row][column + 1]
			var c: Vector2 = rows[row + 1][column + 1]
			var d: Vector2 = rows[row + 1][column]
			_fragments.append(PackedVector2Array([a, b, c]))
			_fragments.append(PackedVector2Array([a, c, d]))


func _piece(uv: PackedVector2Array, rect: Rect2, collapse: float, ordinal: int) -> void:
	var center: Vector2 = (uv[0] + uv[1] + uv[2]) / 3.0
	var destination: Vector2 = center.lerp(Vector2(0.5, 0.76), collapse * 0.32)
	destination.y += collapse * 0.08
	var angle: float = float(ordinal % 5 - 2) * collapse * 0.035
	var points := PackedVector2Array()
	for point in uv:
		var local: Vector2 = (
			((point - center) * rect.size).rotated(angle) * (0.985 - collapse * 0.06)
		)
		points.append(rect.position + destination * rect.size + local)
	var shade: float = 1.0 - collapse * (0.10 + float(ordinal % 3) * 0.04)
	draw_polygon(points, PackedColorArray([Color(shade, shade, shade)]), uv, texture)
