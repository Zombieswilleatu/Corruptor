extends Control

# Centers measured on each source artwork, independent of viewport size.
const LAYOUTS: Dictionary = {
	"Orias": [0.219, 0.500, 0.782, 0.145, 0.096],
	"Deimos": [0.227, 0.500, 0.769, 0.158, 0.096],
	"Gremory": [0.240, 0.500, 0.757, 0.169, 0.110],
	"Humbaba": [0.228, 0.500, 0.774, 0.165, 0.120],
	"Kalligan": [0.233, 0.500, 0.767, 0.190, 0.105],
	"Odradek": [0.250, 0.500, 0.745, 0.182, 0.122]
}
var values: Dictionary = {}
var inspected: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func bind_stats(data: Dictionary, enlarged: bool = false) -> void:
	values = data.duplicate(true)
	inspected = enlarged
	queue_redraw()


func artwork_rect() -> Rect2:
	var texture: Texture2D = get_parent().texture
	if texture == null or size.x <= 0 or size.y <= 0:
		return Rect2()
	var scale_factor: float = minf(size.x / texture.get_width(), size.y / texture.get_height())
	var extent: Vector2 = texture.get_size() * scale_factor
	return Rect2((size - extent) * 0.5, extent)


func _text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: Vector2 = (
		center
		+ Vector2(-width * 0.5, (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	)
	draw_string_outline(
		font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK
	)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	if values.is_empty():
		return
	var rect: Rect2 = artwork_rect()
	if not rect.has_area():
		return
	var layout: Array = LAYOUTS.get(values.lord, [0.25, 0.5, 0.75, 0.18, 0.12])
	var ink := Color("f4e2b9")
	var numbers: Array = [
		str(values.summon), str(values.defense) if values.alive else "—", str(values.fracture)
	]
	var font_size: int = maxi(14, int(rect.size.x * 0.095))
	for index in range(3):
		_text(
			numbers[index],
			rect.position + Vector2(layout[index], layout[3]) * rect.size,
			font_size,
			ink
		)
	if values.lord in ["Deimos", "Gremory", "Kalligan", "Odradek"]:
		var center: Vector2 = rect.position + Vector2(layout[2], layout[4]) * rect.size
		var extent: Vector2 = Vector2(0.24, 0.026) * rect.size
		draw_rect(Rect2(center - extent * 0.5, extent), Color(0.015, 0.012, 0.008, 0.97))
		_text("FRACTURE", center, maxi(6, int(rect.size.x * 0.027)), ink)
	if inspected:
		var center: Vector2 = rect.position + Vector2(0.5, 0.92) * rect.size
		var extent: Vector2 = Vector2(0.86, 0.075) * rect.size
		draw_rect(Rect2(center - extent * 0.5, extent), Color(0.015, 0.012, 0.008, 0.92))
		var detail: String = (
			"BANISHED"
			if not values.alive
			else ("NO THREAT" if values.threat == null else "THREAT %d" % values.threat)
		)
		if values.alive and values.hunt_bonus > 0:
			detail += " · HUNT +%d" % values.hunt_bonus
		_text(detail, center, maxi(12, int(rect.size.x * 0.042)), ink)
