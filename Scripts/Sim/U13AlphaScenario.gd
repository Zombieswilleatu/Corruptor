extends RefCounted

const Content = preload("res://Scripts/Sim/U13Kalligan.gd")
const Base = preload("res://Scripts/Sim/U13KalliganScenario.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const VERSION: String = "U13_FOUR_LORD_ALPHA_FIXTURE_V1"
const LORDS: Array = ["Gremory", "Deimos", "Humbaba", "Kalligan"]
const POWERS: Dictionary = {
	"Gremory": ["PredatorOfRuin", "InevitableRuin"],
	"Deimos": ["WarMachine", "Rout"],
	"Humbaba": ["MusterTheFaithful", "BreathOfLife"],
	"Kalligan": ["Inferno", "Pyroclasm"]
}


static func pair_valid(pair: Array) -> bool:
	return pair.size() == 2 and pair[0] in LORDS and pair[1] in LORDS


static func matrix() -> Array:
	var result: Array = []
	for left in LORDS:
		for right in LORDS:
			result.append([left, right])
	return result


static func world(pair: Array) -> Dictionary:
	if not pair_valid(pair):
		return Data.invalid("alpha_roster_invalid")
	# Same physical fixture on both seats. Two Engines expose instance targeting;
	# a vulnerable Bastion exposes Stones, repair and ruination. Keep/Stockpile
	# remain protected unbuilt choices. Normal draws/resources are not invented.
	var selection: Array = ["SiegeEngine", "SiegeEngine", "Bastion", "Keep", "Stockpile"]
	var result: Dictionary = Base.loadout_world(pair, [selection, selection])
	if result.get("action") == "invalid":
		return result
	var ids = Ids.new()
	ids.restore(result.entities)
	for pid in [0, 1]:
		for slot in [0, 1, 2]:
			var castle: Dictionary = ids.get_entity(Slots.castle_id(pid, slot))
			castle.attributes.integrity = 12 if slot < 2 else 3
			castle.attributes.status = "standing"
			castle.attributes.construction_state = "active"
			ids.update(castle.id, pid, castle.attributes)
	result.entities = ids.snapshot()
	return result


static func create_owner():
	return Content.new().create_combat_match()


static func enumerate(owner, player_id: int) -> Dictionary:
	return Base.enumerate(owner, player_id)
