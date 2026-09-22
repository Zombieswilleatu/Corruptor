extends RefCounted

const Random = preload("res://Scripts/Sim/U13Wishmaster.gd")
const CHANCE: int = 50
const DESCRIPTION: String = "50% chance to block ranged hits and Vulture melee hits, preventing HP and Armor damage."

# Extra shooters and beam collateral each get an independent, repeatable roll.
static func blocks(target: Dictionary, attacker_id: String, seed_value: String, round_number: int, tick: int, kind: String) -> bool:
	if target.kind != "marcher" or target.attributes.get("suit") != "Penitent" or target.attributes.has("monster_id"):
		return false
	var key: String = "%d:%d:%s:%s:%s" % [round_number, tick, kind, attacker_id, target.id]
	return Random.draw(seed_value, key, "PENITENT_RANGED_BLOCK", 100) < CHANCE

# Vultures retain this matchup penalty after switching from shots to melee.
static func blocks_vulture_melee(target: Dictionary, attacker: Dictionary, seed_value: String, round_number: int, tick: int) -> bool:
	return attacker.get("kind") == "marcher" and attacker.attributes.get("suit") == "Vulture" and not attacker.attributes.has("monster_id") and blocks(target, attacker.id, seed_value, round_number, tick, "VultureMelee")
