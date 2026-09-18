extends "res://Prototype/U13/U13SmokeBoard.gd"

# UI2 MarchingLaneView's right rail geometry and original frame/domain crops.
# Positions come exclusively from the U13 playback tape, never the U12 simulator.
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const ScorchVisuals = preload("res://Prototype/U13/U13ScorchVisuals.gd")
var scorch_visuals = ScorchVisuals.new()
const Feedback = preload("res://Prototype/U13/U13MarcherFeedback.gd")
var feedback = Feedback.new()
var projectiles: Array = []
var monster_fields: Array = []
var monster_attacks: Array = []
var field_structures: Array = []
var fortification_visual = preload("res://Prototype/U13/U13FortificationVisuals.gd").new()
var quiet_removal_ids: Array = []
var projectile_visual = preload("res://Prototype/U13/U13VultureProjectile.gd").new()
var deaths = preload("res://Prototype/U13/U13MarcherDeathVisual.gd").new()
const BreathVisuals = preload("res://Prototype/U13/U13BreathVisuals.gd")
var breath_visuals = BreathVisuals.new()
var domain: Texture2D
var skin: Texture2D
var chit_sheet: Texture2D
const SpriteVisuals = preload("res://Prototype/U13/U13MarcherSpriteVisuals.gd")
var sprite_visuals = SpriteVisuals.new()
var sprite_height: float = 58.0
const CHIT_DIAMETER: float = 28.0
var regular_sprites: bool = false
var monster_sprites: bool = true
var display_settings_path: String = "user://u13_battlefield_display.cfg"
var regular_display_button: Button
var monster_display_button: Button
const HEALTH_RING_COLOR = Color("a8cb86")
const ARMOR_RING_COLOR = Color("d3ddec")
var void_active: bool = false
var active_auras: Array = []
var active_scorches: Array = []
const WebVisuals = preload("res://Prototype/U13/U13WebVisuals.gd")
var web_visuals = WebVisuals.new()
var active_webs: Array = []


func bind_scorch(records: Array) -> void:
	active_scorches = records.duplicate(true)
	scorch_visuals.sync(records, "lane")
	set_process(_effects_need_process())
	queue_redraw()


func bind_auras(records: Array, round_number: int) -> void:
	breath_visuals.sync(records, round_number)
	set_process(_effects_need_process())
	active_auras = []
	for record in records:
		if not record.get("payload", {}).has("lane_aura"):
			continue
		var remaining: int = int(record.activated_round) + record.stages.size() - round_number
		if remaining > 0:
			active_auras.append(
				{
					"owner": record.declaration.player_id,
					"lane": record.target.lane,
					"remaining": remaining
				}
			)
	queue_redraw()


func _ready() -> void:
	deaths.texture = Art.texture("res://ConceptImages/Sprites/Effects/MarcherDeath.png")
	chit_sheet = Art.texture("res://ConceptImages/Sprites/Chits.png")
	domain = Art.texture("res://ConceptImages/Menus/Domain1.png")
	skin = Art.texture("res://ConceptImages/Menus/Battlefield.png")
	custom_minimum_size = Vector2(290, 600)
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_display_controls()


func _build_display_controls() -> void:
	var config := ConfigFile.new()
	if not display_settings_path.is_empty() and config.load(display_settings_path) == OK:
		regular_sprites = config.get_value("display", "regular_sprites", false) == true
		monster_sprites = config.get_value("display", "monster_sprites", true) == true
	var controls := HBoxContainer.new()
	controls.name = "UnitDisplayControls"
	controls.anchor_right = 1.0
	controls.offset_left = 22.0
	controls.offset_right = -22.0
	controls.offset_top = 123.0
	controls.offset_bottom = 151.0
	controls.add_theme_constant_override("separation", 6)
	add_child(controls)
	regular_display_button = Button.new()
	monster_display_button = Button.new()
	for button in [regular_display_button, monster_display_button]:
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		controls.add_child(button)
	regular_display_button.tooltip_text = "Switch ordinary marchers between the original chits and animated sprites."
	monster_display_button.tooltip_text = "Switch monsters between animated sprites and compact named tokens."
	regular_display_button.toggled.connect(func(enabled: bool): set_display_modes(enabled, monster_sprites, true))
	monster_display_button.toggled.connect(func(enabled: bool): set_display_modes(regular_sprites, enabled, true))
	set_display_modes(regular_sprites, monster_sprites)


func set_display_modes(regular: bool, monsters: bool, persist: bool = false) -> void:
	regular_sprites = regular
	monster_sprites = monsters
	if regular_display_button != null:
		regular_display_button.set_pressed_no_signal(regular)
		regular_display_button.text = "Units: " + ("Sprites" if regular else "Chits")
	if monster_display_button != null:
		monster_display_button.set_pressed_no_signal(monsters)
		monster_display_button.text = "Monsters: " + ("Sprites" if monsters else "Chits")
	if persist and not display_settings_path.is_empty():
		var config := ConfigFile.new()
		config.set_value("display", "regular_sprites", regular)
		config.set_value("display", "monster_sprites", monsters)
		config.save(display_settings_path)
	queue_redraw()


func uses_sprite(unit: Dictionary) -> bool:
	var a: Dictionary = unit.attributes
	return monster_sprites if a.has("monster_id") or a.get("suit") == "Monster" else regular_sprites


func unit_sprite_height(unit: Dictionary) -> float:
	var frame: Dictionary = sprite_visuals.presentation(unit).frame
	if frame.is_empty(): return sprite_height
	# Broad monsters must not span several neighboring bodies. Preserve aspect.
	var max_width: float = clampf(travel_rect(unit.attributes.lane).size.x * 0.28, 40.0, 58.0)
	return minf(sprite_height, max_width * float(frame.body) / float(frame.texture.get_width()))


func _get_tooltip(at: Vector2) -> String:
	for unit in _units:
		if unit.attributes.get("hidden", false) or deaths.seen.has(unit.id): continue
		var center: Vector2 = _monster_point(unit.attributes)
		var height: float = unit_sprite_height(unit) if uses_sprite(unit) else CHIT_DIAMETER
		var area := Rect2(center - Vector2(24, height if uses_sprite(unit) else height * 0.5), Vector2(48, height + 12))
		if area.has_point(at):
			var unit_name: String = unit.attributes.get("monster_id", unit.attributes.suit)
			var hp: String = "Obscured" if void_active else "%d/%d" % [unit.attributes.hp, unit.attributes.max_hp]
			var description: String = "%s · %s\nHP %s · Armor %d" % [unit_name, "Yours" if unit.owner == 0 else "Enemy", hp, unit.attributes.armor]
			if unit_name == "Penitent": description += "\n" + preload("res://Scripts/Sim/U13PenitentDefense.gd").DESCRIPTION
			if unit_name == "Wright":
				description += "\n" + preload("res://Scripts/Sim/U13FieldFortifications.gd").DESCRIPTION
				if unit.attributes.has("wright_site"):
					description += "\n" + ("Defending / deployment complete" if unit.attributes.get("wright_built", false) else "Building %s · %d/32" % ["tower" if unit.attributes.wright_site == 2 else "wall", unit.attributes.wright_progress])
			return description
	for row in field_structures:
		if fortification_visual.footprint(self, row).has_point(at):
			return "%s · %s\nHP %d/%d · Armor %d%s" % [row.attributes.structure, "Yours" if row.owner == 0 else "Enemy", row.attributes.hp, row.attributes.max_hp, row.attributes.armor, "\n1 attack · range 600 · fires every 32 ticks" if row.attributes.structure == "Tower" else "\nBlocks enemies; allies can pass."]
	return ""


func _scenery(rect: Rect2, crop: Rect2) -> void:
	if domain != null:
		var dimensions: Vector2 = domain.get_size()
		draw_texture_rect_region(
			domain, rect, Rect2(crop.position * dimensions, crop.size * dimensions)
		)
		draw_rect(rect, Color(0, 0, 0, 0.50))


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
		var fighters: Array = _units.filter(func(unit): return unit.id in _clash and not deaths.seen.has(unit.id))
		var index: int = 0
		for unit in fighters:
			_draw_chit(unit, Vector2(22 + (size.x - 44) * (float(index) + 0.5) / maxf(1, fighters.size()), 221), false, true)
			index += 1
	draw_string(font, Vector2(18, 250), action, HORIZONTAL_ALIGNMENT_CENTER, size.x - 36, 12, MUTED)
	# One continuous battlefield surface; only the lane boundary divides it.
	var field_rect := Rect2(16, 279, size.x - 32, size.y - 303)
	_scenery(field_rect, Rect2(0.36, 0.10, 0.24, 0.82))
	draw_line(
		Vector2(size.x * 0.5, field_rect.position.y),
		Vector2(size.x * 0.5, field_rect.end.y),
		Color("625234"),
		2
	)
	for lane_index in range(2):
		var lane: String = "Lord" if lane_index == 0 else "Castle"
		var width: float = (size.x - 37) / 2.0
		var rect := Rect2(16 + lane_index * (width + 5), 279, width, size.y - 303)
		for aura in active_auras:
			if aura.lane != lane:
				continue
			var tint: Color = Color("9fddb5") if aura.owner == 0 else Color("efada5")
			draw_rect(rect, Color(tint, 0.08))
			draw_string(
				font,
				Vector2(rect.position.x, rect.end.y - (25 if aura.owner == 0 else 12)),
				"%s BREATH · %dr" % ["YOUR" if aura.owner == 0 else "ENEMY", aura.remaining],
				HORIZONTAL_ALIGNMENT_CENTER,
				width,
				10,
				tint
			)
		draw_string(
			font,
			Vector2(rect.position.x, rect.position.y + 20),
			lane.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER,
			width,
			13,
			Color("ebdab4")
		)
		for player_id in [0, 1]:
			var notes: Array[String] = []
			for scorch in active_scorches:
				if (
					scorch.owner != player_id
					or scorch.target.kind != "lane"
					or scorch.target.lane != lane
				):
					continue
				if scorch.fire_round == 0:
					draw_rect(rect, Color(0.9, 0.22, 0.04, 0.055 * float(scorch.intensity)))
					notes.append("%d · %dr" % [scorch.intensity, scorch.remaining])
				else:
					draw_rect(rect.grow(-3), Color(1.0, 0.60, 0.22, 0.7), false, 1.5)
					notes.append("R%d→" % scorch.fire_round)
			if not notes.is_empty():
				draw_string(
					font,
					Vector2(rect.position.x, rect.position.y + (35 if player_id == 0 else 48)),
					("Y FIRE " if player_id == 0 else "E FIRE ") + " / ".join(notes),
					HORIZONTAL_ALIGNMENT_CENTER,
					width,
					10,
					Color("ffb26e")
				)
		scorch_visuals.draw_area(
			self, Rect2(rect.position.x, rect.position.y + 55, rect.size.x, rect.size.y - 85), lane
		)
		breath_visuals.draw_lane(
			self, Rect2(rect.position.x, rect.position.y + 55, rect.size.x, rect.size.y - 85), lane
		)
		for web in active_webs:
			if web.target.lane == lane:
				var travel_rect := Rect2(
					rect.position.x, rect.position.y + 65, rect.size.x, rect.size.y - 117
				)
				web_visuals.draw_area(
					self,
					WebVisuals.region_rect(
						travel_rect,
						web.target.field_position,
						int(web.payload.spatial_field.radius_fp)
					),
					travel_rect,
					_round > int(web.activated_round)
				)
		_draw_monster_fields(lane)
		fortification_visual.draw(self, lane, field_structures, _units)
		var ordered: Array = _units.duplicate()
		ordered.sort_custom(func(a: Dictionary, b: Dictionary):
			var ax := SpriteVisuals.position_of(a).x
			var bx := SpriteVisuals.position_of(b).x
			return ax > bx if ax != bx else String(a.id) < String(b.id))
		for unit in ordered:
			var a: Dictionary = unit.attributes
			if a.lane != lane or deaths.seen.has(unit.id):
				continue
			# One mapping for bodies, hit positions, structures and projectiles.
			var center: Vector2 = _monster_point(a)
			_draw_chit(unit, center)
			if a.waiting:
				draw_string(
					font,
					center + Vector2(-17, -unit_sprite_height(unit) - 5 if uses_sprite(unit) else -22),
					"SUPPLICANT",
					HORIZONTAL_ALIGNMENT_LEFT,
					45,
					11
				)

	_draw_monster_attacks()
	projectile_visual.draw(self, projectiles)
	deaths.draw(self)
	draw_string(font, Vector2(size.x * 0.5 - 38, size.y - 7), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HEALTH_RING_COLOR)
	draw_string(font, Vector2(size.x * 0.5 + 4, size.y - 7), "ARMOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ARMOR_RING_COLOR)


var paradox_glitches: Dictionary = {}
const ParadoxTiming = preload("res://Prototype/U13/U13ParadoxTiming.gd")


func _draw_chit(unit: Dictionary, center: Vector2, flash: bool = false, close_up: bool = false) -> void:
	var attributes: Dictionary = unit.attributes
	var tint: Color = BLUE if unit.owner == 0 else RED
	if attributes.get("hidden", false):
		if unit.owner == 0: draw_arc(center, 9, 0, TAU, 24, Color(tint, 0.35), 1.0)
		return
	var glitch: Dictionary = paradox_glitches.get(unit.id, {})
	var height: float = 64.0 if close_up else unit_sprite_height(unit)
	var drawn: bool = (close_up or uses_sprite(unit)) and sprite_visuals.draw(self, unit, center, height, glitch, flash)
	var fallback_character: String = "" if drawn else SpriteVisuals.Catalog.character_for(unit)
	var diameter: float = 36.0 if close_up else CHIT_DIAMETER
	var chit_rect := Rect2(center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)
	var brightness: float = maxf(float(sprite_visuals.presentation(unit).flash), 1.0 if flash else 0.0)
	if not drawn and chit_sheet != null and fallback_character in ["Butcher", "Penitent", "Vulture", "Wright"]:
		# UI2 atlas: Butcher/Penitent/Vulture/Wright columns, human/enemy rows.
		var column: int = int(
			{"Butcher": 0, "Penitent": 1, "Vulture": 2, "Wright": 3}.get(fallback_character, 0)
		)
		var cell: Vector2 = chit_sheet.get_size() / Vector2(4.0, 2.0)
		var row: float = 0.0 if unit.owner == 0 else 1.0
		ParadoxTiming.draw_slices(self, chit_sheet,
			chit_rect,
			Rect2(Vector2(float(column), row) * cell, cell),
			float(glitch.get("amount", 0.0)), int(glitch.get("tick", 0)))
		if brightness > 0.0:
			draw_texture_rect_region(chit_sheet, chit_rect, Rect2(Vector2(float(column), row) * cell, cell), Color(1 + brightness * 3, 1 + brightness * 3, 1 + brightness * 3, 1))
	elif not drawn:
		# Monster chits have distinct two-letter names; hover gives the full name.
		var unit_name: String = attributes.get("monster_id", "?")
		draw_circle(center, diameter * 0.5, Color("302b25").lerp(Color.WHITE, brightness * 0.5))
		draw_string(ThemeDB.fallback_font, center + Vector2(-diameter * 0.5, 4), unit_name.left(2).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, diameter, 11, Color("eed8ad"))
	rout_visuals.draw_chit(self, String(unit.id), center - Vector2(0, height * 0.45 if drawn else 0.0))
	_draw_unit_rings(unit, center, tint, drawn)


func _draw_unit_rings(unit: Dictionary, center: Vector2, owner_color: Color, sprite: bool) -> void:
	var segments := sprite_visuals.health_segments(unit, void_active)
	var outer_radius := 20.0 if sprite else 18.0
	var inner_radius := 15.0
	draw_set_transform(center, 0.0, Vector2(1.0, 0.45 if sprite else 1.0))
	# Ownership stays readable even when both defensive pools are nearly empty.
	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 48, owner_color, 1.5, true)
	draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 48, Color("302e29"), 3.0, true)
	if segments.hp > 0.0:
		draw_arc(Vector2.ZERO, inner_radius, -PI / 2.0, -PI / 2.0 + TAU * segments.hp, 48, HEALTH_RING_COLOR, 3.0, true)
	if segments.armor > 0.0:
		var start: float = -PI / 2.0 + TAU * segments.armor_start
		draw_arc(Vector2.ZERO, inner_radius, start, start + TAU * segments.armor, 48, ARMOR_RING_COLOR, 3.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_marcher_death(unit: Dictionary, center: Vector2, age: float) -> void:
	var blink: bool = age < deaths.FLASH_DURATION and int(age / 0.05) % 2 == 0
	if uses_sprite(unit):
		if sprite_visuals.draw(self, unit, center, unit_sprite_height(unit), paradox_glitches.get(unit.id, {}), blink, age): return
	if blink:
		_draw_chit(unit, center, true)


signal lane_selected(lane: String)
var target_lane_enabled: bool = false
var _lane_pulses: Array = []


func _gui_input(event: InputEvent) -> void:
	if (
		target_lane_enabled
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		if event.position.y >= 279 and event.position.y <= size.y - 24:
			accept_event()
			lane_selected.emit("Lord" if event.position.x < size.x * 0.5 else "Castle")


func pulse_lanes(selected_lane: String = "") -> void:
	for marker in _lane_pulses:
		if is_instance_valid(marker):
			marker.hide()
			marker.queue_free()
	_lane_pulses = []
	for index in range(2):
		if not selected_lane.is_empty() and selected_lane != ("Lord" if index == 0 else "Castle"):
			continue
		var marker := ColorRect.new()
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.color = Color(0.95, 0.76, 0.33, 0.32 if selected_lane.is_empty() else 0.5)
		marker.position = Vector2(16 + float(index) * (size.x - 32) * 0.5, 279)
		marker.size = Vector2((size.x - 32) * 0.5, size.y - 303)
		add_child(marker)
		_lane_pulses.append(marker)
		var tween = marker.create_tween()
		tween.tween_property(marker, "color:a", 0.0, 0.7)
		tween.tween_callback(marker.queue_free)


func reset_effects() -> void:
	field_structures = []
	projectiles = []
	monster_fields = []
	monster_attacks = []
	quiet_removal_ids = []
	deaths.clear()
	_units = []
	_clash = []
	sprite_visuals.clear()
	rout_visuals.clear()
	scorch_visuals.clear()
	feedback.clear()
	breath_visuals.clear()
	active_auras = []
	active_scorches = []
	active_webs = []
	queue_redraw()


func _effects_need_process() -> bool:
	return (
		not sprite_visuals.subjects.is_empty()
		or not deaths.visible.is_empty()
		or not active_webs.is_empty()
		or breath_visuals.textures.size() < 5
		or scorch_visuals.textures.size() < 3
		or not breath_visuals.groups.is_empty()
		or not scorch_visuals.groups.is_empty()
		or not feedback.visible.is_empty()
		or not rout_visuals.subjects.is_empty()
	)


func _process(delta: float) -> void:
	sprite_visuals.advance(delta)
	# Keep the initial warm-up at one asset per frame across both effects.
	if breath_visuals.textures.size() < 5:
		breath_visuals.warm_next()
	else:
		scorch_visuals.warm_next()
	if not active_webs.is_empty():
		web_visuals.warm_next()
		web_visuals.advance(delta)
	breath_visuals.advance(delta)
	scorch_visuals.advance(delta)
	feedback.advance(delta)
	deaths.advance(delta)
	rout_visuals.advance(delta)
	queue_redraw()
	if not _effects_need_process():
		set_process(false)


func show_feedback(rows: Array) -> void:
	feedback.show_rows(rows)
	sprite_visuals.hit(rows)
	if not feedback.visible.is_empty():
		set_process(true)
		queue_redraw()


func clear_feedback() -> void:
	feedback.clear()
	queue_redraw()


func flash_scorch(effect_id: String) -> void:
	scorch_visuals.flash(effect_id)
	if not scorch_visuals.groups.is_empty():
		set_process(true)
		queue_redraw()


func bind_webs(records: Array) -> void:
	active_webs = []
	for record in records:
		if record.get("payload", {}).get("spatial_field", {}).get("kind") == "web":
			active_webs.append(record.duplicate(true))
	set_process(_effects_need_process())
	queue_redraw()


# One geometry contract for sprite feet, projectiles and live spatial targeting.
func travel_rect(lane: String) -> Rect2:
	var width: float = (size.x - 37) / 2.0
	return Rect2(16 + (width + 5) * (1 if lane == "Castle" else 0), 344, width, maxf(1, size.y - 420))


func show_world(entities: Array, round_number: int, structures: Array = []) -> void:
	field_structures = structures.duplicate(true)
	projectiles = []
	monster_attacks = []
	deaths.observe(_units.filter(func(u): return u.id not in quiet_removal_ids), entities)
	super.show_world(entities, round_number)
	sprite_visuals.sync(_units, _clash, _round, false)
	set_process(_effects_need_process())

func show_frame(frame: Dictionary, round_number: int) -> void:
	field_structures = frame.get("field_structures", []).duplicate(true)
	projectiles = frame.get("projectiles", [])
	monster_fields = frame.get("monster_fields", [])
	monster_attacks = frame.get("monster_attacks", [])
	for id in frame.get("banished_ids", []):
		if id not in quiet_removal_ids: quiet_removal_ids.append(id)
	deaths.observe(_units.filter(func(u): return u.id not in quiet_removal_ids), frame.units)
	super.show_frame(frame, round_number)
	sprite_visuals.sync(_units, _clash, _round, true)
	set_process(_effects_need_process())

func show_deaths(rows: Array) -> void:
	for row in rows:
		deaths.add(row.unit)
	set_process(_effects_need_process())

func _monster_point(a: Dictionary) -> Vector2:
	var rect: Rect2 = travel_rect(a.lane)
	return rect.position + Vector2(float(a.get("visual_y", a.y_fp)) / 600.0, 1.0 - float(a.get("visual_x", a.x_fp)) / 2400.0) * rect.size

func _draw_monster_fields(lane: String) -> void:
	var rect: Rect2 = travel_rect(lane)
	for field in monster_fields:
		if field.lane != lane: continue
		var center: Vector2 = _monster_point(field)
		var radius: float = 100.0 if field.kind == "portal" else 200.0
		var points := PackedVector2Array()
		for i in range(49):
			var angle: float = TAU * float(i) / 48.0
			points.append(center + Vector2(cos(angle) * radius / 600.0 * rect.size.x, sin(angle) * radius / 2400.0 * rect.size.y))
		if field.kind == "pool":
			draw_colored_polygon(points, Color(0.20, 0.30, 0.09, 0.42))
			draw_polyline(points, Color(0.48, 0.56, 0.21, 0.55), 1.2, true)
		else:
			draw_colored_polygon(points, Color(0.035, 0.01, 0.075, 0.95))
			draw_polyline(points, Color(0.52, 0.28, 0.85, 0.70), 4.0, true)
			draw_polyline(points, Color(0.45, 0.70, 1.0, 0.9), 1.0, true)

func _attack_point(attributes: Dictionary, identity: String, owner: int) -> Vector2:
	var unit: Dictionary = {"id": identity, "owner": owner, "attributes": attributes}
	var height: float = unit_sprite_height(unit) * 0.55 if uses_sprite(unit) else 0.0
	return _monster_point(attributes) - Vector2(0, height)


func beam_bounds(lane: String) -> Rect2:
	var rect: Rect2 = travel_rect(lane)
	return Rect2(rect.position.x, 310, rect.size.x, size.y - 334)


func beam_points(attack: Dictionary) -> PackedVector2Array:
	var origin := _attack_point(attack.source, attack.get("source_id", ""), attack.get("source_owner", 0))
	var target := _attack_point(attack.target, attack.get("target_id", ""), attack.get("target_owner", 1))
	if attack.get("ground", false):
		origin = _monster_point(attack.source)
		target = _monster_point(attack.target)
	var reach: float = float(attack.get("range_fp", 0))
	if reach > 0.0:
		var delta := Vector2(float(attack.target.x_fp) - float(attack.source.x_fp), float(attack.target.y_fp) - float(attack.source.y_fp))
		target = origin + (target - origin) * reach / maxf(1.0, delta.length())
	# Clip the visible ray at its own lane's edge, without changing game positions.
	var bounds: Rect2 = beam_bounds(attack.source.lane)
	var ray := target - origin
	var fraction: float = 1.0
	if ray.x > 0: fraction = minf(fraction, (bounds.end.x - origin.x) / ray.x)
	elif ray.x < 0: fraction = minf(fraction, (bounds.position.x - origin.x) / ray.x)
	if ray.y > 0: fraction = minf(fraction, (bounds.end.y - origin.y) / ray.y)
	elif ray.y < 0: fraction = minf(fraction, (bounds.position.y - origin.y) / ray.y)
	return PackedVector2Array([origin, origin + ray * clampf(fraction, 0.0, 1.0)])


func _draw_monster_attacks() -> void:
	for attack in monster_attacks:
		var a := _attack_point(attack.source, attack.get("source_id", ""), attack.get("source_owner", 0))
		var b := _attack_point(attack.target, attack.get("target_id", ""), attack.get("target_owner", 1))
		if attack.ability == "RangedBlock":
			# A brief shield glint works for both chits and sprites, without labels.
			var fade: float = 1.0 - float(attack.get("weight", 0.0))
			var shield := PackedVector2Array([b + Vector2(-9, -8), b + Vector2(0, -11), b + Vector2(9, -8), b + Vector2(7, 3), b + Vector2(0, 10), b + Vector2(-7, 3), b + Vector2(-9, -8)])
			draw_colored_polygon(shield, Color(0.75, 0.84, 1.0, 0.25 * fade))
			draw_polyline(shield, Color(0.93, 0.96, 1.0, fade), 2.0, true)
			draw_line(b + Vector2(-4, -1), b + Vector2(4, -1), Color(1.0, 0.90, 0.65, fade), 2.0, true)
		elif attack.ability == "BeamCharge":
			var charge: float = float(attack.weight)
			var radius: float = lerpf(3.0, 10.0, charge)
			draw_circle(a, radius * 1.8, Color(0.08, 0.38, 1.0, 0.10 + 0.18 * charge))
			draw_circle(a, radius, Color(0.20, 0.64, 1.0, 0.35 + 0.45 * charge))
			draw_circle(a, radius * 0.4, Color(0.90, 0.98, 1.0, charge))
			# Tightening sparks gather into the eye; the laser appears on release.
			for i in range(6):
				var angle: float = TAU * float(i) / 6.0 + charge * 1.5
				var direction := Vector2(cos(angle), sin(angle))
				var reach: float = lerpf(23.0, 11.0, charge)
				draw_line(a + direction * reach, a + direction * (reach - 4.0), Color(0.35, 0.76, 1.0, 0.3 + charge * 0.6), 1.5, true)
		elif attack.ability == "Beam":
			var points := beam_points(attack)
			var weight: float = float(attack.get("weight", 0.0))
			var pulse: float = 1.0 - smoothstep(0.45, 1.0, weight)
			var head: Vector2 = points[0].lerp(points[1], clampf(weight / 0.35, 0.0, 1.0))
			draw_line(a, head, Color(0.07, 0.35, 1.0, 0.28 * pulse), 10.0, true)
			draw_line(a, head, Color(0.35, 0.78, 1.0, 0.95 * pulse), 3.5, true)
			draw_line(a, head, Color(0.95, 1.0, 1.0, pulse), 1.3, true)
			draw_circle(head, 5.0, Color(0.78, 0.94, 1.0, pulse))
		elif attack.ability == "BeamTrail":
			var points := beam_points(attack)
			draw_line(points[0], points[1], Color(0.03, 0.10, 0.18, 0.65), 5.0, true)
			draw_line(points[0], points[1], Color(0.28, 0.69, 1.0, 0.45), 1.2, true)
		elif attack.ability == "BeamBlast":
			_draw_beam_blast(attack)
		elif attack.ability == "Muno":
			draw_line(a, b, Color(0.55, 0.84, 0.95, 0.55), 1.5, true)
			draw_line(b + Vector2(-8, 9), b + Vector2(8, -9), Color(0.83, 0.94, 1.0, 0.85), 2.0, true)
		elif attack.ability == "Ambush":
			for i in range(3): draw_line(b + Vector2(-8 + i * 5, 8), b + Vector2(-3 + i * 5, -9), Color(0.9, 0.63, 0.42, 0.8), 1.5, true)


func _draw_beam_blast(attack: Dictionary) -> void:
	var points := beam_points(attack)
	var weight: float = float(attack.get("weight", 0.0))
	var count: int = clampi(ceili(points[0].distance_to(points[1]) / 38.0), 3, 18)
	# Small eruptions follow the locked ground scar. Damage flashes on the
	# recorded casualties at detonation; the smoke and plumes dissipate after.
	draw_line(points[0], points[1], Color(0.05, 0.15, 0.23, 0.7 * (1.0 - weight)), 6.0, true)
	for i in range(1, count + 1):
		var along: float = float(i) / float(count)
		var age: float = (weight - along * 0.18) / 0.82
		if age < 0.0: continue
		var p: Vector2 = points[0].lerp(points[1], along)
		var fade: float = 1.0 - clampf(age, 0.0, 1.0)
		var radius: float = 5.0 + minf(age * 2.0, 1.0) * 15.0
		draw_circle(p - Vector2(0, age * 15.0), radius, Color(0.04, 0.29, 0.92, 0.32 * fade))
		draw_arc(p, radius, PI, TAU, 18, Color(0.31, 0.80, 1.0, fade), 2.2, true)
		for spark in range(3):
			var tip := p + Vector2(float(spark - 1) * radius * 0.4, -radius * (1.2 + float((i + spark) % 3) * 0.3))
			draw_line(p, tip, Color(0.45, 0.80, 1.0, 0.7 * fade), 4.0 * fade + 0.5, true)
			draw_line(p, tip, Color(0.90, 0.99, 1.0, fade), 1.0, true)
	for hit in attack.get("impacts", []):
		if hit.get("blocked", false): continue
		if hit.attributes.get("hidden", false) and hit.owner == 1: continue
		var impact := _monster_point(hit.attributes)
		var flash: float = 1.0 - smoothstep(0.0, 0.55, weight)
		draw_circle(impact, 9.0, Color(0.72, 0.94, 1.0, 0.8 * flash))
