extends RefCounted

const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")


# Finite payload vocabulary only. The shared owner decides which are legal.
# Read this player's projection, never the opponent's hand/submission.
static func enumerate(owner, player_id: int) -> Dictionary:
	var view: Dictionary = owner.player_view(player_id, 0)
	if view.action == "invalid":
		return view
	var hand: Array = view.world.hand.duplicate()
	hand.sort()
	var targets: Array = []
	for entity in view.world.entities:
		if entity.kind == "castle" and entity.owner == 1 - player_id:
			targets.append(entity.id)
	targets.sort()
	var powers: Array = []
	for lane in ["Lord", "Castle"]:
		powers.append(_source(player_id, view.round, Gremory.PREDATOR, {"lane": lane}))
	var payments: Array = []
	for first in range(hand.size()):
		payments.append([hand[first]])
		for second in range(first + 1, hand.size()):
			var pair: Array = [hand[first], hand[second]]
			payments.append(pair)
			for target in targets:
				powers.append(
					_source(
						player_id,
						view.round,
						Gremory.RUIN,
						{"entity_id": target},
						{"discard_ids": pair}
					)
				)
	var orders: Array = []
	for cards in payments:
		for lane in ["Lord", "Castle"]:
			orders.append({"action": "Ward", "lane": lane, "card_ids": cards})
		for target in targets:
			orders.append(
				{"action": "Siege", "lane": "Castle", "target_id": target, "card_ids": cards}
			)
	return {"action": "candidate_vocabulary", "powers": powers, "orders": orders}


static func _source(
	player_id: int, round_number: int, power: String, target: Dictionary, cost: Dictionary = {}
) -> Dictionary:
	var rule: Dictionary = Gremory.rules()[power]
	return Decl.create(
		MatchOwner.declaration_id(player_id, round_number, 0),
		player_id,
		"Gremory",
		power,
		round_number,
		rule.fire_hook,
		round_number + int(rule.delay_rounds),
		0,
		"public",
		target,
		cost,
		{}
	)
