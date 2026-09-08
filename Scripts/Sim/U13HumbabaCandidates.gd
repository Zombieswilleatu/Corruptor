extends RefCounted

const Humbaba = preload("res://Scripts/Sim/U13Humbaba.gd")
const Candidates = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")


# Payload vocabulary only; U13Legality/whole-submission preview owns admission.
static func enumerate(owner, player_id: int) -> Dictionary:
	var result: Dictionary = Candidates.enumerate(owner, player_id)
	if result.action == "invalid":
		return result
	var view: Dictionary = owner.player_view(player_id, 0)
	result.powers = []
	for lane in ["Lord", "Castle"]:
		result.powers.append(source(player_id, view.round, lane))
	return result


static func source(player_id: int, round_number: int, lane: String) -> Dictionary:
	return Decl.create(
		MatchOwner.declaration_id(player_id, round_number, 0),
		player_id,
		"Humbaba",
		Humbaba.MUSTER,
		round_number,
		Humbaba.rules()[Humbaba.MUSTER].fire_hook,
		round_number,
		0,
		"public",
		{"lane": lane},
		{},
		{}
	)
