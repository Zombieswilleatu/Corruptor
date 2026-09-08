extends RefCounted


# Finite payment vocabulary: free build, every single card/pair, optional Repair
# token. All legality/costs still belong to the complete-plan preview.
static func enumerate(view: Dictionary) -> Array:
	var cards: Array = view.world.hand.duplicate()
	cards.sort()
	var payments: Array = [[]]
	for first in range(cards.size()):
		payments.append([cards[first]])
		for second in range(first + 1, cards.size()):
			payments.append([cards[first], cards[second]])
	var result: Array = []
	for castle in view.world.entities:
		if castle.kind != "castle" or castle.owner != _player_id(view):
			continue
		result.append(
			{
				"action": "Activate",
				"target_id": castle.id,
				"card_ids": [],
				"use_repair_token": false
			}
		)
		for payment in payments:
			result.append(
				{
					"action": "Construct",
					"target_id": castle.id,
					"card_ids": payment,
					"use_repair_token": false
				}
			)
			for token in [false, true]:
				result.append(
					{
						"action": "Repair",
						"target_id": castle.id,
						"card_ids": payment,
						"use_repair_token": token
					}
				)
	return result


static func _player_id(view: Dictionary) -> int:
	# The projection explicitly supplies this identity; never infer from Hand.
	return int(view.world.viewer_id)
