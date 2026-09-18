extends "res://Prototype/U13/U13BoardLanes.gd"

var animation_paused: bool = true

func _ready() -> void:
	display_settings_path = ""
	super._ready()
	custom_minimum_size = Vector2(320, 500)
	sprite_height = 76
	var controls: Control = get_node("UnitDisplayControls")
	controls.offset_top = 12
	controls.offset_bottom = 44

func travel_rect(_lane: String) -> Rect2:
	var width: float = minf(500, maxf(240, size.x - 96))
	return Rect2((size.x - width) * 0.5, 108, width, maxf(240, size.y - 200))

func _process(delta: float) -> void:
	if not animation_paused: super._process(delta)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0e100f"))
	var field: Rect2 = travel_rect("Lord")
	_scenery(field.grow(28), Rect2(0.36, 0.10, 0.24, 0.82))
	draw_rect(field.grow(28), Color("68583b"), false, 2)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(field.position.x, 78), "ENEMY  ↓", HORIZONTAL_ALIGNMENT_CENTER, field.size.x, 19, RED)
	draw_string(font, Vector2(field.position.x, size.y - 43), "↑  YOUR SIDE", HORIZONTAL_ALIGNMENT_CENTER, field.size.x, 19, BLUE)
	for y in [field.position.y, field.end.y]:
		draw_line(Vector2(field.position.x, y), Vector2(field.end.x, y), Color("a19066"), 2)
	_draw_monster_fields("Lord")
	var ordered: Array = _units.duplicate()
	ordered.sort_custom(func(a, b): return float(a.attributes.get("visual_x", a.attributes.x_fp)) > float(b.attributes.get("visual_x", b.attributes.x_fp)))
	for unit in ordered:
		if not deaths.seen.has(unit.id): _draw_chit(unit, _monster_point(unit.attributes))
	_draw_monster_attacks()
	projectile_visual.draw(self, projectiles)
	deaths.draw(self)
	draw_string(font, Vector2(field.position.x, size.y - 14), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HEALTH_RING_COLOR)
	draw_string(font, Vector2(field.position.x + 35, size.y - 14), "ARMOR · outer ring = side", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ARMOR_RING_COLOR)
