extends RefCounted

const Opening = preload("res://Scripts/Sim/U13SmokeSession.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const DeimosCandidates = preload("res://Scripts/Sim/U13DeimosCandidates.gd")
const GremoryCandidates = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")


# Explicit artillery exercise opening, separate from the accepted Gremory board.
# Named engines are prebuilt; no unfinished Construction rules are simulated.
static func world(roster: Array) -> Dictionary:
	var result: Dictionary = Opening._initial_world()
	result.data.combat_profile = Structures.PROFILE
	result.data.breach_lord = ""
	result.data["deimos_spoils"] = [0, 0]
	result.data["deimos_fear_round"] = [0, 0]
	result.data["deimos_spoils_events"] = {}
	var entities = Ids.new()
	entities.restore(result.entities)
	for player_id in [0, 1]:
		var player: Dictionary = result.players[player_id]
		player.lord_id = roster[player_id]
		player.resources["personal_tears"] = 0
		var lord: Dictionary = entities.get_entity(player.lord_entity_id)
		lord.attributes.lord_id = player.lord_id
		if player.lord_id == "Deimos":
			lord.attributes["threat"] = 0
		entities.update(lord.id, player_id, lord.attributes)
		var castle: Dictionary = entities.get_entity(Opening._castle_id(player_id))
		entities.update(castle.id, player_id, Structures.attributes(false, 8))
		entities.create(
			"castle", "core:engine:" + str(player_id), 0, player_id, Structures.attributes(true, 12)
		)
	result.entities = entities.snapshot()
	return result


static func enumerate(owner, player_id: int) -> Dictionary:
	var view: Dictionary = owner.player_view(player_id, 0)
	if view.action == "invalid":
		return view
	if view.world.lord_ids[player_id] == "Deimos":
		return DeimosCandidates.enumerate(owner, player_id)
	return GremoryCandidates.enumerate(owner, player_id)
