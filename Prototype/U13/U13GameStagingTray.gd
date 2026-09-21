extends "res://Prototype/U13/U13BoardLanes.gd"

# A protected tray uses the battlefield's existing chits/sprites and tooltips.
# It never installs the reserves as combatants or advances their animations.
var compact: bool = false
var reserves: Array = []
var number: int = 1
var reserve_owner: int = 0
var hits: Array = []

func _ready() -> void:
	chit_sheet = Art.texture("res://ConceptImages/Sprites/Chits.png")
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(0, 90) if compact else Vector2(600, 100)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_height = 34
	bind(reserves, number)

func bind(units: Array, current_round: int) -> void:
	reserves = units.duplicate(true)
	number = current_round
	reserves.sort_custom(func(a, b): return a.attributes.staged_round < b.attributes.staged_round if a.attributes.staged_round != b.attributes.staged_round else a.id < b.id)
	var columns: int = 8 if compact else 15
	custom_minimum_size.y = maxf(90, ceili(float(maxi(15, reserves.size())) / float(columns)) * 44 + 2) if compact else maxf(100, ceili(float(maxi(15, reserves.size())) / 15.0) * 65 + 20)
	sprite_height = 28 if compact else 34
	queue_redraw()

func _draw() -> void:
	hits.clear()
	var tint: Color = BLUE if reserve_owner == 0 else RED
	draw_rect(Rect2(Vector2.ZERO, size), Color("111713"))
	draw_rect(Rect2(Vector2.ZERO, size), Color(tint, 0.45), false, 1)
	var columns: int = 8 if compact else 15
	var width: float = (size.x - 20) / float(columns)
	for i in range(maxi(15, reserves.size())):
		var point: Vector2 = Vector2(10 + width * (float(i % columns) + 0.5), (24 if compact else 45) + floorf(float(i) / float(columns)) * (44 if compact else 65))
		draw_circle(point, 16, Color(tint, 0.09))
		if i >= reserves.size(): continue
		var unit: Dictionary = reserves[i]
		_draw_chit(unit, point)
		var ready: bool = unit.attributes.staged_round < number
		draw_string(ThemeDB.fallback_font, point + Vector2(-18, 17 if compact else 26), "ready" if ready else "new", HORIZONTAL_ALIGNMENT_CENTER, 36, 10, Color("aee6b1") if ready else Color("dec080"))
		hits.append({"rect": Rect2(point - Vector2(width / 2, 25 if compact else 35), Vector2(width, 44 if compact else 64)), "unit": unit})

func _get_tooltip(at: Vector2) -> String:
	for hit in hits:
		if hit.rect.has_point(at):
			var a: Dictionary = hit.unit.attributes
			return "%s · protected\nHP %d/%d · Armor %d · Attack %d\n%s\nCannot attack, be attacked, build or use abilities here." % [a.get("monster_id", a.suit), a.hp, a.max_hp, a.armor, a.attack, "Waiting for MARCH." if a.staged_round < number else "Earliest deployment: round %d." % (a.staged_round + 1)]
	return tooltip_text + "\nProtected reserves · MARCH sends this group next round."
