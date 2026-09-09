extends RefCounted

const Base = preload("res://Scripts/Sim/U13KalliganScenario.gd")
const Content = preload("res://Scripts/Sim/U13Orias.gd")


# Rules fixture, not a production opening. Orias is not added to the playable
# roster until the remaining powers and Development dependencies are complete.
static func world(opponent: String = "Gremory") -> Dictionary:
	var choices: Array = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]
	return loadout_world(["Orias", opponent], [choices, choices])


static func loadout_world(lords: Array, choices: Array) -> Dictionary:
	if lords.size() != 2:
		return Content.Data.invalid("orias_players_invalid")
	var base_lords: Array = lords.duplicate()
	for pid in [0, 1]:
		if base_lords[pid] == "Orias":
			base_lords[pid] = "Gremory"
	var result: Dictionary = Base.loadout_world(base_lords, choices)
	if result.get("action") == "invalid":
		return result
	result.data["orias_profile"] = Content.POLICY
	result.data["spatial_field_profile"] = Content.Fields.VERSION
	var entities = Content.Ids.new()
	entities.restore(result.entities)
	for pid in [0, 1]:
		if lords[pid] == "Orias":
			result.players[pid].lord_id = "Orias"
			var lord: Dictionary = entities.get_entity(result.players[pid].lord_entity_id)
			lord.attributes.lord_id = "Orias"
			lord.attributes["threat"] = 0
			entities.update(lord.id, pid, lord.attributes)
	result.entities = entities.snapshot()
	return result
