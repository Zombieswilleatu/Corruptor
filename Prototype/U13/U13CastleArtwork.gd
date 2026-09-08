extends Control

const ConstructionShader = preload(
	"res://Prototype/UI2/Shaders/CastleConstructionProgress.gdshader"
)
const Fracture = preload("res://Prototype/U13/U13CastleFracture.gd")

# Presentation only: textured shards with cached gravity/contact poses.
# No live physics bodies, generated textures or gameplay state is involved.
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
		_fragments = Fracture.source()
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
			. tween_property(self, "display_ratio", ratio, 1.1)
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
	var stage: float = collapse * 3.0
	var lower: int = mini(int(floor(stage)) + 1, 4)
	var upper: int = mini(lower + 1, 4)
	var blend: float = stage - floor(stage)
	var first: Array = Fracture.pose(lower)
	var second: Array = Fracture.pose(upper)
	# A dark cavity behind separated faces makes the cracks readable at 124px.
	draw_rect(rect, Color("090807"))
	var polygons: Array = []
	for index in range(_fragments.size()):
		var points := PackedVector2Array()
		for vertex in range(3):
			var point: Vector2 = first[index][vertex].lerp(second[index][vertex], blend)
			points.append(rect.position + point * rect.size)
		polygons.append(points)
	# Draw all shadows before all faces so a later shard cannot paint its
	# shadow over a neighbouring face. Shadows are also kept in the container.
	var depth: float = maxf(1.0, rect.size.x * 0.012)
	for polygon in polygons:
		var shadow := PackedVector2Array()
		for point in polygon:
			shadow.append(
				Vector2(
					clampf(point.x + depth * 0.4, rect.position.x, rect.end.x),
					clampf(point.y + depth, rect.position.y, rect.end.y)
				)
			)
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.9))
	for index in range(polygons.size()):
		_piece(polygons[index], _fragments[index], rect, collapse, index)
	draw_rect(rect, Color("625234"), false, 1.0)


func _piece(
	points: PackedVector2Array, uv: PackedVector2Array, rect: Rect2, collapse: float, ordinal: int
) -> void:
	var shade: float = 1.0 - collapse * (0.12 + float(ordinal % 3) * 0.06)
	draw_polygon(points, PackedColorArray([Color(shade, shade, shade)]), uv, texture)
	var width: float = maxf(0.7, rect.size.x * 0.0035)
	for edge in range(points.size()):
		var a: Vector2 = points[edge]
		var b: Vector2 = points[(edge + 1) % points.size()]
		var direction: Vector2 = b - a
		var lit: bool = direction.x - direction.y > 0
		var color := Color(0.68, 0.59, 0.43, 0.75) if lit else Color(0.035, 0.025, 0.02, 0.95)
		draw_line(a, b, color, width, true)
