extends RefCounted

const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const VERSION: String = "U13_KRONI_PLACED_RANDOM_V2"


static func lord(world: Dictionary, pid: int) -> Dictionary:
	for row in world.entities.entities:
		if row.kind == "lord" and row.owner == pid:
			return row
	return {}


static func active(world: Dictionary, pid: int) -> bool:
	var row: Dictionary = lord(world, pid)
	return row.get("attributes", {}).get("lord_id") == "Kroni" and row.attributes.alive


static func hunger(world: Dictionary, pid: int) -> int:
	return int(lord(world, pid).get("attributes", {}).get("hunger", 0))


static func event(kind: String, details: Dictionary, message: String = "") -> Dictionary:
	var fact: Dictionary = {"type": kind, "data": details, "text": message}
	return {"event": fact, "views": [fact, fact]}


# Mutates only the owned result world. All Hunger changes use this gate, so
# dropping below the milestone never makes its personal Tear repeatable.
static func feed(world: Dictionary, pid: int, amount: int, round_number: int, cause: String) -> Array:
	var row: Dictionary = lord(world, pid).duplicate(true)
	var before: int = hunger(world, pid)
	var after: int = clampi(before + amount, 0, 1000000)
	row.attributes.hunger = after
	var events: Array = [event("KRONI_HUNGER_CHANGED", {"player_id": pid, "before": before, "after": after, "round": round_number, "cause": cause}, "%s: Hunger %d → %d." % [cause, before, after])]
	if after >= 3 and not row.attributes.hunger_milestone:
		row.attributes.hunger_milestone = true
		world.players[pid].resources.personal_tears += 1
		events.append(event("KRONI_HUNGER_MILESTONE", {"player_id": pid, "round": round_number, "amount": 1}, "Hunger: +1 personal Tear (once per game)."))
	var ids = Ids.new()
	ids.restore(world.entities)
	ids.update(row.id, pid, row.attributes)
	world.entities = ids.snapshot()
	return events


static func guard(world: Dictionary, identity: String) -> Dictionary:
	for row in world.entities.entities:
		if row.id == identity and row.kind == "card" and row.attributes.get("role") == "guard":
			return row
	return {}


static func devour_guard(world: Dictionary, victim: Dictionary, pid: int, round_number: int, cause: String) -> Dictionary:
	var ids = Ids.new()
	ids.restore(world.entities)
	ids.retire(victim.id)
	world.entities = ids.snapshot()
	return event("GUARD_DEVOURED", {"before": victim, "player_id": pid, "round": round_number, "cause": cause}, "%s devours %s %d." % [cause, victim.attributes.suit, victim.attributes.value])


static func valid(world: Dictionary) -> bool:
	if world.data.get("kroni_profile") != VERSION:
		return false
	for field in ["kroni_feed_round", "kroni_action_round", "kroni_breach_round"]:
		if not Data.is_integer(world.data.get(field)) or world.data[field] < 0:
			return false
	if typeof(world.data.get("kroni_fed")) != TYPE_ARRAY or world.data.kroni_fed.size() != 2:
		return false
	for stamp in world.data.kroni_fed:
		if not Data.is_integer(stamp) or stamp < 0:
			return false
	for pid in [0, 1]:
		var row: Dictionary = lord(world, pid)
		if row.attributes.lord_id != "Kroni":
			continue
		if not Data.is_integer(row.attributes.get("threat")) or row.attributes.threat < 0 or row.attributes.threat > 1000000:
			return false
		if not Data.is_integer(row.attributes.get("hunger")) or row.attributes.hunger < 0 or row.attributes.hunger > 1000000:
			return false
		if typeof(row.attributes.get("hunger_milestone")) != TYPE_BOOL:
			return false
		if row.attributes.hunger >= 3 and not row.attributes.hunger_milestone:
			return false
	return true
