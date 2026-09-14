extends RefCounted

# Public-state arithmetic, never a match clone or a hidden-order simulation.
# Results are a current-board baseline; future choices and power reactions can
# change them. Callers must keep the assumptions beside any predicted outcome.
const VERSION: String = "U13_ACTION_FORECAST_V1"
const View = preload("res://Scripts/Sim/U13DoctrineView.gd")
const Stats = preload("res://Scripts/Sim/U13LordStats.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Plunder = preload("res://Scripts/Sim/U13Plunder.gd")

static func evaluate(public_view: Dictionary, order: Dictionary) -> Dictionary:
	var result: Dictionary = {"version": VERSION, "available": false, "lines": [], "assumptions": "Current board only: new Guards, Ward, Work, artillery and power reactions can change the result."}
	if not public_view.get("world", {}).has("viewer_id"): return result
	var c = View.new(public_view)
	var action: String = order.get("action", "Pass")
	var cards: Array = order.get("card_ids", [])
	for id in cards:
		if not c.rows.has(id) or id not in c.w.get("hand", []): return result
	var lane: String = order.get("lane", "Castle")
	if lane not in ["Lord", "Castle"]: return result
	var strength: int = c.strength(cards, "Penitent" if action == "Ward" else "Butcher")
	var recruits: Dictionary = {}
	for id in cards:
		var a: Dictionary = c.rows[id].attributes
		recruits[a.suit] = int(recruits.get(a.suit, 0)) + int(a.value)
	var total_recruits: int = 0
	for suit in recruits: total_recruits += floori(float(recruits[suit]) / (2.0 if action == "Ward" else 3.0))
	result["recruits"] = total_recruits
	result["card_strength"] = strength
	if action == "Ward":
		result.available = true
		result["strength"] = strength
		result.lines.append("Ward: %d protection in %s; %d in the other lane." % [strength, lane, (strength >> 1)])
		result.lines.append("Recruits: %d Marchers in %s." % [total_recruits, lane])
		result.assumptions = "Protection applies this round. Recruitment is counted per suit; new Marchers begin moving next round."
		return result
	if action == "Profane":
		var castle: Dictionary = c.rows.get(order.get("target_id", ""), {})
		result.available = true
		result.lines.append("Profane: sacrifice this Castle for +1 personal Tear." if Plunder.eligible(castle, c.pid) else "Profane: select a full, active Castle.")
		result.assumptions = "Damage before combat can make the Castle ineligible."
		return result
	if action not in ["Hunt", "Siege"] or cards.is_empty(): return result
	lane = "Lord" if action == "Hunt" else "Castle"
	var target: Dictionary = c.rows.get(order.get("target_id", ""), {})
	var enemy_castles: Array = c.castles(1 - c.pid)
	enemy_castles.sort_custom(func(a, b): return int(a.attributes.castle_slot) < int(b.attributes.castle_slot))
	var pillage: bool = action == "Siege" and enemy_castles.is_empty()
	if action == "Hunt" and (target.is_empty() or target.kind != "lord" or target.owner == c.pid or not target.attributes.get("alive", false)): return result
	if action == "Siege" and not pillage and (target.is_empty() or not Structures.targetable(target) or target.owner == c.pid): return result
	var support: int = c.waiters(c.pid, lane, order)
	var pursuit: int = 0
	if action == "Hunt":
		var own_lords: Array = c.select("lord", c.pid)
		if not own_lords.is_empty(): pursuit = Stats.relentless_pursuit(own_lords[0], target)
	strength += support + pursuit
	result.available = true
	result["strength"] = strength
	result["support"] = support
	result.lines.append("Strength %d = cards %d + Supplicants %d%s." % [strength, result.card_strength, support, " + pursuit %d" % pursuit if pursuit > 0 else ""])
	result.lines.append("Recruits: %d Marchers. %d Supplicants consumed." % [total_recruits, support])
	var pair_screen: int = c.pair_screen(1 - c.pid, lane)
	var guards: Array = c.guards(1 - c.pid, lane)
	guards.sort_custom(func(a, b): return a.attributes.slot < b.attributes.slot if a.attributes.value == b.attributes.value else a.attributes.value > b.attributes.value)
	var remaining: int = maxi(0, strength - pair_screen)
	var defeated: int = 0
	for guard in guards:
		if remaining <= int(guard.attributes.value):
			remaining = 0
			break
		remaining -= int(guard.attributes.value)
		defeated += 1
	result["guards_defeated"] = defeated
	result.lines.append("Visible defense: %d pair protection + %d Guard value." % [pair_screen, c.guard_value(1 - c.pid, lane)])
	result.lines.append("Baseline: %d of %d Guards defeated." % [defeated, guards.size()])
	if pillage:
		result["pillage_success"] = remaining > 0
		result.lines.append("Pillage: +1 Soul." if remaining > 0 else "Pillage stopped by visible defense.")
		result.lines.append("If a Castle becomes active, this becomes Siege against the leftmost one.")
		return result
	var sigil: String = c.w.get("sigils", [{}, {}])[1 - c.pid].get(lane, "")
	var sigil_value: int = 2 if sigil == "fresh" else (1 if sigil == "flipped" else 0)
	remaining = maxi(0, remaining - sigil_value)
	if sigil_value > 0: result.lines.append("Sigil: %d additional protection." % sigil_value)
	var screen_type: String = "Keep" if action == "Hunt" else "Bastion"
	for castle in enemy_castles:
		if castle.attributes.castle_type != screen_type or (action == "Siege" and castle.id == target.id): continue
		var reduction: int = 3 if action == "Hunt" and Structures.operational(castle) else 0
		remaining = maxi(0, remaining - reduction)
		var absorbed: int = mini(remaining, int(castle.attributes.integrity))
		remaining -= absorbed
		result.lines.append("%s intercepts: %d damage%s." % [screen_type, absorbed, " after 3 protection" if reduction > 0 else ""])
		break
	if action == "Hunt":
		var stat_world: Dictionary = {"entities": {"entities": c.w.entities}}
		var defense: int = Stats.defense(stat_world, target)
		result["banished"] = remaining > defense
		result.lines.append("Lord: %d strength reaches %d Defense — %s." % [remaining, defense, "banishment" if remaining > defense else "survives"])
	else:
		var damage: int = mini(remaining, int(target.attributes.integrity))
		result["damage"] = damage
		result["destroyed"] = remaining > 0 and remaining >= int(target.attributes.integrity)
		result.lines.append("%s: %d damage — %s." % [str(target.attributes.castle_type).capitalize(), damage, "ruined" if result.destroyed else "%d Integrity left" % (int(target.attributes.integrity) - damage)])
	return result

static func text(result: Dictionary) -> String:
	if not result.get("available", false): return "FORECAST · Stage cards and choose a target to see the current-board baseline."
	return "FORECAST · CURRENT BOARD\n" + "\n".join(result.lines) + "\n" + result.assumptions
