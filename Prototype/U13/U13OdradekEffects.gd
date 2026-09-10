extends Control

const Timing = preload("res://Prototype/U13/U13ParadoxTiming.gd")
const Visuals = preload("res://Prototype/U13/U13WebVisuals.gd")
const EFFECT_DURATION: float = 1.6
const PARADOX_DURATION: float = 2.1

var vortex
var battlefield
var sides: Array = []
var records: Array = []
var elapsed: float = 0.0
var switched: bool = false
var changed_ids: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 125
	vortex = preload("res://Prototype/U13/U13ParadoxVisual.gd").new()
	add_child(vortex)


func play(rows: Array, lanes, player_sides: Array) -> void:
	clear()
	battlefield = lanes
	sides = player_sides
	records = rows.duplicate(true)
	if active():
		_begin()


func active() -> bool:
	return not records.is_empty()


func _begin() -> void:
	battlefield.paradox_glitches.clear()
	changed_ids.clear()
	for before in records[0].before:
		if before.get("kind", "") != "marcher":
			continue
		for after in records[0].after:
			if before.id == after.id and before != after:
				changed_ids.append(before.id)
	elapsed = 0.0
	switched = false
	battlefield.show_world(records[0].before, records[0].round)


func advance(delta: float) -> bool:
	if not active():
		return false
	if elapsed == 0.0:
		_begin()
	var record: Dictionary = records[0]
	var data: Dictionary = record.data
	var paradox: bool = data.get("player_id", 0) == -1 or data.get("power", "") == "ParadoxGeometry"
	var duration: float = PARADOX_DURATION if paradox else EFFECT_DURATION
	elapsed += maxf(delta, 0.0)
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	var area: Rect2
	var clip: Rect2
	if record.type == "GUARD_RECONFIGURED":
		var guard: Dictionary = data.after if progress >= 0.5 else data.before
		var side = sides[1 - int(guard.owner)]
		var box = side.lord_guard_box if guard.attributes.lane == "Lord" else side.castle_guard_box
		var slot = box.get_child(int(guard.attributes.slot))
		area = slot.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, slot.size)
		clip = box.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, box.size)
	else:
		var transform: Transform2D = battlefield.get_global_transform_with_canvas()
		var lane_rect: Rect2 = battlefield.travel_rect(data.target.lane)
		area = transform * Visuals.region_rect(lane_rect, data.target.field_position, int(data.radius_fp))
		clip = transform * lane_rect
	# Stutter in, snap to a sustained warp, then break apart on exit.
	var envelope: float = Timing.envelope(progress)
	vortex.glitch = Timing.edge_glitch(progress)
	battlefield.paradox_glitches.clear()
	for id in changed_ids:
		battlefield.paradox_glitches[id] = {"amount": Timing.transfer(progress), "tick": int(elapsed * 40)}
	battlefield.queue_redraw()
	vortex.present(area, clip, envelope, 8.0 if paradox else 4.0, 0.8 if paradox else 0.0)
	if progress >= 0.5 and not switched:
		switched = true
		battlefield.show_world(record.after, record.round)
	if progress >= 1.0:
		battlefield.paradox_glitches.clear()
		records.pop_front()
		vortex.hide()
		if active():
			_begin()
	return true


func clear() -> void:
	if is_instance_valid(battlefield):
		battlefield.paradox_glitches.clear()
		battlefield.queue_redraw()
	records = []
	if vortex != null:
		vortex.hide()
