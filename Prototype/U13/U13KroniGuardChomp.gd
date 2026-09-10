extends Control

const Visual = preload("res://Prototype/U13/U13KroniVisual.gd")
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const POP: float = 0.10
const CHOMP: float = 0.55
const EXIT: float = 0.12
var rows: Array = []
var elapsed: float = 0.0
var sheet: Texture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 130
	sheet = Art.texture(Visual.SHEET_PATH)
	hide()


func play(events: Array, sides: Array) -> void:
	clear()
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
	if elapsed >= POP + CHOMP + EXIT:
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
		var sprite_size := Vector2.ONE * maxf(96.0, rect.size.y * 1.25)
		var left: bool = rect.get_center().x >= size.x * 0.5
		var center: Vector2 = rect.get_center() + Vector2((-1 if left else 1) * (rect.size.x + sprite_size.x) * 0.5, 0)
		center.x = clampf(center.x, sprite_size.x * 0.5, size.x - sprite_size.x * 0.5)
		var progress: float = clampf((elapsed - POP) / CHOMP, 0.0, 1.0)
		var mouth: Vector2 = center + Vector2(0.30 if left else -0.30, -0.07) * sprite_size
		var card_center: Vector2 = rect.get_center().lerp(mouth, smoothstep(0.08, 0.78, progress))
		var card_size: Vector2 = rect.size * (1.0 - smoothstep(0.20, 0.82, progress))
		if row.texture != null:
			draw_texture_rect(row.texture, Rect2(card_center - card_size * 0.5, card_size), false)
		var envelope: float = smoothstep(0.0, POP, elapsed) * (1.0 - smoothstep(POP + CHOMP, POP + CHOMP + EXIT, elapsed))
		var frame: int = int(floor(minf(progress, 0.99999) * 12.0)) % 6
		var shown_size: Vector2 = sprite_size * envelope
		draw_texture_rect_region(sheet, Rect2(center - shown_size * 0.5, shown_size), Visual.ROWS[2 if left else 1][frame])
		draw_string(ThemeDB.fallback_font, center - Vector2(75, sprite_size.y * 0.5 + 8), row.event.data.cause, HORIZONTAL_ALIGNMENT_CENTER, 150, 14, Color("eac16c"))
