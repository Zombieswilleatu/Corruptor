extends Control
# Presentation clock only: no gameplay state, timers, or random numbers are changed.
const SandShader = preload("res://Prototype/U13/U13MarchingSand.gdshader")
const FULL_TURN_SECONDS := 0.62
const EMPTY_TURN_SECONDS := 0.26
var body := Control.new()
var frame := TextureRect.new()
var sand := ColorRect.new()
var caption := Label.new()
var sand_material := ShaderMaterial.new()
var _active_tape = null
var _empty := false
var _turning := false
var _turn_elapsed := 0.0
var _settle := 1.0
var _orientation := false
var _phase := 0.0
var _progress := 1.0
var _upper: Array[float] = []
var _lower: Array[float] = []
var _sand_volume := 0
var _frame_rect := Rect2()

func _ready() -> void:
	name = "MarchingHourglass"
	custom_minimum_size = Vector2(94, 126)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = "Marching time · short phases drain faster. An empty field flips straight through."
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	frame.texture = _texture_file("res://Prototype/U13/Assets/MarchingHourglass.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(frame)
	sand.material = sand_material
	sand_material.shader = SandShader
	# Crop the grain's transparent canvas at runtime; keep the supplied asset intact.
	var grain: Texture2D = _texture_file("res://Prototype/U13/Assets/MarchingSandGrain.png")
	var cropped := grain.get_image().get_region(Rect2i(650, 505, 105, 115))
	sand_material.set_shader_parameter("grain_texture", ImageTexture.create_from_image(cropped))
	sand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(sand)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", Color("d7c39b"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	_build_volume_table()
	resized.connect(_layout)
	_layout()
	set_progress(1.0, 0.0)
	caption.text = "MARCHING"

func _layout() -> void:
	var height := minf(110.0, maxf(24.0, size.y - 20.0))
	var width := height * 2.0 / 3.0
	_frame_rect = Rect2(Vector2((size.x - width) * 0.5, 4.0), Vector2(width, height))
	body.position = _frame_rect.position
	body.size = _frame_rect.size
	body.pivot_offset = body.size * 0.5
	frame.size = body.size
	sand.size = body.size
	caption.position = Vector2(0, height + 7)
	caption.size = Vector2(size.x, 16)

func advance_tape(tape, seconds: float, delta: float) -> float:
	if tape != _active_tape:
		_active_tape = tape
		_empty = not tape.has_marching_activity()
		_turning = true
		_turn_elapsed = 0.0
		_settle = 1.0
		caption.text = "EMPTY FIELD" if _empty else "MARCHING"
	if _turning:
		_turn_elapsed += maxf(0.0, delta)
		var length := EMPTY_TURN_SECONDS if _empty else FULL_TURN_SECONDS
		var t := clampf(_turn_elapsed / length, 0.0, 1.0)
		var eased := t * t * (3.0 - 2.0 * t)
		body.rotation = (PI if _empty else TAU + PI) * eased
		body.position.y = _frame_rect.position.y - sin(t * PI) * (5.0 if _empty else 16.0)
		body.scale = Vector2.ONE * (1.0 + sin(t * PI) * 0.10)
		set_progress(1.0 if t < 0.5 else 0.0, 0.0)
		if t < 1.0: return seconds
		_turning = false
		_orientation = not _orientation
		frame.flip_h = _orientation
		frame.flip_v = _orientation
		body.rotation = 0.0
		body.position = _frame_rect.position
		body.scale = Vector2.ONE
		_settle = 0.0
		queue_redraw()
		if _empty:
			set_progress(1.0, 0.0)
			return tape.duration
		# All phase time remains after the landing; launch animation costs no sand.
		set_progress(seconds / maxf(0.001, tape.duration), 0.0)
		return seconds
	var next := minf(tape.duration, seconds + maxf(0.0, delta))
	_phase += maxf(0.0, next - seconds) / maxf(0.001, tape.duration) * 6.0
	sand_material.set_shader_parameter("phase", _phase)
	set_progress(next / maxf(0.001, tape.duration), 1.0 if next > seconds and next < tape.duration else 0.0)
	caption.text = "MARCH  %.1fs" % maxf(0.0, tape.duration - next)
	return next

func is_turning() -> bool:
	return _turning

func finish_tape(tape) -> void:
	if tape != _active_tape: return
	_turning = false
	body.rotation = 0.0
	body.position = _frame_rect.position
	body.scale = Vector2.ONE
	set_progress(1.0, 0.0)
	caption.text = "EMPTY FIELD" if _empty else "MARCH COMPLETE"

func reset() -> void:
	_active_tape = null
	_turning = false
	_settle = 1.0
	body.rotation = 0.0
	body.position = _frame_rect.position
	body.scale = Vector2.ONE
	set_progress(1.0, 0.0)
	caption.text = "MARCHING"

func set_progress(value: float, flowing: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	if _upper.is_empty(): return
	var top_count := roundi(float(_sand_volume) * (1.0 - _progress))
	var bottom_count := _sand_volume - top_count
	var upper_level := 0.5 if top_count == 0 else _upper[maxi(0, _upper.size() - top_count)]
	var lower_level := 1.0 if bottom_count == 0 else _lower[maxi(0, _lower.size() - bottom_count)]
	sand_material.set_shader_parameter("upper_level", upper_level)
	sand_material.set_shader_parameter("lower_level", lower_level)
	sand_material.set_shader_parameter("progress", _progress)
	sand_material.set_shader_parameter("flow", flowing)

func _process(delta: float) -> void:
	if _turning or _settle >= 0.45: return
	_settle += maxf(0.0, delta)
	var strength := pow(maxf(0.0, 1.0 - _settle / 0.45), 2.0)
	body.position = _frame_rect.position + Vector2(sin(_settle * 95.0) * 2.5, abs(sin(_settle * 50.0)) * 2.0) * strength
	body.scale = Vector2(1.0 + strength * 0.11, 1.0 - strength * 0.09)
	queue_redraw()

func _draw() -> void:
	if _settle >= 0.45: return
	var fade := 1.0 - _settle / 0.45
	var floor_y := _frame_rect.end.y
	var radius := 10.0 + _settle * 75.0
	draw_set_transform(Vector2(size.x * 0.5, floor_y), 0, Vector2(1, 0.22))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 36, Color(0.72, 0.55, 0.28, fade * 0.65), 1.5, true)
	draw_set_transform(Vector2.ZERO)
	for i in range(8):
		var direction := -1.0 if i % 2 == 0 else 1.0
		var p := Vector2(size.x * 0.5 + direction * (8 + _settle * (35 + i * 7)), floor_y - sin(_settle / 0.45 * PI) * (3 + i * 2))
		draw_circle(p, 1.2, Color(0.72, 0.58, 0.34, fade * 0.7))

func _build_volume_table() -> void:
	# Equal-area samples conserve the amount of sand while the lower pile grows.
	for iy in range(145, 858, 3):
		var y := float(iy) / 1000.0
		for ix in range(275, 726, 3):
			var x := absf(float(ix) / 1000.0 - 0.5)
			if x > _half_width(y): continue
			if y <= 0.477: _upper.append(y)
			elif y >= 0.54: _lower.append(y - x * 0.35)
	_upper.sort()
	_lower.sort()
	_sand_volume = int(mini(_upper.size(), _lower.size()) * 0.78)

static func _half_width(y: float) -> float:
	if y < 0.145 or y > 0.857: return 0.0
	if y < 0.23: return lerpf(0.195, 0.225, smoothstep(0.145, 0.23, y))
	if y < 0.32: return lerpf(0.225, 0.180, smoothstep(0.23, 0.32, y))
	if y < 0.46: return lerpf(0.180, 0.045, smoothstep(0.32, 0.46, y))
	if y < 0.54: return 0.035
	if y < 0.69: return lerpf(0.045, 0.195, smoothstep(0.54, 0.69, y))
	if y < 0.78: return lerpf(0.195, 0.225, smoothstep(0.69, 0.78, y))
	return lerpf(0.225, 0.190, smoothstep(0.78, 0.857, y))

static func _texture_file(path: String) -> Texture2D:
	# Imported/exported assets use Godot's loader; fresh ZIP installs use PNG bytes.
	if ResourceLoader.exists(path): return load(path) as Texture2D
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
		return ImageTexture.create_from_image(image)
	return null
