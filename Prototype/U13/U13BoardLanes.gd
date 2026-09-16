extends "res://Prototype/U13/U13SmokeBoard.gd"

# UI2 MarchingLaneView's right rail geometry and original frame/domain crops.
# Positions come exclusively from the U13 playback tape, never the U12 simulator.
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const ScorchVisuals = preload("res://Prototype/U13/U13ScorchVisuals.gd")
var scorch_visuals = ScorchVisuals.new()
const Feedback = preload("res://Prototype/U13/U13MarcherFeedback.gd")
var feedback = Feedback.new()
var projectiles: Array = []
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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


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
		var index: int = 0
		for unit in _units:
			if unit.id not in _clash or deaths.seen.has(unit.id):
				continue
			_draw_chit(unit, Vector2(54 + (index % 4) * 56, 205))
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
		var top: float = rect.position.y + 65
		var bottom: float = rect.end.y - 52
		var ordered: Array = _units.duplicate()
		ordered.sort_custom(func(a: Dictionary, b: Dictionary):
			var ax := SpriteVisuals.position_of(a).x
			var bx := SpriteVisuals.position_of(b).x
			return ax > bx if ax != bx else String(a.id) < String(b.id))
		for unit in ordered:
			var a: Dictionary = unit.attributes
			if a.lane != lane or deaths.seen.has(unit.id):
				continue
			# Global x=0 is the human end (bottom), x=2400 the enemy end (top).
			var y: float = lerpf(
				bottom, top, clampf(float(a.get("visual_x", a.x_fp)) / 2400.0, 0, 1)
			)
			# Both axes are recorded game positions; no per-frame scatter or packing.
			var lateral: float = clampf(float(a.get("visual_y", a.y_fp)) / 600.0, 0, 1)
			var center := Vector2(rect.position.x + rect.size.x * lateral, y)
			_draw_chit(unit, center)
			if a.waiting:
				draw_string(
					font,
					center + Vector2(-17, -sprite_height - 5),
					"SUPPLICANT",
					HORIZONTAL_ALIGNMENT_LEFT,
					45,
					11
				)

	projectile_visual.draw(self, projectiles)
	deaths.draw(self)
	draw_string(font, Vector2(size.x * 0.5 - 38, size.y - 7), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HEALTH_RING_COLOR)
	draw_string(font, Vector2(size.x * 0.5 + 4, size.y - 7), "ARMOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ARMOR_RING_COLOR)


var paradox_glitches: Dictionary = {}
const ParadoxTiming = preload("res://Prototype/U13/U13ParadoxTiming.gd")


func _draw_chit(unit: Dictionary, center: Vector2, flash: bool = false) -> void:
	var attributes: Dictionary = unit.attributes
	var tint: Color = BLUE if unit.owner == 0 else RED
	var glitch: Dictionary = paradox_glitches.get(unit.id, {})
	var drawn := sprite_visuals.draw(self, unit, center, sprite_height, glitch, flash)
	var fallback_character: String = "" if drawn else SpriteVisuals.Catalog.character_for(unit)
	if not drawn and chit_sheet != null and fallback_character in ["Butcher", "Penitent", "Vulture", "Wright"]:
		# UI2 atlas: Butcher/Penitent/Vulture/Wright columns, human/enemy rows.
		var column: int = int(
			{"Butcher": 0, "Penitent": 1, "Vulture": 2, "Wright": 3}.get(fallback_character, 0)
		)
		var cell: Vector2 = chit_sheet.get_size() / Vector2(4.0, 2.0)
		var row: float = 0.0 if unit.owner == 0 else 1.0
		ParadoxTiming.draw_slices(self, chit_sheet,
			Rect2(center - Vector2(22, 22), Vector2(44, 44)),
			Rect2(Vector2(float(column), row) * cell, cell),
			float(glitch.get("amount", 0.0)), int(glitch.get("tick", 0)))
		if flash:
			draw_texture_rect_region(chit_sheet, Rect2(center - Vector2(22, 22), Vector2(44, 44)), Rect2(Vector2(float(column), row) * cell, cell), Color(4, 4, 4, 1))
	elif not drawn:
		# Unknown future types remain visible without being mislabeled Butchers.
		draw_circle(center - Vector2(0, 12), 12, tint)
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, -7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
	rout_visuals.draw_chit(self, String(unit.id), center - Vector2(0, sprite_height * 0.45 if drawn else 0.0))
	_draw_unit_rings(unit, center, tint, drawn)


func _draw_unit_rings(unit: Dictionary, center: Vector2, owner_color: Color, sprite: bool) -> void:
	var segments := sprite_visuals.health_segments(unit, void_active)
	var outer_radius := 20.0 if sprite else 27.0
	var inner_radius := 15.0 if sprite else 22.0
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
	if not sprite_visuals.draw(self, unit, center, sprite_height,
		paradox_glitches.get(unit.id, {}), blink, age) and blink:
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
	projectiles = []
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


func show_world(entities: Array, round_number: int) -> void:
	projectiles = []
	deaths.observe(_units, entities)
	super.show_world(entities, round_number)
	sprite_visuals.sync(_units, _clash, _round, false)
	set_process(_effects_need_process())

func show_frame(frame: Dictionary, round_number: int) -> void:
	projectiles = frame.get("projectiles", [])
	deaths.observe(_units, frame.units)
	super.show_frame(frame, round_number)
	sprite_visuals.sync(_units, _clash, _round, true)
	set_process(_effects_need_process())

func show_deaths(rows: Array) -> void:
	for row in rows:
		deaths.add(row.unit)
	set_process(_effects_need_process())
