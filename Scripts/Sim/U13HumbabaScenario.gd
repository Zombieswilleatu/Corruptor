extends RefCounted

const Core = preload("res://Scripts/Sim/U13CoreScenario.gd")
const Humbaba = preload("res://Scripts/Sim/U13Humbaba.gd")
const Candidates = preload("res://Scripts/Sim/U13HumbabaCandidates.gd")
const ConstructionCandidates = preload("res://Scripts/Sim/U13ConstructionCandidates.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")


# Isolated rules/telemetry opening until the headless gate is accepted. Existing
# playable picker remains Gremory/Deimos; this is not a production starting build.
static func world(opponent: String = "Gremory") -> Dictionary:
	var selection: Array = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]
	var result: Dictionary = loadout_world(["Humbaba", opponent], [selection, selection])
	if result.get("action") == "invalid":
		return result
	var entities = Ids.new()
	entities.restore(result.entities)
	for player_id in [0, 1]:
		# Two exposed non-artillery Castles, including one vulnerable to Stones
		# Forget; three protected choices remain available for construction.
		for slot in [0, 1]:
			var castle: Dictionary = entities.get_entity(Slots.castle_id(player_id, slot))
			castle.attributes.integrity = 8 if slot == 0 else 3
			castle.attributes.status = "standing"
			castle.attributes.construction_state = "active"
			entities.update(castle.id, castle.owner, castle.attributes)
	result.entities = entities.snapshot()
	return result


static func loadout_world(lords: Array, selections: Array) -> Dictionary:
	if lords.size() != 2:
		return Humbaba.Data.invalid("loadout_players_invalid")
	var base_lords: Array = lords.duplicate()
	for pid in [0, 1]:
		if base_lords[pid] == "Humbaba":
			base_lords[pid] = "Gremory"
	var result: Dictionary = Core.loadout_world(base_lords, selections)
	if result.get("action") == "invalid":
		return result
	result.data["humbaba_profile"] = Humbaba.POLICY
	result.data["lane_aura_profile"] = Humbaba.LaneAuras.VERSION
	result.data["humbaba_end_round"] = 0
	result.data["humbaba_breach_entries"] = {}
	result.data["hunt_profile"] = Combat.HUNT_VERSION
	var entities = Ids.new()
	entities.restore(result.entities)
	for pid in [0, 1]:
		if lords[pid] != "Humbaba":
			continue
		result.players[pid].lord_id = "Humbaba"
		var lord: Dictionary = entities.get_entity(result.players[pid].lord_entity_id)
		lord.attributes.lord_id = "Humbaba"
		lord.attributes.erase("threat")
		entities.update(lord.id, pid, lord.attributes)
	result.entities = entities.snapshot()
	return result


static func enumerate(owner, player_id: int) -> Dictionary:
	var view: Dictionary = owner.player_view(player_id, 0)
	if view.action == "invalid":
		return view
	if view.world.lord_ids[player_id] != "Humbaba":
		return Core.enumerate(owner, player_id)
	var result: Dictionary = Candidates.enumerate(owner, player_id)
	result["castle_actions"] = ConstructionCandidates.enumerate(view)
	return result
