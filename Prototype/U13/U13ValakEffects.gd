extends Node2D

const Visual = preload("res://Prototype/U13/U13ValakVisual.gd")
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
var sides: Array = []
var battlefield: Control
var energy: Array = []
var orb_visuals: Dictionary = {}
var orb_rows: Array = []
var sequence: Array = []
var elapsed: float = 0.0
var started: bool = false
var impact: Dictionary = {}
var final_counts: Array = [0, 0]
var roster: Array = []


func _ready() -> void:
	z_index = 46
	for pid in [0, 1]:
		var visual = Visual.new()
		add_child(visual)
		energy.append(visual)


func _rect(control: Control) -> Rect2:
	return get_global_transform_with_canvas().affine_inverse() * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func guard_center(pid: int, zone: String) -> Vector2:
	var side = sides[1 - pid]
	return _rect(side.lord_guard_box if zone == "Lord" else side.castle_guard_box).get_center()


func field_point(target: Dictionary) -> Vector2:
	var rect: Rect2 = get_global_transform_with_canvas().affine_inverse() * battlefield.get_global_transform_with_canvas() * battlefield.travel_rect(target.lane)
	return rect.position + Vector2(float(target.field_position.y_fp) / 600.0, 1.0 - float(target.field_position.x_fp) / 2400.0) * rect.size


func bind_world(world: Dictionary) -> void:
	roster = world.get("lord_ids", [])
	final_counts = world.get("life_essence", [0, 0]).duplicate()
	orb_rows = world.get("valak_orbs", []).duplicate(true)
	if not active():
		for pid in [0, 1]:
			energy[pid].set_charges(final_counts[pid])
	_sync_orbs()


func _sync_orbs() -> void:
	var ids: Array = []
	for orb in orb_rows:
		ids.append(orb.id)
		if not orb_visuals.has(orb.id):
			var visual = Visual.new()
			add_child(visual)
			visual.phase = "rotate"
			visual.phase_time = 1.0
			orb_visuals[orb.id] = visual
	for id in orb_visuals.keys():
		if id not in ids:
			orb_visuals[id].queue_free()
			orb_visuals.erase(id)


func play(events: Array) -> void:
	sequence = events.duplicate(true)
	elapsed = 0.0
	started = false
	for pid in [0, 1]:
		for event in sequence:
			if event.type.begins_with("VALAK_") and event.data.player_id == pid:
				energy[pid].set_charges(event.data.before)
				break
	for event in sequence:
		if event.type == "GRAVITY_ORB_STARTED" and orb_visuals.has(event.data.id):
			orb_visuals[event.data.id].hide()


func active() -> bool:
	return not sequence.is_empty()


func clear() -> void:
	sequence = []
	impact = {}
	started = false
	for pid in range(energy.size()):
		energy[pid].clear()
		energy[pid].set_charges(final_counts[pid])
	for visual in orb_visuals.values():
		visual.show()
	queue_redraw()


func advance(delta: float) -> void:
	if sides.size() != 2 or battlefield == null:
		return
	for pid in [0, 1]:
		var visual = energy[pid]
		var card: Rect2 = _rect(sides[1 - pid].lord_card.art)
		visual.staff_position = card.position + card.size * Vector2(0.246, 0.281)
		visual.hover_position = card.position + card.size * Vector2(0.69, 0.48)
		visual.energy_size = card.size.x * 0.18
		visual.energy_step = card.size.x * 0.06
		visual.hover_amount = card.size.x / 60.0
		visual.visible = roster.size() == 2 and roster[pid] == "Valak"
		visual.advance(delta)
	for orb in orb_rows:
		var visual = orb_visuals[orb.id]
		visual.target = field_point(orb.target)
		visual.orb_size = battlefield.travel_rect(orb.target.lane).size.x * 0.42
		visual.advance(delta)
	if not active():
		return
	var event: Dictionary = sequence[0]
	var data: Dictionary = event.data
	var pid: int = int(data.get("player_id", data.get("owner", 0)))
	var visual = energy[pid]
	if not started:
		started = true
		if event.type == "VALAK_ESSENCE_GAINED":
			for charge in range(data.gained):
				visual.absorb_charge(guard_center(int(data.guard.owner), data.guard.attributes.lane))
		elif event.type in ["VALAK_ESSENCE_REINFORCED", "VALAK_PROJECTION_RESOLVED"]:
			# Presentation can send a subset; authoritative spending already happened.
			var target: Vector2 = guard_center(pid, "Lord") if event.type == "VALAK_ESSENCE_REINFORCED" else guard_center(data.target.player_id, data.target.zone)
			visual.projections.append({"origin": visual.hover_point(), "target": target, "charges": data.spent if event.type == "VALAK_ESSENCE_REINFORCED" else data.spend, "age": 0.0})
			visual.set_charges(data.after)
			impact = {"center": target, "whiff": data.get("whiff", false)}
		elif event.type == "GRAVITY_ORB_STARTED" and orb_visuals.has(data.id):
			var orb = orb_visuals[data.id]
			orb.staff_position = visual.staff_position
			orb.show()
			orb.cast(field_point(data.target))
	elapsed += maxf(0.0, delta)
	var duration: float = 1.8 if event.type == "GRAVITY_ORB_STARTED" else 1.0
	if elapsed >= duration:
		if event.type.begins_with("VALAK_"):
			visual.set_charges(data.after)
		sequence.pop_front()
		elapsed = 0.0
		started = false
		impact = {}
		if not active():
			for index in [0, 1]:
				energy[index].set_charges(final_counts[index])
	queue_redraw()


func _draw() -> void:
	if not impact.is_empty() and elapsed >= 0.8:
		draw_arc(impact.center, 12.0 + (elapsed - 0.8) * 180.0, 0, TAU, 48, Color("e3bf6a") if impact.whiff else Color("9dec65"), 3, true)
	if active() and sequence[0].type == "VALAK_PROJECTION_RESOLVED" and elapsed < 0.8:
		var victim: Dictionary = sequence[0].data.victim
		if not victim.is_empty():
			var side = sides[1 - int(victim.owner)]
			var box = side.lord_guard_box if victim.attributes.lane == "Lord" else side.castle_guard_box
			if victim.attributes.slot < box.get_child_count():
				var texture: Texture2D = Art.texture_for(victim.attributes.suit, int(victim.attributes.value))
				if texture != null:
					draw_texture_rect(texture, _rect(box.get_child(victim.attributes.slot)), false)
