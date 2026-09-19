extends RefCounted

const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")
const Wish = preload("res://Scripts/Sim/U13Wishmaster.gd")
# Minimum center separation: half the former 84-unit footprint.
const GAP: int = 42

static func collides(unit: Dictionary, other: Dictionary) -> bool:
	return unit.id != other.id and unit.attributes.lane == other.attributes.lane and (unit.owner == other.owner or not Wish.ignored(unit, other))

static func clear(unit: Dictionary, point: Dictionary, rows: Array, structures: Array, allow_escape: bool = true) -> bool:
	if point.x_fp < 0 or point.x_fp > 2400 or point.y_fp < 0 or point.y_fp > 600: return false
	if Fort.blocked_step(unit, point, structures): return false
	var wall: Dictionary = Fort.blocker(unit, point, structures)
	if not wall.is_empty(): return false
	for other in rows:
		if not collides(unit, other): continue
		var after: int = Fort.distance(point, other.attributes)
		if after < GAP * GAP and (not allow_escape or after <= Fort.distance(unit.attributes, other.attributes)):
			return false
	return true

static func slide(unit: Dictionary, proposed: Dictionary, rows: Array, structures: Array, step: int, hold_contact: bool = true) -> Dictionary:
	# A prior mover may already have reached this fighter since the target
	# snapshot. Hold that contact instead of stepping away and oscillating.
	if hold_contact and rows.any(func(other): return other.owner != unit.owner and collides(unit, other) and Fort.in_melee(unit, other)): return unit.attributes
	if clear(unit, proposed, rows, structures): return proposed
	var side: int = 1 if (unit.id.unicode_at(unit.id.length() - 1) % 2) == 0 else -1
	var mostly_forward: bool = absi(int(proposed.x_fp) - int(unit.attributes.x_fp)) >= absi(int(proposed.y_fp) - int(unit.attributes.y_fp))
	for sign_value in [side, -side]:
		var point: Dictionary = unit.attributes.duplicate(true)
		# Steer perpendicular to the attempted move, including fighters chasing
		# sideways. Always sidestepping on y trapped those fighters in a loop.
		if mostly_forward: point.y_fp = clampi(int(point.y_fp) + sign_value * step, 0, 600)
		else: point.x_fp = clampi(int(point.x_fp) + sign_value * int(point.direction) * step, 0, 2400)
		if clear(unit, point, rows, structures): return point
	return unit.attributes

static func anchored(unit: Dictionary, number: int) -> bool:
	var a: Dictionary = unit.attributes
	return a.waiting or a.movement_ready_round > number or a.get("sprite_form") == "turret" or (a.has("wright_site") and not a.get("wright_released", false))

static func separate(entities, structures: Array, number: int) -> void:
	# Recover exact stacks from old worlds, teleports or summons, including
	# stationary ranged fighters. Stable identity resolves ties in either seat.
	var rows: Array = entities.marchers()
	for unit in rows:
		if anchored(unit, number): continue
		var stacked: bool = rows.any(func(other): return collides(unit, other) and Fort.distance(unit.attributes, other.attributes) == 0 and (other.id < unit.id or anchored(other, number)))
		if not stacked: continue
		var side: int = 1 if (unit.id.unicode_at(unit.id.length() - 1) % 2) == 0 else -1
		var placed: bool = false
		for radius in [GAP, GAP * 2]:
			for offset in [Vector2i(0, side), Vector2i(0, -side), Vector2i(-int(unit.attributes.direction), 0), Vector2i(int(unit.attributes.direction), 0), Vector2i(-int(unit.attributes.direction), side), Vector2i(-int(unit.attributes.direction), -side)]:
				var point: Dictionary = unit.attributes.duplicate(true)
				point.x_fp += offset.x * radius; point.y_fp += offset.y * radius
				if not clear(unit, point, rows, structures, false): continue
				unit.attributes = point
				entities.update(unit.id, unit.owner, point)
				placed = true
				break
			if placed: break
