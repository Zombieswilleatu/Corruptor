extends RefCounted

# Fixed-point combat movement shared by the lane runner and the live game.
const Rules = preload("res://Scripts/Sim/U13MonsterRules.gd")
const Fort = preload("res://Scripts/Sim/U13FieldFortifications.gd")
const Shroud = preload("res://Scripts/Sim/U13DotraShroud.gd")
const GAP: int = 42

static func active(a: Dictionary) -> bool:
	return a.get("tumler_charge_phase", "") in ["windup", "charge"]

static func rank_target(unit: Dictionary) -> int:
	return ["Sooge", "Kopita", "Fyra", "Vulture"].find(unit.attributes.get("monster_id", unit.attributes.suit)) if unit.attributes.get("monster_id", unit.attributes.suit) in ["Sooge", "Kopita", "Fyra", "Vulture"] else 4

static func legal(unit: Dictionary, target: Dictionary) -> bool:
	return not target.is_empty() and target.kind == "marcher" and target.owner != unit.owner and target.attributes.lane == unit.attributes.lane and int(target.attributes.hp) > 0 and Shroud.targetable(target.attributes)

static func engaged_target(unit: Dictionary, rows: Array) -> Dictionary:
	var a: Dictionary = unit.attributes
	var id: String = a.get("tumler_engaged_target", "")
	if id.is_empty() or int(a.get("tumler_engaged_owner", -1)) != int(unit.owner): return {}
	for row in rows:
		if row.id == id and legal(unit, row): return row
	return {}

static func clear_engagement(a: Dictionary) -> void:
	# Explicit empty values also clear phase-start attribute-delta replays.
	if not a.has("tumler_engaged_target"): return
	a["tumler_engaged_target"] = ""
	a["tumler_engaged_owner"] = -1

static func select_target(unit: Dictionary, rows: Array, clock: int) -> Dictionary:
	# Priority chooses a new hunt. After contact, finish that fight even if
	# another backliner becomes closer or a higher-priority wave deploys.
	if not active(unit.attributes):
		var engaged: Dictionary = engaged_target(unit, rows)
		if not engaged.is_empty(): return engaged
	var best: Dictionary = {}
	for row in rows:
		if not legal(unit, row): continue
		if active(unit.attributes):
			if row.id == unit.attributes.get("tumler_charge_target", ""): return row
			continue
		# A charge can clear bodies that ordinary navigation marked unreachable.
		if rank_target(row) == 4 and int(unit.attributes.get("navigation", {}).get("avoid", {}).get(row.id, 0)) > clock: continue
		if best.is_empty() or rank_target(row) < rank_target(best) or (rank_target(row) == rank_target(best) and (Fort.gap(unit, row) < Fort.gap(unit, best) or (Fort.gap(unit, row) == Fort.gap(unit, best) and row.id < best.id))): best = row
	return best

static func fact(kind: String, unit: Dictionary, context: Dictionary, tick: int, extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {"unit_id": unit.id, "target_id": unit.attributes.get("tumler_charge_target", ""), "owner": unit.owner, "lane": unit.attributes.lane, "round": context.round, "tick": tick}
	data.merge(extra, true)
	return Fort.event(kind, data)

static func finish(unit: Dictionary, context: Dictionary, tick: int, reason: String) -> Dictionary:
	var a: Dictionary = unit.attributes
	# Damage already consumes the combined Armor pool through the ordinary
	# combat paths. Temporary Armor is the top five points, spent first. Clamp
	# to the pre-charge remainder; never subtract five from permanent Armor.
	var removed: int = maxi(0, int(a.armor) - int(a.get("tumler_charge_base_armor", a.armor)))
	a.armor -= removed
	var result: Dictionary = fact("MONSTER_CHARGE_ENDED", unit, context, tick, {"reason": reason, "armor_removed": removed})
	if reason == "target":
		a["tumler_engaged_target"] = a.get("tumler_charge_target", "")
		a["tumler_engaged_owner"] = unit.owner
	else: clear_engagement(a)
	a["tumler_charge_phase"] = ""
	a["tumler_charge_target"] = ""
	a["tumler_charge_base_armor"] = 0
	a["tumler_charge_ready_tick"] = 0
	a["tumler_charge_end_tick"] = 0
	a["tumler_charge_goal_x_fp"] = 0
	a["tumler_charge_goal_y_fp"] = 0
	return result

static func swept(a: Dictionary, b: Dictionary, p: Dictionary) -> bool:
	var dx: int = int(b.x_fp) - int(a.x_fp)
	var dy: int = int(b.y_fp) - int(a.y_fp)
	var px: int = int(p.x_fp) - int(a.x_fp)
	var py: int = int(p.y_fp) - int(a.y_fp)
	var length2: int = dx * dx + dy * dy
	var dot: int = px * dx + py * dy
	if length2 == 0 or dot < 0: return false
	if dot > length2: return Fort.distance(b, p) < GAP * GAP
	var cross: int = px * dy - py * dx
	return cross * cross < GAP * GAP * length2

static func side_point(unit: Dictionary, other: Dictionary, heading: Dictionary, rows: Array, structures: Array) -> Dictionary:
	var dx: int = int(heading.x_fp) - int(unit.attributes.x_fp)
	var dy: int = int(heading.y_fp) - int(unit.attributes.y_fp)
	var scale: int = maxi(absi(dx), absi(dy))
	if scale == 0: return {}
	var cross: int = dx * (int(other.attributes.y_fp) - int(unit.attributes.y_fp)) - dy * (int(other.attributes.x_fp) - int(unit.attributes.x_fp))
	var sign_first: int = 1 if cross > 0 else -1
	if cross == 0: sign_first = 1 if other.id.unicode_at(other.id.length() - 1) % 2 == 0 else -1
	for reach in range(GAP * 2, GAP * 15, GAP):
		for side in [sign_first, -sign_first]:
			var p: Dictionary = {"x_fp": int(other.attributes.x_fp) + int(float(-dy * reach * side) / scale), "y_fp": int(other.attributes.y_fp) + int(float(dx * reach * side) / scale)}
			if p.x_fp < 0 or p.x_fp > 2400 or p.y_fp < 0 or p.y_fp > 600: continue
			if Fort.blocked_step(other, p, structures) or not Fort.blocker(other, p, structures).is_empty(): continue
			if rows.any(func(r): return r.id != other.id and r.attributes.lane == other.attributes.lane and Fort.distance(p, r.attributes) < GAP * GAP): continue
			return p
	return {}

static func advance(unit: Dictionary, target: Dictionary, entities, structures: Array, context: Dictionary, tick: int, live_target: bool = true) -> Array:
	var a: Dictionary = unit.attributes
	var dx: int = int(target.attributes.x_fp) - int(a.x_fp)
	var dy: int = int(target.attributes.y_fp) - int(a.y_fp)
	var scale: int = maxi(absi(dx), absi(dy))
	var p: Dictionary = {"x_fp": a.x_fp, "y_fp": a.y_fp}
	var arrival: String = "target" if live_target else "destination"
	var reason: String = arrival if Fort.in_melee(unit, target) else ""
	var wall: Dictionary = Fort.blocker(unit, target.attributes, structures)
	# Sweep the entire movement segment. Stop at the first melee footprint;
	# a diagonal or vertical charge must not pass through the target or wall.
	if reason.is_empty() and scale > 0:
		for offset in range(1, mini(scale, int(Rules.TUNING.tumler_charge_step_fp)) + 1):
			var candidate: Dictionary = {"x_fp": int(a.x_fp) + int(float(dx * offset) / scale), "y_fp": int(a.y_fp) + int(float(dy * offset) / scale)}
			if Fort.blocked_step(unit, candidate, structures): reason = "wall"; break
			p = candidate
			var probe: Dictionary = {"attributes": candidate}
			if not wall.is_empty() and Fort.in_melee(probe, wall): reason = "wall"; break
			if Fort.in_melee(probe, target): reason = arrival; break
	var events: Array = []
	for observed in entities._read_marchers():
		if observed.id in [unit.id, target.id] or observed.attributes.lane != a.lane or not swept(a, p, observed.attributes): continue
		var shifted: Dictionary = side_point(unit, observed, p, entities._read_marchers(), structures)
		if shifted.is_empty():
			# Bodies cannot cancel a committed rush. If every legal shove is
			# occupied, pass through that body; normal separation resumes later.
			continue
		# Registry read versions are immutable; detach only the displaced body.
		var other: Dictionary = observed.duplicate(true)
		var before: Dictionary = {"x_fp": other.attributes.x_fp, "y_fp": other.attributes.y_fp}
		other.attributes.merge(shifted, true)
		other.attributes.contact_tick = -1
		entities.update(other.id, other.owner, other.attributes)
		events.append(fact("MONSTER_CHARGE_DISPLACED", unit, context, tick, {"displaced_id": other.id, "displaced_owner": other.owner, "from": before, "to": shifted}))
	a.x_fp = p.x_fp; a.y_fp = p.y_fp
	a.contact_tick = -1
	if not reason.is_empty(): events.append(finish(unit, context, tick, reason))
	return events

static func step(entities, structures: Array, context: Dictionary, tick: int, fleeing: Dictionary) -> Array:
	var events: Array = []
	var clock: int = int(context.round) * 200 + tick
	for original in entities._read_marchers():
		if original.attributes.get("monster_id") != "Tumler": continue
		var unit: Dictionary = entities.get_entity(original.id)
		var a: Dictionary = unit.attributes
		var allowed: bool = int(a.step_fp) > 0 and not a.waiting and a.movement_ready_round <= context.round and a.get("rout_round", -1) != context.round and not a.get("hidden", false) and not fleeing.has(unit.id)
		if not a.get("tumler_engaged_target", "").is_empty() and (not allowed or engaged_target(unit, entities._read_marchers()).is_empty()): clear_engagement(a)
		var target: Dictionary = select_target(unit, entities._read_marchers(), clock)
		if active(a):
			var live_target: bool = legal(unit, target)
			if live_target:
				a["tumler_charge_goal_x_fp"] = int(target.attributes.x_fp)
				a["tumler_charge_goal_y_fp"] = int(target.attributes.y_fp)
			else:
				# Finish the momentum toward the last visible position. A lost,
				# hidden or newly allied victim cannot be attacked or tracked.
				var direction: int = 1 if int(a.get("tumler_charge_owner", unit.owner)) == 0 else -1
				target = {"id": a.get("tumler_charge_target", ""), "attributes": {"x_fp": a.get("tumler_charge_goal_x_fp", clampi(int(a.x_fp) + direction * int(Rules.TUNING.tumler_charge_range), 0, 2400)), "y_fp": a.get("tumler_charge_goal_y_fp", a.y_fp)}}
			a["tumler_charge_motion_tick"] = clock
			if a.tumler_charge_phase == "windup" and clock >= int(a.tumler_charge_ready_tick):
				a.tumler_charge_phase = "charge"
				events.append(fact("MONSTER_CHARGE_LAUNCHED", unit, context, tick))
			if a.tumler_charge_phase == "charge": events.append_array(advance(unit, target, entities, structures, context, tick, live_target))
		elif allowed and clock >= int(a.get("tumler_charge_next_tick", 0)) and legal(unit, target) and not Fort.in_melee(unit, target) and Fort.gap(unit, target) <= int(Rules.TUNING.tumler_charge_range) ** 2:
			var wall: Dictionary = Fort.blocker(unit, target.attributes, structures)
			if wall.is_empty() or not Fort.in_melee(unit, wall):
				a["hunt_target"] = target.id
				a["tumler_charge_phase"] = "windup"
				a["tumler_charge_target"] = target.id
				a["tumler_charge_owner"] = unit.owner
				a["tumler_charge_goal_x_fp"] = int(target.attributes.x_fp)
				a["tumler_charge_goal_y_fp"] = int(target.attributes.y_fp)
				a["tumler_charge_base_armor"] = int(a.armor)
				a.armor += int(Rules.TUNING.tumler_charge_armor)
				a["tumler_charge_ready_tick"] = clock + int(Rules.TUNING.tumler_charge_windup_ticks)
				a["tumler_charge_end_tick"] = int(a.tumler_charge_ready_tick) + int(Rules.TUNING.tumler_charge_max_ticks)
				a["tumler_charge_next_tick"] = clock + int(Rules.TUNING.tumler_charge_cooldown_ticks)
				a["tumler_charge_motion_tick"] = clock
				a.contact_tick = -1
				events.append(fact("MONSTER_CHARGE_WINDUP", unit, context, tick, {"armor_gained": Rules.TUNING.tumler_charge_armor, "ready_tick": a.tumler_charge_ready_tick}))
		entities.update(unit.id, unit.owner, a)
	return events
