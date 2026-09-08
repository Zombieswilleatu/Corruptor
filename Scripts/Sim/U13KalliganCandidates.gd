extends RefCounted

const Content = preload("res://Scripts/Sim/U13Kalligan.gd")
const Base = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")


static func enumerate(owner, player_id: int) -> Dictionary:
	var result: Dictionary = Base.enumerate(owner, player_id)
	if result.action == "invalid":
		return result
	var view: Dictionary = owner.player_view(player_id, 0)
	result.powers = [source(player_id, view.round, Content.PYROCLASM)]
	for lane in ["Lord", "Castle"]:
		result.powers.append(
			source(player_id, view.round, Content.INFERNO, {"kind": "lane", "lane": lane})
		)
		result.powers.append(
			source(
				player_id,
				view.round,
				Content.INFERNO,
				{"kind": "guard", "lane": lane, "player_id": 1 - player_id}
			)
		)
	return result


static func source(
	player_id: int, round_number: int, power: String, target: Dictionary = {}, queue_index: int = 0
) -> Dictionary:
	var rule: Dictionary = Content.rules()[power]
	return Decl.create(
		Content.MatchOwner.declaration_id(player_id, round_number, queue_index),
		player_id,
		"Kalligan",
		power,
		round_number,
		rule.fire_hook,
		round_number + rule.delay_rounds,
		queue_index,
		"public",
		target,
		{},
		{}
	)
