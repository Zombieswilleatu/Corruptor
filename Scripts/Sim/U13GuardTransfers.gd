extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Guards = preload("res://Scripts/Sim/U13GuardDeployment.gd")


static func guard(world: Dictionary, id: String) -> Dictionary:
	for row in world.entities.entities:
		if row.id == id and row.kind == "card" and row.attributes.get("role") == "guard":
			return row
	return {}


static func free_slots(world: Dictionary, owner: int, lane: String) -> Array:
	var result: Array = []
	for slot in range(Guards.SLOTS_PER_ZONE):
		var occupied: bool = false
		for row in world.entities.entities:
			if (
				row.kind == "card"
				and row.owner == owner
				and row.attributes.get("role") == "guard"
				and row.attributes.lane == lane
				and row.attributes.slot == slot
			):
				occupied = true
		if not occupied:
			result.append(slot)
	return result


# The declaration chooses a zone, not a slot. Keep the existing slot if free,
# otherwise take the lowest free slot. No swap, overflow, death, or new identity.
static func move(
	raw: Dictionary, id: String, expected_owner: int, new_owner: int, lane: String
) -> Dictionary:
	var before: Dictionary = guard(raw, id)
	if expected_owner not in [0, 1] or new_owner not in [0, 1] or lane not in Guards.LANES:
		return Data.invalid("guard_transfer_terms_invalid")
	if before.is_empty() or before.owner != expected_owner:
		return {"action": "fizzle", "reason": "guard_transfer_target_unavailable"}
	if (
		(new_owner == expected_owner and before.attributes.lane == lane)
		or (new_owner != expected_owner and before.attributes.lane != lane)
	):
		return {"action": "fizzle", "reason": "guard_transfer_zone_invalid"}
	var slots: Array = free_slots(raw, new_owner, lane)
	if slots.is_empty():
		return {"action": "fizzle", "reason": "guard_transfer_zone_full"}
	var world: Dictionary = Data.copy_data(raw)
	var ids = Ids.new()
	ids.restore(world.entities)
	var card: Dictionary = ids.get_entity(id)
	card.attributes.lane = lane
	card.attributes.slot = (
		int(card.attributes.slot) if card.attributes.slot in slots else int(slots[0])
	)
	ids.update(id, new_owner, card.attributes)
	world.entities = ids.snapshot()
	return {
		"action": "resolved",
		"world": world,
		"before": Data.copy_data(before),
		"after": ids.get_entity(id)
	}


static func eligible(world: Dictionary, owner: int, lane: String, new_owner: int) -> Array:
	var result: Array = []
	if free_slots(world, new_owner, lane).is_empty():
		return result
	for row in world.entities.entities:
		if (
			row.kind == "card"
			and row.owner == owner
			and row.attributes.get("role") == "guard"
			and row.attributes.lane == lane
		):
			result.append(row.id)
	result.sort()
	return result
