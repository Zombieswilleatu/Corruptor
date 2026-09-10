extends ColorRect

const ShaderSource = preload("res://Prototype/U13/U13Paradox.gdshader")
var circle: Rect2
var bounds: Rect2
var strength: float = 0.0
var swirl: float = 2.5
var chaos: float = 0.0
var phase: float = 0.0
var color_depth: float = 0.25
var glitch: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = ShaderSource
	material = shader_material
	hide()


# Rectangles are in viewport coordinates, never scene/world units.
func present(area: Rect2, clip: Rect2, amount: float, distortion: float = 2.5, disorder: float = 0.0) -> void:
	circle = area
	bounds = clip
	strength = amount
	swirl = distortion
	chaos = disorder
	visible = amount > 0.0 and area.size.x > 0 and area.size.y > 0
	_sync()


func _process(delta: float) -> void:
	phase += delta
	if visible:
		_sync()


func _sync() -> void:
	if material == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	material.set_shader_parameter("center_uv", circle.get_center() / viewport_size)
	material.set_shader_parameter("radius_uv", circle.size * 0.5 / viewport_size)
	material.set_shader_parameter("clip_uv", Vector4(bounds.position.x / viewport_size.x, bounds.position.y / viewport_size.y, bounds.end.x / viewport_size.x, bounds.end.y / viewport_size.y))
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("swirl", swirl)
	material.set_shader_parameter("chaos", chaos)
	material.set_shader_parameter("phase", phase)
	material.set_shader_parameter("color_depth", color_depth)
	material.set_shader_parameter("glitch", glitch)
