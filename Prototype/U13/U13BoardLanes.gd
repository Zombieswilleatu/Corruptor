extends "res://Prototype/U13/U13SmokeBoard.gd"

# UI2 MarchingLaneView's right rail geometry and original frame/domain crops.
# Positions come exclusively from the U13 playback tape, never the U12 simulator.
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
var domain: Texture2D
var skin: Texture2D


func _ready() -> void:
	domain = Art.texture("res://ConceptImages/Menus/Domain1.png")
	skin = Art.texture("res://ConceptImages/Menus/Battlefield.png")
	custom_minimum_size = Vector2(290, 600)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _scenery(rect: Rect2, crop: Rect2) -> void:
	if domain != null:
		var dimensions: Vector2 = domain.get_size()
		draw_texture_rect_region(
			domain, rect, Rect2(crop.position * dimensions, crop.size * dimensions)
		)
		draw_rect(rect, Color(0, 0, 0, 0.38))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if skin != null:
		var dimensions: Vector2 = skin.get_size()
		draw_texture_rect_region(
			skin,
			Rect2(Vector2.ZERO, size),
			Rect2(dimensions.x * 0.105, 0, dimensions.x * 0.790, dimensions.y)
		)
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(10, 76),
		"ENEMY ↓   ·   ↑ YOU",
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 20,
		12,
		MUTED
	)
	var action_rect := Rect2(16, 92, size.x - 32, 176)
	_scenery(action_rect, Rect2(0.26, 0.46, 0.48, 0.42))
	draw_string(
		font,
		Vector2(16, 116),
		"ACTION",
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 32,
		15,
		Color("ebdab4")
	)
	var action: String = "Marching clashes appear here"
	if not _clash.is_empty():
		action = "CLASH"
		var index: int = 0
		for unit in _units:
			if unit.id not in _clash:
				continue
			var card := Rect2(30 + (index % 4) * 56, 140, 48, 68)
			var texture: Texture2D = Art.texture_for(unit.attributes.suit, 1)
			if texture != null:
				draw_texture_rect(texture, card, false)
			draw_rect(card, BLUE if unit.owner == 0 else RED, false, 2)
			index += 1
	draw_string(font, Vector2(18, 250), action, HORIZONTAL_ALIGNMENT_CENTER, size.x - 36, 12, MUTED)
	for lane_index in range(2):
		var lane: String = "Lord" if lane_index == 0 else "Castle"
		var width: float = (size.x - 37) / 2.0
		var rect := Rect2(16 + lane_index * (width + 5), 279, width, size.y - 303)
		_scenery(rect, Rect2(0.36 if lane_index == 0 else 0.48, 0.10, 0.12, 0.82))
		draw_string(
			font,
			Vector2(rect.position.x, rect.position.y + 20),
			lane.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER,
			width,
			13,
			Color("ebdab4")
		)
		var top: float = rect.position.y + 65
		var bottom: float = rect.end.y - 52
		var middle: float = rect.get_center().x
		draw_line(Vector2(middle, top), Vector2(middle, bottom), Color("625234"), 1)
		for mark in range(4):
			var y: float = lerpf(bottom, top, float(mark) / 3.0)
			draw_line(
				Vector2(rect.position.x + 7, y),
				Vector2(rect.end.x - 7, y),
				Color(0.6, 0.5, 0.3, 0.35),
				1
			)
		var occupied: Dictionary = {}
		for unit in _units:
			var a: Dictionary = unit.attributes
			if a.lane != lane:
				continue
			# Global x=0 is the human end (bottom), x=2400 the enemy end (top).
			var y: float = lerpf(
				bottom, top, clampf(float(a.get("visual_x", a.x_fp)) / 2400.0, 0, 1)
			)
			var key: String = "%s:%d" % [unit.owner, roundi(y / 24.0)]
			var ordinal: int = int(occupied.get(key, 0))
			occupied[key] = ordinal + 1
			var center := Vector2(
				middle + (-19 if unit.owner == 0 else 19) + (ordinal % 2) * 8,
				y + floori(float(ordinal) / 2.0) * 9
			)
			var card := Rect2(center - Vector2(17, 25), Vector2(34, 50))
			var texture: Texture2D = Art.texture_for(a.suit, 1)
			if texture != null:
				draw_texture_rect(texture, card, false)
			draw_rect(card, BLUE if unit.owner == 0 else RED, false, 2)
			if unit.id in _clash:
				draw_rect(card.grow(3), Color("f5d39a"), false, 2)
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
					11
				)
