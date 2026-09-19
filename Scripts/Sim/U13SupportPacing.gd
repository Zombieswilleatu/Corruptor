extends RefCounted

# Let nearby front-line fighters establish a screen. Never form a support-only
# queue, pull a unit backward, or reduce its saved movement stat.
const RADIUS: int = 420
const WIDTH: int = 180
const TRAIL: int = 180
const PENITENT_TRAIL: int = 90

static func support(a: Dictionary) -> bool:
	return a.get("suit") == "Vulture" or a.get("monster_id") in ["Kopita", "Sinodek", "Sooge"]

static func support_speed(unit: Dictionary, rows: Array, step: int, clock: int, number: int, fleeing: Dictionary = {}) -> int:
	var a: Dictionary = unit.attributes
	if not support(a): return step
	var screen: Dictionary = {}
	var lead: int = -RADIUS - 1
	for other in rows:
		var b: Dictionary = other.attributes
		if other.id == unit.id or other.owner != unit.owner or b.lane != a.lane: continue
		if b.get("suit") not in ["Butcher", "Penitent"] and b.get("monster_id") not in ["Lemek", "Kurchin"]: continue
		if b.waiting or b.movement_ready_round > number or b.get("hidden", false) or b.get("rout_round", -1) == number or fleeing.has(other.id): continue
		var dx: int = int(b.x_fp) - int(a.x_fp)
		var dy: int = int(b.y_fp) - int(a.y_fp)
		if absi(dy) > WIDTH or dx * dx + dy * dy > RADIUS * RADIUS: continue
		var forward: int = dx * int(a.direction)
		if forward > lead:
			screen = other
			lead = forward
	if screen.is_empty(): return step
	if lead >= TRAIL: return mini(step, lead - TRAIL)
	# Once the screen is fighting, do not creep through it into its opponent.
	if lead >= 0 and int(screen.attributes.contact_tick) >= 0: return 0
	# Quarter speed also works for a two-unit step without rounding it to zero.
	return (step >> 2) + (1 if (clock & 3) < (step & 3) else 0)

# Advancing Butchers and released Wrights let a nearby Penitent take point.
# Once the leader engages, followers close at full speed to contribute damage.
static func speed(unit: Dictionary, rows: Array, step: int, clock: int, number: int, fleeing: Dictionary = {}) -> int:
	var a: Dictionary = unit.attributes
	if a.has("monster_id") or a.get("suit") not in ["Butcher", "Wright"]:
		return support_speed(unit, rows, step, clock, number, fleeing)
	if a.get("suit") == "Wright" and not a.get("wright_released", false): return step
	var screen: Dictionary = {}
	var lead: int = -RADIUS - 1
	for other in rows:
		var b: Dictionary = other.attributes
		if other.owner != unit.owner or b.lane != a.lane or b.get("suit") != "Penitent" or b.has("monster_id"): continue
		if b.waiting or b.movement_ready_round > number or b.get("hidden", false) or b.get("rout_round", -1) == number or fleeing.has(other.id): continue
		var dx: int = int(b.x_fp) - int(a.x_fp)
		var dy: int = int(b.y_fp) - int(a.y_fp)
		if absi(dy) > WIDTH or dx * dx + dy * dy > RADIUS * RADIUS: continue
		var forward: int = dx * int(a.direction)
		if forward > lead:
			screen = other
			lead = forward
	if screen.is_empty() or int(screen.attributes.contact_tick) >= 0: return step
	if lead >= PENITENT_TRAIL: return mini(step, lead - PENITENT_TRAIL)
	return (step >> 2) + (1 if (clock & 3) < (step & 3) else 0)
