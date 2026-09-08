extends RefCounted

const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const GremoryCandidates = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")


static func enumerate(owner, player_id: int) -> Dictionary:
	var result: Dictionary = GremoryCandidates.enumerate(owner, player_id)
	if result.action == "invalid":
		return result
	result.powers = []
	var view: Dictionary = owner.player_view(player_id, 0)
	for entity in view.world.entities:
		if (
			entity.kind == "castle"
			and entity.owner == player_id
			and entity.attributes.combat_profile == "siege_engine"
		):
			result.powers.append(
				_source(player_id, view.round, Deimos.WAR_MACHINE, {"entity_id": entity.id})
			)
	for lane in ["Lord", "Castle"]:
		result.powers.append(_source(player_id, view.round, Deimos.ROUT, {"lane": lane}))
	return result


static func _source(
	player_id: int, round_number: int, power: String, target: Dictionary
) -> Dictionary:
	return Decl.create(
		MatchOwner.declaration_id(player_id, round_number, 0),
		player_id,
		"Deimos",
		power,
		round_number,
		Deimos.rules()[power].fire_hook,
		round_number,
		0,
		"public",
		target,
		{},
		{}
	)
