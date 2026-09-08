extends RefCounted

const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const GremoryCandidates = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")


static func enumerate(owner, player_id: int) -> Dictionary:
	# Reuse the same finite Siege/Ward vocabulary. Shared legality filters it.
	var result: Dictionary = GremoryCandidates.enumerate(owner, player_id)
	if result.action == "invalid":
		return result
	result.powers = []
	var view: Dictionary = owner.player_view(player_id, 0)
	var rule: Dictionary = Deimos.rules()[Deimos.WAR_MACHINE]
	for entity in view.world.entities:
		if (
			entity.kind == "castle"
			and entity.owner == player_id
			and entity.attributes.combat_profile == "siege_engine"
		):
			result.powers.append(
				Decl.create(
					MatchOwner.declaration_id(player_id, view.round, 0),
					player_id,
					"Deimos",
					Deimos.WAR_MACHINE,
					view.round,
					rule.fire_hook,
					view.round,
					0,
					"public",
					{"entity_id": entity.id},
					{},
					{}
				)
			)
	return result
