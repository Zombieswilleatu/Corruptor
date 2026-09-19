extends "res://Prototype/U13/U13BoardLanes.gd"

var animation_paused: bool = true
var staged_units: Array = []
var staging_capacity: int = 0
var staging_round: int = 1
var staging_hits: Array = []

func _ready() -> void:
	display_settings_path = ""
	super._ready()
	custom_minimum_size = Vector2(320, 560)
	sprite_height = 76
	var controls: Control = get_node("UnitDisplayControls")
	controls.offset_top = 12
	controls.offset_bottom = 44

func travel_rect(_lane: String) -> Rect2:
	var width: float = minf(500, maxf(240, size.x - 96))
	# Reserve a full monster's height above the far gate, so battlefield
	# sprites cannot be mistaken for pieces in the protected enemy tray.
	if staging_capacity > 0: return Rect2((size.x - width) * 0.5, 236, width, maxf(160, size.y - 372))
	return Rect2((size.x - width) * 0.5, 108, width, maxf(240, size.y - 200))

func staging_rect(owner: int) -> Rect2:
	var width: float = minf(580, size.x - 16)
	return Rect2((size.x - width) * 0.5, 52 if owner == 1 else size.y - 110, width, 102)

func _draw_staging(owner: int) -> void:
	var box: Rect2 = staging_rect(owner)
	var tint: Color = BLUE if owner == 0 else RED
	var units: Array = staged_units.filter(func(u): return u.owner == owner)
	units.sort_custom(func(a, b): return a.attributes.staged_round < b.attributes.staged_round if a.attributes.staged_round != b.attributes.staged_round else a.id < b.id)
	var ready: int = units.filter(func(u): return int(u.attributes.staged_round) < staging_round).size()
	draw_rect(box, Color("191e1a"))
	draw_rect(box, Color(tint, 0.45), false, 1)
	var caption: String = "%s · STAGING %d/%d · %d ready / %d new" % ["YOUR SIDE" if owner == 0 else "ENEMY", units.size(), staging_capacity, ready, units.size() - ready]
	draw_string(ThemeDB.fallback_font, box.position + Vector2(8, 17), caption, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 16, 13, tint)
	var columns: int = maxi(8, ceili(float(units.size()) / 2.0))
	var width: float = (box.size.x - 16) / float(columns)
	var old_height: float = sprite_height
	sprite_height = 30
	for i in range(maxi(staging_capacity, units.size())):
		var center: Vector2 = box.position + Vector2(8 + width * (float(i % columns) + 0.5), 46 + floorf(float(i) / float(columns)) * 36)
		draw_circle(center, 15, Color(tint, 0.09))
		if i >= units.size():
			draw_arc(center, 14, 0, TAU, 24, Color(tint, 0.2), 1)
			continue
		var unit: Dictionary = units[i]
		_draw_chit(unit, center)
		var fresh: bool = int(unit.attributes.staged_round) >= staging_round
		draw_string(ThemeDB.fallback_font, center + Vector2(13, 4), "N" if fresh else "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("dec080") if fresh else Color("aee6b1"))
		staging_hits.append({"rect": Rect2(center - Vector2(18, 30), Vector2(36, 44)), "unit": unit})
	sprite_height = old_height

func _get_tooltip(at: Vector2) -> String:
	for hit in staging_hits:
		if hit.rect.has_point(at):
			var a: Dictionary = hit.unit.attributes
			return "%s · protected staging\nHP %d/%d · Armor %d\n%s\nCannot attack, be attacked, build or use abilities here." % [a.get("monster_id", a.suit), a.hp, a.max_hp, a.armor, "Ready for the next release." if a.staged_round < staging_round else "New: must wait until round %d." % (a.staged_round + 1)]
	return super._get_tooltip(at)

func beam_bounds(lane: String) -> Rect2:
	return travel_rect(lane)

func _process(delta: float) -> void:
	if not animation_paused: super._process(delta)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0e100f"))
	var field: Rect2 = travel_rect("Lord")
	_scenery(field.grow(28), Rect2(0.36, 0.10, 0.24, 0.82))
	draw_rect(field.grow(28), Color("68583b"), false, 2)
	var font: Font = ThemeDB.fallback_font
	staging_hits.clear()
	if staging_capacity > 0:
		_draw_staging(1)
		_draw_staging(0)
	else:
		draw_string(font, Vector2(field.position.x, 78), "ENEMY  ↓", HORIZONTAL_ALIGNMENT_CENTER, field.size.x, 19, RED)
		draw_string(font, Vector2(field.position.x, size.y - 43), "↑  YOUR SIDE", HORIZONTAL_ALIGNMENT_CENTER, field.size.x, 19, BLUE)
	for y in [field.position.y, field.end.y]:
		draw_line(Vector2(field.position.x, y), Vector2(field.end.x, y), Color("a19066"), 2)
	_draw_monster_fields("Lord")
	fortification_visual.draw(self, "Lord", field_structures, _units)
	var ordered: Array = _units.duplicate()
	ordered.sort_custom(func(a, b): return float(a.attributes.get("visual_x", a.attributes.x_fp)) > float(b.attributes.get("visual_x", b.attributes.x_fp)))
	for unit in ordered:
		if not deaths.seen.has(unit.id): _draw_chit(unit, _monster_point(unit.attributes))
	_draw_monster_attacks()
	projectile_visual.draw(self, projectiles)
	deaths.draw(self)
	_draw_charm_markers()
	if staging_capacity == 0:
		draw_string(font, Vector2(field.position.x, size.y - 14), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HEALTH_RING_COLOR)
		draw_string(font, Vector2(field.position.x + 35, size.y - 14), "ARMOR · outer ring = side", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ARMOR_RING_COLOR)
