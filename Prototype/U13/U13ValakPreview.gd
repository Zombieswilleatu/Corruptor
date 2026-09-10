extends "res://Prototype/U13/U13VisualPreview.gd"

const Visual = preload("res://Prototype/U13/U13ValakVisual.gd")
const Orbs = preload("res://Scripts/Sim/U13GravityOrbs.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const TICK_SECONDS: float = 0.05
var units = Ids.new()
var orb_rows: Array = []
var pull_strength: int = Orbs.PULL_FP
var pull_radius: int = Orbs.ATTRACTION_FP
var tick_clock: float = 0.0
var tick_number: int = 0
var consumed: Array = [0, 0]
var pull_label: Label

const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
var visual
var card: Texture2D
var terrain: Texture2D
var chits: Texture2D
var card_rect := Rect2(36, 238, 300, 450)
var field_rect := Rect2(470, 240, 360, 615)
var destination := Vector2(560, 445)
var status: Label
var guide: Label
var charge_label: Label
var phase_label: Label
var pause: bool = false
var speed: float = 1.0
var auto_absorb: bool = false
var absorb_clock: float = 0.0
var impact_time: float = 0.0
var impact_position := Vector2.ZERO
var move_staff: bool = false
var staff_anchor := Vector2(0.246, 0.281)


func _ready() -> void:
	card = Art.lord_texture("Valak")
	terrain = Art.texture("res://ConceptImages/Menus/Domain1.png")
	chits = Art.texture("res://ConceptImages/Sprites/Chits.png")
	visual = Visual.new()
	add_child(visual)
	visual.charges_changed.connect(func(_v: int) -> void: _refresh())
	visual.projection_arrived.connect(func(point: Vector2) -> void:
		impact_position = point
		impact_time = 0.4
	)
	var heading := Label.new()
	heading.text = "VALAK · ABSORPTION & THE ORB"
	heading.position = Vector2(28, 18)
	heading.add_theme_font_size_override("font_size", 26)
	add_child(heading)
	var controls := HFlowContainer.new()
	controls.position = Vector2(28, 65)
	controls.size = Vector2(1210, 90)
	controls.add_theme_constant_override("h_separation", 14)
	controls.add_theme_constant_override("v_separation", 10)
	add_child(controls)
	_button(controls, "Cast orb", _cast_orb)
	_button(controls, "Absorb +1", _absorb)
	_button(controls, "Project charges", func() -> void: visual.project(destination))
	_button(controls, "Reset", _reset)
	_toggle(controls, "Auto absorb", func(v: bool) -> void: auto_absorb = v; absorb_clock = 0.0)
	_toggle(controls, "Pause", func(v: bool) -> void: pause = v)
	_toggle(controls, "Move staff origin", func(v: bool) -> void: move_staff = v)
	_button(controls, "Back / Exit", _close_preview.bind(0))
	_button(controls, "Main Menu", _main_menu)
	var timing := HBoxContainer.new()
	timing.position = Vector2(28, 153)
	timing.add_theme_constant_override("separation", 14)
	add_child(timing)
	_slider(timing, "Speed", 0.1, 2.0, 1.0, func(v: float) -> void: speed = v)
	_slider(timing, "Flight", 0.2, 2.0, 0.8, func(v: float) -> void: visual.flight_seconds = v)
	_slider(timing, "Formation", 0.2, 2.0, 0.8, func(v: float) -> void: visual.formation_seconds = v)
	_slider(timing, "Orb size", 60.0, 220.0, 140.0, func(v: float) -> void: visual.orb_size = v)
	var tuning := VBoxContainer.new()
	tuning.position = Vector2(36, 755)
	add_child(tuning)
	_slider(tuning, "Pull strength", 0, 14, pull_strength, func(v: float) -> void: pull_strength = int(v))
	_slider(tuning, "Pull radius", 65, 500, pull_radius, func(v: float) -> void: pull_radius = int(v))
	_button(controls, "Reset marchers", _reset_marchers)
	pull_label = Label.new()
	pull_label.position = Vector2(880, 800)
	add_child(pull_label)
	status = Label.new()
	status.position = Vector2(28, 210)
	status.text = "Click either lane to aim · Blue = friendly · Red = enemy"
	status.add_theme_color_override("font_color", Color("c6b99c"))
	add_child(status)
	charge_label = Label.new()
	charge_label.position = Vector2(36, 710)
	charge_label.add_theme_font_size_override("font_size", 22)
	charge_label.add_theme_color_override("font_color", Color("b8e977"))
	add_child(charge_label)
	phase_label = Label.new()
	phase_label.position = Vector2(880, 240)
	phase_label.add_theme_font_size_override("font_size", 24)
	phase_label.add_theme_color_override("font_color", Color("d9b3f0"))
	add_child(phase_label)
	guide = Label.new()
	guide.position = Vector2(880, 310)
	guide.size = Vector2(350, 480)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size", 19)
	guide.text = "ABSORPTION\nA small green core hovers beside Valak. Every absorbed charge adds another rotating layer.\n\nPROJECTION\nSend the stored energy to your selected point. The hovering orb empties as it leaves.\n\nTHE ORB\nLaunch from the head of Valak’s staff. At the target, play the singularity sequence, then sustain the rotating effect.\n\nGRAVITY PULL\nBoth armies are pulled only in the targeted lane; core contact destroys them. Rings show pull and destruction radius.\n\nPull sliders change this preview only. Reset marchers to repeat. No marcher combat in this preview."
	add_child(guide)
	_sync_anchors()
	_reset()


func _button(parent: Node, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	parent.add_child(button)


func _toggle(parent: Node, title: String, action: Callable) -> void:
	var button := CheckButton.new()
	button.text = title
	button.toggled.connect(action)
	parent.add_child(button)


func _slider(parent: Node, title: String, low: float, high: float, initial: float, action: Callable) -> void:
	var column := VBoxContainer.new()
	parent.add_child(column)
	var label := Label.new()
	label.text = "%s %.1f" % [title, initial]
	column.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size.x = 150
	slider.min_value = low
	slider.max_value = high
	slider.step = 1.0 if high > 10 else 0.1
	slider.value = initial
	slider.value_changed.connect(action)
	slider.value_changed.connect(func(v: float) -> void: label.text = "%s %.1f" % [title, v])
	column.add_child(slider)


func _sync_anchors() -> void:
	visual.staff_position = card_rect.position + card_rect.size * staff_anchor
	# Keep all five rotating layers inside the artwork, below the stat row.
	visual.hover_position = card_rect.position + card_rect.size * Vector2(0.69, 0.48)


func _reset() -> void:
	visual.clear()
	absorb_clock = 0.0
	impact_time = 0.0
	_reset_marchers()
	_cast_orb()
	_refresh()


func _absorb() -> void:
	# Five is the preview's artwork showcase limit, not a gameplay cap.
	if visual.charges + visual.absorptions.size() < 5:
		visual.absorb_charge(destination)


func _refresh() -> void:
	if charge_label != null:
		charge_label.text = "STORED CHARGES  %d / 5" % visual.charges
	if pull_label != null:
		pull_label.text = "CONSUMED\nFriendly %d · Enemy %d" % consumed
	if phase_label != null:
		phase_label.text = {"idle": "READY", "flight": "STAFF → TARGET", "singularity": "SINGULARITY", "rotate": "ROTATING HOLD"}[visual.phase]


func _process(delta: float) -> void:
	if visual == null or pause:
		return
	var step: float = delta * speed
	impact_time = maxf(0.0, impact_time - step)
	visual.advance(step)
	tick_clock += step
	while tick_clock >= TICK_SECONDS:
		tick_clock -= TICK_SECONDS
		_step_marchers()
	if auto_absorb:
		absorb_clock += step
		if absorb_clock >= 1.2:
			absorb_clock = 0.0
			_absorb()
	_refresh()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if move_staff and card_rect.has_point(event.position):
		staff_anchor = (event.position - card_rect.position) / card_rect.size
		_sync_anchors()
		accept_event()
	elif field_rect.has_point(event.position):
		destination = event.position
		queue_redraw()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("121410"))
	if card != null:
		draw_texture_rect(card, card_rect, false)
	if terrain != null:
		draw_texture_rect(terrain, field_rect, false)
	draw_rect(field_rect, Color("887752"), false, 2.0)
	draw_line(Vector2(field_rect.get_center().x, field_rect.position.y), Vector2(field_rect.get_center().x, field_rect.end.y), Color("887752"), 2.0)
	if chits != null:
		var cell: Vector2 = chits.get_size() / Vector2(4, 2)
		for unit in units.snapshot().entities:
			var center: Vector2 = _screen_point(unit.attributes)
			var source := Rect2(Vector2(float(unit.ordinal % 4), float(1 if unit.owner == 0 else 0)) * cell, cell)
			draw_texture_rect_region(chits, Rect2(center - Vector2(12, 12), Vector2(24, 24)), source)
	if visual != null and visual.phase == "rotate":
		for radius in [pull_radius, Orbs.DESTRUCTION_FP]:
			var points := PackedVector2Array()
			var target: Dictionary = orb_rows[0].target
			var center: Vector2 = _screen_point({"lane": target.lane, "x_fp": target.field_position.x_fp, "y_fp": target.field_position.y_fp})
			for index in range(65):
				var angle: float = TAU * index / 64.0
				var offset := Vector2(cos(angle) * radius * field_rect.size.x / 1200.0, sin(angle) * radius * field_rect.size.y / 2400.0)
				points.append(center + offset)
			draw_polyline(points, Color("ba87e5") if radius == pull_radius else Color("ee7788"), 2, true)
	draw_arc(destination, 20.0, 0, TAU, 40, Color("e1c393"), 1.5, true)
	if impact_time > 0:
		draw_arc(impact_position, 24.0 + (0.4 - impact_time) * 160.0, 0, TAU, 64, Color(0.6, 1.0, 0.3, impact_time / 0.4), 3.0, true)
	if move_staff and visual != null:
		draw_arc(visual.staff_position, 9, 0, TAU, 32, Color("d4ace9"), 2.0, true)


func _screen_point(a: Dictionary) -> Vector2:
	var lane_offset: float = 0.0 if a.lane == "Lord" else field_rect.size.x * 0.5
	return field_rect.position + Vector2(lane_offset + float(a.y_fp) / 600.0 * field_rect.size.x * 0.5, (1.0 - float(a.x_fp) / 2400.0) * field_rect.size.y)


func _cast_orb() -> void:
	visual.cast(destination)
	var right: bool = destination.x >= field_rect.get_center().x
	var origin: float = field_rect.position.x + (field_rect.size.x * 0.5 if right else 0.0)
	var point: Dictionary = {"x_fp": roundi((1.0 - (destination.y - field_rect.position.y) / field_rect.size.y) * 2400.0), "y_fp": roundi((destination.x - origin) / (field_rect.size.x * 0.5) * 600.0)}
	orb_rows = [{"id": "preview-orb", "owner": 0, "target": {"lane": "Castle" if right else "Lord", "field_position": point}, "round": 1, "consumed": 0, "rewarded": false}]


func _reset_marchers() -> void:
	units = Ids.new()
	consumed = [0, 0]
	tick_clock = 0.0
	tick_number = 0
	for index in range(24):
		var owner: int = index % 2
		units.create("marcher", "preview", index, owner, {"lane": "Lord" if index < 12 else "Castle", "x_fp": 200 + (index % 6) * 360, "y_fp": 180 + (index % 3) * 120, "movement_ready_round": 1, "waiting": false, "contact_tick": -1})
	queue_redraw()


func _step_marchers() -> void:
	var before: Array = units.snapshot().entities
	for unit in before:
		var a: Dictionary = unit.attributes.duplicate(true)
		a.x_fp = clampi(int(a.x_fp) + (4 if unit.owner == 0 else -4), 0, 2400)
		units.update(unit.id, unit.owner, a)
	if visual.phase == "rotate":
		var events: Array = Orbs.step(orb_rows, units, before, 1, tick_number, false, pull_strength, pull_radius)
		for event in events:
			consumed[event.event.data.unit.owner] += 1
	tick_number += 1
