extends RefCounted

const State = preload("res://Scripts/Sim/U13KroniState.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const LENGTH: int = 2400
const WIDTH: int = 1200
const RADIUS: int = 220
const FORWARD: int = 16
const LATERAL_MIN: int = 8
const LATERAL_MAX: int = 24
const BREACH_TICKS: int = 33
const MEAL_LIMIT: int = 3


static func radius(hunger: int) -> int:
	return int(round(float(RADIUS) * [1.0, 1.1, 1.2, 1.35][clampi(hunger, 0, 3)]))


static func create(identity: String, pid: int, round_number: int, hunger: int, breach: bool = false, seed_value: String = "kroni-actor-fixture", start: Dictionary = {}) -> Dictionary:
	var actor: Dictionary = {"id": identity, "owner": pid, "round": round_number, "breach": breach, "x_fp": 0 if pid == 0 else LENGTH, "y_fp": 300, "vx_fp": FORWARD if pid == 0 else -FORWARD, "vy_fp": LATERAL_MIN, "radius_fp": radius(hunger), "hunger": hunger, "age": 0, "active": true, "consumed": 0, "rewarded": false, "meal_count": 0, "meal_x_fp": 0, "meal_y_fp": 0}
	if not breach:
		if not start.is_empty():
			actor.y_fp = int(start.field_position.y_fp) + (600 if start.lane == "Castle" else 0)
		# Roll only at authoritative activation. Placement exposes no direction.
		# Separate activation/round keys preserve replays without repeating a route.
		var key: String = Data.instance_id(identity, str(round_number), "ravenous_launch")
		var magnitude: int = LATERAL_MIN + int(Rng.draw(seed_value, key, "RAVENOUS_ANGLE", 0, LATERAL_MAX - LATERAL_MIN + 1).value)
		actor.vy_fp = magnitude * (-1 if int(Rng.draw(seed_value, key, "RAVENOUS_SIDE", 0, 2).value) == 0 else 1)
	if breach:
		actor.x_fp = int(Rng.draw(seed_value, identity, "BREACH_FORWARD", 0, LENGTH + 1).value)
		actor.y_fp = int(Rng.draw(seed_value, identity, "BREACH_LATERAL", 0, WIDTH + 1).value)
		var vectors: Array = [[24, 0], [17, 17], [0, 24], [-17, 17], [-24, 0], [-17, -17], [0, -24], [17, -17]]
		var direction: Array = vectors[int(Rng.draw(seed_value, identity, "BREACH_DIRECTION", 0, vectors.size()).value)]
		actor.vx_fp = direction[0]
		actor.vy_fp = direction[1]
	return actor


# Integer segment/circle test includes the boundary and prevents tunnelling.
# Coordinates are canonical forward/lateral units, independent of viewport.
static func touches(ax: int, ay: int, bx: int, by: int, px: int, py: int, r: int) -> bool:
	var dx: int = bx - ax
	var dy: int = by - ay
	var qx: int = px - ax
	var qy: int = py - ay
	var dot: int = qx * dx + qy * dy
	var length_sq: int = dx * dx + dy * dy
	if dot <= 0 or length_sq == 0:
		return qx * qx + qy * qy <= r * r
	if dot >= length_sq:
		return (px - bx) * (px - bx) + (py - by) * (py - by) <= r * r
	var cross: int = qx * dy - qy * dx
	return cross * cross <= r * r * length_sq


# Ordered actors and stable entity IDs define simultaneous consumption ties.
# This changes the Marching buffer, never damage, armor, kill reactions or RNG.
static func step(actors: Array, entities, round_number: int, tick: int) -> Array:
	var events: Array = []
	for actor in actors:
		if not actor.active:
			continue
		var ax: int = actor.x_fp
		var ay: int = actor.y_fp
		var bx: int = clampi(ax + int(actor.vx_fp), 0, LENGTH)
		var by: int = ay + int(actor.vy_fp)
		var segments: Array = [[ax, ay, bx, by]]
		if by < 0 or by > WIDTH:
			var wall: int = 0 if by < 0 else WIDTH
			# Exact sub-tick wall contact (integer rounding is part of tuning).
			var contact_x: int = ax + int(round(float(bx - ax) * float(wall - ay) / float(by - ay)))
			by = -by if by < 0 else 2 * WIDTH - by
			segments = [[ax, ay, contact_x, wall], [contact_x, wall, bx, by]]
			actor.vy_fp = -int(actor.vy_fp)
			events.append(State.event("KRONI_WALL_BOUNCE", {"actor_id": actor.id, "round": round_number, "tick": tick}))
		actor.x_fp = bx
		actor.y_fp = by
		actor.age += 1
		# A feeding spot lasts one footprint diameter from its first bite.
		if actor.meal_count > 0 and (bx - int(actor.meal_x_fp)) * (bx - int(actor.meal_x_fp)) + (by - int(actor.meal_y_fp)) * (by - int(actor.meal_y_fp)) >= 4 * int(actor.radius_fp) * int(actor.radius_fp):
			actor.meal_count = 0
		for unit in entities.marchers():
			if actor.meal_count >= MEAL_LIMIT:
				break
			var a: Dictionary = unit.attributes
			var lateral: int = int(a.y_fp) + (600 if a.lane == "Castle" else 0)
			var hit: bool = false
			for segment in segments:
				hit = hit or touches(segment[0], segment[1], segment[2], segment[3], int(a.x_fp), lateral, int(actor.radius_fp))
			if hit:
				if actor.meal_count == 0:
					actor.meal_x_fp = bx
					actor.meal_y_fp = by
				actor.meal_count += 1
				entities.retire(unit.id)
				actor.consumed += 1
				events.append(State.event("MARCHER_DEVOURED", {"actor_id": actor.id, "actor": actor.duplicate(true), "before": unit, "round": round_number, "tick": tick, "breach": actor.breach}, "Insatiable Hunger devours a Marcher." if actor.breach else "Ravenous devours a Marcher."))
		if actor.breach:
			if bx == 0 or bx == LENGTH:
				actor.vx_fp = -int(actor.vx_fp)
			actor.active = actor.age < BREACH_TICKS
		else:
			actor.active = bx != (LENGTH if actor.owner == 0 else 0)
		if not actor.active:
			events.append(State.event("KRONI_ACTOR_FINISHED", {"actor": actor.duplicate(true), "round": round_number, "tick": tick}))
	return events


static func valid(actors) -> bool:
	if typeof(actors) != TYPE_ARRAY or actors.size() > 3:
		return false
	var seen: Array = []
	for a in actors:
		if typeof(a) != TYPE_DICTIONARY or typeof(a.get("id")) != TYPE_STRING or a.id.is_empty() or a.id in seen:
			return false
		seen.append(a.id)
		for field in ["owner", "round", "x_fp", "y_fp", "vx_fp", "vy_fp", "radius_fp", "hunger", "age", "consumed", "meal_count", "meal_x_fp", "meal_y_fp"]:
			if not Data.is_integer(a.get(field)):
				return false
		for field in ["breach", "active", "rewarded"]:
			if typeof(a.get(field)) != TYPE_BOOL:
				return false
		if a.owner not in [-1, 0, 1] or (not a.breach and a.owner == -1) or a.round < 1 or a.x_fp < 0 or a.x_fp > LENGTH or a.y_fp < 0 or a.y_fp > WIDTH or a.age < 0 or a.age > 200 or a.consumed < 0 or a.hunger < 0 or a.radius_fp != radius(a.hunger):
			return false
		if a.meal_count < 0 or a.meal_count > MEAL_LIMIT or a.meal_x_fp < 0 or a.meal_x_fp > LENGTH or a.meal_y_fp < 0 or a.meal_y_fp > WIDTH:
			return false
		if absi(a.vx_fp) > 24 or absi(a.vy_fp) > 24 or (a.vx_fp == 0 and a.vy_fp == 0):
			return false
		if not a.breach and (a.vx_fp != (FORWARD if a.owner == 0 else -FORWARD) or absi(a.vy_fp) < LATERAL_MIN or absi(a.vy_fp) > LATERAL_MAX):
			return false
		if a.breach and (a.hunger != 0 or a.rewarded):
			return false
	return true
