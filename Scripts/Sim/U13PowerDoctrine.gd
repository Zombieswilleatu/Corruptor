extends RefCounted

# Tier 1A targets from the originating U13 handoff. Each Lord has an isolated
# scorer below; no legacy doctrine, hidden trajectory, or continuous grid search.
const Content = preload("res://Scripts/Sim/U13Kanifous.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const Owner = preload("res://Scripts/Sim/U13Match.gd")
const Common = preload("res://Scripts/Sim/U13CommonDoctrine.gd")

static func options(c, order: Dictionary) -> Array:
	match c.w.lord_ids[c.pid]:
		"Gremory": return gremory(c, order)
		"Deimos": return deimos(c)
		"Humbaba": return humbaba(c)
		"Kalligan": return kalligan(c)
		"Orias": return orias(c)
		"Odradek": return odradek(c)
		"Kroni": return kroni(c)
		"Valak": return valak(c)
		"Kanifous": return kanifous(c)
	return []

static func add(result: Array, c, power: String, target: Dictionary, score: float, cost: Dictionary = {}, parameters: Dictionary = {}) -> void:
	if score <= 0:
		return
	var rule: Dictionary = Content.rules()[power]
	var source: Dictionary = Decl.create(Owner.declaration_id(c.pid, c.view.round, 0), c.pid, rule.lord_id, power, c.view.round, rule.fire_hook, c.view.round + int(rule.delay_rounds), 0, "public", target, rule.cost if cost.is_empty() else cost, parameters)
	result.append(Common.candidate(source, score, power))

static func lane_value(c, lane: String) -> float:
	return 4.0 + c.select("marcher", 1 - c.pid, lane).size() * 0.5 - c.guard_value(1 - c.pid, lane) * 0.15

# At most eight enemy centers. Prioritize threats near our boundary, stable IDs
# on ties. Radius scoring penalizes friendly fire where the power has it.
static func points(c, radius: int, friendly_cost: float = 0.0) -> Array:
	var enemies: Array = c.select("marcher", 1 - c.pid)
	enemies.sort_custom(func(a, b):
		var ax: int = int(a.attributes.x_fp) if c.pid == 0 else 2400 - int(a.attributes.x_fp)
		var bx: int = int(b.attributes.x_fp) if c.pid == 0 else 2400 - int(b.attributes.x_fp)
		return a.id < b.id if ax == bx else ax < bx)
	var result: Array = []
	var seen: Array = []
	for row in enemies.slice(0, 8):
		var target: Dictionary = {"lane": row.attributes.lane, "field_position": {"x_fp": row.attributes.x_fp, "y_fp": row.attributes.y_fp}}
		if target in seen:
			continue
		seen.append(target)
		var score: float = 0.0
		for body in c.w.entities:
			if body.kind != "marcher" or body.attributes.lane != target.lane:
				continue
			var dx: int = int(body.attributes.x_fp) - int(target.field_position.x_fp)
			var dy: int = int(body.attributes.y_fp) - int(target.field_position.y_fp)
			if dx * dx + dy * dy <= radius * radius:
				score += 1.0 if body.owner != c.pid else -friendly_cost
		result.append({"target": target, "score": score})
	return result

static func gremory(c, order: Dictionary) -> Array:
	var result: Array = []
	for lane in ["Lord", "Castle"]:
		add(result, c, "PredatorOfRuin", {"lane": lane}, lane_value(c, lane))
	var cards: Array = c.available([], order)
	cards.sort_custom(func(a, b): return a < b if c.card_score(a) == c.card_score(b) else c.card_score(a) < c.card_score(b))
	if cards.size() >= 2:
		for row in c.castles(1 - c.pid):
			if row.attributes.integrity > 0 and row.attributes.integrity < row.attributes.max_integrity:
				add(result, c, "InevitableRuin", {"entity_id": row.id}, 9.0 + c.castle_value(row) - c.printed(cards.slice(0, 2)) * 0.6, {"discard_ids": cards.slice(0, 2)})
	return result

static func deimos(c) -> Array:
	var result: Array = []
	for row in c.castles(c.pid):
		if row.attributes.castle_type == "SiegeEngine":
			add(result, c, "WarMachine", {"entity_id": row.id}, 7.0 if not c.castles(1 - c.pid).is_empty() else 0.0)
	for lane in ["Lord", "Castle"]:
		add(result, c, "Rout", {"lane": lane}, c.select("marcher", 1 - c.pid, lane).size() * 3.0)
	return result

static func humbaba(c) -> Array:
	var result: Array = []
	for lane in ["Lord", "Castle"]:
		add(result, c, "MusterTheFaithful", {"lane": lane}, lane_value(c, lane))
		add(result, c, "BreathOfLife", {"lane": lane}, c.select("marcher", c.pid, lane).size() * 1.5)
	return result

static func kalligan(c) -> Array:
	var result: Array = []
	var net: int = c.select("marcher", 1 - c.pid).size() - c.select("marcher", c.pid).size()
	add(result, c, "Pyroclasm", {}, net * 2.0)
	for lane in ["Lord", "Castle"]:
		add(result, c, "Inferno", {"kind": "lane", "lane": lane}, c.select("marcher", 1 - c.pid, lane).size() * 2.0)
		add(result, c, "Inferno", {"kind": "guard", "lane": lane, "player_id": 1 - c.pid}, c.guard_value(1 - c.pid, lane) * 1.0)
	return result

static func orias(c) -> Array:
	var result: Array = []
	for point in points(c, int(c.w.web_radius_fp)):
		add(result, c, "Web", point.target, point.score * 4.0)
	# Threat/Conduit is a real opportunity cost. Avoid repeatedly disabling our
	# last operational Circle merely to deny an empty opponent's deployment.
	var fragile: bool = c.castles(c.pid).any(func(e): return e.attributes.castle_type == "SummoningCircle" and e.attributes.integrity in [7, 8, 9])
	var score: float = mini(8, int(c.w.opponent_hand_count)) - (6.0 if fragile else 0.0)
	add(result, c, "Snare", {"player_id": 1 - c.pid}, score)
	return result

static func odradek(c) -> Array:
	var result: Array = []
	var resource: int = c.w.reconfiguration[c.pid]
	for point in points(c, int(c.w.shift_radius_fp), 1.0):
		add(result, c, "AllegianceShift", point.target, point.score * 5.0)
		# Bank for allegiance swing when it is reachable next round.
		if resource >= 4 or point.score < 2:
			add(result, c, "Redirect", point.target, point.score * 1.5)
	for lane in ["Lord", "Castle"]:
		var value: int = c.guard_value(1 - c.pid, lane)
		add(result, c, "Inversion", {"owner_id": 1 - c.pid, "lane": lane}, value * 1.2)
		for guard in c.guards(1 - c.pid, lane).slice(0, 3):
			add(result, c, "FalseOrders", {"entity_id": guard.id, "owner_id": 1 - c.pid, "lane": "Castle" if lane == "Lord" else "Lord"}, float(c.guard_strength(guard)) - 1.0)
	return result

static func kroni(c) -> Array:
	var result: Array = []
	for lane in ["Lord", "Castle"]:
		add(result, c, "Ravenous", {"lane": lane, "field_position": {"x_fp": 0 if c.pid == 0 else 2400, "y_fp": 300}}, c.select("marcher", 1 - c.pid, lane).size() * 2.0 + c.guards(1 - c.pid, lane).size() * 2.0 - c.select("marcher", c.pid, lane).size())
		for guard in c.guards(1 - c.pid, lane).slice(0, 3):
			add(result, c, "Consume", {"entity_id": guard.id}, float(c.guard_strength(guard)) + 4.0)
	return result

static func valak(c) -> Array:
	var result: Array = []
	for point in points(c, 300, 1.0):
		add(result, c, "GravityOrb", point.target, point.score * 3.0)
	var essence: int = c.w.life_essence[c.pid]
	for lane in ["Lord", "Castle"]:
		for guard in c.guards(1 - c.pid, lane):
			# Projection defeats one guard, not a zone's combined strength. For a
			# hidden face, bank toward the fixed prior; success is never guaranteed.
			var spend: int = c.guard_strength(guard)
			if essence >= spend:
				add(result, c, "Projection", {"kind": "guard_zone", "player_id": 1 - c.pid, "zone": lane}, spend * 1.5, {}, {"spend": spend})
	return result

static func redundant(c, source: Dictionary, order: Dictionary) -> bool:
	var action: String = order.get("action", "Pass")
	if action not in ["Hunt", "Siege"]:
		return false
	var strength: int = c.strength(order.card_ids) + c.waiters(c.pid, order.lane, order)
	if action == "Hunt":
		strength += int(c.w.relentless_pursuit[c.pid].strength_bonus)
		# Valak can reinforce from public Essence before guards take damage.
		strength -= int(c.w.life_essence[1 - c.pid]) if c.w.lord_ids[1 - c.pid] == "Valak" else 0
	# This is a heuristic using occupied slots and estimated hidden faces. It
	# neither reads enemy submissions nor promises what simultaneous combat does.
	var guard_screen: int = c.guard_value(1 - c.pid, order.lane)
	if source.power_id == "Projection":
		return source.target.zone == order.lane and strength > guard_screen
	if source.power_id != "InevitableRuin" or action != "Siege" or source.target.entity_id != order.target_id:
		return false
	var remaining: int = maxi(0, strength - c.screen("Castle"))
	var row: Dictionary = c.rows[order.target_id]
	if row.attributes.castle_type != "Bastion":
		for castle in c.castles(1 - c.pid):
			if castle.attributes.castle_type == "Bastion":
				remaining = maxi(0, remaining - int(castle.attributes.integrity))
				break
	return remaining >= int(row.attributes.integrity)

static func kanifous(c) -> Array:
	var result: Array = []
	# Price is deferred and uncertain: do not treat any Wish as free or roll it
	# during planning. V1 pays a fixed risk penalty; no RNG peeking.
	for row in c.castles(c.pid):
		var missing: int = row.attributes.max_integrity - row.attributes.integrity
		add(result, c, "WishLongevity", {"entity_id": row.id}, mini(missing, 12) - 3.0)
	for point in points(c, 300, 1.0):
		add(result, c, "WishDeath", point.target, point.score * 3.0 - 3.0)
	for lane in ["Lord", "Castle"]:
		add(result, c, "WishPower", {"lane": lane}, lane_value(c, lane) - 3.0)
		add(result, c, "WishResurrection", {"kind": "guard_zone", "zone": lane}, 4.0 - c.guards(c.pid, lane).size() * 2.0)
	add(result, c, "WishWealth", {}, 3.0 if c.w.souls[c.pid] < 10 else 0.0)
	return result
