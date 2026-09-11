extends Control
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const DURATION: float = 0.8
const IMPACT: float = 0.46
signal impact(details: Dictionary)
var battlefield
var texture: Texture2D
var pending: Array = []
var current: Dictionary = {}
var age: float = 0.0
var impacted: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 52
	texture = Art.texture("res://ConceptImages/Sprites/Kanifous/WishDeath.png")

func play_events(events: Array) -> Array:
	clear()
	var victims: Array = []
	for event in events:
		if event.type == "KANIFOUS_WISH_RESOLVED" and event.data.power == "WishDeath":
			pending.append(event.data.duplicate(true))
			victims.append_array(event.data.get("victims", []).duplicate(true))
	_next()
	return victims

func active() -> bool:
	return not current.is_empty()

func _next() -> void:
	current = {} if pending.is_empty() else pending.pop_front()
	age = 0.0
	impacted = false
	queue_redraw()

func advance(delta: float) -> void:
	var remaining: float = maxf(delta, 0.0)
	while active() and remaining > 0:
		var step: float = minf(remaining, DURATION - age)
		age += step
		remaining -= step
		if not impacted and age >= IMPACT:
			impacted = true
			impact.emit(current)
		if age >= DURATION:
			_next()
	queue_redraw()

func clear() -> void:
	pending.clear()
	current = {}
	age = 0.0
	impacted = false
	queue_redraw()

func _draw() -> void:
	if not active() or battlefield == null:
		return
	var lane: Rect2 = get_global_transform().affine_inverse() * battlefield.get_global_transform() * battlefield.travel_rect(current.target.lane)
	var p: Dictionary = current.target.field_position
	var center: Vector2 = lane.position + Vector2(float(p.y_fp) / 600.0, 1.0 - float(p.x_fp) / 2400.0) * lane.size
	var radius: Vector2 = Vector2(lane.size.x / 600.0, lane.size.y / 2400.0) * preload("res://Scripts/Sim/U13Wishmaster.gd").DEATH_RADIUS
	var fade: float = 1.0 - clampf((age - 0.6) / 0.2, 0.0, 1.0)
	var collapse: float = 1.0 - clampf((age - IMPACT) / 0.15, 0.0, 1.0)
	var points := PackedVector2Array()
	for i in range(49):
		var angle: float = TAU * i / 48.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * (0.2 + 0.8 * collapse))
	draw_colored_polygon(points, Color(0.09, 0.01, 0.14, (0.55 + 0.2 * sin(age * 24)) * fade))
	draw_polyline(points, Color(0.7, 0.25, 0.9, 0.55 * fade), 2.0, true)
	if age < 0.12 or texture == null:
		return
	var scale_value: float = lerpf(1.25, 1.0, clampf((age - 0.12) / 0.23, 0.0, 1.0))
	if age >= IMPACT:
		scale_value *= lerpf(1.0, 0.88, clampf((age - IMPACT) / 0.12, 0.0, 1.0))
	var dimensions: Vector2 = Vector2(110, 110) * scale_value
	var box := Rect2(center - dimensions * 0.5, dimensions)
	for i in range(6):
		var a: float = TAU * i / 6.0 + age * 2.0
		draw_circle(center + Vector2(cos(a) * 30, sin(a) * 38), 12 + age * 8, Color(0.6, 0.2, 0.85, 0.09 * fade))
	draw_texture_rect(texture, box, false, Color(1, 1, 1, fade))
	# A single localized flash in the eye sockets and mouth; never the whole card.
	if age >= 0.4 and age < 0.49:
		var flash: float = sin(PI * (age - 0.4) / 0.09)
		for point in [Vector2(0.4, 0.415), Vector2(0.6, 0.415), Vector2(0.5, 0.64)]:
			var at: Vector2 = box.position + point * box.size
			draw_circle(at, 5.5, Color(0.75, 0.35, 1, flash * 0.65))
			draw_circle(at, 2.5, Color(1, 0.9, 1, flash))
