extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const VERSION: String = "U13_VALAK_V1"
const RESOURCE: String = "life_essence"
const CAP: int = 5


static func active(world: Dictionary, pid: int) -> bool:
	if not world.data.has("valak_profile") or world.players[pid].lord_id != "Valak":
		return false
	for row in world.entities.entities:
		if row.id == world.players[pid].lord_entity_id:
			return row.attributes.alive
	return false


static func event(kind: String, details: Dictionary) -> Dictionary:
	var fact: Dictionary = {"type": kind, "text": "", "data": details}
	return {"event": fact, "views": [fact, fact]}


# Reserved Essence still occupies pool capacity until Projection fires. It
# cannot also shield a Hunt; combat gains cannot enlarge the sealed shot.
static func gain(world: Dictionary, pid: int, guard: Dictionary, round_number: int) -> Dictionary:
	var before: int = world.players[pid].resources[RESOURCE]
	var reserved: int = world.data.valak_reserved[pid]
	var after: int = mini(CAP - reserved, before + 2)
	world.players[pid].resources[RESOURCE] = after
	return event("VALAK_ESSENCE_GAINED", {"player_id": pid, "guard": guard, "before": before + reserved, "after": after + reserved, "gained": after - before, "round": round_number})


static func reinforce(world: Dictionary, pid: int, incoming: int, round_number: int) -> Dictionary:
	if not active(world, pid):
		return {"spent": 0, "events": []}
	var before: int = world.players[pid].resources[RESOURCE]
	var spent: int = mini(before, maxi(0, incoming))
	world.players[pid].resources[RESOURCE] = before - spent
	return {"spent": spent, "events": [] if spent == 0 else [event("VALAK_ESSENCE_REINFORCED", {"player_id": pid, "zone": "Lord", "spent": spent, "before": before + world.data.valak_reserved[pid], "after": before - spent + world.data.valak_reserved[pid], "round": round_number})]}


static func valid(world: Dictionary) -> bool:
	if world.data.get("valak_profile") != VERSION:
		return false
	var reserved = world.data.get("valak_reserved")
	if typeof(reserved) != TYPE_ARRAY or reserved.size() != 2:
		return false
	for pid in [0, 1]:
		var amount = world.players[pid].resources.get(RESOURCE)
		if not Data.is_integer(amount) or not Data.is_integer(reserved[pid]) or amount < 0 or reserved[pid] < 0 or amount + reserved[pid] > CAP:
			return false
		if world.players[pid].lord_id != "Valak" and amount + reserved[pid] != 0:
			return false
	return true
