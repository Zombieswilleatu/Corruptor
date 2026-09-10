extends "res://Prototype/U13/U13VisualPreview.gd"

const Timing = preload("res://Prototype/U13/U13ParadoxTiming.gd")
const Visual = preload("res://Prototype/U13/U13ParadoxVisual.gd")
const Effects = preload("res://Prototype/U13/U13OdradekEffects.gd")
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
var vortex
var terrain: Texture2D
var controls: HFlowContainer
var elapsed: float = 0.0
var speed: float = 1.0
var radius: float = 240.0
var twist: float = 4.0
var chaos: float = 0.0
var paused: bool = false
var hold: bool = false
var grid: bool = true
var enabled: bool = true
var center_ratio := Vector2(0.35, 0.5)
var color_depth: float = 0.25
var mode_index: int = 0
var progress: float = 0.0
var chits: Texture2D
var cards: Array = []


func _ready() -> void:
	chits = Art.texture("res://ConceptImages/Sprites/Chits.png")
	for suit in ["Butcher", "Penitent", "Vulture"]:
		cards.append(Art.texture_for(suit, 2))
	terrain = Art.texture("res://ConceptImages/Menus/Domain1.png")
	controls = HFlowContainer.new()
	controls.position = Vector2(24, 58)
	controls.add_theme_constant_override("h_separation", 16)
	controls.add_theme_constant_override("v_separation", 12)
	add_child(controls)
	var mode := OptionButton.new()
	for title in ["Redirect", "Allegiance Shift", "Paradox Geometry"]:
		mode.add_item(title)
	mode.item_selected.connect(_preset)
	controls.add_child(mode)
	_slider("Radius", 80, 340, radius, func(v: float) -> void: radius = v)
	_slider("Twist", 0, 12, twist, func(v: float) -> void: twist = v)
	_slider("Speed", 0.1, 2, speed, func(v: float) -> void: speed = v)
	_slider("Color depth", 0, 1, color_depth, func(v: float) -> void: color_depth = v)
	_toggle("Hold effect", false, func(v: bool) -> void: hold = v; elapsed = 0.0)
	_toggle("Pause", false, func(v: bool) -> void: paused = v)
	_toggle("Reference grid", true, func(v: bool) -> void: grid = v)
	_toggle("Effect on", true, func(v: bool) -> void: enabled = v)
	var replay := Button.new()
	replay.text = "Replay"
	replay.pressed.connect(func() -> void: elapsed = 0.0; vortex.phase = 0.0)
	controls.add_child(replay)
	var close := Button.new()
	close.text = "Back / Exit"
	close.pressed.connect(_close_preview.bind(0))
	controls.add_child(close)
	vortex = Visual.new()
	add_child(vortex)
	# Drive the production shader's clock here so pause and speed are exact.
	vortex.set_process(false)
	resized.connect(_layout)
	_layout()


func _slider(title: String, low: float, high: float, initial: float, changed: Callable) -> void:
	var column := VBoxContainer.new()
	controls.add_child(column)
	var label := Label.new()
	column.add_child(label)
	var slider := HSlider.new()
	slider.name = title
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01 if title == "Color depth" else 0.1
	slider.value = initial
	slider.custom_minimum_size.x = 150
	column.add_child(slider)
	label.text = "%s: %.2f" % [title, initial]
	slider.value_changed.connect(changed)
	slider.value_changed.connect(func(v: float) -> void: label.text = "%s: %.2f" % [title, v])


func _toggle(title: String, initial: bool, changed: Callable) -> void:
	var button := CheckButton.new()
	button.text = title
	button.button_pressed = initial
	button.toggled.connect(changed)
	controls.add_child(button)


func _preset(index: int) -> void:
	mode_index = index
	chaos = 0.8 if index == 2 else 0.0
	var slider := controls.find_child("Twist", true, false) as HSlider
	slider.value = 8.0 if index == 2 else 4.0
	elapsed = 0.0


func _layout() -> void:
	controls.size.x = maxf(300, size.x - 48)
	queue_redraw()


func _field() -> Rect2:
	var top: float = maxf(190, controls.position.y + controls.size.y + 45)
	return Rect2(24, top, maxf(1, size.x - 48), maxf(1, size.y - top - 24))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var field: Rect2 = _field()
		if field.has_point(event.position):
			center_ratio = (event.position - field.position) / field.size
			accept_event()


func _process(delta: float) -> void:
	if vortex == null:
		return
	var duration: float = Effects.PARADOX_DURATION if chaos > 0 else Effects.EFFECT_DURATION
	if not paused:
		elapsed = fmod(elapsed + delta * speed, duration + 0.6)
		vortex.phase += delta * speed
	progress = clampf(elapsed / duration, 0.0, 1.0)
	var amount: float = 1.0 if hold else Timing.envelope(progress)
	vortex.color_depth = color_depth
	vortex.glitch = 0.0 if hold else Timing.edge_glitch(progress)
	var field: Rect2 = _field()
	var center: Vector2 = field.position + center_ratio * field.size
	var area := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2)
	var transform: Transform2D = get_global_transform_with_canvas()
	vortex.present(transform * area, transform * field, amount if enabled else 0.0, twist, chaos)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("111211"))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(24, 34), "ODRADEK · SPIRAL TWEAKER", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e6d5af"))
	if controls == null:
		return
	var field: Rect2 = _field()
	draw_string(font, Vector2(24, field.position.y - 16), "Click to move · Preview settings only · Turn effect off to compare the original pixels", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	if terrain != null:
		draw_texture_rect(terrain, field, false)
	else:
		draw_rect(field, Color("29332d"))
	if grid:
		for x in range(int(field.position.x), int(field.end.x), 48):
			draw_line(Vector2(x, field.position.y), Vector2(x, field.end.y), Color(0.7, 0.8, 0.7, 0.45), 2)
		for y in range(int(field.position.y), int(field.end.y), 48):
			draw_line(Vector2(field.position.x, y), Vector2(field.end.x, y), Color(0.7, 0.8, 0.7, 0.45), 2)
	var tick: int = int(elapsed * 40)
	var transfer: float = Timing.transfer(progress) if enabled and not hold else 0.0
	var changed: bool = enabled and not hold and progress >= 0.5
	var center: Vector2 = field.position + center_ratio * field.size
	draw_line(Vector2(field.get_center().x, field.position.y), Vector2(field.get_center().x, field.end.y), Color("d5bd85"), 3)
	draw_string(font, field.position + Vector2(15, 25), "LORD LANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(font, Vector2(field.get_center().x + 15, field.position.y + 25), "CASTLE LANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	for index in range(6):
		var point: Vector2 = field.position + field.size * Vector2(0.28 + (index % 2) * 0.1, 0.3 + floorf(float(index) / 2.0) * 0.18)
		var owner: int = index % 2
		var affected: bool = point.distance_to(center) <= radius and (mode_index != 1 or owner == 1)
		if affected and changed:
			if mode_index == 0:
				point.x += field.size.x * 0.5
			else:
				owner = 1 - owner
		if chits != null:
			var cell: Vector2 = chits.get_size() / Vector2(4, 2)
			Timing.draw_slices(self, chits, Rect2(point - Vector2(30, 30), Vector2(60, 60)), Rect2(Vector2(index % 4, owner) * cell, cell), transfer if affected else 0.0, tick)
		draw_arc(point, 32, 0, TAU, 40, Color("72cddd") if owner == 0 else Color("e77069"), 2)
	for index in range(cards.size()):
		var point: Vector2 = field.position + field.size * Vector2(0.2 + index * 0.2, 0.82)
		var affected: bool = mode_index == 2 and point.distance_to(center) <= radius
		var destination := Rect2(point - Vector2(35, 52), Vector2(70, 104))
		var texture: Texture2D = cards[index]
		if texture != null:
			Timing.draw_slices(self, texture, destination, Rect2(Vector2.ZERO, texture.get_size()), transfer if affected else 0.0, tick)
		draw_rect(destination, Color("72cddd") if affected and changed else Color("e77069"), false, 2)
