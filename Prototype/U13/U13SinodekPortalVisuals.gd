extends Control

# Share Odradek's renderer, including its shader and palette, rather than copy it.
const Portal = preload("res://Prototype/U13/U13ParadoxVisual.gd")
var portals: Dictionary = {}
var fields: Dictionary = {}
var battlefield: Control
var radius_fp: float = 100.0
var capture: BackBufferCopy


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	capture = BackBufferCopy.new()
	capture.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	add_child(capture)
	set_process(false)


func sync(board: Control, records: Array, radius: float) -> void:
	battlefield = board
	radius_fp = radius
	fields.clear()
	for field in records:
		if field.get("kind", "") != "portal":
			continue
		var id: String = str(field.id)
		fields[id] = field.duplicate(true)
		if not portals.has(id):
			var visual = Portal.new()
			add_child(visual)
			visual.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			portals[id] = visual
	for id in portals.keys():
		if not fields.has(id):
			portals[id].hide()
			portals[id].queue_free()
			portals.erase(id)
	# Explicitly capture the current battlefield before any portal samples it.
	# All portals share this fresh snapshot, avoiding stale screen-read passes.
	capture.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if not portals.is_empty() else BackBufferCopy.COPY_MODE_DISABLED
	set_process(not portals.is_empty())
	_update_geometry()


func clear() -> void:
	for visual in portals.values():
		visual.hide()
		visual.queue_free()
	portals.clear()
	fields.clear()
	if capture != null:
		capture.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	set_process(false)


func _process(_delta: float) -> void:
	_update_geometry()


func _update_geometry() -> void:
	if not is_instance_valid(battlefield):
		clear()
		return
	var transform: Transform2D = battlefield.get_global_transform_with_canvas()
	for id in portals:
		var field: Dictionary = fields[id]
		var lane: Rect2 = battlefield.travel_rect(field.lane)
		var center: Vector2 = battlefield._monster_point(field)
		var half_size := Vector2(radius_fp / 600.0 * lane.size.x, radius_fp / 2400.0 * lane.size.y)
		var area := Rect2(center - half_size, half_size * 2.0)
		var visible_area: Rect2 = area.intersection(lane)
		var visual = portals[id]
		# Bound each draw to its footprint as well as the shader's lane clip.
		visual.position = visible_area.position
		visual.size = visible_area.size
		visual.present(transform * area, transform * lane, 1.0, 4.0, 0.0)
		if not visible_area.has_area():
			visual.hide()
