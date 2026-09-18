extends RefCounted

const Random = preload("res://Scripts/Sim/U13Wishmaster.gd")
const CHANCE: int = 50
const DESCRIPTION: String = "50% chance to block each ranged hit, preventing HP and Armor damage."

# Extra shooters and beam collateral each get an independent, repeatable roll.
static func blocks(target: Dictionary, attacker_id: String, seed_value: String, round_number: int, tick: int, kind: String) -> bool:
	if target.kind != "marcher" or target.attributes.get("suit") != "Penitent" or target.attributes.has("monster_id"):
		return false
	var key: String = "%d:%d:%s:%s:%s" % [round_number, tick, kind, attacker_id, target.id]
	return Random.draw(seed_value, key, "PENITENT_RANGED_BLOCK", 100) < CHANCE
