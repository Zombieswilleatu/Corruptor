extends RefCounted

const Spacing = preload("res://Scripts/Sim/U13MarcherSpacing.gd")
const Fort = Spacing.Fort
const STALL_TICKS: int = 24 # 1.8 seconds of a 15-second round at 1x.
const RETRY_TICKS: int = 80
const CELL: int = 24
const SEARCH_RADIUS: int = 14

static func avoided(unit: Dictionary, target: Dictionary, clock: int) -> bool:
	return not target.is_empty() and int(unit.attributes.get("navigation", {}).get("avoid", {}).get(target.id, 0)) > clock

static func candidates(unit: Dictionary, targets: Array, clock: int) -> Array:
	return targets.filter(func(t): return not avoided(unit, t, clock) or Fort.in_melee(unit, t))

static func retained(unit: Dictionary, targets: Array) -> Dictionary:
	var nav: Dictionary = unit.attributes.get("navigation", {})
	if nav.get("path", []).is_empty(): return {}
	for target in targets:
		if target.id == nav.get("target", "") and target.owner != unit.owner and not target.attributes.get("hidden", false): return target
	return {}

static func route(unit: Dictionary, destination: Dictionary, rows: Array, structures: Array) -> Array:
	# Bounded local flood fill. Every edge respects walls and actual small
	# footprints. Persistent waypoints stop direct/sideways oscillation.
	var a: Dictionary = unit.attributes
	var side: int = 1 if unit.id.unicode_at(unit.id.length() - 1) % 2 == 0 else -1
	var offsets: Array = [Vector2i(1, 0), Vector2i(0, side), Vector2i(0, -side), Vector2i(-1, 0)]
	var queue: Array = [Vector2i.ZERO]
	var parents: Dictionary = {Vector2i.ZERO: Vector2i.ZERO}
	var points: Dictionary = {Vector2i.ZERO: {"x_fp": int(a.x_fp), "y_fp": int(a.y_fp)}}
	var start_gap: int = Fort.distance(a, destination)
	var cursor: int = 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]; cursor += 1
		var point: Dictionary = points[cell]
		if cell != Vector2i.ZERO and Fort.distance(point, destination) + CELL * CELL * 4 < start_gap:
			var path: Array = []
			while cell != Vector2i.ZERO:
				path.push_front(points[cell]); cell = parents[cell]
			return path
		for offset in offsets:
			var next: Vector2i = cell + offset
			if absi(next.x) > SEARCH_RADIUS or absi(next.y) > SEARCH_RADIUS or parents.has(next): continue
			var proposed: Dictionary = {"x_fp": int(a.x_fp) + next.x * int(a.direction) * CELL, "y_fp": int(a.y_fp) + next.y * CELL}
			var from: Dictionary = unit.duplicate()
			from.attributes = a.merged(point, true)
			# Half-edge checks prevent a coarse grid step cutting through a body.
			var middle: Dictionary = {"x_fp": (int(point.x_fp) + int(proposed.x_fp)) >> 1, "y_fp": (int(point.y_fp) + int(proposed.y_fp)) >> 1}
			if not Spacing.clear(from, middle, rows, structures) or not Spacing.clear(from, proposed, rows, structures): continue
			parents[next] = cell; points[next] = proposed; queue.append(next)
	return []

static func steer(unit: Dictionary, proposed: Dictionary, destination: Dictionary, target: String, rows: Array, structures: Array, step: int, clock: int, protected_target: bool = false, retreat: bool = false) -> Dictionary:
	if retreat or step <= 0: return Spacing.slide(unit, proposed, rows, structures, step, not retreat and not protected_target)
	# Taunt changes the contact target before movement. An old opponent must
	# not pin the fighter in place while its attacks now aim at Kurchin.
	if not protected_target and rows.any(func(other): return other.owner != unit.owner and Spacing.collides(unit, other) and Fort.in_melee(unit, other)): return unit.attributes
	var a: Dictionary = unit.attributes
	var goal: Dictionary = destination if not destination.is_empty() else {"x_fp": 2400 if unit.owner == 0 else 0, "y_fp": int(a.y_fp)}
	var nav: Dictionary = a.get("navigation", {}).duplicate(true)
	var gap: int = Fort.distance(a, goal)
	if not nav.has("progress"):
		nav = {"target": target, "best": gap, "progress": clock, "path": [], "avoid": {}, "origin": {"x_fp": int(a.x_fp), "y_fp": int(a.y_fp)}}
	if nav.get("target", "") != target:
		nav.target = target; nav.best = gap; nav.path = []
	for id in nav.avoid.keys():
		if int(nav.avoid[id]) <= clock: nav.avoid.erase(id)
	if gap + step * step < int(nav.best) and Fort.distance(a, nav.origin) >= 16 * 16:
		nav.best = gap; nav.progress = clock; nav.origin = {"x_fp": int(a.x_fp), "y_fp": int(a.y_fp)}
	if nav.path.is_empty() and clock - int(nav.progress) >= STALL_TICKS:
		nav.path = route(unit, goal, rows, structures)
		nav.progress = clock
		if nav.path.is_empty() and not target.is_empty() and not protected_target:
			nav.avoid[target] = clock + RETRY_TICKS
	var moved: Dictionary
	if not nav.path.is_empty():
		var point: Dictionary = nav.path[0]
		var dx: int = int(point.x_fp) - int(a.x_fp)
		var dy: int = int(point.y_fp) - int(a.y_fp)
		var distance: int = maxi(1, ceili(sqrt(float(dx * dx + dy * dy))))
		moved = a.duplicate(true)
		moved.x_fp += dx if distance <= step else roundi(float(dx * step) / float(distance))
		moved.y_fp += dy if distance <= step else roundi(float(dy * step) / float(distance))
		if Spacing.clear(unit, moved, rows, structures):
			if distance <= step: nav.path.pop_front()
			nav.progress = clock
		else:
			nav.path = []
			nav.progress = clock - STALL_TICKS
			moved = Spacing.slide(unit, proposed, rows, structures, step, not protected_target)
	else:
		moved = Spacing.slide(unit, proposed, rows, structures, step, not protected_target)
	# slide may return a read-only snapshot; always own the navigation update.
	moved = moved.duplicate(true)
	moved["navigation"] = nav
	return moved
