extends RefCounted

const Base = preload("res://Scripts/Sim/U13OriasScenario.gd")
const Content = preload("res://Scripts/Sim/U13Odradek.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")


static func world(opponent: String = "Gremory") -> Dictionary:
	var choices: Array = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]
	return loadout_world(["Odradek", opponent], [choices, choices])


static func loadout_world(lords: Array, choices: Array) -> Dictionary:
	var base_lords: Array = lords.duplicate()
	for pid in range(base_lords.size()):
		if base_lords[pid] == "Odradek":
			base_lords[pid] = "Gremory"
	var result: Dictionary = Base.loadout_world(base_lords, choices)
	if result.get("action") == "invalid":
		return result
	result.data["odradek_profile"] = Content.ODRADEK_POLICY
	result.data["reconfiguration_round"] = 0
	var entities = Content.Ids.new()
	entities.restore(result.entities)
	for pid in [0, 1]:
		result.players[pid].resources[Content.RESOURCE] = 0
		if lords[pid] == "Odradek":
			result.players[pid].lord_id = "Odradek"
			var lord: Dictionary = entities.get_entity(result.players[pid].lord_entity_id)
			lord.attributes.lord_id = "Odradek"
			lord.attributes["threat"] = 0
			entities.update(lord.id, pid, lord.attributes)
	result.entities = entities.snapshot()
	return result


static func source(pid: int, round_number: int, target: Dictionary, index: int = 0) -> Dictionary:
	return Decl.create(
		Content.MatchOwner.declaration_id(pid, round_number, index),
		pid,
		"Odradek",
		Content.REDIRECT,
		round_number,
		Content.Timeline.POST_RESOLUTION_POSITION,
		round_number,
		index,
		"public",
		target,
		{Content.RESOURCE: 1}
	)


static func enumerate(owner, player_id: int) -> Dictionary:
	var result: Dictionary = Base.enumerate(owner, player_id)
	if (
		result.action == "invalid"
		or owner.player_view(player_id, 0).world.lord_ids[player_id] != "Odradek"
	):
		return result
	result.powers = []
	# Tier-1 bot samples live bodies plus a fallback center. Shared legality
	# screens costs/alive state; strategic multi-effect combos come later.
	var view: Dictionary = owner.player_view(player_id, 0)
	for entity in view.world.entities:
		if entity.kind == "marcher":
			result.powers.append(
				source(
					player_id,
					owner.round_number(),
					{
						"lane": entity.attributes.lane,
						"field_position":
						{"x_fp": entity.attributes.x_fp, "y_fp": entity.attributes.y_fp}
					}
				)
			)
	for lane in Content.Space.LANES:
		result.powers.append(
			source(
				player_id,
				owner.round_number(),
				{"lane": lane, "field_position": {"x_fp": 1200, "y_fp": 300}}
			)
		)
	return result
