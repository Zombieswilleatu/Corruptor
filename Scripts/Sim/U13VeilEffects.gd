extends RefCounted

const Veil = preload("res://Scripts/Sim/U13VeilBreaches.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")

static func reconcile(result: Dictionary) -> Dictionary:
	if result.get("action") == "invalid" or not result.has("world"):
		return result
	for castle in result.world.entities.entities:
		if castle.kind == "castle" and castle.attributes.max_integrity != castle.attributes.base_max_integrity - (5 if Veil.affects(result.world, "Deimos", castle.owner) else 0):
			var changed: Dictionary = Structures.sync_breach(result.world)
			result.world = changed.world
			result.events.append_array(changed.events)
			break
	return result

static func begin(context: Dictionary, reaction: Callable) -> Dictionary:
	var world: Dictionary = context.world
	var events: Array = []
	var admitted: Array = Veil.begin(world, context.round, context.seed)
	for row in admitted:
		var details: Dictionary = row.duplicate(true)
		details["protected_players"] = [Veil.protected_player(world, row.lord_id, 0), Veil.protected_player(world, row.lord_id, 1)]
		events.append(Structures.public_event("VEIL_LORD_ARRIVED", details))
	var result: Dictionary = reconcile({"action": "resolved", "world": world, "events": events})
	world = result.world
	var source: String = ""
	var entry_round: int = 0
	var entry: Dictionary = Veil.arrival(world, "Humbaba")
	if not entry.is_empty():
		source = "veil:Humbaba"
		entry_round = entry.round
	elif world.data.get("breach_lord", "") == "Humbaba":
		for lord in world.entities.entities:
			if lord.kind == "lord" and lord.attributes.get("lord_id") == "Humbaba" and not lord.attributes.alive:
				source = lord.id
		for n in world.data.humbaba_breach_entries.values():
			entry_round = maxi(entry_round, n)
	if source.is_empty() or entry_round == 0:
		return result
	var fresh: bool = admitted.any(func(row): return row.lord_id == "Humbaba")
	if not fresh and entry_round >= context.round:
		return result
	var damage: int = 4 if fresh else 1
	var identity: String = "stones:%d:%s" % [context.round, source]
	var targets: Array = []
	for castle in world.entities.entities:
		if Structures.targetable(castle) and castle.attributes.integrity > 0 and Veil.affects(world, "Humbaba", castle.owner):
			targets.append(castle.id)
	targets.sort()
	for id in targets:
		var hit: Dictionary = Structures.breach_damage(world, id, source, damage, identity, context, reaction)
		if hit.action == "invalid":
			return hit
		world = hit.world
		events.append_array(hit.events)
	events.append(Structures.public_event("THE_STONES_FORGET", {"source_id": source, "entry_id": identity, "round": context.round, "castle_ids": targets, "damage_per_castle": damage}))
	return {"action": "resolved", "world": world, "events": events}
