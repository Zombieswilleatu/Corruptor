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
const FLEE_PERCENT: int = 30
const CHOMP_MS: int = 550
const TICK_MS: int = 30
const FLEE_RADIUS_SCALE: int = 2
const FLEE_MS: int = CHOMP_MS * 2


static func radius(hunger: int) -> int:
	return int(round(float(RADIUS) * [1.0, 1.1, 1.2, 1.35][clampi(hunger, 0, 3)]))


static func create(identity: String, pid: int, round_number: int, hunger: int, breach: bool = false, seed_value: String = "kroni-actor-fixture", start: Dictionary = {}) -> Dictionary:
	var actor: Dictionary = {"id": identity, "owner": pid, "round": round_number, "breach": breach, "x_fp": 0 if pid == 0 else LENGTH, "y_fp": 300, "vx_fp": FORWARD if pid == 0 else -FORWARD, "vy_fp": LATERAL_MIN, "radius_fp": radius(hunger), "hunger": hunger, "age": 0, "active": true, "consumed": 0, "rewarded": false, "fleeing": {}, "nearby": [], "fled_this_tick": []}
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
		actor.fled_this_tick = actor.fleeing.keys()
		flee(actor, entities, TICK_MS)
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
		var started: Array = notice(actor, entities)
		if not started.is_empty():
			events.append(State.event("KRONI_FLEE_STARTED", {"actor_id": actor.id, "units": started, "round": round_number, "tick": tick, "duration_ms": FLEE_MS}))
		for unit in entities.marchers():
			var a: Dictionary = unit.attributes
			var lateral: int = int(a.y_fp) + (600 if a.lane == "Castle" else 0)
			var hit: bool = false
			for segment in segments:
				hit = hit or touches(segment[0], segment[1], segment[2], segment[3], int(a.x_fp), lateral, int(actor.radius_fp))
			if hit:
				entities.retire(unit.id)
				actor.consumed += 1
				actor.fleeing.erase(unit.id)
				var bite_actor: Dictionary = actor.duplicate(true)
				var fleeing: Array = flee(actor, entities, CHOMP_MS)
				events.append(State.event("MARCHER_DEVOURED", {"actor_id": actor.id, "actor": bite_actor, "before": unit, "round": round_number, "tick": tick, "breach": actor.breach, "flee": fleeing, "chomp_ms": CHOMP_MS}, "Insatiable Hunger devours a Marcher." if actor.breach else "Ravenous devours a Marcher."))
				# One victim per chomp; survivors have time to flee before the next bite.
				break
		if actor.breach:
			if bx == 0 or bx == LENGTH:
				actor.vx_fp = -int(actor.vx_fp)
			actor.active = actor.age < BREACH_TICKS
		else:
			actor.active = bx != (LENGTH if actor.owner == 0 else 0)
		if not actor.active:
			events.append(State.event("KRONI_ACTOR_FINISHED", {"actor": actor.duplicate(true), "round": round_number, "tick": tick}))
	return events


# Entry into the warning radius starts an independent panic timer. Staying
# nearby does not renew it or replay audio; leaving and returning can retrigger.
static func notice(actor: Dictionary, entities) -> Array:
	var nearby: Array = []
	var started: Array = []
	var reach: int = int(actor.radius_fp) * FLEE_RADIUS_SCALE
	for unit in entities.marchers():
		var a: Dictionary = unit.attributes
		var lateral: int = int(a.y_fp) + (600 if a.lane == "Castle" else 0)
		var dx: int = int(a.x_fp) - int(actor.x_fp)
		var dy: int = lateral - int(actor.y_fp)
		if dx * dx + dy * dy > reach * reach or int(a.step_fp) == 0:
			continue
		nearby.append(unit.id)
		if unit.id in actor.nearby or actor.fleeing.has(unit.id):
			continue
		actor.fleeing[unit.id] = {"remaining_ms": FLEE_MS, "carry_x": 0.0, "carry_y": 0.0, "unit": unit}
		started.append(unit.id)
	actor.nearby = nearby
	return started


# Both normal field ticks and the bite pause spend the same panic timer.
# Publish the bite's before/after positions for presentation interpolation.
static func flee(actor: Dictionary, entities, elapsed_ms: int = CHOMP_MS) -> Array:
	var changes: Array = []
	for identity in actor.fleeing.keys():
		var unit: Dictionary = entities.get_entity(identity)
		if unit.is_empty():
			actor.fleeing.erase(identity)
			continue
		var state: Dictionary = actor.fleeing[identity]
		var duration: int = mini(elapsed_ms, int(state.remaining_ms))
		var a: Dictionary = unit.attributes.duplicate(true)
		var lateral: int = int(a.y_fp) + (600 if a.lane == "Castle" else 0)
		var dx: int = int(a.x_fp) - int(actor.x_fp)
		var dy: int = lateral - int(actor.y_fp)
		if dx == 0 and dy == 0:
			var directions: Array = [[1,0], [1,1], [0,1], [-1,1], [-1,0], [-1,-1], [0,-1], [1,-1]]
			var direction: Array = directions[int(Rng.draw(actor.id, unit.id, "FLEE_OVERLAP", 0, 8).value)]
			dx = direction[0]
			dy = direction[1]
		var length: float = sqrt(float(dx * dx + dy * dy))
		var distance: float = float(int(a.step_fp) * FLEE_PERCENT * duration) / float(100 * TICK_MS)
		var move_x: float = float(dx) / length * distance + float(state.carry_x)
		var move_y: float = float(dy) / length * distance + float(state.carry_y)
		var shift_x: int = int(round(move_x))
		var shift_y: int = int(round(move_y))
		state.carry_x = move_x - shift_x
		state.carry_y = move_y - shift_y
		a.x_fp = clampi(int(a.x_fp) + shift_x, 0, LENGTH)
		var after_lateral: int = clampi(lateral + shift_y, 0, WIDTH)
		a.lane = "Lord" if after_lateral < 600 else "Castle"
		a.y_fp = after_lateral - (600 if a.lane == "Castle" else 0)
		a.contact_tick = -1
		if a.x_fp != (LENGTH if unit.owner == 0 else 0):
			a.waiting = false
			a.waiting_since_round = 0
		entities.update(unit.id, unit.owner, a)
		state.unit = entities.get_entity(unit.id)
		changes.append({"before": unit, "after": state.unit, "duration_ms": duration})
		state.remaining_ms -= duration
		if state.remaining_ms <= 0:
			actor.fleeing.erase(identity)
	return changes


static func valid(actors) -> bool:
	if typeof(actors) != TYPE_ARRAY or actors.size() > 3:
		return false
	var seen: Array = []
	for a in actors:
		if typeof(a) != TYPE_DICTIONARY or typeof(a.get("id")) != TYPE_STRING or a.id.is_empty() or a.id in seen:
			return false
		seen.append(a.id)
		if typeof(a.get("fleeing")) != TYPE_DICTIONARY or typeof(a.get("nearby")) != TYPE_ARRAY or typeof(a.get("fled_this_tick")) != TYPE_ARRAY:
			return false
		for identity in a.fleeing:
			var panic = a.fleeing[identity]
			if typeof(identity) != TYPE_STRING or typeof(panic) != TYPE_DICTIONARY:
				return false
			if not Data.is_integer(panic.get("remaining_ms")) or panic.remaining_ms <= 0 or panic.remaining_ms > FLEE_MS:
				return false
			for field in ["carry_x", "carry_y"]:
				if typeof(panic.get(field)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(panic[field])) or absf(float(panic[field])) > 0.5:
					return false
			if typeof(panic.get("unit")) != TYPE_DICTIONARY or panic.unit.get("id") != identity:
				return false

		for field in ["owner", "round", "x_fp", "y_fp", "vx_fp", "vy_fp", "radius_fp", "hunger", "age", "consumed"]:
			if not Data.is_integer(a.get(field)):
				return false
		for field in ["breach", "active", "rewarded"]:
			if typeof(a.get(field)) != TYPE_BOOL:
				return false
		if a.owner not in [-1, 0, 1] or (not a.breach and a.owner == -1) or a.round < 1 or a.x_fp < 0 or a.x_fp > LENGTH or a.y_fp < 0 or a.y_fp > WIDTH or a.age < 0 or a.age > 200 or a.consumed < 0 or a.hunger < 0 or a.radius_fp != radius(a.hunger):
			return false
		if absi(a.vx_fp) > 24 or absi(a.vy_fp) > 24 or (a.vx_fp == 0 and a.vy_fp == 0):
			return false
		if not a.breach and (a.vx_fp != (FORWARD if a.owner == 0 else -FORWARD) or absi(a.vy_fp) < LATERAL_MIN or absi(a.vy_fp) > LATERAL_MAX):
			return false
		if a.breach and (a.hunger != 0 or a.rewarded):
			return false
	return true
