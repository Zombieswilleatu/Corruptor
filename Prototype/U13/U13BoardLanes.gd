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


func _scenery(rect: Rect2, crop: Rect2) -> void:
	if domain != null:
		var dimensions: Vector2 = domain.get_size()
		draw_texture_rect_region(
			domain, rect, Rect2(crop.position * dimensions, crop.size * dimensions)
		)
		draw_rect(rect, Color(0, 0, 0, 0.38))


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
			_draw_chit(unit, Vector2(54 + (index % 4) * 56, 176))
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
		for unit in _units:
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
			if unit.id in _clash:
				draw_arc(center, 26.0, 0.0, TAU, 48, Color("f5d39a"), 2.0, true)
			if a.waiting or a.movement_ready_round > _round:
				draw_string(
					font,
					center + Vector2(-17, -29),
					"WAIT" if a.waiting else "NEW",
					HORIZONTAL_ALIGNMENT_LEFT,
					45,
					11
				)

	_draw_feedback()
	projectile_visual.draw(self, projectiles)
	deaths.draw(self)


var paradox_glitches: Dictionary = {}
const ParadoxTiming = preload("res://Prototype/U13/U13ParadoxTiming.gd")


func _draw_chit(unit: Dictionary, center: Vector2, flash: bool = false) -> void:
	var attributes: Dictionary = unit.attributes
	var tint: Color = BLUE if unit.owner == 0 else RED
	if chit_sheet != null:
		# UI2 atlas: Butcher/Penitent/Vulture/Wright columns, human/enemy rows.
		var column: int = int(
			{"Butcher": 0, "Penitent": 1, "Vulture": 2, "Wright": 3}.get(attributes.suit, 0)
		)
		var cell: Vector2 = chit_sheet.get_size() / Vector2(4.0, 2.0)
		var row: float = 0.0 if unit.owner == 0 else 1.0
		var glitch: Dictionary = paradox_glitches.get(unit.id, {})
		ParadoxTiming.draw_slices(self, chit_sheet,
			Rect2(center - Vector2(22, 22), Vector2(44, 44)),
			Rect2(Vector2(float(column), row) * cell, cell),
			float(glitch.get("amount", 0.0)), int(glitch.get("tick", 0)))
		if flash:
			draw_texture_rect_region(chit_sheet, Rect2(center - Vector2(22, 22), Vector2(44, 44)), Rect2(Vector2(float(column), row) * cell, cell), Color(4, 4, 4, 1))
	rout_visuals.draw_chit(self, String(unit.id), center)
	var health: float = clampf(float(attributes.hp) / maxf(1.0, float(attributes.max_hp)), 0.0, 1.0)
	if void_active and health > 0:
		health = ceilf(health * 3.0) / 3.0
	draw_arc(center, 23.0, 0.0, TAU, 48, Color("302e29"), 3.0, true)
	if health > 0.0:
		draw_arc(center, 23.0, -PI / 2.0, -PI / 2.0 + TAU * health, 48, tint, 3.0, true)


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
		not deaths.visible.is_empty()
		or not active_webs.is_empty()
		or breath_visuals.textures.size() < 5
		or scorch_visuals.textures.size() < 3
		or not breath_visuals.groups.is_empty()
		or not scorch_visuals.groups.is_empty()
		or not feedback.visible.is_empty()
		or not rout_visuals.subjects.is_empty()
	)


func _process(delta: float) -> void:
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
	if not feedback.visible.is_empty():
		set_process(true)
		queue_redraw()


func clear_feedback() -> void:
	feedback.clear()
	queue_redraw()


func _draw_feedback() -> void:
	var anchors: Dictionary = {}
	for unit in _units:
		anchors[unit.id] = Feedback.row(unit, 0, 0)
	var stacks: Dictionary = {}
	for hit in feedback.visible:
		var anchor: Dictionary = anchors.get(hit.id, hit)
		var width: float = (size.x - 37) / 2.0
		var left: float = 16.0 + (width + 5.0) * (0.0 if anchor.lane == "Lord" else 1.0)
		var center := Vector2(
			left + width * clampf(float(anchor.y) / 600.0, 0.0, 1.0),
			lerpf(size.y - 76.0, 344.0, clampf(float(anchor.x) / 2400.0, 0.0, 1.0))
		)
		var stack: int = int(stacks.get(hit.id, 0))
		stacks[hit.id] = stack + 1
		center.x = clampf(center.x, left + 39.0, left + width - 39.0)
		center.y -= 32.0 + float(hit.age) * 25.0 + float(stack) * 45.0
		var alpha: float = clampf((Feedback.LIFETIME - float(hit.age)) / 0.35, 0.0, 1.0)
		if hit.hp != 0:
			_number_text(
				center,
				"%+d" % int(hit.hp),
				Color("8bffae") if hit.hp > 0 else Color("ff7771"),
				alpha,
				22
			)
			center.y += 16.0
		if hit.armor != 0:
			_number_text(center, "%+d ARM" % int(hit.armor), Color("87ceff"), alpha, 14)
			center.y += 13.0
		if not String(hit.source).is_empty():
			_number_text(center, hit.source, Color("eadab9"), alpha, 10)


func _number_text(
	center: Vector2, label: String, tint: Color, alpha: float, font_size: int
) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_position: Vector2 = (
		center
		- Vector2(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5, 0)
	)
	draw_string_outline(
		font,
		text_position,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		4,
		Color(0, 0, 0, alpha)
	)
	draw_string(
		font, text_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(tint, alpha)
	)


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


# One geometry contract for the drawn chits and live spatial targeting.
func travel_rect(lane: String) -> Rect2:
	var width: float = (size.x - 37) / 2.0
	return Rect2(16 + (width + 5) * (1 if lane == "Castle" else 0), 344, width, maxf(1, size.y - 420))


func show_world(entities: Array, round_number: int) -> void:
	projectiles = []
	deaths.observe(_units, entities)
	super.show_world(entities, round_number)
	set_process(_effects_need_process())

func show_frame(frame: Dictionary, round_number: int) -> void:
	projectiles = frame.get("projectiles", [])
	deaths.observe(_units, frame.units)
	super.show_frame(frame, round_number)
	set_process(_effects_need_process())

func show_deaths(rows: Array) -> void:
	for row in rows:
		deaths.add(row.unit)
	set_process(_effects_need_process())
