extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Fields = preload("res://Scripts/Sim/U13SpatialFields.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const VERSION: String = "U13_KANIFOUS_V1"
const RADIUS: int = 540
const CONTACT: int = 65
const DEATH_RADIUS: int = 100
const ATTRACTION_RADIUS: int = 180

static func event(kind: String, data: Dictionary) -> Dictionary:
	var fact: Dictionary = {"type": kind, "text": kind.replace("_", " ").capitalize(), "data": data}
	return {"event": fact, "views": [fact, fact]}

static func active(world: Dictionary, pid: int) -> bool:
	for row in world.entities.entities:
		if row.kind == "lord" and row.owner == pid:
			return row.attributes.lord_id == "Kanifous" and row.attributes.alive
	return false

static func draw(seed_value: String, id: String, purpose: String, count: int, index: int = 0) -> int:
	return int(Rng.draw(seed_value, id, purpose, index, count).value)

static func advance(world: Dictionary, hook: String, round_number: int, seed_value: String) -> Array:
	var events: Array = []
	var rows: Array = world.data.kanifous_objects
	if hook == Timeline.ROUND_START_AUTOMATIC:
		world.data.kanifous_losses = []
		world.data.kanifous_loss_round = round_number
		for pid in [0, 1]:
			if not active(world, pid):
				continue
			var id: String = Data.instance_id("wishmaster", str(pid), str(round_number))
			var target: Dictionary = {"lane": ["Lord", "Castle"][draw(seed_value, id, "SMOKE_LANE", 2)], "field_position": {"x_fp": 600 + draw(seed_value, id, "SMOKE_X", 1201), "y_fp": 180 + draw(seed_value, id, "SMOKE_Y", 241)}}
			var row: Dictionary = {"id": id, "owner": pid, "phase": "smoke", "created_round": round_number, "due_round": round_number + 1, "target": target}
			rows.append(row)
			events.append(event("WISHMASTER_SMOKE_CREATED", row.duplicate(true)))
	elif hook == Timeline.MARCHING_START:
		for row in rows:
			if row.phase != "smoke" or row.due_round != round_number:
				continue
			var origin: Dictionary = row.target.field_position
			# Rejection sampling is keyed by attempt, never by unrelated RNG traffic.
			for attempt in range(128):
				var dx: int = draw(seed_value, row.id, "LAMP_X", RADIUS * 2 + 1, attempt) - RADIUS
				var dy: int = draw(seed_value, row.id, "LAMP_Y", RADIUS * 2 + 1, attempt) - RADIUS
				if dx * dx + dy * dy <= RADIUS * RADIUS and origin.x_fp + dx >= 0 and origin.x_fp + dx <= 2400 and origin.y_fp + dy >= 0 and origin.y_fp + dy <= 600:
					origin.x_fp += dx
					origin.y_fp += dy
					break
			row.phase = "lamp"
			events.append(event("WISHMASTER_LAMP_SPAWNED", row.duplicate(true)))
	elif hook == Timeline.END_MARCHING_CHECKS:
		for row in rows:
			if row.phase == "lamp":
				events.append(event("WISHMASTER_LAMP_EXPIRED", row.duplicate(true)))
		world.data.kanifous_objects = rows.filter(func(row: Dictionary) -> bool: return row.phase == "smoke")
	return events

static func distance(a: Dictionary, b: Dictionary) -> int:
	return (int(a.x_fp) - int(b.x_fp)) ** 2 + (int(a.y_fp) - int(b.y_fp)) ** 2

static func contact_time(a: Dictionary, b: Dictionary, point: Dictionary) -> float:
	var p := Vector2(a.x_fp - point.x_fp, a.y_fp - point.y_fp)
	var d := Vector2(b.x_fp - a.x_fp, b.y_fp - a.y_fp)
	var c: float = p.length_squared() - CONTACT * CONTACT
	if c <= 0:
		return 0.0
	var length: float = d.length_squared()
	var dot: float = p.dot(d)
	var discriminant: float = dot * dot - length * c
	if length == 0 or discriminant < 0:
		return -1.0
	var t: float = (-dot - sqrt(discriminant)) / length
	return t if t >= 0 and t <= 1 else -1.0

static func claim(rows: Array, entities, before: Array, seed_value: String, round_number: int, tick: int) -> Array:
	var events: Array = []
	var candidates: Array = []
	for row in rows:
		if row.phase != "lamp":
			continue
		for old in before:
			var unit: Dictionary = entities.get_entity(old.id)
			if unit.is_empty() or unit.attributes.lane != row.target.lane:
				continue
			var at: float = contact_time(old.attributes, unit.attributes, row.target.field_position)
			if at >= 0:
				candidates.append({"at": at, "lamp": row, "id": unit.id})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at < b.at if a.at != b.at else (a.id < b.id if a.id != b.id else a.lamp.id < b.lamp.id))
	var used: Array = []
	for candidate in candidates:
		var lamp: Dictionary = candidate.lamp
		var unit: Dictionary = entities.get_entity(candidate.id)
		if lamp.id in used or unit.is_empty():
			continue
		used.append(lamp.id)
		var info: Dictionary = {"lamp_id": lamp.id, "unit": unit.duplicate(true), "round": round_number, "tick": tick, "target": lamp.target.duplicate(true)}
		events.append(event("WISHMASTER_LAMP_CLAIMED", info))
		if draw(seed_value, lamp.id + ":" + unit.id, "WISHMASTER_REJECTION", 10) == 0:
			entities.retire(unit.id)
			events.append(event("WISHMASTER_REJECTED", info))
			continue
		match unit.attributes.suit:
			"Butcher":
				unit.attributes["blood_wish"] = true
			"Penitent":
				unit.attributes.armor += 2
			"Vulture":
				unit.attributes["ghost_wishes"] = 2
			"Wright":
				var marching = load("res://Scripts/Sim/U13Marching.gd")
				var a: Dictionary = marching.profile("Wright", unit.attributes.lane, unit.owner, round_number, round_number)
				a.x_fp = unit.attributes.x_fp
				a.y_fp = unit.attributes.y_fp
				var spawn_ids = Ids.new()
				spawn_ids.restore(entities.snapshot())
				var clone: Dictionary = spawn_ids.create("marcher", lamp.id, 0, unit.owner, a)
				marching.place_near_spawn(spawn_ids, clone.entity.id, a)
				clone.entity = spawn_ids.get_entity(clone.entity.id)
				entities.restore(spawn_ids.snapshot())
				events.append(event("WISHMASTER_WRIGHT_CREATED", {"lamp_id": lamp.id, "unit": clone.entity, "round": round_number, "tick": tick}))
		entities.update(unit.id, unit.owner, unit.attributes)
		events.append(event("WISHMASTER_WISH_GRANTED", info))
	for i in range(rows.size() - 1, -1, -1):
		if rows[i].id in used:
			rows.remove_at(i)
	return events

static func ignored(a: Dictionary, b: Dictionary) -> bool:
	return b.id in a.attributes.get("ghost_bypassed", []) or a.id in b.attributes.get("ghost_bypassed", [])

static func bypass(entities, round_number: int, tick: int) -> Array:
	var events: Array = []
	var units: Array = entities.marchers()
	for source in units:
		var unit: Dictionary = entities.get_entity(source.id)
		if unit.attributes.get("ghost_wishes", 0) == 0:
			continue
		for other in units:
			if other.owner == unit.owner or other.attributes.lane != unit.attributes.lane or ignored(unit, other) or distance(unit.attributes, other.attributes) > 180 * 180:
				continue
			unit.attributes.ghost_wishes -= 1
			if not unit.attributes.has("ghost_bypassed"):
				unit.attributes["ghost_bypassed"] = []
			unit.attributes.ghost_bypassed.append(other.id)
			unit.attributes.waiting = false
			unit.attributes.contact_tick = -1
			entities.update(unit.id, unit.owner, unit.attributes)
			events.append(event("WISHMASTER_VULTURE_BYPASS", {"unit_id": unit.id, "other_id": other.id, "round": round_number, "tick": tick}))
			if unit.attributes.ghost_wishes == 0:
				break
	return events

static func attack_amount(a: Dictionary) -> int:
	var multiplier: int = 2 if a.get("blood_wish", false) else 1
	a.erase("blood_wish")
	return int(a.attack) * multiplier

static func valid(world: Dictionary) -> bool:
	if world.data.get("kanifous_profile") != VERSION:
		return false
	for field in ["kanifous_objects", "kanifous_prices", "kanifous_losses"]:
		if typeof(world.data.get(field)) != TYPE_ARRAY:
			return false
	if not Data.is_integer(world.data.get("kanifous_loss_round")):
		return false
	var ids: Array = []
	for row in world.data.kanifous_objects:
		if typeof(row) != TYPE_DICTIONARY or row.size() != 6 or typeof(row.get("id")) != TYPE_STRING or row.id in ids or row.get("owner") not in [0, 1] or row.get("phase") not in ["smoke", "lamp"] or not Data.is_integer(row.get("created_round")) or row.created_round < 1 or row.get("due_round") != row.created_round + 1 or typeof(row.get("target")) != TYPE_DICTIONARY or not Fields.target_valid(row.target):
			return false
		ids.append(row.id)
	for row in world.data.kanifous_prices:
		if typeof(row) != TYPE_DICTIONARY or row.size() != 4 or typeof(row.get("id")) != TYPE_STRING or row.id in ids or row.get("owner") not in [0, 1] or not Data.is_integer(row.get("created_round")) or not Data.is_integer(row.get("due_round")) or row.due_round < row.created_round + 1 or row.due_round > row.created_round + 3:
			return false
		ids.append(row.id)
	for loss in world.data.kanifous_losses:
		if typeof(loss) != TYPE_DICTIONARY or loss.get("kind") != "card" or loss.get("owner") not in [0, 1] or loss.get("id") not in world.entities.used_ids or typeof(loss.get("attributes")) != TYPE_DICTIONARY:
			return false
		if loss.attributes.get("role") != "guard" or loss.attributes.get("lane") not in ["Lord", "Castle"] or not Data.is_integer(loss.attributes.get("slot")) or not Data.is_integer(loss.attributes.get("value")):
			return false
	for unit in world.entities.entities:
		if unit.kind != "marcher":
			continue
		var a: Dictionary = unit.attributes
		if a.has("blood_wish") and typeof(a.blood_wish) != TYPE_BOOL:
			return false
		if a.has("ghost_wishes") and (not Data.is_integer(a.ghost_wishes) or a.ghost_wishes < 0 or a.ghost_wishes > 2):
			return false
		if a.has("ghost_bypassed") and (typeof(a.ghost_bypassed) != TYPE_ARRAY or not a.ghost_bypassed.all(func(id): return typeof(id) == TYPE_STRING)):
			return false
	return true


# Only materialized lamps attract; nearest distance then stable ID breaks ties.
static func nearby_lamp(attributes: Dictionary, rows: Array) -> Dictionary:
	var selected: Dictionary = {}
	var best: int = ATTRACTION_RADIUS * ATTRACTION_RADIUS
	for row in rows:
		if row.phase != "lamp" or row.target.lane != attributes.lane:
			continue
		var d: int = distance(attributes, row.target.field_position)
		if d < best or (d == best and (selected.is_empty() or str(row.id) < str(selected.id))):
			selected = row
			best = d
	return selected

static func power_count(seed_value: String, declaration_id: String) -> int:
	var roll: int = draw(seed_value, declaration_id, "WISH_COUNT", 100)
	return 1 if roll < 70 else (2 if roll < 95 else 3)
