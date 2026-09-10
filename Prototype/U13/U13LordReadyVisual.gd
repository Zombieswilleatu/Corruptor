extends Control

const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const Status = preload("res://Prototype/U13/U13LordCooldowns.gd")
const Kroni = preload("res://Prototype/U13/U13KroniVisual.gd")
const Valak = preload("res://Prototype/U13/U13ValakVisual.gd")
const POWERS: Dictionary = {
	"Gremory": "PredatorOfRuin", "Deimos": "Rout", "Humbaba": "BreathOfLife",
	"Kalligan": "Inferno", "Orias": "Web", "Kroni": "Ravenous", "Valak": "GravityOrb"
}
const PATHS: Dictionary = {
	"Gremory": "Chits.png", "Deimos": "Rout/Rout.png", "Humbaba": "BreathOfLife/Flower1.png",
	"Kalligan": "Scorch/Fire1.png", "Orias": "Orias/Spider.png",
	"Kroni": "Kroni/KroniSprite.png", "Valak": "Valak/OrbRotate.png"
}
var lord: String = ""
var available: bool = false
var clock: float = 0.0
var texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(false)


func bind_view(view: Dictionary, pid: int) -> void:
	var next_lord: String = view.world.get("lord_ids", ["Gremory", "Gremory"])[pid]
	if next_lord != lord:
		lord = next_lord
		texture = Art.texture("res://ConceptImages/Sprites/" + PATHS[lord]) if PATHS.has(lord) else null
	var next_ready: bool = false
	for row in Status.statuses(view, pid):
		if row.power == POWERS.get(lord, ""):
			next_ready = row.ready
	if next_ready and not available:
		clock = 0.0
	available = next_ready
	visible = available
	set_process(available and lord != "Gremory")
	queue_redraw()


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func _stamp(source: Rect2, center: Vector2, width: float, tint: Color = Color.WHITE) -> void:
	var extent := Vector2(width, width * source.size.y / source.size.x)
	draw_texture_rect_region(texture, Rect2(center - extent * 0.5, extent), source, tint)


func _draw() -> void:
	if not available or texture == null or size.x <= 0:
		return
	# Bottom artwork band stays above the existing caption and below printed stats.
	var center: Vector2 = size * Vector2(0.5, 0.72)
	var width: float = size.x * 0.23
	match lord:
		"Gremory":
			var cell: Vector2 = texture.get_size() / Vector2(4, 2)
			for i in range(3):
				_stamp(Rect2(Vector2(cell.x * 2, cell.y), cell), center + Vector2((i - 1) * size.x * 0.21, 0), size.x * 0.19)
		"Deimos":
			for i in range(3):
				var phase: float = clock * 2.0 + i * 2.0
				_stamp(Rect2(Vector2.ZERO, texture.get_size()), center + Vector2((i - 1) * size.x * 0.19, sin(phase) * size.y * 0.012), width, Color(1, 1, 1, 0.65 + 0.25 * sin(phase)))
		"Humbaba":
			var cell: Vector2 = texture.get_size() / Vector2(3, 2)
			var frame: int = mini(4, int(clock / 0.22))
			_stamp(Rect2(Vector2(frame % 3, floori(frame / 3.0)) * cell, cell), center, size.x * (0.31 + 0.01 * sin(clock * 2)))
		"Kalligan":
			var cell: Vector2 = texture.get_size() / Vector2(5, 1)
			_stamp(Rect2(Vector2((int(clock * 6) % 5) * cell.x, 0), cell), center, size.x * 0.32)
		"Orias":
			var cell_width: float = texture.get_width() / 6.0
			_stamp(Rect2((int(clock * 8) % 6) * cell_width, 95, cell_width, 451), center + Vector2(sin(clock) * size.x * 0.05, 0), width)
		"Kroni":
			_stamp(Kroni.ROWS[1][int(clock * 10) % 6], center, size.x * 0.28)
		"Valak":
			var frame: int = int(clock * 9) % 7
			var source := Rect2(Valak.ROTATE_CUTS[frame], 0, Valak.ROTATE_CUTS[frame + 1] - Valak.ROTATE_CUTS[frame], 682)
			var anchor: Vector2 = Valak.ROTATE_CENTERS[frame] - source.position
			var factor: float = size.x * 0.12 / 400.0
			draw_texture_rect_region(texture, Rect2(size * Vector2(0.246, 0.281) - anchor * factor, source.size * factor), source)
