extends Control
# Menu scenery only: fixed actor count, no simulation and no gameplay RNG.
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const Sprites = preload("res://Prototype/U13/U13MarcherSpriteCatalog.gd")
const Motion = preload("res://Prototype/U13/U13StillSpriteMotion.gd")
var domain: Texture2D
var fire: Texture2D
var edge_shade: GradientTexture2D
var floor_shade: GradientTexture2D
var age: float = 0.0
var tick: float = 0.0
var actors: Array = []
var pending: Array = ["Sinodek", "Lemek", "Batboy"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	domain = Art.texture("res://ConceptImages/Menus/Domain1.png")
	edge_shade = _gradient(false)
	floor_shade = _gradient(true)
	var path := "res://ConceptImages/Sprites/Scorch/Fire1.png"
	if FileAccess.file_exists(path) or ResourceLoader.exists(path): fire = Art.texture(path)

func _process(delta: float) -> void:
	age += delta
	tick += delta
	if not pending.is_empty():
		var character: String = pending.pop_front()
		actors.append({"name": character, "right": Sprites.pose_frame(character, false), "left": Sprites.pose_frame(character, true)})
	if tick >= 1.0 / 30.0:
		tick = 0.0
		queue_redraw()

func _draw() -> void:
	if domain == null: return
	var scale_value: float = maxf(size.x / domain.get_width(), size.y / domain.get_height())
	var dimensions: Vector2 = domain.get_size() * scale_value
	var origin: Vector2 = (size - dimensions) * 0.5
	draw_texture_rect(domain, Rect2(origin, dimensions), false, Color(0.82, 0.85, 0.88))
	# Artwork coordinates keep scenery attached to the ruins at any aspect ratio.
	var unit: Vector2 = dimensions / Vector2(1774, 887)
	_portal(origin + Vector2(1208, 347) * unit, unit.x)
	for i in range(3):
		var place: Vector2 = [Vector2(177, 168), Vector2(1550, 207), Vector2(938, 563)][i]
		_flame(origin + place * unit, [48.0, 34.0, 28.0][i] * unit.x, float(i) * 1.7)
	for i in range(actors.size()):
		var a: Dictionary = actors[i]
		var phase: float = age * [0.065, 0.042, 0.09][i] + float(i) * 2.0
		var center: Vector2 = [Vector2(1290, 675), Vector2(1020, 427), Vector2(1450, 420)][i]
		var feet: Vector2 = origin + (center + Vector2(sin(phase) * [105.0, 95.0, 65.0][i], sin(phase * 0.5) * 8.0)) * unit
		var left: bool = cos(phase) < 0.0
		var pose: Dictionary = a.left if left else a.right
		var frame: Dictionary = pose.get("frame", {})
		if frame.is_empty(): continue
		Motion.paint(self, frame.texture, feet, [85.0, 58.0, 46.0][i] * unit.x,
			left, "March", age, float(i), frame.anchor, frame.body, pose.mirror, a.name,
			false, {"tint": Color(0.68, 0.69, 0.67, 0.82)})
	# Cached smooth gradients avoid strip overlaps/banding on scaled windows.
	draw_texture_rect(edge_shade, Rect2(Vector2.ZERO, size), false)
	draw_texture_rect(floor_shade, Rect2(0, size.y * 0.82, size.x, size.y * 0.18), false)

func _gradient(bottom: bool) -> GradientTexture2D:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in range(17):
		var amount: float = float(i) / 16.0
		offsets.append(amount)
		colors.append(Color(0.025, 0.026, 0.035, amount * 0.45 if bottom else 0.78 * pow(1.0 - amount, 3.0)))
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1 if bottom else 512
	texture.height = 128 if bottom else 1
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(0, 1) if bottom else Vector2(1, 0)
	return texture

func _flame(feet: Vector2, height: float, phase: float) -> void:
	if fire == null: return
	var glow: float = 0.8 + sin(age * 6.0 + phase) * 0.15
	for i in range(5, 0, -1):
		draw_set_transform(feet, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, height * float(i) * 0.25, Color(1, 0.3, 0.04, 0.025 * glow))
	draw_set_transform(Vector2.ZERO)
	var cell := Vector2(float(fire.get_width()) / 5.0, fire.get_height())
	var index: int = int((age + phase) * 6.0) % 5
	var dimensions := Vector2(cell.x / cell.y * height, height)
	draw_texture_rect_region(fire, Rect2(feet - Vector2(dimensions.x * 0.5, dimensions.y), dimensions), Rect2(Vector2(cell.x * index, 0), cell), Color(1, 0.83, 0.65, 0.82))

func _portal(feet: Vector2, zoom: float) -> void:
	var pulse: float = 0.8 + sin(age * 1.3) * 0.15
	draw_set_transform(feet - Vector2(0, 31) * zoom, 0.0, Vector2(0.55, 1.0) * zoom)
	for i in range(7, 0, -1):
		draw_circle(Vector2.ZERO, 33.0 + float(i) * 3.0, Color(0.4, 0.15, 0.62, 0.018 * pulse))
	draw_circle(Vector2.ZERO, 29.0, Color(0.07, 0.02, 0.12, 0.85))
	for i in range(3):
		var start: float = age * (0.4 + float(i) * 0.15) + float(i) * 2.1
		draw_arc(Vector2.ZERO, 31.0 + float(i), start, start + 3.5, 32, Color(0.55, 0.31, 0.73, 0.5 * pulse), 1.5, true)
	draw_set_transform(Vector2.ZERO)
