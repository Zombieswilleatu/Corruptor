extends Control

# U12 SiegeEngineBombardmentView assets, adapted to stable U13 Castle IDs.
# This ordered presentation tape never applies damage or consumes sim RNG.
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const FLIGHT_SECONDS: float = 0.96
const IMPACT_SECONDS: float = 0.8
const SHOT_SECONDS: float = FLIGHT_SECONDS + IMPACT_SECONDS + 0.06
var _bolt: Sprite2D
var _blast: Sprite2D
var _bolt_frames: Array = []
var _blast_frames: Array = []
var _shots: Array = []
var _sides: Array = []
var _index: int = 0
var _elapsed: float = 0.0
var _started: bool = false
var _start: Vector2
var _end: Vector2
var _bend: Vector2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 88
	var bolt_texture: Texture2D = Art.texture("res://ConceptImages/Other/BallistaBolt.png")
	var blast_texture: Texture2D = Art.texture("res://ConceptImages/Other/Explosion.png")
	if bolt_texture != null:
		# One native bounding-box scan replaces U12's GDScript pixel loop.
		var image: Image = bolt_texture.get_image()
		if image != null and image.is_compressed():
			image.decompress()
		var bounds: Rect2i = image.get_used_rect() if image != null else Rect2i()
		_bolt_frames = _frames(bolt_texture, 8, 1, bounds)
	if blast_texture != null:
		_blast_frames = _frames(blast_texture, 4, 2)
	_bolt = Sprite2D.new()
	_blast = Sprite2D.new()
	add_child(_bolt)
	add_child(_blast)
	clear()


func _frames(texture: Texture2D, columns: int, rows: int, bounds: Rect2i = Rect2i()) -> Array:
	var result: Array = []
	var cell: Vector2 = texture.get_size() / Vector2(float(columns), float(rows))
	for row in range(rows):
		for column in range(columns):
			var region := Rect2(Vector2(float(column), float(row)) * cell, cell)
			if bounds.has_area() and rows == 1:
				var top: float = maxf(0.0, float(bounds.position.y) - 12.0)
				region.position.y = top
				region.size.y = minf(cell.y, float(bounds.end.y) + 12.0) - top
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = region
			result.append(atlas)
	return result


func play_shots(events: Array, sides: Array) -> void:
	clear()
	_sides = sides
	for event in events:
		if event.get("type") == "ARTILLERY_FIRED":
			_shots.append(event.data.duplicate(true))


func active() -> bool:
	return _index < _shots.size()


# A true result holds Marching at t=0 for this artillery frame.
func advance(delta: float) -> bool:
	if not active():
		return false
	if not _started:
		if not _begin_shot(_shots[_index]):
			_index += 1
			return true
		_started = true
	_elapsed += maxf(0.0, delta)
	if _elapsed < FLIGHT_SECONDS:
		var t: float = clampf(_elapsed / FLIGHT_SECONDS, 0.0, 1.0)
		_bolt.texture = _bolt_frames[int(_elapsed * 12.0) % _bolt_frames.size()]
		_bolt.position = _start.bezier_interpolate(_bend, _bend, _end, t)
		_bolt.rotation = _start.bezier_derivative(_bend, _bend, _end, t).angle()
		_bolt.show()
		_blast.hide()
	elif _elapsed < FLIGHT_SECONDS + IMPACT_SECONDS:
		_bolt.hide()
		_blast.texture = _blast_frames[mini(7, int((_elapsed - FLIGHT_SECONDS) * 10.0))]
		_blast.show()
	else:
		_bolt.hide()
		_blast.hide()
	if _elapsed >= SHOT_SECONDS:
		_index += 1
		_elapsed = 0.0
		_started = false
	return true


func _begin_shot(shot: Dictionary) -> bool:
	if _bolt_frames.is_empty() or _blast_frames.is_empty() or _sides.size() != 2:
		return false
	var source: Rect2 = _castle_rect(shot.engine_id)
	var target: Rect2 = _castle_rect(shot.target_id)
	if not source.has_area() or not target.has_area():
		return false
	var trajectory: Dictionary = path_for(shot, source, target)
	_start = trajectory.start - global_position
	_end = trajectory.end - global_position
	_bend = trajectory.bend - global_position
	_bolt.texture = _bolt_frames[0]
	_bolt.scale = Vector2.ONE * (150.0 / maxf(1.0, _bolt.texture.get_width()))
	_blast.texture = _blast_frames[0]
	_blast.position = _end
	var extent: float = clampf(maxf(target.size.x, target.size.y) * 1.55, 185.0, 320.0)
	_blast.scale = (
		Vector2.ONE * (extent / maxf(_blast.texture.get_width(), _blast.texture.get_height()))
	)
	return true


func _castle_rect(id: String) -> Rect2:
	for side in _sides:
		var surface: Control = side.target_controls.get(id)
		if is_instance_valid(surface):
			return surface.get_global_rect()
	return Rect2()


static func path_for(shot: Dictionary, source: Rect2, target: Rect2) -> Dictionary:
	var key: String = "%s:%s:%s:%s" % [shot.round, shot.engine_id, shot.target_id, shot.shot]
	var visual_hash: int = key.hash()
	var direction: Vector2 = (target.get_center() - source.get_center()).normalized()
	var start_point: Vector2 = (
		source.get_center() + direction * minf(source.size.x, source.size.y) * 0.38
	)
	start_point.x += (float(visual_hash % 101) / 100.0 - 0.5) * source.size.x * 0.16
	var end_point: Vector2 = (
		target.get_center()
		+ Vector2(
			(float((visual_hash >> 8) % 101) / 100.0 - 0.5) * target.size.x * 0.2,
			(float((visual_hash >> 16) % 101) / 100.0 - 0.5) * target.size.y * 0.1
		)
	)
	var curve: float = 45.0 + float(visual_hash % 51)
	var side_sign: float = -1.0 if (visual_hash & 1) == 0 else 1.0
	var bend_point: Vector2 = (
		start_point.lerp(end_point, 0.5)
		+ direction.orthogonal() * curve * side_sign
		+ Vector2(0, -25)
	)
	return {"start": start_point, "end": end_point, "bend": bend_point}


func clear() -> void:
	_shots = []
	_sides = []
	_index = 0
	_elapsed = 0.0
	_started = false
	if is_instance_valid(_bolt):
		_bolt.hide()
	if is_instance_valid(_blast):
		_blast.hide()
