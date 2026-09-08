extends RefCounted

const Base = preload("res://Scripts/Sim/U13HumbabaScenario.gd")
const Kalligan = preload("res://Scripts/Sim/U13Kalligan.gd")
const Candidates = preload("res://Scripts/Sim/U13KalliganCandidates.gd")
const CastleCandidates = preload("res://Scripts/Sim/U13ConstructionCandidates.gd")


static func world(opponent: String = "Gremory") -> Dictionary:
	var result: Dictionary = Base.world("Gremory" if opponent == "Kalligan" else opponent)
	if result.get("action") == "invalid":
		return result
	result.data["kalligan_profile"] = Kalligan.POLICY
	result.data["hazard_profile"] = Kalligan.Hazards.VERSION
	result.data["kalligan_upkeep_round"] = 0
	result.data["scorch_guard_round"] = 0
	result.data["scorch_lane_round"] = 0
	result.data["rekindle_rounds"] = [0, 0]
	result.data["rekindle_defunct_ids"] = []
	var ids = Kalligan.Ids.new()
	ids.restore(result.entities)
	for pid in [0, 1] if opponent == "Kalligan" else [0]:
		result.players[pid].lord_id = "Kalligan"
		var lord: Dictionary = ids.get_entity(result.players[pid].lord_entity_id)
		lord.attributes.lord_id = "Kalligan"
		lord.attributes["threat"] = 0
		ids.update(lord.id, pid, lord.attributes)
	result.entities = ids.snapshot()
	return result


static func enumerate(owner, player_id: int) -> Dictionary:
	var view: Dictionary = owner.player_view(player_id, 0)
	if view.action == "invalid":
		return view
	if view.world.lord_ids[player_id] != "Kalligan":
		return Base.enumerate(owner, player_id)
	var result: Dictionary = Candidates.enumerate(owner, player_id)
	result["castle_actions"] = CastleCandidates.enumerate(view)
	return result
