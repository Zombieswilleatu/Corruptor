extends RefCounted

const Embolden = preload("res://Scripts/Sim/U13Embolden.gd")

const Buffer = preload("res://Scripts/Sim/U13MarchingBuffer.gd")

# Structures are battlefield objects, not Marchers: no gate contribution,
# resurrection, charm, death pools or unit-death rewards.
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const CONTACT: int = 90
const LATERAL_CONTACT: int = 42
const BUILD_TICKS: int = 32
const GUARD_TICKS: int = 200
const TOWER_RANGE: int = 600
const REPAIR_RANGE: int = CONTACT
const REPAIR_TICKS: int = 27
const WALL_HP: int = 16
const WALL_ARMOR: int = 4
const TOWER_HP: int = 12
const TOWER_ARMOR: int = 6
const GUARD_RANGE: int = 400
const GUARD_ALERT_RANGE: int = 600
const DESCRIPTION: String = "Builds walls (16 HP / 4 Armor), then a tower (12 HP / 6 Armor) after both walls. New Wrights can take over damaged unguarded friendly structures. Wrights move to damaged nearby structures and each repair 1 HP about every 2 seconds at melee range; no Armor repair. Guards fire at range 400, remain while threatened, and use ordinary melee after leaving their post."

static func rows(world: Dictionary) -> Array:
	return world.data.get("field_structures", [])

static func site_point(owner: int, site: int) -> Dictionary:
	return {"x_fp": (640 if owner == 0 else 1760) if site < 2 else (480 if owner == 0 else 1920), "y_fp": [150, 450, 300][site]}

static func anchor(owner: int, site: int) -> Dictionary:
	var p: Dictionary = site_point(owner, site)
	p.x_fp -= 80 if owner == 0 else -80
	return p

static func find(structures: Array, owner: int, lane: String, site: int) -> Dictionary:
	for row in structures:
		if row.owner == owner and row.attributes.lane == lane and row.attributes.site == site:
			return row
	return {}

static func point(a: Dictionary, target: Dictionary) -> Dictionary:
	var b: Dictionary = target.attributes
	if target.get("kind", "marcher") != "fortification" or b.structure != "Wall":
		return {"x_fp": b.x_fp, "y_fp": b.y_fp}
	# Distance to a wall's physical rectangle, rather than its decorative center.
	return {"x_fp": clampi(int(a.x_fp), int(b.x_fp) - 24, int(b.x_fp) + 24), "y_fp": clampi(int(a.y_fp), int(b.y_fp) - 150, int(b.y_fp) + 150)}

static func distance(a: Dictionary, b: Dictionary) -> int:
	var dx: int = int(a.x_fp) - int(b.x_fp)
	var dy: int = int(a.y_fp) - int(b.y_fp)
	return dx * dx + dy * dy

static func gap(unit: Dictionary, target: Dictionary) -> int:
	if target.get("kind", "marcher") != "fortification" or target.attributes.structure != "Wall":
		return distance(unit.attributes, target.attributes)
	return distance(unit.attributes, point(unit.attributes, target))

static func in_melee(unit: Dictionary, target: Dictionary) -> bool:
	if target.is_empty(): return false
	var a: Dictionary = unit.attributes
	var b: Dictionary = target.attributes
	var dx: int = int(a.x_fp) - int(b.x_fp)
	var dy: int = int(a.y_fp) - int(b.y_fp)
	if target.get("kind", "marcher") == "fortification" and b.structure == "Wall":
		dx = int(a.x_fp) - clampi(int(a.x_fp), int(b.x_fp) - 24, int(b.x_fp) + 24)
		dy = int(a.y_fp) - clampi(int(a.y_fp), int(b.y_fp) - 150, int(b.y_fp) + 150)
	if absi(dx) > CONTACT or absi(dy) > LATERAL_CONTACT: return false
	# The lane is much more stretched laterally on screen. A narrow lateral
	# footprint keeps a sideways hit near the feet instead of across a row.
	return dx * dx * LATERAL_CONTACT * LATERAL_CONTACT + dy * dy * CONTACT * CONTACT <= CONTACT * CONTACT * LATERAL_CONTACT * LATERAL_CONTACT

static func blocker(unit: Dictionary, destination: Dictionary, structures: Array) -> Dictionary:
	if unit.attributes.get("flying", false) or destination.is_empty(): return {}
	var a: Dictionary = unit.attributes
	var best: Dictionary = {}
	var best_gap: int = 9223372036854775807
	for row in structures:
		var b: Dictionary = row.attributes
		if row.owner == unit.owner or b.lane != a.lane or b.structure != "Wall": continue
		var dx: int = int(destination.x_fp) - int(a.x_fp)
		if dx == 0: continue
		var along: int = (int(b.x_fp) - int(a.x_fp)) * (1 if dx > 0 else -1)
		if along < 0 or along > absi(dx): continue
		var cross_y: int = int(a.y_fp) + roundi(float((int(destination.y_fp) - int(a.y_fp)) * along) / float(absi(dx)))
		if absi(cross_y - int(b.y_fp)) > 150: continue
		var d: int = gap(unit, row)
		if d < best_gap: best = row; best_gap = d
	return best

static func blocked_step(unit: Dictionary, proposed: Dictionary, structures: Array) -> bool:
	if unit.attributes.get("flying", false): return false
	for row in structures:
		if row.owner == unit.owner or row.attributes.lane != unit.attributes.lane or row.attributes.structure != "Wall": continue
		var after: int = distance(proposed, point(proposed, row))
		if after < 42 * 42 and after < gap(unit, row): return true
	return false

static func assigned_structure(unit: Dictionary, structures: Array) -> Dictionary:
	var a: Dictionary = unit.attributes
	if not a.has("wright_site") or a.get("wright_owner", -1) != unit.owner: return {}
	var structure: Dictionary = find(structures, unit.owner, a.lane, a.wright_site)
	if a.has("wright_guard_target"):
		return structure if not structure.is_empty() and structure.id == a.wright_guard_target else {}
	return structure if not structure.is_empty() and structure.attributes.builder_id == unit.id else {}

static func guarding(a: Dictionary) -> bool:
	return a.get("wright_built", false) or a.has("wright_guard_target")

static func ranged_guard(unit: Dictionary, structures: Array, number: int) -> bool:
	if unit.get("kind") != "marcher": return false
	var a: Dictionary = unit.attributes
	return a.get("suit") == "Wright" and not a.has("monster_id") and guarding(a) and not a.get("wright_released", false) and not a.waiting and a.movement_ready_round <= number and not a.get("hidden", false) and not assigned_structure(unit, structures).is_empty() and distance(a, anchor(unit.owner, a.wright_site)) <= 32 * 32

static func threatened_post(unit: Dictionary, units: Array, structures: Array) -> bool:
	var home: Dictionary = anchor(unit.owner, unit.attributes.wright_site)
	for other in units:
		var b: Dictionary = other.attributes
		if other.owner == unit.owner or b.lane != unit.attributes.lane or b.get("hidden", false) or b.waiting: continue
		# An incoming wave remains a threat even while an ally intercepts it
		# outside the local alert radius. Distant enemy fort guards and turrets
		# need not hold both armies at their own posts indefinitely.
		if distance(home, b) <= GUARD_ALERT_RANGE * GUARD_ALERT_RANGE: return true
		if b.get("sprite_form") == "turret": continue
		if b.get("suit") == "Wright" and not b.has("monster_id") and guarding(b) and not b.get("wright_released", false) and not assigned_structure(other, structures).is_empty(): continue
		return true
	return false

static func repair_support_target(unit: Dictionary, structures: Array) -> Dictionary:
	var a: Dictionary = unit.attributes
	if not guarding(a) or a.get("wright_released", false) or (a.has("wright_guard_target") and not a.get("wright_arrived", false)): return {}
	var held: Dictionary = assigned_structure(unit, structures)
	if held.is_empty() or held.attributes.hp < held.attributes.max_hp: return {}
	var home: Dictionary = anchor(unit.owner, a.wright_site)
	var best: Dictionary = {}
	var best_gap: int = 9223372036854775807
	for other in structures:
		var b: Dictionary = other.attributes
		if other.owner != unit.owner or b.lane != a.lane or b.hp >= b.max_hp or distance(home, anchor(unit.owner, b.site)) > GUARD_ALERT_RANGE * GUARD_ALERT_RANGE: continue
		var d: int = gap(unit, other)
		if d < best_gap or (d == best_gap and (best.is_empty() or other.id < best.id)):
			best = other; best_gap = d
	return best

static func work_in_reach(unit: Dictionary, structures: Array, destination: Dictionary) -> bool:
	# The normal post-arrival tolerance must not stop a repairer outside contact.
	for structure in structures:
		var b: Dictionary = structure.attributes
		if structure.owner == unit.owner and b.lane == unit.attributes.lane and anchor(unit.owner, b.site) == destination and b.hp < b.max_hp:
			return in_melee(unit, structure)
	return true

static func goal(unit: Dictionary, structures: Array, _clock: int, _enemy: Dictionary) -> Dictionary:
	var a: Dictionary = unit.attributes
	if not a.has("wright_site"): return {}
	var home: Dictionary = anchor(unit.owner, int(a.wright_site))
	if not guarding(a): return home
	var structure: Dictionary = assigned_structure(unit, structures)
	if a.get("wright_released", false) or structure.is_empty(): return {}
	if a.has("wright_guard_target") and not a.get("wright_arrived", false): return home
	var support: Dictionary = repair_support_target(unit, structures)
	if not support.is_empty(): return anchor(unit.owner, support.attributes.site)
	# Only step() releases guard duty; movement must honor that decision.
	return home

static func step(world: Dictionary, entities, number: int, tick: int, fleeing: Dictionary = {}) -> Array:
	if not world.data.has("field_structures"): world.data["field_structures"] = []
	var structures: Array = rows(world)
	var units: Array = entities.marchers()
	var clock: int = number * 200 + tick
	var events: Array = []
	var reserved: Dictionary = {}
	var guarded: Dictionary = {}
	# Living builders reserve a site; death or an owner change releases it.
	for unit in units:
		var a: Dictionary = unit.attributes
		if a.get("suit") != "Wright" or a.has("monster_id"): continue
		if guarding(a) and not a.get("wright_released", false):
			var held: Dictionary = assigned_structure(unit, structures)
			if not held.is_empty(): guarded[held.id] = unit.id
		if a.has("wright_site") and not guarding(a):
			var site: int = a.wright_site
			if a.get("wright_owner", -1) != unit.owner or not find(structures, unit.owner, a.lane, site).is_empty() or (site == 2 and (find(structures, unit.owner, a.lane, 0).is_empty() or find(structures, unit.owner, a.lane, 1).is_empty())):
				a.erase("wright_site"); a.erase("wright_progress"); a.erase("wright_owner")
				entities.update(unit.id, unit.owner, a)
			else: reserved["%d:%s:%d" % [unit.owner, a.lane, site]] = unit.id
	for original in units:
		if original.attributes.get("suit") != "Wright" or original.attributes.has("monster_id"): continue
		var unit: Dictionary = entities.get_entity(original.id)
		var a: Dictionary = unit.attributes
		var active: bool = not a.waiting and a.movement_ready_round <= number and a.get("rout_round", -1) != number and not a.get("hidden", false) and not fleeing.has(unit.id)
		if a.get("suit") == "Wright" and not a.has("monster_id") and not a.has("wright_site") and not guarding(a) and active:
			var repair: Dictionary = {}
			var repair_distance: int = 9223372036854775807
			for structure in structures:
				var b: Dictionary = structure.attributes
				if structure.owner != unit.owner or b.lane != a.lane or b.hp >= b.max_hp or guarded.has(structure.id): continue
				var d: int = distance(a, anchor(unit.owner, b.site))
				if d < repair_distance:
					repair = structure; repair_distance = d
			if not repair.is_empty():
				a.merge({"wright_site": repair.attributes.site, "wright_owner": unit.owner, "wright_progress": 0, "wright_guard_target": repair.id, "wright_arrived": false, "wright_guard_until": 0, "wright_repair_round": a.get("wright_repair_round", 0), "wright_released": false}, true)
				guarded[repair.id] = unit.id
				events.append(event("WRIGHT_REPAIR_ASSIGNED", {"unit_id": unit.id, "structure": repair, "owner": unit.owner, "lane": a.lane, "round": number, "tick": tick}))
		if a.get("suit") == "Wright" and not a.has("monster_id") and guarding(a):
			if a.get("wright_released", false): continue
			var structure: Dictionary = assigned_structure(unit, structures)
			if structure.is_empty():
				a["wright_released"] = true
			elif active:
				var arrived_now: bool = a.has("wright_guard_target") and not a.get("wright_arrived", false) and distance(a, anchor(unit.owner, a.wright_site)) <= 16 * 16
				if arrived_now:
					a["wright_arrived"] = true
					a["wright_guard_until"] = clock + GUARD_TICKS
				var at_post: bool = not a.has("wright_guard_target") or a.get("wright_arrived", false)
				if at_post and clock >= int(a.wright_guard_until) and structure.attributes.hp == structure.attributes.max_hp and not threatened_post(unit, units, structures) and repair_support_target(unit, structures).is_empty():
					a["wright_released"] = true
			entities.update(unit.id, unit.owner, a)
			continue
		if a.suit != "Wright" or a.has("monster_id") or guarding(a) or not active: continue
		if not a.has("wright_site"):
			var choices: Array = [0, 1]
			if not find(structures, unit.owner, a.lane, 0).is_empty() and not find(structures, unit.owner, a.lane, 1).is_empty(): choices = [2]
			var selected: int = -1
			var best: int = 9223372036854775807
			for site in choices:
				if not find(structures, unit.owner, a.lane, site).is_empty() or reserved.has("%d:%s:%d" % [unit.owner, a.lane, site]): continue
				var d: int = distance(a, anchor(unit.owner, site))
				if d < best: best = d; selected = site
			if selected < 0: continue
			a.merge({"wright_site": selected, "wright_progress": 0, "wright_owner": unit.owner}, true)
			reserved["%d:%s:%d" % [unit.owner, a.lane, selected]] = unit.id
			events.append(event("WRIGHT_BUILD_ASSIGNED", {"unit_id": unit.id, "site": selected, "owner": unit.owner, "lane": a.lane, "round": number, "tick": tick}))
		var threatened: bool = units.any(func(r): return r.owner != unit.owner and r.attributes.lane == a.lane and not r.attributes.get("hidden", false) and in_melee(unit, r))
		if distance(a, anchor(unit.owner, a.wright_site)) <= 16 * 16 and not threatened:
			a.wright_progress += 1
			if a.wright_progress >= BUILD_TICKS:
				var p: Dictionary = site_point(unit.owner, a.wright_site)
				var tower: bool = a.wright_site == 2
				var built: Dictionary = {"id": Data.instance_id("wright_structure", unit.id, str(a.wright_site)), "kind": "fortification", "owner": unit.owner, "attributes": {"structure": "Tower" if tower else "Wall", "site": a.wright_site, "lane": a.lane, "x_fp": p.x_fp, "y_fp": p.y_fp, "hp": TOWER_HP if tower else WALL_HP, "max_hp": TOWER_HP if tower else WALL_HP, "armor": TOWER_ARMOR if tower else WALL_ARMOR, "max_armor": TOWER_ARMOR if tower else WALL_ARMOR, "attack": 1 if tower else 0, "ranged_next_tick": clock + 1, "builder_id": unit.id}}
				structures.append(built)
				guarded[built.id] = unit.id
				structures.sort_custom(func(x, y): return x.id < y.id)
				a["wright_built"] = true
				a["wright_guard_until"] = clock + GUARD_TICKS
				a["wright_repair_round"] = a.get("wright_repair_round", 0)
				a["wright_released"] = false
				events.append(event("WRIGHT_STRUCTURE_BUILT", {"unit_id": unit.id, "structure": built, "round": number, "tick": tick}))
		entities.update(unit.id, unit.owner, a)
	events.append_array(repair_nearby(world, entities, number, tick, fleeing))
	return events

static func repair_nearby(world: Dictionary, entities, number: int, tick: int, fleeing: Dictionary = {}) -> Array:
	var events: Array = []
	var observed: Array = entities._read_marchers() if entities is Buffer else entities.marchers()
	for unit in observed:
		var a: Dictionary = unit.attributes
		if a.get("suit") != "Wright" or a.has("monster_id") or a.waiting or a.movement_ready_round > number or a.get("rout_round", -1) == number or a.get("hidden", false) or fleeing.has(unit.id) or int(a.get("wright_repair_next_tick", 0)) > number * 200 + tick: continue
		var target: Dictionary = {}
		var nearest_gap: int = 9223372036854775807
		for structure in rows(world):
			var b: Dictionary = structure.attributes
			if structure.owner != unit.owner or b.lane != a.lane or b.hp >= b.max_hp: continue
			var d: int = gap(unit, structure)
			if not in_melee(unit, structure): continue
			if d < nearest_gap or (d == nearest_gap and (target.is_empty() or structure.id < target.id)):
				target = structure; nearest_gap = d
		if target.is_empty(): continue
		var before = target.attributes.hp
		target.attributes.hp = min(target.attributes.max_hp, before + 1)
		# Borrowed rows are immutable; detach only the successful repairer.
		a = a.duplicate(true)
		a["wright_repair_next_tick"] = number * 200 + tick + REPAIR_TICKS
		entities.update(unit.id, unit.owner, a)
		events.append(event("WRIGHT_STRUCTURE_REPAIRED", {"unit_id": unit.id, "structure": target, "owner": unit.owner, "lane": a.lane, "hp_before": before, "hp_after": target.attributes.hp, "round": number, "tick": tick}))
	return events

static func damage(world: Dictionary, target_id: String, source: Dictionary, amount, bypass: bool, number: int, tick: int) -> Dictionary:
	for row in rows(world):
		if row.id != target_id: continue
		var a: Dictionary = row.attributes
		var absorbed = 0 if bypass else min(a.armor, amount)
		a.armor -= absorbed
		var dealt = amount - absorbed
		a.hp = max(0, Embolden.clean(a.hp - dealt))
		var events: Array = []
		if a.hp == 0:
			events.append(event("WRIGHT_STRUCTURE_DESTROYED", {"structure": row, "attacker": source, "round": number, "tick": tick}))
			world.data.field_structures.erase(row)
		return {"damage_dealt": dealt, "hp_after": a.hp, "events": events}
	return {"damage_dealt": 0, "hp_after": 0, "events": []}

static func beam_hit(source: Dictionary, aim: Dictionary, row: Dictionary, radius: int, half_width: int) -> bool:
	var vx: int = int(aim.x_fp) - int(source.x_fp)
	var vy: int = int(aim.y_fp) - int(source.y_fp)
	var p: Dictionary = row.attributes.duplicate()
	if p.structure == "Wall" and vx != 0:
		var ray_y: int = int(source.y_fp) + roundi(float((int(p.x_fp) - int(source.x_fp)) * vy) / float(vx))
		p.y_fp = clampi(ray_y, int(p.y_fp) - 150, int(p.y_fp) + 150)
	var dx: int = int(p.x_fp) - int(source.x_fp)
	var dy: int = int(p.y_fp) - int(source.y_fp)
	var cross: int = dx * vy - dy * vx
	return dx * vx + dy * vy >= 0 and dx * dx + dy * dy <= radius * radius and cross * cross <= half_width * half_width * maxi(1, vx * vx + vy * vy)

static func valid_unit(a: Dictionary) -> bool:
	for key in ["wright_site", "wright_progress", "wright_owner", "wright_guard_until", "wright_repair_round", "wright_repair_next_tick"]:
		if a.has(key) and (a.get("suit") != "Wright" or a.has("monster_id") or not Data.is_integer(a[key]) or int(a[key]) < 0): return false
	for key in ["wright_built", "wright_released", "wright_arrived"]:
		if a.has(key) and (a.get("suit") != "Wright" or a.has("monster_id") or typeof(a[key]) != TYPE_BOOL): return false
	if a.has("wright_guard_target") and (a.get("suit") != "Wright" or a.has("monster_id") or typeof(a.wright_guard_target) != TYPE_STRING or a.wright_guard_target.is_empty() or not a.has("wright_arrived")): return false
	if a.has("wright_arrived") and not a.has("wright_guard_target"): return false
	if a.has("wright_released") and not guarding(a): return false
	if a.has("wright_site") and (int(a.wright_site) > 2 or not a.has("wright_progress") or int(a.wright_progress) > BUILD_TICKS or a.get("wright_owner", -1) not in [0, 1]): return false
	if guarding(a) and (not a.has("wright_site") or not a.has("wright_guard_until")): return false
	return true

static func valid(world: Dictionary) -> bool:
	var structures = world.data.get("field_structures", [])
	if typeof(structures) != TYPE_ARRAY or structures.size() > 12: return false
	var sites: Array = []
	var builders: Array = []
	for row in structures:
		if typeof(row) != TYPE_DICTIONARY or row.get("kind") != "fortification" or row.get("owner") not in [0, 1] or typeof(row.get("attributes")) != TYPE_DICTIONARY: return false
		var a: Dictionary = row.attributes
		if a.has("repair_round") and (not Data.is_integer(a.repair_round) or int(a.repair_round) < 0): return false
		for key in ["site", "x_fp", "y_fp", "hp", "max_hp", "armor", "max_armor", "attack", "ranged_next_tick"]:
			if not (Embolden.numeric(a.get(key)) if Embolden.enabled(world) and key in ["hp", "armor"] else Data.is_integer(a.get(key))): return false
		if a.site not in [0, 1, 2] or a.get("lane") not in ["Lord", "Castle"] or typeof(a.get("builder_id")) != TYPE_STRING: return false
		if row.get("id") != Data.instance_id("wright_structure", a.builder_id, str(a.site)): return false
		if a.builder_id not in world.entities.get("used_ids", []) or a.builder_id in builders: return false
		builders.append(a.builder_id)
		var p: Dictionary = site_point(row.owner, a.site)
		if a.x_fp != p.x_fp or a.y_fp != p.y_fp or a.hp <= 0 or a.hp > a.max_hp or a.armor < 0 or a.armor > a.max_armor or a.ranged_next_tick < 0: return false
		var tower: bool = a.site == 2
		# Keep old saves readable without silently upgrading their structures.
		var legacy: bool = a.max_hp == 6 and a.max_armor == (4 if tower else 2)
		var current: bool = a.max_hp == (TOWER_HP if tower else WALL_HP) and a.max_armor == (TOWER_ARMOR if tower else WALL_ARMOR)
		if not (legacy or current) or a.get("structure") != ("Tower" if tower else "Wall") or a.attack != (1 if tower else 0): return false
		var key: String = "%d:%s:%d" % [row.owner, a.lane, a.site]
		if key in sites: return false
		sites.append(key)
	var claims: Array = []
	var guard_claims: Array = []
	for row in world.entities.entities:
		if row.kind == "marcher" and guarding(row.attributes) and not row.attributes.get("wright_released", false):
			var held: Dictionary = assigned_structure(row, structures)
			if not held.is_empty():
				if held.id in guard_claims: return false
				guard_claims.append(held.id)
		if row.kind != "marcher" or not row.attributes.has("wright_site") or guarding(row.attributes): continue
		# Charm releases the old claim; step() clears it before assigning a new one.
		if row.attributes.get("wright_owner", -1) != row.owner: continue
		var key: String = "%s:%s:%s" % [row.owner, row.attributes.get("lane", ""), row.attributes.wright_site]
		if key in claims: return false
		claims.append(key)
	return true

static func event(kind: String, details: Dictionary) -> Dictionary:
	var fact: Dictionary = {"type": kind, "text": "", "data": details.duplicate(true)}
	return {"event": fact, "views": [fact, fact]}
