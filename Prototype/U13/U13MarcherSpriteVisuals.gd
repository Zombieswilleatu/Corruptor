extends RefCounted

# Cosmetic state keyed by stable entity IDs. Never writes into recorded units,
# moves their world anchors, allocates per-unit nodes, or consumes match RNG.
const Catalog = preload("res://Prototype/U13/U13MarcherSpriteCatalog.gd")
const Motion = preload("res://Prototype/U13/U13StillSpriteMotion.gd")
const STALE_SECONDS: float = 0.18
var subjects: Dictionary = {}
var clock: float = 0.0
var has_snapshot: bool = false

static func position_of(unit: Dictionary) -> Vector2:
	var a: Dictionary = unit.attributes
	return Vector2(float(a.get("visual_x", a.get("x_fp", 0))), float(a.get("visual_y", a.get("y_fp", 300))))

func sync(units: Array, clash: Array, round_number: int, playback: bool) -> void:
	for state in subjects.values():
		state.present = false
	for unit in units:
		var id: String = unit.id
		var character := Catalog.character_for(unit)
		var point := position_of(unit)
		var a: Dictionary = unit.attributes
		var new_unit: bool = not subjects.has(id)
		var fresh: bool = new_unit or subjects[id].character != character
		if fresh:
			Catalog.assets(character) # Cache extraction outside drawing and per-frame motion.
			var digest := id.sha256_buffer()
			subjects[id] = {"character": character, "position": point, "lane": a.lane,
				"face_left": unit.owner == 1, "facing_y": point.y,
				"phase": float(digest[0]) / 256.0, "hit_age": 10.0,
				"spawn_age": 0.0 if new_unit and has_snapshot else 10.0,
				"attack_age": 10.0, "clashing": false, "moving": false,
				"armor_capacity": maxf(float(a.get("armor", 0)), float(a.get("max_armor", 0))),
				"ranged_tick": maxi(int(a.get("ranged_next_tick", 0)), int(a.get("beam_next_tick", 0))),
				"transform_age": 10.0 if character == "Sooge" and a.get("sprite_form", "") == "turret" else -1.0}
		var state: Dictionary = subjects[id]
		# Retain the meter's capacity so losing Armor empties its segment instead
		# of enlarging the HP segment. Armor grants can expand this cosmetic cap.
		state.armor_capacity = maxf(state.armor_capacity, maxf(float(a.get("armor", 0)), float(a.get("max_armor", 0))))
		var same_lane: bool = state.lane == a.lane
		var ready: bool = not a.get("waiting", false) and int(a.get("movement_ready_round", 0)) <= round_number
		state.moving = playback and not fresh and same_lane and ready and point.distance_squared_to(state.position) > 0.0001
		# Retain facing through vertical movement and teleports. Lateral travel
		# must clear a dead band before turning, so tiny packing shifts do not flicker.
		if state.moving and absf(point.y - float(state.facing_y)) >= 12.0:
			state.face_left = point.y < float(state.facing_y)
			state.facing_y = point.y
		elif not same_lane:
			state.facing_y = point.y
		var clashing: bool = playback and id in clash
		if character == "Sooge" and a.get("sprite_form", "") == "turret": clashing = false
		var shot: bool = playback and not fresh and maxi(int(a.get("ranged_next_tick", 0)), int(a.get("beam_next_tick", 0))) > int(state.ranged_tick)
		if (clashing and not state.clashing) or shot:
			state.attack_age = 0.0
		if not playback:
			state.attack_age = 10.0
		if character == "Sooge" and a.get("sprite_form", "") == "turret" and state.transform_age < 0.0:
			state.transform_age = 0.0
		state.ranged_tick = maxi(int(a.get("ranged_next_tick", 0)), int(a.get("beam_next_tick", 0)))
		state.clashing = clashing
		state.position = point
		state.lane = a.lane
		state.synced = clock
		state.present = true
	# Opening a board/save is not a fresh spawn for every existing marcher.
	has_snapshot = true

func hit(rows: Array) -> void:
	for row in rows:
		if subjects.has(row.id) and (int(row.get("hp", 0)) < 0 or int(row.get("armor", 0)) < 0):
			subjects[row.id].hit_age = 0.0

func advance(delta: float) -> void:
	delta = maxf(0.0, delta)
	clock += delta
	for id in subjects.keys():
		var state: Dictionary = subjects[id]
		state.hit_age += delta
		state.spawn_age += delta
		state.attack_age += delta
		if state.transform_age >= 0.0:
			state.transform_age += delta
		if not state.present and clock - float(state.synced) > 0.8:
			subjects.erase(id)

func clear() -> void:
	subjects.clear()
	clock = 0.0
	has_snapshot = false

func health_segments(unit: Dictionary, obscured: bool = false) -> Dictionary:
	var a: Dictionary = unit.attributes
	var max_hp := maxf(1.0, float(a.get("max_hp", 1)))
	var hp := clampf(float(a.get("hp", 0)) / max_hp, 0.0, 1.0)
	if obscured and hp > 0.0:
		hp = ceilf(hp * 3.0) / 3.0
	var armor := maxf(0.0, float(a.get("armor", 0)))
	var capacity := maxf(armor, maxf(float(a.get("max_armor", 0)),
		float(subjects.get(unit.id, {}).get("armor_capacity", 0.0))))
	var total := max_hp + capacity
	return {"hp": hp * max_hp / total, "armor_start": max_hp / total, "armor": armor / total}

func presentation(unit: Dictionary, death_age: float = -1.0) -> Dictionary:
	var state: Dictionary = subjects.get(unit.id, {})
	var character: String = state.get("character", Catalog.character_for(unit))
	var face_left: bool = state.get("face_left", unit.owner == 1)
	if unit.attributes.has("visual_muno_face_left"): face_left = unit.attributes.visual_muno_face_left
	var transform_age: float = state.get("transform_age", 10.0 if character == "Sooge" and unit.attributes.get("sprite_form", "") == "turret" else -1.0)
	var pose_data := Catalog.pose_frame(character, face_left, transform_age)
	var motion := "Idle"
	var time := clock
	var recent := clock - float(state.get("synced", -10.0)) < STALE_SECONDS
	var attacking: bool = float(state.get("attack_age", 10.0)) < 0.9
	if recent and state.get("clashing", false):
		motion = "Attack"
		time = fmod(float(state.attack_age), 0.9)
	elif attacking:
		motion = "Attack"
		time = state.attack_age
	elif float(state.get("hit_age", 10.0)) < 0.43:
		motion = "Hit"
		time = state.hit_age
	elif recent and state.get("moving", false) and transform_age < 0.0:
		motion = "March"
	if transform_age >= 0.0 and transform_age < 0.75:
		motion = "Hold"
	if death_age >= 0.0:
		motion = "Death"
		time = death_age * 1.25 / 0.48 # Match the existing casualty/ghost lifetime.
	elif unit.attributes.has("visual_muno_weight"):
		motion = "Attack"
		time = float(unit.attributes.visual_muno_weight) * 0.6
	var arrival_light := 0.35 * (1.0 - smoothstep(0.0, 0.8, float(state.get("spawn_age", 10.0))))
	return {"frame": pose_data.frame, "mirror": pose_data.mirror, "character": character,
		"face_left": face_left, "motion": motion, "time": time,
		"phase": float(state.get("phase", 0.0)), "rooted": transform_age >= 0.0,
		"flash": maxf(arrival_light, 1.0 - smoothstep(0.035, 0.13, float(state.get("hit_age", 10.0))))}

func draw(canvas: CanvasItem, unit: Dictionary, feet: Vector2, height: float,
		glitch: Dictionary = {}, flash: bool = false, death_age: float = -1.0) -> bool:
	var p := presentation(unit, death_age)
	if p.frame.is_empty():
		return false
	Motion.paint(canvas, p.frame.texture, feet, height, p.face_left, p.motion, p.time,
		p.phase, p.frame.anchor, p.frame.body, p.mirror, p.character, p.rooted,
		{"glitch": glitch, "flash": maxf(float(p.flash), 1.0 if flash else 0.0)})
	return true


func draw_afterimage(canvas: CanvasItem, unit: Dictionary, feet: Vector2, height: float, tint: Color) -> bool:
	var p := presentation(unit)
	if p.frame.is_empty(): return false
	Motion.paint(canvas, p.frame.texture, feet, height, p.face_left, "Hold", 0.0,
		p.phase, p.frame.anchor, p.frame.body, p.mirror, p.character, p.rooted,
		{"tint": tint, "shadow": false})
	return true
