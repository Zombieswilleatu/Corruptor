class_name U13CardZones
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")


# Piles are bottom -> top; hand cards retain their physical entity identity.
static func valid(world: Dictionary) -> bool:
	var zones = world.data.get("card_zones")
	if typeof(zones) != TYPE_DICTIONARY or not Data.is_data(zones):
		return false
	if typeof(zones.get("hands")) != TYPE_ARRAY or zones.hands.size() != 2:
		return false
	if not Data.is_integer(zones.get("hand_limit")) or zones.hand_limit < 1:
		return false
	var entities = Ids.new()
	if entities.restore(world.entities).action == "invalid":
		return false
	var seen: Dictionary = {}
	var piles: Array = [zones.get("deck"), zones.get("discard"), zones.hands[0], zones.hands[1]]
	for index in range(piles.size()):
		if typeof(piles[index]) != TYPE_ARRAY:
			return false
		for card_id in piles[index]:
			if typeof(card_id) != TYPE_STRING or seen.has(card_id):
				return false
			var card: Dictionary = entities.get_entity(card_id)
			if (
				card.is_empty()
				or card.kind != "card"
				or card.attributes.get("role") == "guard"
				or card.owner != (index - 2 if index >= 2 else -1)
			):
				return false
			seen[card_id] = true
	for entity in world.entities.entities:
		if (
			entity.kind == "card"
			and entity.attributes.get("role") != "guard"
			and not seen.has(entity.id)
		):
			return false
	return true


static func can_discard(world: Dictionary, player_id: int, selected, count: int) -> bool:
	if (
		player_id not in [0, 1]
		or not valid(world)
		or typeof(selected) != TYPE_ARRAY
		or selected.size() != count
	):
		return false
	var seen: Dictionary = {}
	for card_id in selected:
		if (
			typeof(card_id) != TYPE_STRING
			or seen.has(card_id)
			or card_id not in world.data.card_zones.hands[player_id]
		):
			return false
		seen[card_id] = true
	return true


static func discard(world: Dictionary, player_id: int, selected: Array) -> Dictionary:
	if not can_discard(world, player_id, selected, selected.size()):
		return Data.invalid("discard_payment_invalid")
	var entities = Ids.new()
	entities.restore(world.entities)
	for card_id in selected:
		world.data.card_zones.hands[player_id].erase(card_id)
		world.data.card_zones.discard.append(card_id)
		var card: Dictionary = entities.get_entity(card_id)
		entities.update(card_id, -1, card.attributes)
	world.entities = entities.snapshot()
	return {"action": "resolved"}


static func draw(
	world: Dictionary,
	player_id: int,
	seed_value: String,
	event_id: String,
	from_discard: bool = false
) -> Dictionary:
	if player_id not in [0, 1] or not valid(world):
		return Data.invalid("card_draw_world_invalid")
	var zones: Dictionary = world.data.card_zones
	# Preserve baseline recycle-before-hand-limit semantics. Sifting never recycles.
	if not from_discard and zones.deck.is_empty() and not zones.discard.is_empty():
		var shuffled: Array = zones.discard.duplicate()
		for index in range(shuffled.size() - 1, 0, -1):
			var roll: Dictionary = Rng.draw(
				seed_value, event_id, "DISCARD_RECYCLE", index, index + 1
			)
			if roll.action == "invalid":
				return roll
			var swap = shuffled[index]
			shuffled[index] = shuffled[roll.value]
			shuffled[roll.value] = swap
		zones.deck = shuffled
		zones.discard.clear()
	var pile: Array = zones.discard if from_discard else zones.deck
	if zones.hands[player_id].size() >= zones.hand_limit or pile.is_empty():
		return {"action": "draw", "drawn": false, "player_id": player_id}
	var card_id: String = pile.pop_back()
	zones.hands[player_id].append(card_id)
	var entities = Ids.new()
	entities.restore(world.entities)
	var card: Dictionary = entities.get_entity(card_id)
	entities.update(card_id, player_id, card.attributes)
	world.entities = entities.snapshot()
	return {"action": "draw", "drawn": true, "player_id": player_id, "card_id": card_id}
