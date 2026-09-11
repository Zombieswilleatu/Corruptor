extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const VERSION: String = "U13_FRACTURE_V1"
# Printed Fracture, formerly GameSetup.LORD_CONTENT.return_threat. This is
# independent of the current U13 summon-payment shortfall/Mark Threat rules.
const VALUES: Dictionary = {"Orias": 0, "Deimos": 0, "Valak": 1, "Kroni": 1, "Kalligan": 1, "Gremory": 2, "Odradek": 2, "Kanifous": 1, "Humbaba": 2}


static func configure(world: Dictionary) -> void:
	world.data["fracture_profile"] = VERSION
	world.data["fracture_events"] = {}


static func valid(world: Dictionary) -> bool:
	if world.data.get("fracture_profile") != VERSION or typeof(world.data.get("fracture_events")) != TYPE_DICTIONARY:
		return false
	for id in world.data.fracture_events:
		var row = world.data.fracture_events[id]
		if (
			not world.data.get("battle_commands", {}).has(id)
			or typeof(row) != TYPE_DICTIONARY
			or row.size() != 3
			or row.get("player_id") not in [0, 1]
			or row.get("category") not in ["subjects", "infrastructure"]
			or row.get("value") != VALUES[world.players[row.player_id].lord_id]
		):
			return false
	return true


static func resolve(raw: Dictionary, fact: Dictionary, seed: String, player_order: Array, reaction: Callable) -> Dictionary:
	if fact.get("type") != "LORD_BANISHED":
		return {"action": "resolved", "world": raw, "events": []}
	if not valid(raw):
		return Data.invalid("fracture_state_invalid")
	var detail: Dictionary = fact.data
	var event_id: String = detail.get("event_id", "")
	var ids = Ids.new()
	ids.restore(raw.entities)
	var lord: Dictionary = ids.get_entity(detail.get("lord_id", ""))
	if (
		lord.is_empty() or lord.kind != "lord" or lord.attributes.alive
		or not raw.data.get("battle_commands", {}).has(event_id)
		or raw.data.fracture_events.has(event_id)
		or detail.get("fracture_target", "") not in ["", "subjects", "infrastructure"]
	):
		return Data.invalid("fracture_banishment_invalid")
	var world: Dictionary = raw.duplicate(true)
	var pid: int = lord.owner
	var value: int = VALUES[lord.attributes.lord_id]
	var category: String = detail.get("fracture_target", "")
	if category.is_empty():
		category = default_category(world, pid, value)
	world.data.fracture_events[event_id] = {"player_id": pid, "category": category, "value": value}
	var events: Array = []
	var used: Array = []
	for point in range(value):
		var targets: Array = []
		var group: String = "infrastructure"
		if category == "infrastructure":
			var candidates: Array = castles(world, pid).filter(func(e): return e.id not in used)
			if candidates.is_empty():
				used.clear()
				candidates = castles(world, pid)
			if candidates.is_empty():
				break
			targets = [candidates[0]]
			used.append(candidates[0].id)
		else:
			var buckets: Dictionary = groups(world, pid)
			var names: Array = buckets.keys()
			if names.is_empty():
				break
			group = names[_pick(seed, event_id, point, "group", names.size())]
			var available: Array = buckets[group].duplicate()
			for hit in range(mini(3 if group == "Marcher" else 1, available.size())):
				targets.append(available.pop_at(_pick(seed, event_id, point, "victim:%d" % hit, available.size())))
		for victim in targets:
			var before: int = victim.attributes.hp if group == "Marcher" else (victim.attributes.integrity if group == "infrastructure" else victim.attributes.value)
			var after: int = maxi(0 if group in ["Marcher", "infrastructure"] else 1, before - (1 if group == "Marcher" else 2))
			var command: Dictionary = {"command_id": "%s:fracture:%d:%s" % [event_id, point, victim.id], "target_id": victim.id}
			if group == "Marcher":
				command.merge({"kind": "marcher_damage", "damage": 1, "cause": "hazard"})
			elif group == "infrastructure" and after == 0:
				command.merge({"kind": "ruin_castle_fracture", "source_id": lord.id, "cause": "fracture"})
			else:
				ids.restore(world.entities)
				if group == "infrastructure":
					victim.attributes.integrity = after
					Structures.note_integrity_loss(victim, before, detail.round)
				else:
					victim.attributes.value = after
				ids.update(victim.id, victim.owner, victim.attributes)
				world.entities = ids.snapshot()
				command.clear()
			events.append(_event("FRACTURE_HIT", {"event_id": event_id, "round": detail.round, "point": point, "category": category, "group": group, "target_id": victim.id, "player_id": pid, "before": before, "after": after}))
			if not command.is_empty():
				var applied: Dictionary = Battle.apply(world, command, detail.round, detail.hook)
				if applied.action == "invalid":
					return applied
				events.append({"event": applied.event, "views": [applied.event, applied.event]})
				var reacted: Dictionary = reaction.call(applied.world, applied.event, seed, player_order)
				if reacted.action == "invalid":
					return reacted
				world = reacted.world
				events.append_array(reacted.events)
	events.append(_event("FRACTURE_RESOLVED", {"event_id": event_id, "round": detail.round, "player_id": pid, "lord_id": lord.id, "value": value, "category": category}))
	return {"action": "resolved", "world": world, "events": events}


# Rebuild live buckets on every point. Marchers use current allegiance and both
# lanes, including waiters. Guards at value one and private Hands are immune.
static func groups(world: Dictionary, pid: int) -> Dictionary:
	var result: Dictionary = {}
	for name in ["Lord", "Castle", "Marcher"]:
		var rows: Array = world.entities.entities.filter(func(e): return e.owner == pid and (
			(e.kind == "marcher" and e.attributes.hp > 0) if name == "Marcher" else
			(e.kind == "card" and e.attributes.get("role") == "guard" and e.attributes.lane == name and e.attributes.value > 1)))
		rows.sort_custom(func(a, b): return a.id < b.id)
		if not rows.is_empty():
			result[name] = rows
	return result


static func castles(world: Dictionary, pid: int) -> Array:
	var result: Array = world.entities.entities.filter(func(e): return e.owner == pid and Structures.targetable(e) and e.attributes.integrity > 0)
	result.sort_custom(func(a, b):
		if a.attributes.integrity != b.attributes.integrity:
			return a.attributes.integrity > b.attributes.integrity
		return a.attributes.castle_slot < b.attributes.castle_slot)
	return result


static func default_category(world: Dictionary, pid: int, value: int) -> String:
	var buckets: Dictionary = groups(world, pid)
	var capacity: int = 0
	for name in buckets:
		var best: int = 0
		if name == "Marcher":
			best = mini(3, buckets[name].size())
		else:
			for guard in buckets[name]:
				best = maxi(best, mini(2, int(guard.attributes.value) - 1))
		capacity += best
	var subject_score: int = 0 if buckets.is_empty() else int(round(float(capacity * value) / buckets.size()))
	var infrastructure: int = 0
	for castle in castles(world, pid):
		infrastructure += int(castle.attributes.integrity)
	return "infrastructure" if mini(value * 2, infrastructure) > subject_score else "subjects"


static func _pick(seed: String, event_id: String, point: int, purpose: String, count: int) -> int:
	return int(Rng.draw(seed, event_id, VERSION + ":" + purpose, point, count).value)


static func _event(kind: String, data: Dictionary) -> Dictionary:
	var event: Dictionary = {"type": kind, "text": "", "data": data}
	return {"event": event, "views": [event, event]}
