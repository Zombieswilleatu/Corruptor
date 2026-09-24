extends RefCounted

const Embolden = preload("res://Scripts/Sim/U13Embolden.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")

static func record(world: Dictionary, pid: int, order: Dictionary, number: int, events: Array) -> void:
	if world.data.get("ward_conversion_experiment", "") != "regular" or order.get("action") not in ["Hunt", "Siege"]: return
	if not world.data.has("ward_conversion_cohorts"): world.data["ward_conversion_cohorts"] = [{}, {}]
	var ids: Array = []
	for row in events:
		if row.event.type == "MARCHER_SPAWNED": ids.append(row.event.data.id)
	world.data.ward_conversion_cohorts[pid] = {"round": number, "lane": order.lane, "unit_ids": ids}

static func eligible(unit: Dictionary, attacker: int, ids: Array) -> bool:
	return unit.id in ids and unit.kind == "marcher" and unit.owner == attacker and unit.attributes.hp > 0 and not unit.attributes.has("monster_id")

static func rank(unit: Dictionary) -> int:
	return 0 if unit.attributes.suit == "Penitent" else (2 if unit.attributes.suit == "Vulture" else 1)

static func convert(world: Dictionary, attacker: int, order: Dictionary, number: int, seed_value: String) -> Array:
	if world.data.get("ward_conversion_experiment", "") != "regular": return []
	var cohort: Dictionary = world.data.get("ward_conversion_cohorts", [{}, {}])[attacker]
	if cohort.get("round") != number or cohort.get("lane") != order.lane or cohort.get("consumed", false): return []
	cohort["consumed"] = true
	var chosen: Array = world.entities.entities.filter(func(u): return eligible(u, attacker, cohort.unit_ids))
	for tray in world.data.get("game_staging", {}).get("lanes", {}).values():
		var taken: Array = tray.units.filter(func(u): return eligible(u, attacker, cohort.unit_ids))
		tray.units = tray.units.filter(func(u): return not eligible(u, attacker, cohort.unit_ids))
		world.entities.entities.append_array(taken)
		chosen.append_array(taken)
	if chosen.is_empty(): return []
	var defender: int = 1 - attacker
	var placement: Array = chosen.duplicate()
	placement.sort_custom(func(a, b): return rank(a) < rank(b) if rank(a) != rank(b) else a.id < b.id)
	# Use the ordinary placement and identity registry, with ownership changed
	# one body at a time in the same order as the Python simulation.
	var entities = Ids.new()
	world.entities.entities.sort_custom(func(a, b): return a.id < b.id)
	entities.restore(world.entities)
	var converted: Array = []
	var marching = load("res://Scripts/Sim/U13Marching.gd")
	for row in placement:
		var a: Dictionary = row.attributes.duplicate(true)
		Embolden.apply(a, 0)
		a.merge({"direction": 1 if defender == 0 else -1, "movement_ready_round": number, "deployed_round": number, "ward_converted_round": number}, true)
		a.erase("staged_round")
		entities.update(row.id, defender, a)
		marching.place_spawn(entities, row.id, seed_value)
	for row in chosen: converted.append(entities.get_entity(row.id))
	world.entities = entities.snapshot()
	var event: Dictionary = {"type": "WARD_RECRUITS_CONVERTED", "text": "", "data": {"round": number, "lane": order.lane, "attacker_id": attacker, "player_id": defender, "mode": "regular", "regular_count": converted.size(), "monster_count": 0, "units": converted}}
	return [{"event": event, "views": [event, event]}]
