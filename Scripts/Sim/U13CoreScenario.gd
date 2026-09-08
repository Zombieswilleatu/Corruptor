extends RefCounted

const Opening = preload("res://Scripts/Sim/U13SmokeSession.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const DeimosCandidates = preload("res://Scripts/Sim/U13DeimosCandidates.gd")
const GremoryCandidates = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Construction = preload("res://Scripts/Sim/U13Construction.gd")
const ConstructionCandidates = preload("res://Scripts/Sim/U13ConstructionCandidates.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Rout = preload("res://Scripts/Sim/U13Rout.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")


# Explicit artillery exercise opening, separate from the accepted Gremory board.
# Named engines are prebuilt; no unfinished Construction rules are simulated.
static func world(roster: Array) -> Dictionary:
	var result: Dictionary = Opening._initial_world()
	result.data.combat_profile = Structures.PROFILE
	result.data["rout_profile"] = Rout.VERSION
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


static func construction_world() -> Dictionary:
	var result: Dictionary = world(["Deimos", "Gremory"])
	result.data["construction_profile"] = Construction.VERSION
	result.data["construction_round"] = 0
	result.data["construction_targets"] = ["", ""]
	result.data["castle_orders"] = [null, null]
	var entities = Ids.new()
	entities.restore(result.entities)
	for entity in entities.snapshot().entities:
		if entity.kind != "castle":
			continue
		entity.attributes["construction_state"] = "active"
		if entity.attributes.combat_profile == "siege_engine":
			entity.attributes.integrity = 0
			entity.attributes.status = "ruined" if entity.owner == 0 else "defunct"
			entity.attributes.construction_state = "active" if entity.owner == 0 else "unbuilt"
		entities.update(entity.id, entity.owner, entity.attributes)
	for player in result.players:
		player.resources["repair_tokens"] = 2
	result.entities = entities.snapshot()
	return result


static func enumerate(owner, player_id: int) -> Dictionary:
	var view: Dictionary = owner.player_view(player_id, 0)
	if view.action == "invalid":
		return view
	var result: Dictionary = (
		DeimosCandidates.enumerate(owner, player_id)
		if view.world.lord_ids[player_id] == "Deimos"
		else GremoryCandidates.enumerate(owner, player_id)
	)
	if view.world.has("construction_profile"):
		result["castle_actions"] = ConstructionCandidates.enumerate(view)
	return result


# Setup boundary for the eventual Lord/Castle picker. Only implemented Lords
# can start this slice; all five Castle identities may be selected. Non-artillery
# printed powers are not migrated yet. Starting resources remain fixture data.
static func loadout_world(lords: Array, selections: Array) -> Dictionary:
	if lords.size() != 2 or selections.size() != 2:
		return Data.invalid("loadout_players_invalid")
	for player_id in [0, 1]:
		if lords[player_id] not in ["Gremory", "Deimos"]:
			return Data.invalid("loadout_lord_not_implemented")
		if not Slots.selection_valid(selections[player_id]):
			return Data.invalid("castle_loadout_invalid")
	var result: Dictionary = world(lords)
	result.data["construction_profile"] = Construction.VERSION
	result.data["construction_round"] = 0
	result.data["construction_targets"] = ["", ""]
	result.data["castle_orders"] = [null, null]
	result.data["castle_slot_profile"] = Slots.VERSION
	result.data["castle_loadouts"] = selections.duplicate(true)
	var entities = Ids.new()
	entities.restore(result.entities)
	for entity in entities.snapshot().entities:
		if entity.kind == "castle":
			entities.retire(entity.id)
	for player_id in [0, 1]:
		result.players[player_id].resources["repair_tokens"] = 2
		for slot in range(Slots.SLOT_COUNT):
			var type: String = selections[player_id][slot]
			var attributes: Dictionary = Structures.attributes(type == "SiegeEngine", 0)
			attributes["construction_state"] = "unbuilt"
			attributes["castle_type"] = type
			attributes["castle_slot"] = slot
			entities.create(
				"castle", "loadout:castle:" + str(player_id), slot, player_id, attributes
			)
	result.entities = entities.snapshot()
	return result


# Explicit density/stacking fixture, not the production opening economy.
static func duplicate_world() -> Dictionary:
	var selection: Array = ["SiegeEngine", "SiegeEngine", "Keep", "Bastion", "Stockpile"]
	var result: Dictionary = loadout_world(["Deimos", "Gremory"], [selection, selection])
	var entities = Ids.new()
	entities.restore(result.entities)
	for player_id in [0, 1]:
		for slot in [0, 1]:
			var castle: Dictionary = entities.get_entity(Slots.castle_id(player_id, slot))
			castle.attributes.integrity = 21
			castle.attributes.status = "standing"
			castle.attributes.construction_state = "active"
			entities.update(castle.id, castle.owner, castle.attributes)
	result.entities = entities.snapshot()
	return result


static func start_loadout(seed_value: String, lords: Array, selections: Array) -> Dictionary:
	var initial: Dictionary = loadout_world(lords, selections)
	if initial.get("action") == "invalid":
		return initial
	var content = Deimos.new(true, true)
	var owner = content.create_combat_match()
	var started: Dictionary = owner.start(seed_value, initial, [0, 1])
	if started.action == "invalid":
		return started
	return {"action": "loadout_match_started", "owner": owner}
