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
	for power in [Humbaba.MUSTER, Humbaba.BREATH]:
		for lane in ["Lord", "Castle"]:
			result.powers.append(source(player_id, view.round, lane, power))
	return result


static func source(
	player_id: int,
	round_number: int,
	lane: String,
	power: String = Humbaba.MUSTER,
	queue_index: int = 0
) -> Dictionary:
	return Decl.create(
		MatchOwner.declaration_id(player_id, round_number, queue_index),
		player_id,
		"Humbaba",
		power,
		round_number,
		Humbaba.rules()[power].fire_hook,
		round_number,
		queue_index,
		"public",
		{"lane": lane},
		{},
		{}
	)
