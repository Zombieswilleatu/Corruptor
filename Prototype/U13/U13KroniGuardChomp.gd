extends Control

const Visual = preload("res://Prototype/U13/U13KroniVisual.gd")
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const POP: float = 0.10
const CHOMP: float = 0.55
const EXIT: float = 0.12
var rows: Array = []
var elapsed: float = 0.0
var sheet: Texture2D
var board_sides: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 130
	sheet = Art.texture(Visual.SHEET_PATH)
	hide()


func play(events: Array, sides: Array) -> void:
	clear()
	board_sides = sides
	for event in events:
		var victim: Dictionary = event.data.before
		var side = sides[1 - int(victim.owner)]
		var box = side.lord_guard_box if victim.attributes.lane == "Lord" else side.castle_guard_box
		var slot = box.get_child(int(victim.attributes.slot))
		rows.append({"event": event.duplicate(true), "slot": slot, "color": slot.modulate, "texture": Art.texture_for(victim.attributes.suit, int(victim.attributes.value))})
		# The final board is authoritative; the overlay carries the eaten card.
		slot.modulate.a = 0.0
	if active():
		show()
	queue_redraw()


func active() -> bool:
	return not rows.is_empty()


func advance(delta: float) -> void:
	if not active():
		return
	elapsed += maxf(0.0, delta)
	if elapsed >= _flight_duration(rows[0]) + POP + CHOMP + EXIT:
		_restore(rows.pop_front())
		elapsed = 0.0
		if not active():
			hide()
	queue_redraw()


func _restore(row: Dictionary) -> void:
	if is_instance_valid(row.slot):
		row.slot.modulate = row.color


func clear() -> void:
	for row in rows:
		_restore(row)
	rows = []
	elapsed = 0.0
	hide()
	queue_redraw()


func _draw() -> void:
	if not active() or sheet == null:
		return
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		if not is_instance_valid(row.slot):
			continue
		var rect: Rect2 = get_global_transform_with_canvas().affine_inverse() * row.slot.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, row.slot.size)
		if index > 0:
			if row.texture != null:
				draw_texture_rect(row.texture, rect, false)
			continue
		var flight_duration: float = _flight_duration(row)
		if elapsed < flight_duration:
			if row.texture != null: draw_texture_rect(row.texture,rect,false)
			var point: Vector2 = _flight_position(row,elapsed / flight_duration)
			var next_point: Vector2 = _flight_position(row,minf(1.0,elapsed / flight_duration + 0.01))
			var direction: int = 1 if next_point.x >= point.x else 2
			var frame: int = int(elapsed * 12) % 6
			var dimensions: Vector2 = Visual.atlas_size(80.0,direction,frame)
			draw_texture_rect_region(sheet,Rect2(point-dimensions*0.5,dimensions),Visual.ROWS[direction][frame])
			continue
		var local_elapsed: float = elapsed - flight_duration
		var left: bool = rect.get_center().x >= size.x * 0.5
		var progress: float = clampf((local_elapsed - POP) / CHOMP, 0.0, 1.0)
		var frame: int = int(floor(minf(progress, 0.99999) * 12.0)) % 6
		var sprite_size: Vector2 = Visual.atlas_size(maxf(96.0, rect.size.y * 1.25), 2 if left else 1, frame)
		var center: Vector2 = rect.get_center() + Vector2((-1 if left else 1) * (rect.size.x + sprite_size.x) * 0.5, 0)
		center.x = clampf(center.x, sprite_size.x * 0.5, size.x - sprite_size.x * 0.5)
		var mouth: Vector2 = center + Vector2(0.30 if left else -0.30, -0.07) * sprite_size
		var card_center: Vector2 = rect.get_center().lerp(mouth, smoothstep(0.08, 0.78, progress))
		var card_size: Vector2 = rect.size * (1.0 - smoothstep(0.20, 0.82, progress))
		if row.texture != null:
			draw_texture_rect(row.texture, Rect2(card_center - card_size * 0.5, card_size), false)
		var envelope: float = smoothstep(0.0, POP, local_elapsed) * (1.0 - smoothstep(POP + CHOMP, POP + CHOMP + EXIT, local_elapsed))
		var shown_size: Vector2 = sprite_size * envelope
		draw_texture_rect_region(sheet, Rect2(center - shown_size * 0.5, shown_size), Visual.ROWS[2 if left else 1][frame])
		draw_string(ThemeDB.fallback_font, center - Vector2(75, sprite_size.y * 0.5 + 8), row.event.data.cause, HORIZONTAL_ALIGNMENT_CENTER, 150, 14, Color("eac16c"))


func _flight_duration(row: Dictionary) -> float:
	var flight: Dictionary = row.event.data.get("guard_bounce",{})
	if flight.is_empty(): return 0.0
	return clampf(float(flight.ticks) / 80.0,0.6,2.5)


func _slot_center(owner: int, lane: String, index: int) -> Vector2:
	var side = board_sides[1-owner]
	var box = side.lord_guard_box if lane == "Lord" else side.castle_guard_box
	var slot = box.get_child(index)
	return get_global_transform_with_canvas().affine_inverse() * (slot.get_global_transform_with_canvas() * (slot.size*0.5))


func _axis(value: float, keys: Array, positions: Array) -> float:
	for i in range(1,keys.size()):
		if value <= keys[i]: return lerpf(positions[i-1],positions[i],clampf((value-keys[i-1]) / float(keys[i]-keys[i-1]),0.0,1.0))
	return positions[-1]


func _arena_position(point: Vector2) -> Vector2:
	var l: float = (_slot_center(0,"Lord",0).x+_slot_center(1,"Lord",0).x)*0.5
	var a: float = (_slot_center(0,"Castle",0).x+_slot_center(1,"Castle",0).x)*0.5
	var b: float = (_slot_center(0,"Castle",1).x+_slot_center(1,"Castle",1).x)*0.5
	var c: float = (_slot_center(0,"Castle",2).x+_slot_center(1,"Castle",2).x)*0.5
	var top: float = _slot_center(1,"Lord",0).y
	var bottom: float = _slot_center(0,"Lord",2).y
	var enemy_castle: float = _slot_center(1,"Castle",0).y
	var own_castle: float = _slot_center(0,"Castle",0).y
	return Vector2(_axis(point.x,[0,80,450,720,820,920,1000],[l-32,l,(l+a)*0.5,a,b,c,c+32]),
		_axis(point.y,[0,100,230,360,410,500,590,640,770,900,1000],[top-32,top,_slot_center(1,"Lord",1).y,_slot_center(1,"Lord",2).y,enemy_castle,(enemy_castle+own_castle)*0.5,own_castle,_slot_center(0,"Lord",0).y,_slot_center(0,"Lord",1).y,bottom,bottom+32]))


func _flight_position(row: Dictionary, progress: float) -> Vector2:
	var points: Array = row.event.data.guard_bounce.path
	var length: float = 0.0
	for i in range(1,points.size()): length += Vector2(points[i][0]-points[i-1][0],points[i][1]-points[i-1][1]).length()
	var remaining: float = length*progress
	for i in range(1,points.size()):
		var a := Vector2(points[i-1][0],points[i-1][1])
		var b := Vector2(points[i][0],points[i][1])
		var distance: float = a.distance_to(b)
		if remaining <= distance: return _arena_position(a.lerp(b,remaining/maxf(0.001,distance)))
		remaining -= distance
	return _arena_position(Vector2(points[-1][0],points[-1][1]))
