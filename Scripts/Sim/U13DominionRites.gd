extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Guards = preload("res://Scripts/Sim/U13GuardDeployment.gd")
const VERSION: String = "U13_DOMINION_RITES_V1"
const WAITERS_PER_TEAR: int = 5
const INVOCATION_GATE: int = 7
const INVOCATION_COST: int = 11
const RUINS_REQUIRED: int = 2
const RUINS_SOUL_COST: int = 2


static func configure(world: Dictionary) -> void:
	world.data["dominion_rites"] = {"version": VERSION, "resolved_round": 0, "orders": [null, null], "invocation_rounds": [0, 0]}


static func strip(order: Dictionary) -> Dictionary:
	var result: Dictionary = order.duplicate(true)
	result.erase("rites")
	return result


static func ids_shape(raw, count: int = -1) -> bool:
	if typeof(raw) != TYPE_ARRAY or (count >= 0 and raw.size() != count):
		return false
	var seen: Dictionary = {}
	for id in raw:
		if typeof(id) != TYPE_STRING or id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true


static func shape(choice) -> bool:
	if typeof(choice) != TYPE_DICTIONARY or not Data.is_data(choice):
		return false
	for key in choice:
		if key not in ["waiter_spends", "invocation", "profane_ruins"]:
			return false
	if choice.has("invocation"):
		var invocation = choice.invocation
		if typeof(invocation) != TYPE_DICTIONARY or invocation.size() != 1 or not ids_shape(invocation.get("card_ids")):
			return false
	if choice.has("profane_ruins"):
		var profane = choice.profane_ruins
		if typeof(profane) != TYPE_DICTIONARY or profane.size() != 1 or typeof(profane.get("castle_id")) != TYPE_STRING or profane.castle_id.is_empty():
			return false
	var spends = choice.get("waiter_spends", [])
	if typeof(spends) != TYPE_ARRAY:
		return false
	var used: Array = []
	for spend in spends:
		if typeof(spend) != TYPE_DICTIONARY or spend.size() != 2 or spend.get("lane") not in Marching.LANES or not ids_shape(spend.get("marcher_ids"), WAITERS_PER_TEAR):
			return false
		for id in spend.marcher_ids:
			if id in used:
				return false
			used.append(id)
	return true


static func valid(world: Dictionary) -> bool:
	var state = world.data.get("dominion_rites")
	if typeof(state) != TYPE_DICTIONARY or state.size() != 4 or state.get("version") != VERSION or not Data.is_integer(state.get("resolved_round")) or state.resolved_round < 0:
		return false
	for key in ["orders", "invocation_rounds"]:
		if typeof(state.get(key)) != TYPE_ARRAY or state[key].size() != 2:
			return false
	for pid in [0, 1]:
		if not Data.is_integer(state.invocation_rounds[pid]) or state.invocation_rounds[pid] < 0 or state.invocation_rounds[pid] > state.resolved_round:
			return false
		var record = state.orders[pid]
		if record != null and (typeof(record) != TYPE_DICTIONARY or record.size() != 2 or not Data.is_integer(record.get("round")) or record.round < 1 or not shape(record.get("choice"))):
			return false
	return true


static func veil(world: Dictionary) -> int:
	return int(world.data.neutral_tears + world.players[0].resources.personal_tears + world.players[1].resources.personal_tears)


static func validate(world: Dictionary, pid: int, order: Dictionary) -> Dictionary:
	var choice = order.get("rites", {})
	if not shape(choice):
		return Data.invalid("rites_shape_invalid")
	if choice.is_empty():
		return {"action": "legal"}
	var registry = Ids.new()
	registry.restore(world.entities)
	for spend in choice.get("waiter_spends", []):
		for id in spend.marcher_ids:
			var body: Dictionary = registry.get_entity(id)
			if body.is_empty() or body.kind != "marcher" or body.owner != pid or not body.attributes.waiting or body.attributes.hp <= 0 or body.attributes.lane != spend.lane:
				return Data.invalid("rite_waiter_unavailable")
	if choice.has("invocation"):
		if world.data.dominion_rites.invocation_rounds[pid] != 0:
			return Data.invalid("invocation_already_used")
		if veil(world) < INVOCATION_GATE:
			return Data.invalid("invocation_veil_below_gate")
		var payment: Array = choice.invocation.card_ids
		if not Cards.can_discard(world, pid, payment, payment.size()):
			return Data.invalid("invocation_cards_unavailable")
		var total: int = 0
		for id in payment:
			total += int(registry.get_entity(id).attributes.value)
		if total < INVOCATION_COST:
			return Data.invalid("invocation_insufficient_payment")
		var reserved: Array = order.get("card_ids", []).duplicate() if typeof(order.get("card_ids", [])) == TYPE_ARRAY else []
		for key in ["castle_action", "summon"]:
			var other = order.get(key, {})
			if typeof(other) == TYPE_DICTIONARY and typeof(other.get("card_ids", [])) == TYPE_ARRAY:
				reserved.append_array(other.get("card_ids", []))
		if typeof(order.get("guard_moves", [])) == TYPE_ARRAY:
			for move in order.get("guard_moves", []):
				if typeof(move) == TYPE_DICTIONARY:
					reserved.append(move.get("card_id"))
		for id in payment:
			if id in reserved:
				return Data.invalid("rite_card_already_reserved")
	if choice.has("profane_ruins"):
		var target: Dictionary = registry.get_entity(choice.profane_ruins.castle_id)
		var ruins: Array = world.entities.entities.filter(func(e): return e.kind == "castle" and e.owner == pid and e.attributes.status == "ruined")
		if ruins.size() < RUINS_REQUIRED or target.is_empty() or target.kind != "castle" or target.owner != pid or target.attributes.status != "ruined":
			return Data.invalid("profane_ruins_target_unavailable")
		if world.players[pid].resources.souls < RUINS_SOUL_COST:
			return Data.invalid("profane_ruins_insufficient_souls")
		var castle = order.get("castle_action", {})
		if typeof(castle) == TYPE_DICTIONARY and castle.get("target_id") == target.id:
			return Data.invalid("rite_castle_already_reserved")
	return {"action": "legal"}


# Payments use the same staged hand/resources as powers and other Development.
# Marchers remain on the board until Development; no combat occurs before then.
static func pay(world: Dictionary, pid: int, choice: Dictionary) -> void:
	if choice.has("invocation"):
		Cards.discard(world, pid, choice.invocation.card_ids)
	if choice.has("profane_ruins"):
		world.players[pid].resources.souls -= RUINS_SOUL_COST


static func reserve(context: Dictionary) -> Dictionary:
	var checked: Dictionary = validate(context.world, context.player_id, context.order)
	if checked.action == "invalid":
		return checked
	var world: Dictionary = context.world.duplicate(true)
	var pid: int = context.player_id
	if world.data.dominion_rites.orders[pid] != null:
		return Data.invalid("rites_already_reserved")
	var choice: Dictionary = context.order.get("rites", {}).duplicate(true)
	pay(world, pid, choice)
	world.data.dominion_rites.orders[pid] = {"round": context.round, "choice": choice}
	return {"action": "resolved", "world": world, "events": []}


static func resolve(context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	var state: Dictionary = world.data.dominion_rites
	if context.hook != Timeline.DEVELOPMENT or state.resolved_round != context.round - 1:
		return Data.invalid("rites_resolution_clock_invalid")
	var registry = Ids.new()
	registry.restore(world.entities)
	var events: Array = []
	for pid in context.player_order:
		var record = state.orders[pid]
		if record == null or record.round != context.round:
			return Data.invalid("rites_reservation_missing")
		var choice: Dictionary = record.choice
		for spend in choice.get("waiter_spends", []):
			for id in spend.marcher_ids:
				var body: Dictionary = registry.get_entity(id)
				if body.is_empty() or body.owner != pid or not body.attributes.waiting or body.attributes.lane != spend.lane:
					return Data.invalid("reserved_waiter_missing")
				registry.retire(id)
			_gain(world, events, pid, context.round, "waiters", {"lane": spend.lane, "marcher_ids": spend.marcher_ids})
		if choice.has("invocation"):
			state.invocation_rounds[pid] = context.round
			_gain(world, events, pid, context.round, "invocation", {"card_ids": choice.invocation.card_ids})
		if choice.has("profane_ruins"):
			var castle: Dictionary = registry.get_entity(choice.profane_ruins.castle_id)
			if castle.is_empty() or castle.attributes.status != "ruined":
				return Data.invalid("reserved_ruin_missing")
			castle.attributes.status = "profaned"
			castle.attributes.artillery_target = ""
			registry.update(castle.id, pid, castle.attributes)
			_gain(world, events, pid, context.round, "profane_ruins", {"castle_id": castle.id, "soul_cost": RUINS_SOUL_COST})
	state.resolved_round = context.round
	world.entities = registry.snapshot()
	return {"action": "resolved", "world": world, "events": events}


static func _gain(world: Dictionary, events: Array, pid: int, round_number: int, source: String, details: Dictionary) -> void:
	world.players[pid].resources.personal_tears += 1
	var payload: Dictionary = details.duplicate(true)
	payload.merge({"player_id": pid, "round": round_number, "source": source, "amount": 1, "veil_after": veil(world)})
	events.append(Marching.public_event("PERSONAL_TEAR_CREATED", payload))


static func snapshot_valid(context: Dictionary) -> bool:
	var state: Dictionary = context.world.data.dominion_rites
	var cursor: int = context.next_hook_index
	var pid: int = context.player_id
	var current: int = context.round
	if state.resolved_round != current - (1 if cursor <= Timeline.hook_rank(Timeline.DEVELOPMENT) else 0):
		return false
	var choice = context.order.get("rites", {})
	if not shape(choice):
		return false
	var locked: bool = cursor > Timeline.hook_rank(Timeline.SUBMISSION_LOCK) and cursor <= Timeline.hook_rank(Timeline.AFTERMATH)
	var record = state.orders[pid]
	if cursor > Timeline.hook_rank(Timeline.PRESENT_PUBLIC_STATE):
		var expected_use: int = context.presentation_world.data.dominion_rites.invocation_rounds[pid]
		if cursor > Timeline.hook_rank(Timeline.DEVELOPMENT) and choice.has("invocation"):
			expected_use = current
		if state.invocation_rounds[pid] != expected_use:
			return false
	if not locked:
		return record == null and (cursor > Timeline.hook_rank(Timeline.AFTERMATH) or validate(context.world, pid, context.order).action != "invalid")
	if record == null or record.round != current or record.choice != choice or validate(context.presentation_world, pid, context.order).action == "invalid":
		return false
	for source in context.declarations:
		for id in choice.get("invocation", {}).get("card_ids", []):
			if id in source.cost.get("discard_ids", []):
				return false
	if cursor <= Timeline.hook_rank(Timeline.DEVELOPMENT):
		for id in choice.get("invocation", {}).get("card_ids", []):
			if id not in context.world.data.card_zones.discard:
				return false
		if choice.has("profane_ruins"):
			var expected_souls: int = context.presentation_world.players[pid].resources.souls - RUINS_SOUL_COST
			for source in context.declarations:
				expected_souls -= int(source.cost.get("souls", 0))
			if context.world.players[pid].resources.souls != expected_souls:
				return false
	var after: bool = cursor > Timeline.hook_rank(Timeline.DEVELOPMENT)
	if choice.has("invocation") and state.invocation_rounds[pid] != (current if after else 0):
		return false
	var registry = Ids.new()
	registry.restore(context.world.entities)
	for spend in choice.get("waiter_spends", []):
		for id in spend.marcher_ids:
			var body: Dictionary = registry.get_entity(id)
			if after:
				if not body.is_empty() or id not in context.world.entities.used_ids:
					return false
			elif body.is_empty() or body.owner != pid or not body.attributes.waiting or body.attributes.lane != spend.lane:
				return false
	if choice.has("profane_ruins"):
		var castle: Dictionary = registry.get_entity(choice.profane_ruins.castle_id)
		if castle.is_empty() or castle.attributes.status != ("profaned" if after else "ruined"):
			return false
	return true


static func legal_orders(context: Dictionary) -> Dictionary:
	# Group by rite payment so the existing exact bulk Development predicate is
	# still run once per shared hand, not once for every guard placement.
	var groups: Dictionary = {}
	for index in range(context.orders.size()):
		var order = context.orders[index]
		if typeof(order) != TYPE_DICTIONARY or not Data.is_data(order) or validate(context.world, context.player_id, order).action == "invalid":
			continue
		var key: String = JSON.stringify(order.get("rites", {}), "", true)
		if not groups.has(key):
			groups[key] = {"choice": order.get("rites", {}), "orders": [], "indices": []}
		groups[key].orders.append(strip(order))
		groups[key].indices.append(index)
	var indices: Array = []
	for group in groups.values():
		var world: Dictionary = context.world.duplicate(true)
		pay(world, context.player_id, group.choice)
		var ordinary: Dictionary = context.duplicate()
		ordinary.world = world
		ordinary.orders = group.orders
		var checked: Dictionary = Guards.legal_orders(ordinary)
		if checked.action == "invalid":
			return checked
		for index in checked.indices:
			indices.append(group.indices[index])
	indices.sort()
	return {"action": "legal_orders", "indices": indices}
