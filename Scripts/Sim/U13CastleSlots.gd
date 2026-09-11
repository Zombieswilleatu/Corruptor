extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const VERSION: String = "U13_CASTLE_SLOTS_V1"
const SLOT_COUNT: int = 5
const TYPE_LIMIT: int = 2
const TYPES: Array = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]


static func enabled(world: Dictionary) -> bool:
	return world.data.get("castle_slot_profile") == VERSION


static func selection_valid(selection) -> bool:
	if typeof(selection) != TYPE_ARRAY or selection.size() != SLOT_COUNT:
		return false
	var counts: Dictionary = {}
	for type in selection:
		if typeof(type) != TYPE_STRING or type not in TYPES:
			return false
		counts[type] = int(counts.get(type, 0)) + 1
		if counts[type] > (1 if type == "Keep" else TYPE_LIMIT):
			return false
	return true


# Physical slot is identity; changing type in a setup draft does not change it.
# Once a match starts, its chosen loadout is sealed and cannot be replaced.
static func castle_id(player_id: int, slot: int) -> String:
	return Ids.identity("castle", "loadout:castle:" + str(player_id), slot)


static func valid(world: Dictionary) -> bool:
	if not enabled(world):
		return not world.data.has("castle_slot_profile")
	var selections = world.data.get("castle_loadouts")
	if typeof(selections) != TYPE_ARRAY or selections.size() != 2:
		return false
	for selection in selections:
		if not selection_valid(selection):
			return false
	var castles: Dictionary = {}
	for entity in world.entities.entities:
		if entity.kind != "castle":
			continue
		var a: Dictionary = entity.attributes
		if entity.owner not in [0, 1] or not Data.is_integer(a.get("castle_slot")):
			return false
		if a.castle_slot < 0 or a.castle_slot >= SLOT_COUNT:
			return false
		if (
			entity.id != castle_id(entity.owner, int(a.castle_slot))
			or a.get("castle_type") != selections[entity.owner][int(a.castle_slot)]
		):
			return false
		var profile: String = (
			"siege_engine" if a.castle_type == "SiegeEngine" else "plain_integrity"
		)
		if a.get("combat_profile") != profile or castles.has(entity.id):
			return false
		castles[entity.id] = entity
	if castles.size() != SLOT_COUNT * 2:
		return false
	return true

