# UI2_DOMAIN_CROP_VIEW_V1
# UI2_DOMAIN_CROP_VIEW_TONED_V2
# UI2_DOMAIN_CROP_VIEW_EXPLICIT_CAMERA_V3
extends Control

# UI2_DOMAIN_CAMERA_DIAGNOSTIC_V7_13
var _domain_debug_printed: bool = false


var source_texture: Texture2D = null

var normalized_region := Rect2(
	0.0,
	0.0,
	1.0,
	1.0
)

var _camera_mode: bool = false
var _camera_pan := Vector2(
	0.5,
	0.5
)
var _camera_zoom: float = 1.0


func _install_tone_material(
	brightness: float,
	contrast: float,
	saturation: float,
	edge_vignette: float,
	center_band_dim: float
) -> void:
	var shader := Shader.new()
	shader.code = (
		"shader_type canvas_item;\n"
		+ "\n"
		+ "uniform float brightness = 1.0;\n"
		+ "uniform float contrast = 1.0;\n"
		+ "uniform float saturation = 1.0;\n"
		+ "uniform float edge_vignette = 0.0;\n"
		+ "uniform float center_band_dim = 0.0;\n"
		+ "\n"
		+ "void fragment() {\n"
		+ "\tvec4 c = texture(TEXTURE, UV);\n"
		+ "\tfloat luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n"
		+ "\tvec3 toned = mix(vec3(luma), c.rgb, saturation);\n"
		+ "\ttoned = (toned - vec3(0.5)) * contrast + vec3(0.5);\n"
		+ "\ttoned *= brightness;\n"
		+ "\tvec2 centered_uv = UV - vec2(0.5);\n"
		+ "\tfloat edge = smoothstep(0.28, 0.72, length(centered_uv));\n"
		+ "\tfloat center_band = 1.0 - smoothstep(0.05, 0.42, abs(centered_uv.x));\n"
		+ "\ttoned *= 1.0 - edge * edge_vignette - center_band * center_band_dim;\n"
		+ "\tCOLOR = vec4(max(toned, vec3(0.0)), c.a);\n"
		+ "}\n"
	)

	var material_instance := ShaderMaterial.new()
	material_instance.shader = shader
	material_instance.set_shader_parameter(
		"brightness",
		brightness
	)
	material_instance.set_shader_parameter(
		"contrast",
		contrast
	)
	material_instance.set_shader_parameter(
		"saturation",
		saturation
	)
	material_instance.set_shader_parameter(
		"edge_vignette",
		edge_vignette
	)
	material_instance.set_shader_parameter(
		"center_band_dim",
		center_band_dim
	)
	material = material_instance


func setup(
	texture: Texture2D,
	region: Rect2,
	brightness: float = 1.0,
	contrast: float = 1.0,
	saturation: float = 1.0,
	edge_vignette: float = 0.0,
	center_band_dim: float = 0.0
) -> void:
	source_texture = texture
	normalized_region = region
	_camera_mode = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_install_tone_material(
		brightness,
		contrast,
		saturation,
		edge_vignette,
		center_band_dim
	)

	set_process(false)
	queue_redraw()


func setup_camera(
	texture: Texture2D,
	pan: Vector2,
	zoom: float,
	brightness: float = 1.0,
	contrast: float = 1.0,
	saturation: float = 1.0,
	edge_vignette: float = 0.0,
	center_band_dim: float = 0.0
) -> void:
	source_texture = texture
	_camera_mode = true
	_camera_pan = Vector2(
		clampf(pan.x, 0.0, 1.0),
		clampf(pan.y, 0.0, 1.0)
	)
	_camera_zoom = maxf(
		0.05,
		zoom
	)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_install_tone_material(
		brightness,
		contrast,
		saturation,
		edge_vignette,
		center_band_dim
	)

	set_process(false)
	queue_redraw()


func _notification(
	what: int
) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _camera_source_rect(
	texture_size: Vector2
) -> Rect2:
	var dest_aspect: float = (
		size.x
		/ maxf(
			1.0,
			size.y
		)
	)

	# Resolution-independent zoom:
	# zoom 1.0 = full texture width,
	# zoom 2.0 = half texture width,
	# zoom 3.0 = one-third texture width.
	var source_width: float = (
		texture_size.x
		/ _camera_zoom
	)
	var source_height: float = (
		source_width
		/ dest_aspect
	)

	# If the requested width-derived camera is taller than the texture,
	# clamp by height instead while preserving destination aspect.
	if source_height > texture_size.y:
		source_height = texture_size.y
		source_width = (
			source_height
			* dest_aspect
		)

	var source_size := Vector2(
		minf(
			source_width,
			texture_size.x
		),
		minf(
			source_height,
			texture_size.y
		)
	)

	var center := Vector2(
		_camera_pan.x * texture_size.x,
		_camera_pan.y * texture_size.y
	)

	var source_pos := (
		center
		- source_size * 0.5
	)

	source_pos.x = clampf(
		source_pos.x,
		0.0,
		maxf(
			0.0,
			texture_size.x
			- source_size.x
		)
	)
	source_pos.y = clampf(
		source_pos.y,
		0.0,
		maxf(
			0.0,
			texture_size.y
			- source_size.y
		)
	)

	return Rect2(
		source_pos,
		source_size
	)


func _normalized_source_rect(
	texture_size: Vector2
) -> Rect2:
	var source_rect := Rect2(
		Vector2(
			normalized_region.position.x
			* texture_size.x,
			normalized_region.position.y
			* texture_size.y
		),
		Vector2(
			normalized_region.size.x
			* texture_size.x,
			normalized_region.size.y
			* texture_size.y
		)
	)

	var dest_aspect: float = (
		size.x
		/ maxf(
			1.0,
			size.y
		)
	)
	var source_aspect: float = (
		source_rect.size.x
		/ maxf(
			1.0,
			source_rect.size.y
		)
	)

	if source_aspect > dest_aspect:
		var desired_width: float = (
			source_rect.size.y
			* dest_aspect
		)
		source_rect.position.x += (
			source_rect.size.x
			- desired_width
		) * 0.5
		source_rect.size.x = desired_width
	else:
		var desired_height: float = (
			source_rect.size.x
			/ dest_aspect
		)
		source_rect.position.y += (
			source_rect.size.y
			- desired_height
		) * 0.5
		source_rect.size.y = desired_height

	return source_rect


func _draw() -> void:
	if source_texture == null:
		return

	if size.x <= 1.0 or size.y <= 1.0:
		return

	var texture_size := Vector2(
		float(source_texture.get_width()),
		float(source_texture.get_height())
	)

	var source_rect: Rect2 = (
		_camera_source_rect(
			texture_size
		)
		if _camera_mode
		else _normalized_source_rect(
			texture_size
		)
	)

	if not _domain_debug_printed:
		_domain_debug_printed = true
		print(
			"DOMAIN DEBUG path=",
			get_path(),
			" mode=",
			_camera_mode,
			" size=",
			size,
			" pan=",
			_camera_pan,
			" zoom=",
			_camera_zoom,
			" tex=",
			texture_size,
			" src=",
			source_rect
		)

	draw_texture_rect_region(
		source_texture,
		Rect2(
			Vector2.ZERO,
			size
		),
		source_rect
	)
