extends RefCounted

const Content = preload("res://Scripts/Sim/U13Orias.gd")
const Base = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const Space = preload("res://Scripts/Sim/U13SpatialSpace.gd")


static func source(
	player_id: int, round_number: int, target: Dictionary, queue_index: int = 0
) -> Dictionary:
	return Decl.create(
		Content.MatchOwner.declaration_id(player_id, round_number, queue_index),
		player_id,
		"Orias",
		Content.WEB,
		round_number,
		Content.Timeline.POST_RESOLUTION_HAZARDS,
		round_number,
		queue_index,
		"public",
		target
	)


# All in-bounds positions have identical declaration legality for Web. Sample
# one uniform position per lane; RandomLegal chooses the lane and still asks
# the authoritative legality path before accepting the complete submission.
static func enumerate(owner, player_id: int) -> Dictionary:
	var result: Dictionary = Base.enumerate(owner, player_id)
	if result.action == "invalid":
		return result
	result.powers = []
	var identity: String = Content.MatchOwner.declaration_id(player_id, owner.round_number(), 0)
	for lane in Space.LANES:
		var sampled: Dictionary = Space.random_position(
			Space.lane_region(lane), owner.rng_seed(), identity, "BOT_POWER_POSITION:Web:" + lane
		)
		if sampled.action == "invalid":
			return sampled
		result.powers.append(
			source(
				player_id,
				owner.round_number(),
				{"lane": lane, "field_position": sampled.field_position}
			)
		)
	return result
