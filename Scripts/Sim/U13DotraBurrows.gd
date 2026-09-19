extends RefCounted

const Rules = preload("res://Scripts/Sim/U13MonsterRules.gd")
const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")
const GAP: int = 42

static func distance(a: Dictionary, b: Dictionary) -> int:
	return (int(a.x_fp) - int(b.x_fp)) ** 2 + (int(a.y_fp) - int(b.y_fp)) ** 2

static func begin(a: Dictionary, clock: int) -> void:
	# Fixed exits: one escape behind the advance and two spread across the lane.
	var direction: int = int(a.direction)
	a["dotra_holes"] = [
		{"x_fp": clampi(int(a.x_fp), 30, 2370), "y_fp": clampi(int(a.y_fp), 180, 420)},
		{"x_fp": clampi(int(a.x_fp) + direction * 360, 30, 2370), "y_fp": 100},
		{"x_fp": clampi(int(a.x_fp) + direction * 600, 30, 2370), "y_fp": 500}]
	a["dotra_burrow_ready_tick"] = clock + int(Rules.TUNING.dotra_burrow_ticks)
	a["dotra_ambush_ready"] = false
	a["dotra_ambush_target"] = ""
	a.contact_tick = -1
	a.waiting = false
	a.waiting_since_round = 0

static func visible_enemies(unit: Dictionary, rows: Array, clock: int = -1) -> Array:
	return rows.filter(func(r): return r.kind == "marcher" and r.owner != unit.owner and r.attributes.lane == unit.attributes.lane and not r.attributes.get("hidden", false) and (clock < 0 or int(unit.attributes.get("navigation", {}).get("avoid", {}).get(r.id, 0)) <= clock))

static func clear_exit(unit: Dictionary, point: Dictionary, rows: Array, structures: Array) -> bool:
	if point.x_fp < 30 or point.x_fp > 2370 or point.y_fp < 30 or point.y_fp > 570: return false
	for other in rows:
		if other.id != unit.id and other.attributes.lane == unit.attributes.lane and distance(point, other.attributes) < GAP * GAP: return false
	var probe: Dictionary = unit.duplicate(true)
	probe.attributes.merge(point, true)
	for structure in structures:
		if structure.attributes.lane == unit.attributes.lane and Fort.gap(probe, structure) < GAP * GAP: return false
	return true

static func exits(unit: Dictionary, rows: Array, structures: Array) -> Array:
	var result: Array = []
	for hole in unit.attributes.get("dotra_holes", []):
		var found: Dictionary = {}
		for radius in [0, 42, 84, 126]:
			for offset in [[1, 0], [0, -1], [0, 1], [-1, 0], [1, -1], [1, 1], [-1, -1], [-1, 1]]:
				var point: Dictionary = {"x_fp": int(hole.x_fp) + radius * int(offset[0]) * int(unit.attributes.direction), "y_fp": int(hole.y_fp) + radius * int(offset[1])}
				if clear_exit(unit, point, rows, structures):
					found = point
					break
			if not found.is_empty(): break
		result.append(found)
	return result

static func isolated(unit: Dictionary, rows: Array, points: Array, clock: int = -1) -> Dictionary:
	var choices: Array = visible_enemies(unit, rows, clock)
	var selected: Dictionary = {}
	var best: Array = []
	for target in choices:
		var count: int = 0
		var separation: int = 10000000
		# Score visible allies of the victim; never use concealed information.
		for ally in rows:
			if ally.id == target.id or ally.kind != "marcher" or ally.owner != target.owner or ally.attributes.lane != target.attributes.lane or ally.attributes.get("hidden", false): continue
			var gap: int = distance(target.attributes, ally.attributes)
			separation = mini(separation, gap)
			if gap <= int(Rules.TUNING.dotra_isolation_radius) ** 2: count += 1
		var reach: int = 10000000
		for point in points:
			if not point.is_empty(): reach = mini(reach, distance(point, target.attributes))
		var score: Array = [count, -separation, reach, target.id]
		var better: bool = best.is_empty()
		if not better:
			for i in range(score.size()):
				if score[i] == best[i]: continue
				better = score[i] < best[i]
				break
		if better: selected = target; best = score
	return selected

static func choose_exit(unit: Dictionary, points: Array, target: Dictionary) -> int:
	var chosen: int = -1
	var best: int = 10000000
	for i in range(points.size()):
		if points[i].is_empty(): continue
		var score: int = distance(points[i], target.attributes) if not target.is_empty() else -int(points[i].x_fp) * int(unit.attributes.direction)
		if score < best: chosen = i; best = score
	return chosen

static func prepared_target(unit: Dictionary, rows: Array, clock: int) -> Dictionary:
	for target in visible_enemies(unit, rows, clock):
		if target.id == unit.attributes.get("dotra_ambush_target", ""): return target
	return isolated(unit, rows, [unit.attributes], clock)
