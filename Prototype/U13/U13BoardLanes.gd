extends "res://Prototype/U13/U13SmokeBoard.gd"

const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const Textures = preload("res://Prototype/U13/U13BoardTextures.gd")
var domain: Texture2D = null


func _ready() -> void:
	domain = Textures.texture("res://ConceptImages/Menus/Domain1.png")
	custom_minimum_size = Vector2(650, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if domain != null:
		draw_texture_rect(domain, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.65))
	var font: Font = ThemeDB.fallback_font
	var width: float = maxf(100.0, size.x - 140.0)
	for lane_index in range(2):
		var lane: String = "Lord" if lane_index == 0 else "Castle"
		var y: float = 50.0 + lane_index * (size.y - 100.0)
		draw_line(Vector2(70, y), Vector2(size.x - 70, y), Color("80715c"), 2)
		draw_string(font, Vector2(8, y), lane.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 65, 13)
		var occupied: Dictionary = {}
		for unit in _units:
			var a: Dictionary = unit.attributes
			if a.lane != lane:
				continue
			var x: float = 70.0 + width * float(a.get("visual_x", a.x_fp)) / 2400.0
			var key: String = "%s:%d" % [unit.owner, roundi(x / 25.0)]
			var ordinal: int = occupied.get(key, 0)
			occupied[key] = ordinal + 1
			var center := Vector2(x + ordinal * 12, y + (-12 if unit.owner == 0 else 12))
			var rect := Rect2(center - Vector2(17, 25), Vector2(34, 50))
			var texture: Texture2D = Art.texture_for(a.suit, 1)
			if texture != null:
				draw_texture_rect(texture, rect, false)
			draw_rect(rect, BLUE if unit.owner == 0 else RED, false, 2)
			if unit.id in _clash:
				draw_rect(rect.grow(3), Color("f5d39a"), false, 2)
			draw_rect(
				Rect2(center + Vector2(-17, 27), Vector2(34 * float(a.hp) / float(a.max_hp), 3)),
				BLUE if unit.owner == 0 else RED
			)
			if a.waiting or a.movement_ready_round > _round:
				draw_string(
					font,
					center + Vector2(-17, -29),
					"WAIT" if a.waiting else "NEW",
					HORIZONTAL_ALIGNMENT_LEFT,
					45,
					12
				)
