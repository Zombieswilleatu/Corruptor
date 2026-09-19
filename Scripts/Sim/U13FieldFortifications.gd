extends RefCounted

# Structures are battlefield objects, not Marchers: no gate contribution,
# resurrection, charm, death pools or unit-death rewards.
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const CONTACT: int = 90
const LATERAL_CONTACT: int = 42
const BUILD_TICKS: int = 32
const GUARD_TICKS: int = 200
const TOWER_RANGE: int = 600
const DESCRIPTION: String = "Builds one wall, or a tower when both walls stand. Guards for at least one round and repairs 1 HP each round. Marches onward once its structure has full HP."

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
	return (int(a.x_fp) - int(b.x_fp)) ** 2 + (int(a.y_fp) - int(b.y_fp)) ** 2

static func gap(unit: Dictionary, target: Dictionary) -> int:
	return distance(unit.attributes, point(unit.attributes, target))

static func in_melee(unit: Dictionary, target: Dictionary) -> bool:
	if target.is_empty(): return false
	var p: Dictionary = point(unit.attributes, target)
	var dx: int = int(unit.attributes.x_fp) - int(p.x_fp)
	var dy: int = int(unit.attributes.y_fp) - int(p.y_fp)
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
	return structure if not structure.is_empty() and structure.attributes.builder_id == unit.id else {}

static func goal(unit: Dictionary, structures: Array, clock: int, enemy: Dictionary) -> Dictionary:
	var a: Dictionary = unit.attributes
	if not a.has("wright_site"): return {}
	var home: Dictionary = anchor(unit.owner, int(a.wright_site))
	if not a.get("wright_built", false): return home
	var structure: Dictionary = assigned_structure(unit, structures)
	if a.get("wright_released", false) or structure.is_empty(): return {}
	if clock >= int(a.get("wright_guard_until", 0)) and structure.attributes.hp == structure.attributes.max_hp: return {}
	if not enemy.is_empty() and distance(home, point(home, enemy)) <= 240 * 240:
		return point(a, enemy)
	return home

static func step(world: Dictionary, entities, number: int, tick: int, fleeing: Dictionary = {}) -> Array:
	if not world.data.has("field_structures"): world.data["field_structures"] = []
	var structures: Array = rows(world)
	var units: Array = entities.marchers()
	var clock: int = number * 200 + tick
	var events: Array = []
	var reserved: Dictionary = {}
	# Living builders reserve a site; death or an owner change releases it.
	for unit in units:
		var a: Dictionary = unit.attributes
		if a.get("suit") != "Wright" or a.has("monster_id"): continue
		if a.has("wright_site") and not a.get("wright_built", false):
			var site: int = a.wright_site
			if a.get("wright_owner", -1) != unit.owner or not find(structures, unit.owner, a.lane, site).is_empty() or (site == 2 and (find(structures, unit.owner, a.lane, 0).is_empty() or find(structures, unit.owner, a.lane, 1).is_empty())):
				a.erase("wright_site"); a.erase("wright_progress"); a.erase("wright_owner")
				entities.update(unit.id, unit.owner, a)
			else: reserved["%d:%s:%d" % [unit.owner, a.lane, site]] = unit.id
	for original in units:
		var unit: Dictionary = entities.get_entity(original.id)
		var a: Dictionary = unit.attributes
		if a.get("suit") == "Wright" and not a.has("monster_id") and a.get("wright_built", false):
			if a.get("wright_released", false): continue
			var structure: Dictionary = assigned_structure(unit, structures)
			if structure.is_empty():
				a["wright_released"] = true
			elif not a.waiting and a.movement_ready_round <= number and a.get("rout_round", -1) != number and not a.get("hidden", false) and not fleeing.has(unit.id):
				# A round-start repair is spent once, even when HP is already full.
				if tick == 0 and int(a.get("wright_repair_round", 0)) < number:
					a["wright_repair_round"] = number
					var before: int = int(structure.attributes.hp)
					if before < int(structure.attributes.max_hp):
						structure.attributes.hp = before + 1
						events.append(event("WRIGHT_STRUCTURE_REPAIRED", {"unit_id": unit.id, "structure": structure, "owner": unit.owner, "lane": a.lane, "hp_before": before, "hp_after": structure.attributes.hp, "round": number, "tick": tick}))
				if clock >= int(a.wright_guard_until) and structure.attributes.hp == structure.attributes.max_hp:
					a["wright_released"] = true
			entities.update(unit.id, unit.owner, a)
			continue
		if a.suit != "Wright" or a.has("monster_id") or a.get("wright_built", false) or a.waiting or int(a.movement_ready_round) > number or int(a.get("rout_round", -1)) == number or a.get("hidden", false): continue
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
				var built: Dictionary = {"id": Data.instance_id("wright_structure", unit.id, str(a.wright_site)), "kind": "fortification", "owner": unit.owner, "attributes": {"structure": "Tower" if tower else "Wall", "site": a.wright_site, "lane": a.lane, "x_fp": p.x_fp, "y_fp": p.y_fp, "hp": 6, "max_hp": 6, "armor": 4 if tower else 2, "max_armor": 4 if tower else 2, "attack": 1 if tower else 0, "ranged_next_tick": clock + 1, "builder_id": unit.id}}
				structures.append(built)
				structures.sort_custom(func(x, y): return x.id < y.id)
				a["wright_built"] = true
				a["wright_guard_until"] = clock + GUARD_TICKS
				a["wright_repair_round"] = number
				a["wright_released"] = false
				events.append(event("WRIGHT_STRUCTURE_BUILT", {"unit_id": unit.id, "structure": built, "round": number, "tick": tick}))
		entities.update(unit.id, unit.owner, a)
	return events

static func damage(world: Dictionary, target_id: String, source: Dictionary, amount: int, bypass: bool, number: int, tick: int) -> Dictionary:
	for row in rows(world):
		if row.id != target_id: continue
		var a: Dictionary = row.attributes
		var absorbed: int = 0 if bypass else mini(int(a.armor), amount)
		a.armor -= absorbed
		var dealt: int = amount - absorbed
		a.hp = maxi(0, int(a.hp) - dealt)
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
	for key in ["wright_site", "wright_progress", "wright_owner", "wright_guard_until", "wright_repair_round"]:
		if a.has(key) and (a.get("suit") != "Wright" or a.has("monster_id") or not Data.is_integer(a[key]) or int(a[key]) < 0): return false
	for key in ["wright_built", "wright_released"]:
		if a.has(key) and (a.get("suit") != "Wright" or a.has("monster_id") or typeof(a[key]) != TYPE_BOOL): return false
	if (a.has("wright_repair_round") or a.has("wright_released")) and not a.get("wright_built", false): return false
	if a.has("wright_site") and (int(a.wright_site) > 2 or not a.has("wright_progress") or int(a.wright_progress) > BUILD_TICKS or a.get("wright_owner", -1) not in [0, 1]): return false
	if a.get("wright_built", false) and (not a.has("wright_site") or not a.has("wright_guard_until")): return false
	return true

static func valid(world: Dictionary) -> bool:
	var structures = world.data.get("field_structures", [])
	if typeof(structures) != TYPE_ARRAY or structures.size() > 12: return false
	var sites: Array = []
	var builders: Array = []
	for row in structures:
		if typeof(row) != TYPE_DICTIONARY or row.get("kind") != "fortification" or row.get("owner") not in [0, 1] or typeof(row.get("attributes")) != TYPE_DICTIONARY: return false
		var a: Dictionary = row.attributes
		for key in ["site", "x_fp", "y_fp", "hp", "max_hp", "armor", "max_armor", "attack", "ranged_next_tick"]:
			if not Data.is_integer(a.get(key)): return false
		if a.site not in [0, 1, 2] or a.get("lane") not in ["Lord", "Castle"] or typeof(a.get("builder_id")) != TYPE_STRING: return false
		if row.get("id") != Data.instance_id("wright_structure", a.builder_id, str(a.site)): return false
		if a.builder_id not in world.entities.get("used_ids", []) or a.builder_id in builders: return false
		builders.append(a.builder_id)
		var p: Dictionary = site_point(row.owner, a.site)
		if a.x_fp != p.x_fp or a.y_fp != p.y_fp or a.hp < 1 or a.hp > 6 or a.max_hp != 6 or a.armor < 0 or a.armor > a.max_armor or a.ranged_next_tick < 0: return false
		var tower: bool = a.site == 2
		if a.get("structure") != ("Tower" if tower else "Wall") or a.max_armor != (4 if tower else 2) or a.attack != (1 if tower else 0): return false
		var key: String = "%d:%s:%d" % [row.owner, a.lane, a.site]
		if key in sites: return false
		sites.append(key)
	var claims: Array = []
	for row in world.entities.entities:
		if row.kind != "marcher" or not row.attributes.has("wright_site") or row.attributes.get("wright_built", false): continue
		# Charm releases the old claim; step() clears it before assigning a new one.
		if row.attributes.get("wright_owner", -1) != row.owner: continue
		var key: String = "%s:%s:%s" % [row.owner, row.attributes.get("lane", ""), row.attributes.wright_site]
		if key in claims: return false
		claims.append(key)
	return true

static func event(kind: String, details: Dictionary) -> Dictionary:
	var fact: Dictionary = {"type": kind, "text": "", "data": details.duplicate(true)}
	return {"event": fact, "views": [fact, fact]}
