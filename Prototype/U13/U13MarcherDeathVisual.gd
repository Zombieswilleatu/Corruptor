extends RefCounted

# One shared six-frame atlas, no node/timer allocation per casualty.
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const DURATION: float = 0.48
const FLASH_DURATION: float = 0.15
var texture: Texture2D
var visible: Array = []
var seen: Dictionary = {}

func add(unit: Dictionary) -> void:
	if seen.has(unit.id):
		return
	seen[unit.id] = true
	visible.append({"unit": unit.duplicate(true), "age": 0.0})
	if texture == null:
		texture = Art.texture("res://ConceptImages/Sprites/Effects/MarcherDeath.png")

func observe(before: Array, after: Array) -> void:
	var remaining: Dictionary = {}
	for unit in after:
		if unit.kind == "marcher":
			remaining[unit.id] = unit
	for unit in before:
		var next: Dictionary = remaining.get(unit.id, {})
		if next.is_empty() or int(next.attributes.hp) <= 0:
			add(next if not next.is_empty() else unit)

func advance(delta: float) -> void:
	for row in visible:
		row.age += maxf(delta, 0.0)
	visible = visible.filter(func(row): return row.age < DURATION)

func clear() -> void:
	visible.clear()
	seen.clear()

func draw(board) -> void:
	for row in visible:
		var unit: Dictionary = row.unit
		var a: Dictionary = unit.attributes
		var lane: Rect2 = board.travel_rect(a.lane)
		var center: Vector2 = lane.position + Vector2(float(a.get("visual_y", a.y_fp)) / 600.0, 1.0 - float(a.get("visual_x", a.x_fp)) / 2400.0) * lane.size
		# Only the chit blinks/flashes. The ghost has its own uninterrupted clock.
		if row.age < FLASH_DURATION and int(row.age / 0.05) % 2 == 0:
			board._draw_chit(unit, center, true)
		if texture != null:
			var cell: Vector2 = texture.get_size() / Vector2(6, 1)
			var frame: int = mini(5, int(row.age * 6.0 / DURATION))
			board.draw_texture_rect_region(texture, Rect2(center - Vector2(26, 82), Vector2(52, 104)), Rect2(Vector2(frame * cell.x, 0), cell))
