# UI2_SIEGE_ENGINE_BOMBARDMENT_FX_V1
# UI2_SIEGE_ENGINE_UNIFIED_ANIMATED_FX_V1
class_name UI2SiegeEngineBombardmentView
extends Control


const BALLISTA_BOLT: Texture2D = preload(
	"res://ConceptImages/Other/BallistaBolt.png"
)
const EXPLOSION: Texture2D = preload(
	"res://ConceptImages/Other/Explosion.png"
)


# The supplied sheets are explicit:
#   BallistaBolt.png = 8 frames, 8 x 1, left-to-right.
#   Explosion.png    = 8 frames, 4 x 2, row-major.
#   Shrapnel.png     = one debris image, spawned as several fragments.
const BOLT_COLUMNS: int = 8
const BOLT_ROWS: int = 1
const EXPLOSION_COLUMNS: int = 4
const EXPLOSION_ROWS: int = 2

const BOLT_FPS: float = 12.0
const EXPLOSION_FPS: float = 10.0

# Deliberate half-speed flight from the previous tuning pass.
const FLIGHT_SECONDS: float = 0.96

# Keep the bolt readable without letting the sheet's tall transparent cell
# make the projectile visually enormous.
# UI2_SIEGE_ENGINE_BOLT_READABILITY_V1
const BOLT_VISUAL_LENGTH: float = 150.0
const BOLT_VERTICAL_SQUASH: float = 1.0

# One large impact animation. The frame art itself supplies the bloom/fade.
const EXPLOSION_MIN_EXTENT: float = 185.0
const EXPLOSION_MAX_EXTENT: float = 320.0
const EXPLOSION_TARGET_SCALE: float = 1.55

const SHRAPNEL_SECONDS: float = 0.86

const SOURCE_EDGE_RATIO: float = 0.38
const TARGET_EDGE_RATIO: float = 0.10


var _bolt_frames: SpriteFrames = null
var _explosion_frames: SpriteFrames = null
var _shrapnel_texture: Texture2D = null
var _bolt_material: ShaderMaterial = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	z_index = 88
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	_bolt_frames = _build_bolt_frames()

	_explosion_frames = _build_grid_frames(
		EXPLOSION,
		EXPLOSION_COLUMNS,
		EXPLOSION_ROWS,
		"blast",
		EXPLOSION_FPS,
		false
	)

	# Runtime load avoids depending on a fresh Shrapnel.png Godot import.
	_shrapnel_texture = _load_runtime_texture(
		"res://ConceptImages/Other/Shrapnel.png"
	)

	_bolt_material = _make_bolt_material()


func play_bombardment(
	events: Array,
	human_board,
	enemy_board
) -> bool:
	if (
		_bolt_frames == null
		or _explosion_frames == null
		or human_board == null
		or enemy_board == null
	):
		return false

	var launched: bool = false

	for raw_event in events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event

		if not bool(
			event.get(
				"fired",
				false
			)
		):
			continue

		var shooter_id: int = int(
			event.get(
				"shooter_id",
				-1
			)
		)

		var target_name: String = String(
			event.get(
				"target_castle",
				""
			)
		)

		if (
			shooter_id not in [0, 1]
			or target_name.is_empty()
		):
			continue

		var source_board = (
			human_board
			if shooter_id == 0
			else enemy_board
		)

		var target_board = (
			enemy_board
			if shooter_id == 0
			else human_board
		)

		var source_rect: Rect2 = _castle_global_rect(
			source_board,
			"SiegeEngine"
		)

		var target_rect: Rect2 = _castle_global_rect(
			target_board,
			target_name
		)

		if (
			source_rect.size.x <= 0.0
			or source_rect.size.y <= 0.0
			or target_rect.size.x <= 0.0
			or target_rect.size.y <= 0.0
		):
			continue

		_launch_bolt(
			source_rect,
			target_rect
		)

		launched = true

	return launched


func _castle_global_rect(
	board,
	wanted_name: String
) -> Rect2:
	if (
		board == null
		or not is_instance_valid(board)
		or board.castle_row == null
		or not is_instance_valid(
			board.castle_row
		)
	):
		return Rect2()

	for child in board.castle_row.get_children():
		if (
			child != null
			and is_instance_valid(child)
			and String(
				child.get(
					"castle_name"
				)
			) == wanted_name
		):
			return child.get_global_rect()

	# A lethal bombardment may remove the target card before presentation gets
	# its deferred frame. Keep the event visible by falling back to the row.
	return board.castle_row.get_global_rect()


func _launch_bolt(
	source_rect: Rect2,
	target_rect: Rect2
) -> void:
	var source_center: Vector2 = source_rect.get_center()
	var target_center: Vector2 = target_rect.get_center()

	var direction: Vector2 = (
		target_center
		- source_center
	)

	if direction.length_squared() <= 0.01:
		return

	direction = direction.normalized()

	var source_radius: float = (
		minf(
			source_rect.size.x,
			source_rect.size.y
		)
		* SOURCE_EDGE_RATIO
	)

	var target_radius: float = (
		minf(
			target_rect.size.x,
			target_rect.size.y
		)
		* TARGET_EDGE_RATIO
	)

	var start_global: Vector2 = (
		source_center
		+ direction * source_radius
	)

	var end_global: Vector2 = (
		target_center
		- direction * target_radius
	)

	var overlay_origin: Vector2 = (
		get_global_rect().position
	)

	var start_local: Vector2 = (
		start_global
		- overlay_origin
	)

	var end_local: Vector2 = (
		end_global
		- overlay_origin
	)

	var impact_local: Vector2 = (
		target_center
		- overlay_origin
	)

	var bolt := AnimatedSprite2D.new()
	bolt.name = "BallistaBoltFx"
	bolt.sprite_frames = _bolt_frames
	bolt.animation = "fly"
	bolt.position = start_local
	bolt.rotation = (
		end_local
		- start_local
	).angle()
	bolt.z_index = 3
	bolt.material = _bolt_material

	var bolt_frame_size: Vector2 = (
		_grid_frame_size(
			BALLISTA_BOLT,
			BOLT_COLUMNS,
			BOLT_ROWS
		)
	)

	var base_scale: float = (
		BOLT_VISUAL_LENGTH
		/ maxf(
			1.0,
			bolt_frame_size.x
		)
	)

	bolt.scale = Vector2(
		base_scale,
		base_scale
		* BOLT_VERTICAL_SQUASH
	)

	add_child(
		bolt
	)

	bolt.play(
		"fly"
	)

	var flight := create_tween()
	flight.set_trans(
		Tween.TRANS_SINE
	)
	flight.set_ease(
		Tween.EASE_IN_OUT
	)

	flight.tween_property(
		bolt,
		"position",
		end_local,
		FLIGHT_SECONDS
	)

	flight.tween_callback(
		_impact.bind(
			bolt,
			impact_local,
			target_rect.size
		)
	)


func _impact(
	bolt: Node,
	impact_local: Vector2,
	target_size: Vector2
) -> void:
	if (
		bolt != null
		and is_instance_valid(bolt)
	):
		bolt.queue_free()

	# One explosion event, but now it is an actual 8-frame animation.
	var explosion := AnimatedSprite2D.new()
	explosion.name = "SiegeExplosionFx"
	explosion.sprite_frames = _explosion_frames
	explosion.animation = "blast"
	explosion.centered = true
	explosion.position = impact_local
	explosion.z_index = 4

	var frame_size: Vector2 = _grid_frame_size(
		EXPLOSION,
		EXPLOSION_COLUMNS,
		EXPLOSION_ROWS
	)

	var desired_extent: float = clampf(
		maxf(
			target_size.x,
			target_size.y
		)
		* EXPLOSION_TARGET_SCALE,
		EXPLOSION_MIN_EXTENT,
		EXPLOSION_MAX_EXTENT
	)

	var native_extent: float = maxf(
		1.0,
		maxf(
			frame_size.x,
			frame_size.y
		)
	)

	var explosion_scale: float = (
		desired_extent
		/ native_extent
	)

	explosion.scale = Vector2(
		explosion_scale,
		explosion_scale
	)

	add_child(
		explosion
	)

	_spawn_shrapnel(
		impact_local,
		target_size
	)

	explosion.animation_finished.connect(
		explosion.queue_free
	)

	explosion.play(
		"blast"
	)


func _spawn_shrapnel(
	impact_local: Vector2,
	target_size: Vector2
) -> void:
	if _shrapnel_texture == null:
		return

	# Fixed variation: looks irregular without adding presentation RNG.
	var angles: Array[float] = [
		-2.58,
		-1.88,
		-1.18,
		-0.42,
		0.52,
		1.30,
	]

	var distance_scales: Array[float] = [
		0.82,
		1.13,
		0.94,
		1.21,
		0.88,
		1.06,
	]

	var fragment_scales: Array[float] = [
		0.050,
		0.068,
		0.046,
		0.074,
		0.056,
		0.063,
	]

	var base_distance: float = clampf(
		maxf(
			target_size.x,
			target_size.y
		)
		* 0.80,
		110.0,
		185.0
	)

	for index: int in range(
		angles.size()
	):
		var piece := Sprite2D.new()
		piece.name = "SiegeShrapnelFx"
		piece.texture = _shrapnel_texture
		piece.position = impact_local
		piece.centered = true
		piece.z_index = 5
		piece.rotation = (
			angles[index] * 0.35
		)

		var fragment_scale: float = (
			fragment_scales[index]
		)

		piece.scale = Vector2(
			fragment_scale,
			fragment_scale
		)

		piece.flip_h = (
			index % 2 == 0
		)

		add_child(
			piece
		)

		var direction: Vector2 = (
			Vector2.RIGHT.rotated(
				angles[index]
			)
		)

		var destination: Vector2 = (
			impact_local
			+ direction
			* base_distance
			* distance_scales[index]
			+ Vector2(
				0.0,
				38.0
			)
		)

		var spin: float = (
			TAU * 0.72
			if index % 2 == 0
			else -TAU * 0.86
		)

		var fragment_tween := create_tween()
		fragment_tween.set_parallel(
			true
		)

		fragment_tween.set_trans(
			Tween.TRANS_QUAD
		)

		fragment_tween.set_ease(
			Tween.EASE_OUT
		)

		fragment_tween.tween_property(
			piece,
			"position",
			destination,
			SHRAPNEL_SECONDS
		)

		fragment_tween.tween_property(
			piece,
			"rotation",
			piece.rotation + spin,
			SHRAPNEL_SECONDS
		)

		fragment_tween.tween_property(
			piece,
			"modulate:a",
			0.0,
			0.44
		).set_delay(
			0.34
		)

		fragment_tween.set_parallel(
			false
		)

		fragment_tween.tween_callback(
			piece.queue_free
		)


# UI2_SIEGE_ENGINE_BOLT_READABILITY_V1
func _build_bolt_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("fly")
	frames.set_animation_loop("fly", true)
	frames.set_animation_speed("fly", BOLT_FPS)

	var image: Image = BALLISTA_BOLT.get_image()
	var texture_size: Vector2 = BALLISTA_BOLT.get_size()

	if image == null or image.is_empty():
		return _build_grid_frames(
			BALLISTA_BOLT,
			BOLT_COLUMNS,
			BOLT_ROWS,
			"fly",
			BOLT_FPS,
			true
		)

	var y_bounds: Vector2i = _bolt_shared_y_bounds(image)
	var y0: int = y_bounds.x
	var y1: int = y_bounds.y

	for column: int in range(BOLT_COLUMNS):
		var x0: int = int(
			round(
				float(column)
				* texture_size.x
				/ float(BOLT_COLUMNS)
			)
		)
		var x1: int = int(
			round(
				float(column + 1)
				* texture_size.x
				/ float(BOLT_COLUMNS)
			)
		)

		var atlas := AtlasTexture.new()
		atlas.atlas = BALLISTA_BOLT
		atlas.region = Rect2(
			Vector2(x0, y0),
			Vector2(
				x1 - x0,
				y1 - y0
			)
		)

		frames.add_frame(
			"fly",
			atlas
		)

	print(
		"SIEGE BOLT SHEET · 8 frames · cropped Y %d..%d"
		% [y0, y1]
	)

	return frames


func _bolt_shared_y_bounds(
	image: Image
) -> Vector2i:
	var min_y: int = image.get_height()
	var max_y: int = -1

	for y: int in range(image.get_height()):
		var occupied: bool = false

		for x: int in range(
			0,
			image.get_width(),
			2
		):
			if image.get_pixel(x, y).a > 0.025:
				occupied = true
				break

		if occupied:
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)

	if max_y < min_y:
		return Vector2i(
			0,
			image.get_height()
		)

	var padding: int = 12

	return Vector2i(
		maxi(
			0,
			min_y - padding
		),
		mini(
			image.get_height(),
			max_y + padding + 1
		)
	)


func _build_grid_frames(
	texture: Texture2D,
	columns: int,
	rows: int,
	animation_name: String,
	fps: float,
	looped: bool
) -> SpriteFrames:
	var frames := SpriteFrames.new()

	if frames.has_animation(
		animation_name
	):
		frames.remove_animation(
			animation_name
		)

	frames.add_animation(
		animation_name
	)

	frames.set_animation_loop(
		animation_name,
		looped
	)

	frames.set_animation_speed(
		animation_name,
		fps
	)

	var texture_size: Vector2 = (
		texture.get_size()
	)

	for row: int in range(rows):
		var y0: int = int(
			round(
				float(row)
				* texture_size.y
				/ float(rows)
			)
		)

		var y1: int = int(
			round(
				float(row + 1)
				* texture_size.y
				/ float(rows)
			)
		)

		for column: int in range(columns):
			var x0: int = int(
				round(
					float(column)
						* texture_size.x
						/ float(columns)
				)
			)

			var x1: int = int(
				round(
					float(column + 1)
						* texture_size.x
						/ float(columns)
				)
			)

			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(
				Vector2(
					x0,
					y0
				),
				Vector2(
					x1 - x0,
					y1 - y0
				)
			)

			frames.add_frame(
				animation_name,
				atlas
			)

	return frames


func _grid_frame_size(
	texture: Texture2D,
	columns: int,
	rows: int
) -> Vector2:
	var texture_size: Vector2 = (
		texture.get_size()
	)

	return Vector2(
		texture_size.x
		/ float(columns),
		texture_size.y
		/ float(rows)
	)


func _load_runtime_texture(
	resource_path: String
) -> Texture2D:
	var image := Image.new()

	var error_code: Error = image.load(
		resource_path
	)

	if error_code != OK:
		push_warning(
			"Siege Engine FX could not load image: %s"
			% resource_path
		)
		return null

	return ImageTexture.create_from_image(
		image
	)


func _make_bolt_material() -> ShaderMaterial:
	var shader := Shader.new()

	shader.code = (
		"shader_type canvas_item;\n"
		+ "uniform vec3 warm = vec3(1.0, 0.80, 0.34);\n"
		+ "uniform float gain = 1.10;\n"
		+ "uniform float glow_gain = 0.34;\n"
		+ "void fragment() {\n"
		+ "  vec4 tex = texture(TEXTURE, UV);\n"
		+ "  float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));\n"
		+ "  float glow = smoothstep(0.30, 0.82, lum);\n"
		+ "  vec3 rgb = tex.rgb * gain + warm * glow * glow_gain;\n"
		+ "  rgb = min(rgb, vec3(1.0));\n"
		+ "  COLOR = vec4(rgb, tex.a);\n"
		+ "}\n"
	)

	var material := ShaderMaterial.new()
	material.shader = shader

	return material

