extends "res://Prototype/U13/U13BoardLanes.gd"
signal placement(point: Vector2)
const Sprites = preload("res://Prototype/U13/U13MarcherSpriteVisuals.gd")
const Objectives = preload("res://Prototype/U13/Encounters/U13EncounterObjectives.gd")
var sprites = Sprites.new()
var units: Array = []
var picture: Dictionary = {}
var objective: Dictionary = {}
var round_number: int = 1
var running: bool = false
var placing: bool = false
var selection: String = ""
var progress: float = 0.0
var clock: float = 0.0
var hits: Array = []
var previous: Dictionary = {}
var ghosts: Array = []
var lamp_texture: Texture2D
var hourglass = preload("res://Prototype/U13/U13MarchingHourglass.gd").new()
var horizontal_portals = preload("res://Prototype/U13/Encounters/U13CrossingPortals.gd").new()
var _fort_local := false
const GOLD := Color("d8b978")

func _ready() -> void:
	custom_minimum_size = Vector2(700, 260)
	mouse_filter = Control.MOUSE_FILTER_STOP
	domain = Art.texture("res://ConceptImages/Menus/Domain1.png")
	regular_sprites = true
	sprite_visuals = sprites
	projectile_visual = preload("res://Prototype/U13/Encounters/U13CrossingProjectile.gd").new()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sinodek_portals.free()
	sinodek_portals = horizontal_portals
	add_child(horizontal_portals)
	add_child(hourglass)
	hourglass.scale = Vector2.ONE * 0.65
	hourglass.size = Vector2(94, 126)
	hourglass.tooltip_text = "Marching time · follows the selected replay speed."
	resized.connect(_layout_hourglass)
	_layout_hourglass()
	lamp_texture = Art.texture("res://ConceptImages/Sprites/Kanifous/Lamp.png")

func field() -> Rect2:
	return Rect2(76, 54, maxf(200, size.x - 152), maxf(120, size.y - 88))

func point(x: float, y: float) -> Vector2:
	var r := field()
	return r.position + Vector2(x / 2400.0 * r.size.x, y / 600.0 * r.size.y)

func show_state(frame: Dictionary, state: Dictionary, number: int, moving: bool) -> void:
	picture = frame
	_units = frame.get("units", [])
	monster_attacks = frame.get("monster_attacks", [])
	monster_fields = frame.get("monster_fields", [])
	field_structures = frame.get("field_structures", [])
	horizontal_portals.sync(self, monster_fields, 100.0)
	units = frame.get("units", [])
	objective = state
	round_number = number
	running = moving
	var current: Dictionary = {}
	var changes: Array = []
	for unit in units:
		current[unit.id] = unit
		if previous.has(unit.id):
			changes.append({"id": unit.id, "hp": unit.attributes.hp - previous[unit.id].attributes.hp, "armor": unit.attributes.armor - previous[unit.id].attributes.armor})
	if moving:
		for id in previous:
			if not current.has(id): ghosts.append({"unit": previous[id], "age": 0.0})
	previous = current.duplicate(true)
	sprites.sync(units, frame.get("clash", []), number, moving)
	sprites.hit(changes)
	# The shared catalog normally faces across a vertical lane. This screen uses X.
	for unit in units:
		if sprites.subjects.has(unit.id):
			sprites.subjects[unit.id].face_left = (unit.owner == 1) != bool(unit.attributes.get("encounter_carrier", false))
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	charm_visuals.age += delta if running else 0.0
	sprites.advance(delta if running else 0.0)
	for ghost in ghosts: ghost.age += delta
	ghosts = ghosts.filter(func(g): return g.age < 0.48)
	if running or placing: queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and placing:
		var p: Vector2 = (event.position - field().position) / field().size * Vector2(2400, 600)
		placement.emit(p)
		accept_event()

func _get_tooltip(at: Vector2) -> String:
	for i in range(hits.size() - 1, -1, -1):
		var hit: Dictionary = hits[i]
		if hit.rect.has_point(at):
			var u: Dictionary = hit.unit
			var a: Dictionary = u.attributes
			return "%s · %s\nHP %s/%s · Armor %s · Attack %s%s" % [a.get("structure", a.get("monster_id", a.get("suit", "Unit"))), "Yours" if u.owner == 0 else "Enemy", a.hp, a.max_hp, a.armor, a.attack, "\nLAMP CARRIER · returning home" if a.get("encounter_carrier", false) else construction_hint(a)]
	return "Select a reinforcement, then click the blue zone." if placing else ""

func text(at: Vector2, value: String, color: Color = GOLD, font_size: int = 16) -> void:
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	var r := field()
	draw_rect(Rect2(Vector2.ZERO, size), Color("11191b"))
	# The same Lord-lane crop as U13LiveLaneLayout, turned clockwise.
	# Rotate the scenery only; units, health bars and targeting remain upright.
	draw_rect(r.grow(9), Color("27251e"))
	if domain != null:
		var dimensions := domain.get_size()
		draw_set_transform(Vector2(r.end.x, r.position.y), PI * 0.5)
		draw_texture_rect_region(domain, Rect2(Vector2.ZERO, Vector2(r.size.y, r.size.x)), Rect2(Vector2(0.26, 0.10) * dimensions, Vector2(0.24, 0.82) * dimensions))
		draw_set_transform(Vector2.ZERO)
		draw_rect(r, Color(0.025, 0.035, 0.025, 0.22))
	draw_rect(r.grow(3), Color("786747"), false, 1)
	draw_rect(r.grow(7), Color("494236"), false, 1)
	var zone := Rect2(point(60, 60), point(420, 540) - point(60, 60))
	draw_rect(zone, Color(0.3, 0.7, 0.8, 0.16 if placing else 0.05))
	draw_rect(zone, Color(0.4, 0.8, 0.85, 0.6 if placing else 0.18), false, 1)
	text(Vector2(r.position.x, 29), "YOUR CAMP", BLUE)
	text(Vector2(r.end.x - 112, 29), "ENEMY CAMP", RED)
	text(Vector2(r.position.x, size.y - 15), "DEPLOY HERE" if placing else "SURVIVORS HOLD THEIR GROUND", BLUE, 13)
	text(Vector2(r.end.x - 315, size.y - 15), "Hover troops or structures for health & armor", Color("9caa9e"), 13)
	for side in [0, 1]:
		var x: float = r.position.x - 25 if side == 0 else r.end.x + 25
		var color: Color = BLUE if side == 0 else RED
		draw_rect(Rect2(x - 12, r.position.y - 8, 24, r.size.y + 16), Color("191e1c"))
		for j in range(5): draw_line(Vector2(x - 10, r.position.y + j * r.size.y / 4.0), Vector2(x + 10, r.position.y + j * r.size.y / 4.0), color.darkened(0.5), 4)
		if objective.get("scenario", "") == "gate":
			text(Vector2(x - 23, 57), "%d HP" % objective.gate_hp[side], color, 16)
		else: text(Vector2(x - 27, 57), "HOME", color, 13)
	_draw_horizontal_fields()
	hits.clear()
	_draw_fortifications()
	var ordered := units.duplicate()
	ordered.sort_custom(func(a, b): return a.attributes.get("visual_y", a.attributes.y_fp) < b.attributes.get("visual_y", b.attributes.y_fp))
	for unit in ordered: _unit(unit)
	for ghost in ghosts:
		var a: Dictionary = ghost.unit.attributes
		sprites.draw(self, ghost.unit, point(a.get("visual_x", a.x_fp), a.get("visual_y", a.y_fp)), unit_height(ghost.unit, true), {}, false, ghost.age)
	projectile_visual.draw(self, picture.get("projectiles", []))
	_draw_monster_attacks()
	_draw_charm_markers()
	if objective.get("scenario", "") == "lamp":
		var p := point(objective.lamp_x, objective.lamp_y)
		if not str(objective.carrier).is_empty(): p.y -= 78
		draw_circle(p, 19 + sin(clock * 3) * 2, Color(0.9, 0.65, 0.22, 0.15))
		if lamp_texture != null: draw_texture_rect(lamp_texture, Rect2(p - Vector2(21, 21), Vector2(42, 42)), false)
		else: draw_circle(p, 9, GOLD)
		if str(objective.carrier).is_empty():
			var contested: bool = objective.get("contested", false)
			var secure: float = float(objective.get("secure_ticks", 0)) / float(Objectives.SECURE_TICKS)
			var color: Color = BLUE if int(objective.get("secure_owner", -1)) == 0 else RED
			if secure > 0: draw_arc(p, 25, -PI * 0.5, -PI * 0.5 + TAU * secure, 40, color, 3, true)
			text(p + Vector2(-43, -32), "CONTESTED" if contested else "SECURE 3s", GOLD, 12)
	if placing and zone.has_point(get_local_mouse_position()):
		var p := get_local_mouse_position()
		draw_arc(p, 18, 0, TAU, 32, BLUE, 2)
		text(p + Vector2(22, -6), selection, BLUE, 14)

func _unit(unit: Dictionary) -> void:
	var a: Dictionary = unit.attributes
	var p := point(a.get("visual_x", a.x_fp), a.get("visual_y", a.y_fp))
	if a.get("hidden", false): return
	var color: Color = BLUE if unit.owner == 0 else RED
	var height: float = unit_height(unit)
	_draw_unit_footprint(p, color, 0.5 if a.get("monster_id", "") == "Varn" else 1.0)
	if not sprites.draw(self, unit, p, height):
		var factor: float = 0.5 if a.get("monster_id", "") == "Varn" else 1.0
		draw_circle(p - Vector2(0, 20 * factor), 15 * factor, color)
	_draw_tumler_charge(unit, p)
	var hp: float = float(a.hp) / float(a.max_hp)
	draw_rect(Rect2(p + Vector2(-19, 7), Vector2(38, 4)), Color("131a17"))
	draw_rect(Rect2(p + Vector2(-19, 7), Vector2(38 * hp, 4)), color)
	if a.armor > 0: draw_rect(Rect2(p + Vector2(-19, 13), Vector2(minf(38, float(a.armor) * 5), 3)), GOLD)
	hits.append({"rect": Rect2(p - Vector2(22, height), Vector2(44, height + 17)), "unit": unit})

static func unit_height(unit: Dictionary, ghost: bool = false) -> float:
	var height: float = 62.0 if ghost else (72.0 if unit.attributes.has("monster_id") else 57.0)
	return height * 0.5 if unit.attributes.get("monster_id", "") == "Varn" else height

func _draw_unit_footprint(p: Vector2, color: Color, factor: float = 1.0) -> void:
	draw_set_transform(p, 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 19 * factor, Color(color, 0.3))
	draw_set_transform(Vector2.ZERO)

func construction_hint(a: Dictionary) -> String:
	if a.get("suit", "") != "Wright" or a.get("wright_built", false): return ""
	var progress_ticks: int = int(a.get("wright_progress", 0)) * 3 + int(a.get("wright_build_subtick", 0))
	return "\nConstruction: %.1f / 7.2s at the site. Repairs unchanged." % (float(progress_ticks) * 0.075)

func _layout_hourglass() -> void:
	if hourglass.get_parent() != self: return
	hourglass.position = Vector2((size.x - 94 * 0.65) * 0.5, 0)

func travel_rect(_lane: String) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(field().size.y, field().size.x)) if _fort_local else field()

func beam_bounds(_lane: String) -> Rect2:
	return field()

func _monster_point(a: Dictionary) -> Vector2:
	return Vector2.ZERO if _fort_local else point(float(a.get("visual_x", a.x_fp)), float(a.get("visual_y", a.y_fp)))

func unit_sprite_height(unit: Dictionary) -> float:
	return unit_height(unit)

func uses_sprite(_unit_record: Dictionary) -> bool:
	return true

func kopita_pulse_outline(attack: Dictionary, fraction: float = 1.0) -> PackedVector2Array:
	return _field_outline(attack.source, float(attack.range_fp) * fraction)

func _field_outline(center_attributes: Dictionary, radius: float) -> PackedVector2Array:
	var bounds := field()
	var center := _monster_point(center_attributes)
	var extent := bounds.size / Vector2(2400, 600) * radius
	var points := PackedVector2Array()
	for i in range(64):
		var angle: float = TAU * float(i) / 64.0
		points.append(center + Vector2(cos(angle), sin(angle)) * extent)
	var border := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	var clipped := Geometry2D.intersect_polygons(points, border)
	if clipped.is_empty(): return PackedVector2Array()
	var outline: PackedVector2Array = clipped[0]
	outline.append(outline[0])
	return outline

func _draw_horizontal_fields() -> void:
	for record in monster_fields:
		if record.kind != "pool": continue
		var outline := _field_outline(record, 200.0)
		if outline.size() < 4: continue
		draw_colored_polygon(outline, Color(0.20, 0.30, 0.09, 0.42))
		draw_polyline(outline, Color(0.48, 0.56, 0.21, 0.55), 1.2, true)

func _draw_monster_attacks() -> void:
	# The shared renderer handles beams, pulses, dash echoes and impact assets.
	# Dotra's radial wave also needs the horizontal coordinate projection.
	var original := monster_attacks
	monster_attacks = original.filter(func(a): return a.ability != "DotraExpose")
	super._draw_monster_attacks()
	monster_attacks = original
	for attack in original:
		if attack.ability != "DotraExpose": continue
		var weight: float = float(attack.get("weight", 0.0))
		var outline := _field_outline(attack.source, float(attack.range_fp) * (0.15 + weight * 0.85))
		if outline.size() < 4: continue
		draw_colored_polygon(outline, Color(0.60, 0.24, 0.15, 0.16 * (1.0 - weight)))
		draw_polyline(outline, Color(ExposureVisuals.COLOR, 1.0 - weight), 2.2, true)

func _draw_fortifications() -> void:
	# Reuse the actual Wright masonry. Walls turn across the road; towers stay upright.
	for row in field_structures:
		var a: Dictionary = row.attributes
		var center := _monster_point(a)
		var angle: float = PI * 0.5 if a.structure == "Wall" else 0.0
		_fort_local = true
		draw_set_transform(center, angle)
		fortification_visual.draw(self, a.lane, [row], [])
		var local_rect: Rect2 = fortification_visual.footprint(self, row).grow(7)
		draw_set_transform(Vector2.ZERO)
		_fort_local = false
		hits.append({"rect": Transform2D(angle, center) * local_rect, "unit": row})
	for unit in units:
		var a: Dictionary = unit.attributes
		if not a.has("wright_site") or a.get("wright_built", false): continue
		var site: Dictionary = fortification_visual.Fort.site_point(unit.owner, a.wright_site)
		var center := point(site.x_fp, site.y_fp)
		var display_unit: Dictionary = unit.duplicate(true)
		display_unit.attributes.wright_progress = float(a.get("wright_progress", 0)) + float(a.get("wright_build_subtick", 0)) / 3.0
		_fort_local = true
		draw_set_transform(center, 0.0 if a.wright_site == 2 else PI * 0.5)
		fortification_visual.draw(self, a.lane, [], [display_unit])
		draw_set_transform(Vector2.ZERO)
		_fort_local = false

# The shared dash trail, with facing measured along this horizontal road.
func _draw_muno_dash(attack: Dictionary, target: Vector2) -> void:
	var elapsed: float = attack.elapsed
	var impact_age: float = elapsed - float(attack.impact_at)
	if impact_age >= 0.0 and impact_age < 0.12:
		var flash: float = 1.0 - impact_age / 0.12
		draw_line(target + Vector2(-8, 9), target + Vector2(8, -9), Color(0.85, 0.91, 1.0, flash), 2.5, true)
	if not attack.get("ward_active", true): return
	var playback_script = preload("res://Prototype/U13/U13SmokePlayback.gd")
	var retreat_start: float = float(attack.impact_at) + playback_script.MUNO_STRIKE_HOLD
	var home: Vector2 = attack.get("return_point", Vector2(attack.source.x_fp, attack.source.y_fp))
	var unit: Dictionary = {"id": attack.source_id, "owner": attack.source_owner, "attributes": attack.source.duplicate(true)}
	unit.attributes["visual_muno_face_left"] = attack.target.x_fp < attack.source.x_fp if attack.target.x_fp != attack.source.x_fp else attack.source_owner == 1
	for i in range(5, 0, -1):
		var age: float = float(i) * 0.032
		var trail_time: float = elapsed - age
		if trail_time < retreat_start or trail_time > float(attack.return_at): continue
		var point: Vector2 = playback_script.muno_position(attack, trail_time, home)
		unit.attributes["visual_x"] = point.x
		unit.attributes["visual_y"] = point.y
		var feet: Vector2 = _monster_point(unit.attributes)
		var tint := Color(0.62, 0.40, 1.0, 0.46 * (1.0 - age / 0.19))
		if uses_sprite(unit) and sprite_visuals.draw_afterimage(self, unit, feet, unit_sprite_height(unit), tint): continue
		# Token mode keeps the same dash, with quiet token-shaped echoes.
		draw_circle(feet, CHIT_DIAMETER * 0.5, tint)


