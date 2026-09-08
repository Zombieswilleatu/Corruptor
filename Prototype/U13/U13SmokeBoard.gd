class_name U13SmokeBoard
extends Control

const INK: Color = Color("111821")
const MUTED: Color = Color("a3adbb")
const BLUE: Color = Color("72cddd")
const RED: Color = Color("ef9786")
const SUIT_COLORS: Dictionary = {
	"Butcher": Color("d97a71"),
	"Penitent": Color("bab0df"),
	"Vulture": Color("ccbf76"),
	"Wright": Color("79bba8")
}
var _units: Array = []
var _clash: Array = []
var _round: int = 1


func _ready() -> void:
	custom_minimum_size = Vector2(650, 300)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_world(entities: Array, round_number: int) -> void:
	_units = []
	for entity in entities:
		if entity.kind == "marcher":
			_units.append(entity.duplicate(true))
	_clash = []
	_round = round_number
	queue_redraw()


func show_frame(frame: Dictionary, round_number: int) -> void:
	_units = frame.units.duplicate(true)
	_clash = frame.clash.duplicate()
	_round = round_number
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var left: float = 64.0
	var right: float = maxf(left + 100.0, size.x - 64.0)
	var width: float = right - left
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	draw_string(font, Vector2(20, 30), "YOU / GREMORY", HORIZONTAL_ALIGNMENT_LEFT, 260, 16, BLUE)
	draw_string(
		font,
		Vector2(size.x - 260, 30),
		"GREMORY / OPPONENT",
		HORIZONTAL_ALIGNMENT_RIGHT,
		240,
		16,
		RED
	)
	for lane_index in range(2):
		var lane: String = "Lord" if lane_index == 0 else "Castle"
		var center: float = 84.0 + float(lane_index) * (size.y - 168.0)
		draw_rect(Rect2(left, center - 41, width, 90), Color("18222d"))
		draw_line(Vector2(left, center), Vector2(right, center), Color("334151"), 2)
		for gate in [left, right]:
			draw_line(Vector2(gate, center - 45), Vector2(gate, center + 50), Color("697687"), 3)
		draw_string(
			font,
			Vector2(left + width * 0.35, center - 45),
			lane.to_upper() + " LANE",
			HORIZONTAL_ALIGNMENT_LEFT,
			240,
			15,
			MUTED
		)
		for mark in range(1, 4):
			var x: float = left + width * float(mark) / 4.0
			draw_line(Vector2(x, center - 3), Vector2(x, center + 3), Color("697687"), 1)
		for unit in _units:
			if unit.attributes.lane != lane:
				continue
			var a: Dictionary = unit.attributes
			var x: float = left + width * clampf(float(a.get("visual_x", a.x_fp)) / 2400.0, 0, 1)
			var lateral: float = clampf(
				float(a.get("visual_y", a.get("y_fp", 300))) / 600.0, 0.0, 1.0
			)
			var y: float = center - 35.0 + 70.0 * lateral
			var point: Vector2 = Vector2(x, y)
			var color: Color = BLUE if unit.owner == 0 else RED
			if unit.id in _clash:
				draw_arc(point, 19, 0.0, TAU, 32, Color("f5d39a"), 2.0, true)
			draw_circle(point, 13, SUIT_COLORS.get(a.suit, MUTED))
			draw_arc(point, 14, 0.0, TAU, 32, color, 2.0, true)
			draw_string(
				font,
				point + Vector2(-5, 5),
				String(a.suit).substr(0, 1),
				HORIZONTAL_ALIGNMENT_LEFT,
				20,
				14,
				INK
			)
			draw_rect(Rect2(point + Vector2(-14, 17), Vector2(28, 4)), Color("3b4554"))
			draw_rect(
				Rect2(point + Vector2(-14, 17), Vector2(28.0 * float(a.hp) / float(a.max_hp), 4)),
				color
			)
			if a.waiting:
				draw_string(
					font,
					point + Vector2(-7, -19),
					"W",
					HORIZONTAL_ALIGNMENT_LEFT,
					24,
					12,
					Color("f5d39a")
				)
			elif a.movement_ready_round > _round:
				draw_string(
					font, point + Vector2(-7, -19), "H", HORIZONTAL_ALIGNMENT_LEFT, 24, 12, MUTED
				)
	if _units.is_empty():
		draw_string(
			font,
			Vector2(90, size.y * 0.5 + 5),
			"No Marchers on the field.",
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x - 180,
			17,
			MUTED
		)
	draw_string(
		font,
		Vector2(20, size.y - 14),
		(
			"B  Butcher     P  Penitent     V  Vulture     W  Wright"
			+ "       H  Birth hold       W above token  Waiting"
		),
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 40,
		13,
		MUTED
	)
