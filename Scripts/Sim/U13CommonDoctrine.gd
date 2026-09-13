extends RefCounted

const Development = preload("res://Scripts/Sim/U13GameDevelopment.gd")
const Plunder = preload("res://Scripts/Sim/U13Plunder.gd")

static func candidate(payload: Dictionary, score: float, reason: String) -> Dictionary:
	return {"payload": payload, "score": score, "reason": reason}

static func rites(c, powers: Array, base: Dictionary, stage: String) -> Array:
	var result: Array = []
	for order in Development.rite_orders(c.view, powers, base, stage):
		var score: float = c.tear_value()
		if stage == "invocation":
			score -= c.printed(order.rites.invocation.card_ids) * 0.65
		elif stage == "profane_ruins":
			# Do not give up an imminent Ritual win for a non-winning Tear.
			score -= 30.0 if c.w.souls[c.pid] >= 10 and score < 100 else 5.0
		else:
			score *= order.rites.waiter_spends.size()
		result.append(candidate(order, score, stage))
	return result

static func summon(c, powers: Array, base: Dictionary) -> Array:
	var result: Array = []
	for order in Development.summon_orders(c.view, powers, base):
		result.append(candidate(order, 100.0 - c.printed(order.summon.card_ids) - order.summon.card_ids.size() * 0.25, "restore Lord"))
	return result

static func castles(c, powers: Array, base: Dictionary) -> Array:
	var result: Array = []
	var payments: Array = c.payments(powers, base, "Wright")
	for row in c.castles(c.pid, false):
		var a: Dictionary = row.attributes
		var actions: Array = ["Repair"] if a.construction_state == "active" and a.status != "ruined" else ["Construct", "Activate"]
		for action in actions:
			for ids in payments:
				if action == "Activate" and not ids.is_empty():
					continue
				# Paid construction accelerates cheaply; do not pour a whole hand into it.
				if action == "Construct" and ids.size() > 1:
					continue
				for token in ([false, true] if action == "Repair" and c.w.repair_tokens > 0 else [false]):
					var score: float = 0.0
					var paid: int = c.printed(ids)
					var gain: int = mini(a.max_integrity - a.integrity, (c.strength(ids, "Wright") - _pair_bonus(c, ids, "Wright") + (3 if token else 0)))
					if action == "Repair":
						score = gain * 1.15 - paid * 0.8
						if a.integrity < 7 and a.integrity + gain >= 7:
							score += c.castle_value(row)
					elif action == "Activate":
						# Early commissioning forfeits protected growth; wait for useful health.
						score = c.castle_value(row) - (10.0 if a.integrity < 12 else 0.0)
					else:
						score = 2.5 + c.castle_value(row) * 0.2 - paid * 0.65
						if c.w.construction_target == row.id:
							score -= 4.0 # its free continuing progress already happens
						if a.integrity + 3 + floori(paid / 3.0) >= a.max_integrity:
							score += c.castle_value(row)
					var order: Dictionary = base.duplicate(true)
					order["castle_action"] = {"action": action, "target_id": row.id, "card_ids": ids, "use_repair_token": token}
					result.append(candidate(order, score, "develop " + str(a.castle_type)))
	return result

static func _pair_bonus(c, ids: Array, suit: String) -> int:
	return 1 if ids.filter(func(id): return c.rows[id].attributes.suit == suit).size() >= 2 else 0

static func combat(c, powers: Array, base: Dictionary) -> Array:
	var result: Array = []
	var targets: Array = []
	for lord in c.select("lord", 1 - c.pid):
		if lord.attributes.alive:
			targets.append({"action": "Hunt", "lane": "Lord", "target_id": lord.id})
	for row in c.castles(1 - c.pid):
		targets.append({"action": "Siege", "lane": "Castle", "target_id": row.id})
	if c.castles(1 - c.pid).is_empty():
		targets.append({"action": "Siege", "lane": "Castle", "target_id": Plunder.zone_id(1 - c.pid)})
	for row in c.castles(c.pid):
		if Plunder.eligible(row, c.pid):
			targets.append({"action": "Profane", "lane": "Castle", "target_id": row.id})
	for lane in ["Lord", "Castle"]:
		targets.append({"action": "Ward", "lane": lane})
	for target in targets:
		if base.has("summon") and target.action not in ["Hunt", "Siege", "Ward"]:
			continue
		for ids in ([[]] if target.action == "Profane" else c.payments(powers, base, "Penitent" if target.action == "Ward" else "Butcher")):
			var order: Dictionary = base.duplicate(true)
			order.merge(target)
			order["card_ids"] = ids
			if target.action == "Hunt":
				order["fracture_target"] = "subjects" if c.select("marcher", 1 - c.pid).size() >= 4 else "infrastructure"
			result.append(candidate(order, combat_score(c, order), "public " + str(target.action) + " pressure"))
	return result

# A cheap pressure estimate, not an Action Forecast. Unknown simultaneous Ward
# and new guards are not read or predicted as facts. Authority owns the result.
static func combat_score(c, order: Dictionary) -> float:
	var ids: Array = order.card_ids
	var lane: String = order.lane
	var cost: float = c.printed(ids) * 0.7 + ids.size() * 0.35
	var total: int = c.strength(ids, "Penitent" if order.action == "Ward" else "Butcher")
	var bodies: Dictionary = {}
	for id in ids:
		var a: Dictionary = c.rows[id].attributes
		bodies[a.suit] = int(bodies.get(a.suit, 0)) + int(a.value)
	var recruits: int = 0
	for value in bodies.values():
		recruits += floori(value / 3.0)
	var score: float = recruits * 1.8 - cost
	if order.action == "Profane":
		return c.tear_value() - c.castle_value(c.rows[order.target_id]) - 8.0
	if order.action == "Ward":
		var pressure: int = c.waiters(1 - c.pid, lane) + c.select("marcher", 1 - c.pid, lane).size()
		return score + mini(total, maxi(0, pressure - c.guard_value(c.pid, lane))) * 1.5
	total += c.waiters(c.pid, lane, order)
	var remaining: int = maxi(0, total - c.screen(lane))
	if order.action == "Hunt":
		remaining += int(c.w.relentless_pursuit[c.pid].strength_bonus)
		for castle in c.castles(1 - c.pid):
			if castle.attributes.castle_type == "Keep":
				remaining = maxi(0, remaining - int(castle.attributes.integrity) - (3 if c.Structures.operational(castle) else 0))
				break
		var threshold: int = int(c.w.lord_stats[1 - c.pid].defense)
		if remaining > threshold:
			score += 28.0 + (120.0 if c.w.souls[c.pid] >= 10 else 0.0)
		else:
			score += mini(total, c.screen(lane)) * 0.8
	else:
		if order.target_id.begins_with("castle_zone:"):
			# No castle sigil while pillaging; all active targetable castles count.
			remaining = total - c.guard_value(1 - c.pid, lane)
			if remaining > 0:
				score += 15.0 + (120.0 if c.w.souls[c.pid] >= 11 else 0.0)
		else:
			var row: Dictionary = c.rows[order.target_id]
			if row.attributes.castle_type != "Bastion":
				for castle in c.castles(1 - c.pid):
					if castle.attributes.castle_type == "Bastion":
						remaining = maxi(0, remaining - int(castle.attributes.integrity))
						break
			score += mini(remaining, int(row.attributes.integrity)) * 1.5
			if remaining > 0 and remaining >= row.attributes.integrity:
				score += 16.0 + c.castle_value(row)
	return score

static func guards(c, powers: Array, base: Dictionary) -> Array:
	var result: Array = []
	for order in Development.guard_orders(c.view, powers, base):
		var move: Dictionary = order.guard_moves.back()
		if powers.any(func(p): return p.power_id == "Inversion" and p.target.lane == move.lane):
			continue # Keep receiving slots open for the already chosen transfer.
		var coverage: int = c.guard_value(c.pid, move.lane)
		for prior in base.get("guard_moves", []):
			if prior.lane == move.lane:
				coverage += c.printed([prior.card_id])
		var score: float = 9.0 + mini(5, c.select("marcher", 1 - c.pid, move.lane).size()) - coverage * 1.5 - c.printed([move.card_id]) * 0.4
		if move.lane == "Lord":
			score += 2.0
		result.append(candidate(order, score, "cover " + str(move.lane)))
	return result
