extends "res://Prototype/U13/U13VisualPreview.gd"

const Actors = preload("res://Scripts/Sim/U13KroniActors.gd")
const State = preload("res://Scripts/Sim/U13KroniState.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Buffer = preload("res://Scripts/Sim/U13MarchingBuffer.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Visual = preload("res://Prototype/U13/U13KroniVisual.gd")
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
var visual
var terrain: Texture2D
var chits: Texture2D
var status: Label
var lord_card: Texture2D
var guide: Label
var hunger: int = 0
var breach: bool = false
var paused: bool = false
var speed: float = 1.0
var elapsed: float = 0.0
var frames: Array = []
var duration: float = 6.0
var seed_index: int = 0
var start: Dictionary = {"lane": "Lord", "field_position": {"x_fp": 0, "y_fp": 300}}


func _ready() -> void:
	terrain = Art.texture("res://ConceptImages/Menus/Domain1.png")
	chits = Art.texture("res://ConceptImages/Sprites/Chits.png")
	lord_card = Art.lord_texture("Kroni")
	visual = Visual.new()
	add_child(visual)
	var controls := HFlowContainer.new()
	controls.position = Vector2(24, 18)
	controls.size.x = 1000
	controls.add_theme_constant_override("h_separation", 14)
	add_child(controls)
	var mode := OptionButton.new()
	mode.add_item("Ravenous")
	mode.add_item("Breach · Insatiable Hunger")
	mode.item_selected.connect(func(i: int) -> void: breach = i == 1; _restart())
	controls.add_child(mode)
	var hunger_choice := OptionButton.new()
	for value in ["Hunger 0 · 100%", "Hunger 1 · 110%", "Hunger 2 · 120%", "Hunger 3+ · 135%"]:
		hunger_choice.add_item(value)
	hunger_choice.item_selected.connect(func(i: int) -> void: hunger = i; _restart())
	controls.add_child(hunger_choice)
	_slider(controls, "Speed", 0.1, 2.0, 1.0, func(v: float) -> void: speed = v)
	_slider(controls, "Chomp pause", 0.1, 1.2, 0.55, func(v: float) -> void: visual.chomp_seconds = v)
	_slider(controls, "Frame rate", 3.0, 20.0, 10.0, func(v: float) -> void: visual.frame_rate = v)
	var pause := CheckButton.new()
	pause.text = "Pause"
	pause.toggled.connect(func(v: bool) -> void: paused = v)
	controls.add_child(pause)
	var footprint := CheckButton.new()
	footprint.text = "Collision outline"
	footprint.toggled.connect(func(v: bool) -> void: visual.show_footprint = v)
	controls.add_child(footprint)
	var replay := Button.new()
	replay.text = "New launch"
	replay.pressed.connect(_restart)
	controls.add_child(replay)
	var close := Button.new()
	close.text = "Back / Exit"
	close.pressed.connect(_close_preview.bind(0))
	controls.add_child(close)
	status = Label.new()
	status.position = Vector2(24, 126)
	add_child(status)
	guide = Label.new()
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.text = "RAVENOUS\nClick either lane to place his start. Each launch rolls a new angle toward the enemy, bouncing off outer walls. No steering. Both sides can be eaten. Up to 3 per spot, then move one body-width before feeding again.\n\n6+ DEVOURED\nOne Soul, one Hunger and one Neutral Tear per activation.\n\nHUNGER\n0: Defense 4\n1–2: Defense 6\n3+: Defense 8\nFirst reaching 3 grants one personal Tear.\n\nBREACH\nA short random manifestation. No rewards."
	add_child(guide)
	resized.connect(_layout)
	_layout()
	_restart()


func _slider(parent: Node, title: String, low: float, high: float, initial: float, changed: Callable) -> void:
	var column := VBoxContainer.new()
	parent.add_child(column)
	var label := Label.new()
	column.add_child(label)
	label.text = "%s %.2f" % [title, initial]
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size.x = 130
	column.add_child(slider)
	slider.value_changed.connect(changed)
	slider.value_changed.connect(func(v: float) -> void: label.text = "%s %.2f" % [title, v])


func _layout() -> void:
	if visual != null:
		var height: float = maxf(200, size.y - 215)
		var width: float = minf(size.x - 120, height * 0.5)
		visual.field_rect = Rect2((size.x - width) * 0.5, 175, width, height)
		if guide != null:
			guide.position = Vector2(visual.field_rect.end.x + 36, 195)
			guide.size = Vector2(maxf(100, size.x - guide.position.x - 32), height)
	queue_redraw()


func _restart() -> void:
	seed_index += 1
	elapsed = 0.0
	frames = []
	var ids = Ids.new()
	# Stable scene fixtures include both sides, every suit, and both lanes.
	for index in range(32):
		var a: Dictionary = Marching.profile(Marching.SUITS[index % 4], "Lord" if index % 2 == 0 else "Castle", index % 2, 0, 1)
		a.x_fp = 150 + int(floor(float(index) / 4.0)) * 290
		a.y_fp = 80 + (index % 4) * 140
		ids.create("marcher", "kroni-preview", index, index % 2, a)
	var buffer = Buffer.new()
	buffer.restore(ids.snapshot())
	var actor: Dictionary = Actors.create("preview", -1 if breach else 0, 1, 0 if breach else hunger, breach, "kroni-preview-%d" % seed_index, start)
	var actors: Array = [actor]
	var events: Array = [State.event("KRONI_ACTORS_STARTED", {"actors": actors.duplicate(true)}).event]
	frames.append(buffer.marchers())
	for tick in range(200):
		for row in Actors.step(actors, buffer, 1, tick):
			events.append(row.event)
		events.append(State.event("KRONI_ACTOR_TICK", {"tick": tick, "actors": actors.duplicate(true)}).event)
		frames.append(buffer.marchers())
	visual.load_tape(events)
	status.text = "Both lanes · Blue = yours / Red = enemy · %d devoured%s" % [actor.consumed, " · Breach grants no rewards" if breach else (" · 6+ reward earned" if actor.consumed >= 6 else " · 6 needed for reward")]
	duration = 6.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if breach or visual == null or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	for lane in ["Lord", "Castle"]:
		var rect: Rect2 = visual.field_rect
		rect.size.x *= 0.5
		if lane == "Castle":
			rect.position.x += rect.size.x
		var target: Dictionary = preload("res://Prototype/U13/U13SpatialInput.gd").target_at(event.position, rect, lane)
		if not target.is_empty():
			start = target
			_restart()
			accept_event()
			return


func _process(delta: float) -> void:
	if visual == null or paused:
		return
	if visual.busy():
		visual.advance_bite(delta * speed)
	else:
		elapsed += visual.limit_delta(elapsed, delta * speed)
		visual.show_time(elapsed)
		if elapsed > duration + 1.0:
			_restart()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("151410"))
	if visual == null:
		return
	var rect: Rect2 = visual.field_rect
	if lord_card != null:
		var card_width: float = maxf(60, minf(270, rect.position.x - 64))
		draw_texture_rect(lord_card, Rect2(32, rect.position.y + 45, card_width, card_width * 1.5), false)
	if terrain != null:
		draw_texture_rect(terrain, rect, false)
	draw_line(Vector2(rect.get_center().x, rect.position.y), Vector2(rect.get_center().x, rect.end.y), Color("9f8760"), 2)
	if frames.is_empty() or chits == null:
		return
	var index: int = clampi(int(floor(elapsed / Visual.TICK_SECONDS + 0.00001)), 0, frames.size() - 1)
	var cell: Vector2 = chits.get_size() / Vector2(4.0, 2.0)
	for unit in frames[index]:
		var a: Dictionary = unit.attributes
		var center: Vector2 = visual.point(float(a.x_fp), float(a.y_fp) + (600.0 if a.lane == "Castle" else 0.0))
		var column: int = Marching.SUITS.find(a.suit)
		draw_texture_rect_region(chits, Rect2(center - Vector2(22, 22), Vector2(44, 44)), Rect2(Vector2(float(column), float(unit.owner)) * cell, cell))
