extends Control

# Replaceable art hooks. Missing sprites use explicit smoke/lantern placeholders.
@export var smoke_texture: Texture2D
@export var lamp_texture: Texture2D
signal presentation_event(kind: String, details: Dictionary)
var battlefield
var objects: Array = []
var clock: float = 0.0
var claims: Array = []
var playback_time: float = -1.0

func _ready() -> void:
	if lamp_texture == null:
		lamp_texture = preload("res://Prototype/U13/U13BoardTextures.gd").texture("res://ConceptImages/Sprites/Kanifous/Lamp.png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 47

func bind_world(world: Dictionary) -> void:
	objects = world.get("wishmaster_objects", []).duplicate(true)
	queue_redraw()

func play_events(events: Array) -> void:
	claims = []
	for event in events:
		if event.type.begins_with("WISHMASTER_"):
			presentation_event.emit(event.type, event.data.duplicate(true))
		if event.type == "WISHMASTER_LAMP_SPAWNED":
			objects = objects.filter(func(row: Dictionary) -> bool: return row.id != event.data.id)
			objects.append(event.data.duplicate(true))
		if event.type == "WISHMASTER_LAMP_CLAIMED":
			claims.append({"at": (float(event.data.tick) + 1) * 6.0 / 200.0, "id": event.data.lamp_id})
	playback_time = 0.0

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func show_time(at: float) -> void:
	playback_time = at
	for claim in claims:
		if playback_time >= claim.at:
			objects = objects.filter(func(row: Dictionary) -> bool: return row.id != claim.id)
	queue_redraw()

func _draw() -> void:
	if battlefield == null:
		return
	for row in objects:
		var lane: Rect2 = get_global_transform().affine_inverse() * battlefield.get_global_transform() * battlefield.travel_rect(row.target.lane)
		var p: Dictionary = row.target.field_position
		var center: Vector2 = lane.position + Vector2(float(p.y_fp) / 600.0, 1.0 - float(p.x_fp) / 2400.0) * lane.size
		if row.phase == "smoke":
			if smoke_texture != null:
				draw_texture_rect(smoke_texture, Rect2(center - Vector2(24, 36), Vector2(48, 48)), false)
			else:
				for i in range(5):
					var rise: float = fposmod(clock * 0.3 + i * 0.2, 1.0)
					draw_circle(center + Vector2(sin(clock + i) * 9, -rise * 32), 6 + rise * 9, Color(0.6, 0.4, 0.8, (1 - rise) * 0.3))
			draw_string(ThemeDB.fallback_font, center + Vector2(-28, 24), "Lamp R%d" % row.due_round, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("dac2ee"))
		else:
			if lamp_texture != null:
				draw_texture_rect(lamp_texture, Rect2(center - Vector2(32, 32), Vector2(64, 64)), false)
			else:
				draw_circle(center, 12, Color("c9943b"))
				draw_arc(center, 16, 0, TAU, 32, Color("f2dc94"), 2, true)
				draw_line(center + Vector2(8, -2), center + Vector2(22, -8), Color("f2dc94"), 4, true)
