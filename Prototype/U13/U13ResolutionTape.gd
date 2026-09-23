extends RefCounted

# Read only public, already-resolved events. Never recompute combat or use RNG.
static func build(presentation: Dictionary) -> Array:
	if not presentation.has("before"):
		return []
	var attacks: Dictionary = {}
	var wards: Dictionary = {}
	var pending: Dictionary = {}
	var result: Array = []
	var retired: Array = []
	for event in presentation.get("events", []):
		var d: Dictionary = event.get("data", {})
		var kind: String = event.get("type", "")
		if kind == "COMBAT_ORDER_REVEALED":
			if d.order.action == "Ward":
				wards[d.player_id] = d
			elif d.order.action in ["Siege", "Hunt"]:
				attacks[d.player_id] = d
		elif kind in ["SIEGE_STARTED", "HUNT_STARTED"]:
			pending = {"start": d, "intercepts": [], "deaths": [], "pair_screen": 0}
		elif not pending.is_empty():
			if kind in ["BASTION_SCREENED", "KEEP_INTERPOSED"]:
				pending.intercepts.append(d.duplicate(true))
			elif kind == "GUARD_DEFEATED" and d.has("guard"):
				pending.deaths.append(d.guard.duplicate(true))
			elif kind == "GUARD_PAIR_SCREEN":
				pending.pair_screen += int(d.get("amount", 0))
			elif kind in ["SIEGE_RESOLVED", "HUNT_RESOLVED"]:
				var pid: int = d.player_id
				var lane: String = "Castle" if kind == "SIEGE_RESOLVED" else "Lord"
				var guards: Array = []
				for row in presentation.before.world.entities:
					if row.kind == "card" and row.owner == 1 - pid and row.attributes.get("role") == "guard" and row.attributes.get("lane") == lane and row.id not in retired:
						guards.append(row.duplicate(true))
				guards.sort_custom(func(a, b):
					if a.attributes.value != b.attributes.value: return a.attributes.value > b.attributes.value
					return a.attributes.slot < b.attributes.slot)
				var ward: Dictionary = wards.get(1 - pid, {})
				var cards: Array = attacks.get(pid, {}).get("cards", []).duplicate(true)
				result.append({"kind": "advance", "pid": pid, "lane": lane, "target_id": d.target_id, "cards": cards, "result": d.duplicate(true), "seconds": 0.95})
				if int(d.get("ward_screen", 0)) > 0:
					result.append({"kind": "ward", "pid": 1 - pid, "lane": lane, "target_id": d.target_id, "cards": ward.get("cards", []).duplicate(true), "amount": d.ward_screen, "seconds": 0.65})
				if not guards.is_empty():
					result.append({"kind": "guards", "pid": 1 - pid, "lane": lane, "target_id": d.target_id, "cards": guards, "deaths": pending.deaths.duplicate(true), "pair_screen": pending.pair_screen, "seconds": 0.8})
				if d.get("sigil_broken", false):
					result.append({"kind": "sigil", "pid": 1 - pid, "lane": lane, "target_id": d.target_id, "seconds": 0.35})
				for intercept in pending.intercepts:
					result.append({"kind": "intercept", "pid": 1 - pid, "lane": lane, "target_id": d.target_id, "hit_id": intercept.castle_id, "result": intercept, "seconds": 1.1})
				result.append({"kind": "impact", "pid": 1 - pid, "lane": lane, "target_id": d.target_id, "hit_id": d.target_id, "result": d.duplicate(true), "seconds": 1.0})
				for dead in pending.deaths:
					retired.append(dead.id)
				pending = {}
	return result
