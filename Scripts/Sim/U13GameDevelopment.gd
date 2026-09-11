extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Guards = preload("res://Scripts/Sim/U13GuardDeployment.gd")
const Castles = preload("res://Scripts/Sim/U13ConstructionCandidates.gd")
const VERSION: String = "U13_GAME_DEVELOPMENT_CHOICES_V1"


# Like U12 BotDeployDoctrine.reserved_cards, account for every competing use
# of the hand before proposing deployment. This is enumeration, not authority:
# callers must pass every proposed complete order to the U13 match validator.
static func reserved_cards(powers: Array, order: Dictionary) -> Array:
	var result: Array = []
	for source in powers:
		result.append_array(source.cost.get("discard_ids", []))
	result.append_array(order.get("rites", {}).get("invocation", {}).get("card_ids", []))
	result.append_array(order.get("card_ids", []))
	result.append_array(order.get("castle_action", {}).get("card_ids", []))
	result.append_array(order.get("summon", {}).get("card_ids", []))
	for move in order.get("guard_moves", []):
		result.append(move.card_id)
	return result


static func free_cards(view: Dictionary, powers: Array, order: Dictionary) -> Array:
	var reserved: Array = reserved_cards(powers, order)
	var result: Array = view.world.hand.filter(func(id): return id not in reserved)
	result.sort()
	return result


static func summon_orders(view: Dictionary, powers: Array, base: Dictionary) -> Array:
	var pid: int = view.world.viewer_id
	var actors: Array = view.world.entities.filter(func(e): return e.kind == "lord" and e.owner == pid)
	if actors.is_empty() or actors[0].attributes.alive or base.has("summon") or base.has("action"):
		return []
	var cards: Array = free_cards(view, powers, base)
	var result: Array = []
	# Both value directions cover economical and fully paid returns without
	# enumerating all 2^hand subsets. Humans may submit any legal exact payment.
	var values: Dictionary = {}
	for entity in view.world.entities:
		if entity.id in cards:
			values[entity.id] = int(entity.attributes.value)
	cards.sort_custom(func(a, b): return a < b if values[a] == values[b] else values[a] < values[b])
	for direction in [false, true]:
		var ordered: Array = cards.duplicate()
		if direction:
			ordered.reverse()
		for count in range(ordered.size() + 1):
			var order: Dictionary = base.duplicate(true)
			var payment: Array = ordered.slice(0, count)
			payment.sort()
			order["summon"] = {"card_ids": payment}
			if order not in result:
				result.append(order)
	return result


static func castle_orders(view: Dictionary, powers: Array, base: Dictionary) -> Array:
	if base.has("castle_action"):
		return []
	var available: Dictionary = view.duplicate(true)
	available.world.hand = free_cards(view, powers, base)
	var result: Array = []
	for choice in Castles.enumerate(available):
		var order: Dictionary = base.duplicate(true)
		order["castle_action"] = choice
		result.append(order)
	return result


# Append one move to an already complete order. Repeating this operation can
# fill both zones while respecting cards/cells used by earlier choices.
static func guard_orders(view: Dictionary, powers: Array, base: Dictionary) -> Array:
	var pid: int = view.world.viewer_id
	var moves: Array = base.get("guard_moves", [])
	if moves.size() >= int(view.world.guard_placement_limits[pid]):
		return []
	var occupied: Array = moves.duplicate(true)
	for entity in view.world.entities:
		if entity.kind == "card" and entity.owner == pid and entity.attributes.get("role") == "guard":
			occupied.append(entity.attributes)
	var result: Array = []
	for lane in Guards.LANES:
		for slot in range(Guards.SLOTS_PER_ZONE):
			if occupied.any(func(cell): return cell.lane == lane and cell.slot == slot):
				continue
			for id in free_cards(view, powers, base):
				var order: Dictionary = base.duplicate(true)
				order["guard_moves"] = moves.duplicate(true)
				order.guard_moves.append({"card_id": id, "lane": lane, "slot": slot})
				result.append(order)
	return result


# Bounded public-state samples. Exact physical IDs remain player-selectable.
static func rite_orders(view: Dictionary, powers: Array, base: Dictionary, stage: String) -> Array:
	const Rites = preload("res://Scripts/Sim/U13DominionRites.gd")
	var pid: int = view.world.viewer_id
	var result: Array = []
	var choices: Array = []
	if stage == "waiters":
		for lane in Guards.LANES:
			var bodies: Array = view.world.entities.filter(func(e): return e.kind == "marcher" and e.owner == pid and e.attributes.waiting and e.attributes.lane == lane)
			bodies.sort_custom(func(a, b): return a.id < b.id)
			var spends: Array = []
			for offset in range(0, bodies.size() - Rites.WAITERS_PER_TEAR + 1, Rites.WAITERS_PER_TEAR):
				var selected: Array = []
				for body in bodies.slice(offset, offset + Rites.WAITERS_PER_TEAR):
					selected.append(body.id)
				spends.append({"lane": lane, "marcher_ids": selected})
				choices.append({"waiter_spends": spends.duplicate(true)})
	elif stage == "invocation":
		if view.world.veil_total < Rites.INVOCATION_GATE or view.world.dominion_rites.invocation_rounds[pid] != 0:
			return []
		var available: Array = free_cards(view, powers, base)
		var cards: Array = view.world.entities.filter(func(e): return e.id in available)
		cards.sort_custom(func(a, b): return a.id < b.id if a.attributes.value == b.attributes.value else a.attributes.value < b.attributes.value)
		for descending in [false, true]:
			var ordered: Array = cards.duplicate()
			if descending:
				ordered.reverse()
			var payment: Array = []
			var total: int = 0
			for card in ordered:
				payment.append(card.id)
				total += int(card.attributes.value)
				if total >= Rites.INVOCATION_COST:
					choices.append({"invocation": {"card_ids": payment}})
					break
	elif stage == "profane_ruins":
		for castle in view.world.entities:
			if castle.kind == "castle" and castle.owner == pid and castle.attributes.status == "ruined":
				choices.append({"profane_ruins": {"castle_id": castle.id}})
	for choice in choices:
		var order: Dictionary = base.duplicate(true)
		var rites: Dictionary = order.get("rites", {}).duplicate(true)
		rites.merge(choice)
		order["rites"] = rites
		result.append(order)
	return result
