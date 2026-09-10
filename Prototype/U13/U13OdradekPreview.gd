extends "res://Prototype/U13/U13VisualPreview.gd"

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
var hold: bool = true
var grid: bool = true
var enabled: bool = true
var center_ratio := Vector2(0.5, 0.5)


func _ready() -> void:
	terrain = Art.texture("res://ConceptImages/Menus/Domain1.png")
	controls = HFlowContainer.new()
	controls.position = Vector2(24, 58)
	controls.add_theme_constant_override("h_separation", 16)
	controls.add_theme_constant_override("v_separation", 12)
	add_child(controls)
	var mode := OptionButton.new()
	for title in ["Redirect / Allegiance Shift", "Paradox Geometry"]:
		mode.add_item(title)
	mode.item_selected.connect(_preset)
	controls.add_child(mode)
	_slider("Radius", 80, 340, radius, func(v: float) -> void: radius = v)
	_slider("Twist", 0, 12, twist, func(v: float) -> void: twist = v)
	_slider("Speed", 0.1, 2, speed, func(v: float) -> void: speed = v)
	_toggle("Hold effect", true, func(v: bool) -> void: hold = v; elapsed = 0.0)
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
	slider.step = 0.1
	slider.value = initial
	slider.custom_minimum_size.x = 150
	column.add_child(slider)
	label.text = "%s: %.1f" % [title, initial]
	slider.value_changed.connect(changed)
	slider.value_changed.connect(func(v: float) -> void: label.text = "%s: %.1f" % [title, v])


func _toggle(title: String, initial: bool, changed: Callable) -> void:
	var button := CheckButton.new()
	button.text = title
	button.button_pressed = initial
	button.toggled.connect(changed)
	controls.add_child(button)


func _preset(index: int) -> void:
	chaos = 0.8 if index == 1 else 0.0
	var slider := controls.find_child("Twist", true, false) as HSlider
	slider.value = 8.0 if index == 1 else 4.0
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
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	var amount: float = 1.0 if hold else smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.72, 1.0, progress))
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
	for index in range(7):
		var point: Vector2 = field.position + field.size * Vector2(0.2 + index * 0.1, 0.4 + (index % 3) * 0.1)
		draw_rect(Rect2(point - Vector2(12, 18), Vector2(24, 36)), Color("304357"))
		draw_rect(Rect2(point - Vector2(12, 18), Vector2(24, 36)), Color("d5bd85"), false, 2)
		draw_string(font, point + Vector2(-5, 6), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
