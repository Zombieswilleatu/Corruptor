extends RefCounted

const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Stats = preload("res://Scripts/Sim/U13LordStats.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const VERSION: String = "U13_BLOOD_CONDUIT_V1"

static func quote(world: Dictionary, actor: Dictionary, before: int, amount: int) -> Dictionary:
	var result: Dictionary = {"after": before + amount, "circle_id": "", "prevented": 0}
	if amount <= 0 or world.data.get("blood_conduit_profile") != VERSION or Stats.threat_value(actor) == null:
		return result
	var prior: Dictionary = actor.duplicate(true)
	var later: Dictionary = actor.duplicate(true)
	prior.attributes.threat = before
	later.attributes.threat = before + amount
	if Stats.defense(world, later) >= Stats.defense(world, prior):
		return result
	var circles: Array = world.entities.entities.filter(func(e): return e.owner == actor.owner and e.attributes.get("castle_type") == "SummoningCircle" and Structures.operational(e))
	circles.sort_custom(func(a, b): return a.attributes.castle_slot < b.attributes.castle_slot)
	if not circles.is_empty():
		result.circle_id = circles[0].id
		result.prevented = 1
		result.after -= 1
	return result

# Caller establishes baseline Threat before invoking a gain. Resets and payment
# shortfalls are not themselves gains; they never exert a Circle.
static func gain(world: Dictionary, lord_id: String, amount: int, round_number: int) -> Dictionary:
	var ids = Ids.new()
	ids.restore(world.entities)
	var actor: Dictionary = ids.get_entity(lord_id)
	var before: int = int(actor.attributes.get("threat", 0))
	var quoted: Dictionary = quote(world, actor, before, amount)
	var events: Array = []
	if not quoted.circle_id.is_empty():
		var circle: Dictionary = ids.get_entity(quoted.circle_id)
		var integrity: int = circle.attributes.integrity
		circle.attributes.integrity -= 3
		Structures.note_integrity_loss(circle, integrity, round_number)
		ids.update(circle.id, circle.owner, circle.attributes)
		var event: Dictionary = {"type": "BLOOD_CONDUIT", "text": "Blood Conduit prevented one Threat.", "data": {"player_id": actor.owner, "lord_id": lord_id, "castle_id": circle.id, "round": round_number, "integrity_before": integrity, "integrity_after": circle.attributes.integrity, "threat_before": before, "threat_after": quoted.after, "prevented": 1}}
		events.append({"event": event, "views": [event, event]})
	if Stats.threat_value(actor) != null:
		actor.attributes.threat = quoted.after
		ids.update(actor.id, actor.owner, actor.attributes)
	world.entities = ids.snapshot()
	return {"action": "resolved", "world": world, "events": events, "after": quoted.after}
