extends RefCounted

const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const VERSION: String = "U13_CASTLE_DEFENSES_V1"


static func screen(world: Dictionary, pid: int, type: String) -> Dictionary:
	if world.data.get("castle_defense_profile") != VERSION:
		return {}
	var choices: Array = []
	for row in world.entities.entities:
		if row.owner == pid and Structures.targetable(row) and row.attributes.get("castle_type") == type:
			choices.append(row)
	choices.sort_custom(func(a, b): return a.attributes.castle_slot < b.attributes.castle_slot)
	return {} if choices.is_empty() else choices[0].duplicate(true)


static func absorb_hunt(raw: Dictionary, pid: int, strength: int, round_number: int) -> Dictionary:
	var keep: Dictionary = screen(raw, pid, "Keep")
	if keep.is_empty() or strength <= 0:
		return {"world": raw, "remaining": strength, "events": []}
	var world: Dictionary = raw.duplicate(true)
	var before: int = keep.attributes.integrity
	var reduction: int = mini(strength, 3) if Structures.operational(keep) else 0
	var remaining: int = maxi(0, strength - reduction)
	var damage: int = mini(before, remaining)
	var ruined: bool = remaining > 0 and remaining >= before
	if not ruined:
		keep.attributes.integrity -= damage
		Structures.note_integrity_loss(keep, before, round_number)
		var ids = Ids.new()
		ids.restore(world.entities)
		ids.update(keep.id, pid, keep.attributes)
		world.entities = ids.snapshot()
	# The caller delivers a real ruination through U13's current Lord callbacks,
	# but does not award the separate Siege Souls/neutral-Tear reward.
	var event: Dictionary = Structures.public_event("KEEP_INTERPOSED", {"player_id": pid, "round": round_number, "castle_id": keep.id, "integrity_before": before, "damage": damage, "reduction": reduction, "destroyed": ruined, "overflow": remaining - damage})
	return {"world": world, "remaining": remaining - damage, "events": [event], "ruin_id": keep.id if ruined else ""}
