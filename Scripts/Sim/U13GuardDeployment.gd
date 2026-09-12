extends RefCounted

const Resummon = preload("res://Scripts/Sim/U13Resummoning.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Construction = preload("res://Scripts/Sim/U13Construction.gd")
const SnareCost = preload("res://Scripts/Sim/U13SnareCost.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Stats = preload("res://Scripts/Sim/U13LordStats.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const BREACH_NAME: String = "Entanglement"
const VERSION: String = "U13_HAND_GUARD_DEPLOYMENT_V1"
const SLOTS_PER_ZONE: int = 3
const LANES: Array = ["Lord", "Castle"]


static func configure(world: Dictionary) -> void:
	world.data["guard_deployment_profile"] = VERSION
	world.data["guard_deployment_round"] = 0
	world.data["guard_public_round"] = 0
	world.data["guard_public_limits"] = [6, 6]
	world.data["guard_orders"] = [null, null]
	world.data["snare_rounds"] = [0, 0]


static func enabled(world: Dictionary) -> bool:
	return world.data.get("guard_deployment_profile") == VERSION


static func valid(world: Dictionary) -> bool:
	if not enabled(world) or not Cards.valid(world):
		return false
	for key in ["guard_deployment_round", "guard_public_round"]:
		if not Data.is_integer(world.data.get(key)) or world.data[key] < 0:
			return false
	for key in ["guard_public_limits", "guard_orders", "snare_rounds"]:
		if typeof(world.data.get(key)) != TYPE_ARRAY or world.data[key].size() != 2:
			return false
	for pid in [0, 1]:
		var limit = world.data.guard_public_limits[pid]
		var snare = world.data.snare_rounds[pid]
		if (
			not Data.is_integer(limit)
			or limit not in [1, 2, 6]
			or not Data.is_integer(snare)
			or snare < 0
		):
			return false
		var record = world.data.guard_orders[pid]
		if (
			record != null
			and (
				typeof(record) != TYPE_DICTIONARY
				or record.size() != 2
				or not Data.is_integer(record.get("round"))
				or record.round < 1
				or not moves_shape(record.get("moves"))
			)
		):
			return false
	var occupied: Dictionary = {}
	for entity in world.entities.entities:
		if entity.kind == "card" and entity.attributes.get("role") == "guard":
			var slot = entity.attributes.get("slot")
			if (
				not Data.is_integer(slot)
				or slot < 0
				or slot >= SLOTS_PER_ZONE
				or entity.attributes.get("lane") not in LANES
			):
				return false
			var cell: String = str(entity.owner) + ":" + entity.attributes.lane + ":" + str(slot)
			if occupied.has(cell):
				return false
			occupied[cell] = true
	return true


static func moves_shape(moves) -> bool:
	if typeof(moves) != TYPE_ARRAY or moves.size() > 2 * SLOTS_PER_ZONE:
		return false
	var cards: Dictionary = {}
	var slots: Dictionary = {}
	for move in moves:
		if (
			typeof(move) != TYPE_DICTIONARY
			or move.size() != 3
			or typeof(move.get("card_id")) != TYPE_STRING
			or move.card_id.is_empty()
			or move.get("lane") not in LANES
			or not Data.is_integer(move.get("slot"))
			or move.slot < 0
			or move.slot >= SLOTS_PER_ZONE
		):
			return false
		var key: String = move.lane + ":" + str(int(move.slot))
		if cards.has(move.card_id) or slots.has(key):
			return false
		cards[move.card_id] = true
		slots[key] = true
	return true


static func strip_order(order: Dictionary) -> Dictionary:
	var stripped: Dictionary = order.duplicate(true)
	stripped.erase("guard_moves")
	stripped.erase("summon")
	return stripped


# Evaluate only at public presentation, after scheduled powers and upkeep.
# A Threat payment or Breach change later in this round cannot alter this cap.
static func limit_for(world: Dictionary, pid: int, round_number: int) -> int:
	var cap: int = 2 * SLOTS_PER_ZONE
	if world.data.snare_rounds[pid] == round_number:
		cap = 1
	if world.data.breach_lord == "Orias":
		for entity in world.entities.entities:
			if entity.id == world.players[pid].lord_entity_id and Stats.threat_at_least(entity, 2):
				cap = mini(cap, 2)
	return cap


static func capture_limits(world: Dictionary, round_number: int) -> void:
	world.data.guard_public_limits = [
		limit_for(world, 0, round_number), limit_for(world, 1, round_number)
	]
	world.data.guard_public_round = round_number


static func validate_order(
	world: Dictionary, pid: int, order: Dictionary, round_number: int
) -> Dictionary:
	var moves = order.get("guard_moves", [])
	if not moves_shape(moves):
		return Data.invalid("guard_moves_invalid")
	if (
		world.data.guard_public_round != round_number
		or moves.size() > world.data.guard_public_limits[pid]
	):
		return Data.invalid("guard_public_limit_exceeded")
	var castle = order.get("castle_action", {})
	if not Construction.choice_shape(castle):
		return Data.invalid("castle_action_shape_invalid")
	# U12 production allows Repair and deployment; only shared card costs conflict.
	if typeof(order.get("card_ids", [])) != TYPE_ARRAY:
		return Data.invalid("combat_order_shape_invalid")
	if world.data.get("resummon_profile") == Resummon.VERSION:
		var summon_check: Dictionary = Resummon.validate_order(world, pid, order)
		if summon_check.action == "invalid":
			return summon_check
	var spent: Array = order.get("card_ids", []).duplicate()
	spent.append_array(castle.get("card_ids", []))
	var hand: Array = world.data.card_zones.hands[pid]
	for move in moves:
		if move.card_id not in hand or move.card_id in spent:
			return Data.invalid("guard_card_unavailable")
		for entity in world.entities.entities:
			if (
				entity.kind == "card"
				and entity.owner == pid
				and entity.attributes.get("role") == "guard"
				and entity.attributes.lane == move.lane
				and entity.attributes.slot == move.slot
			):
				return Data.invalid("guard_slot_occupied")
	return {"action": "legal"}


static func reserve(
	world: Dictionary, pid: int, order: Dictionary, round_number: int
) -> Dictionary:
	if world.data.guard_orders[pid] != null:
		return Data.invalid("guard_order_already_reserved")
	var checked: Dictionary = validate_order(world, pid, order, round_number)
	if checked.action == "invalid":
		return checked
	var moves: Array = order.get("guard_moves", []).duplicate(true)
	world.data.guard_orders[pid] = {"round": round_number, "moves": moves}
	# Cards remain physically in Hand until Development. Their IDs cannot also
	# fund a power, Castle action or combat order; the whole joint lock is atomic.
	var events: Array = []
	if not moves.is_empty():
		var event: Dictionary = {
			"type": "GUARDS_SEALED",
			"text": "",
			"data": {"player_id": pid, "round": round_number, "moves": moves}
		}
		var views: Array = [null, null]
		views[pid] = event
		events.append({"event": event, "views": views})
	return {"action": "resolved", "world": world, "events": events}


static func resolve(context: Dictionary) -> Dictionary:
	if (
		context.hook != Timeline.DEVELOPMENT
		or context.world.data.guard_deployment_round >= context.round
	):
		return Data.invalid("guard_development_timing_invalid")
	var world: Dictionary = context.world.duplicate(true)
	var entities = Ids.new()
	entities.restore(world.entities)
	var events: Array = []
	for pid in context.player_order:
		var record = world.data.guard_orders[pid]
		if record == null or record.round != context.round:
			return Data.invalid("guard_order_missing")
		for move in record.moves:
			var card: Dictionary = entities.get_entity(move.card_id)
			if (
				card.is_empty()
				or card.id not in world.data.card_zones.hands[pid]
				or card.owner != pid
			):
				return Data.invalid("reserved_guard_missing")
			world.data.card_zones.hands[pid].erase(card.id)
			card.attributes["role"] = "guard"
			card.attributes["lane"] = move.lane
			card.attributes["slot"] = int(move.slot)
			entities.update(card.id, pid, card.attributes)
			var event: Dictionary = {
				"type": "GUARD_DEPLOYED",
				"text": "",
				"data":
				{
					"player_id": pid,
					"card_id": card.id,
					"lane": move.lane,
					"slot": move.slot,
					"round": context.round,
					"hook": context.hook
				}
			}
			events.append({"event": event, "views": [event, event]})
	world.entities = entities.snapshot()
	world.data.guard_deployment_round = context.round
	return {"action": "resolved", "world": world, "events": events}


static func snapshot_valid(context: Dictionary) -> bool:
	var world: Dictionary = context.world
	var cursor: int = context.next_hook_index
	var current: int = context.round
	var pid: int = context.player_id
	if (
		world.data.guard_deployment_round
		!= (current if cursor > Timeline.hook_rank(Timeline.DEVELOPMENT) else current - 1)
	):
		return false
	if (
		world.data.guard_public_round
		!= (current if cursor > Timeline.hook_rank(Timeline.PRESENT_PUBLIC_STATE) else current - 1)
	):
		return false
	for snare_round in world.data.snare_rounds:
		if snare_round > current:
			return false
	if cursor > Timeline.hook_rank(Timeline.PRESENT_PUBLIC_STATE):
		if world.data.snare_rounds != context.presentation_world.data.snare_rounds:
			return false
		for owner_id in [0, 1]:
			if (
				world.data.guard_public_limits[owner_id]
				!= limit_for(context.presentation_world, owner_id, current)
			):
				return false
	var moves = context.order.get("guard_moves", [])
	if not moves_shape(moves):
		return false
	var locked: bool = (
		cursor > Timeline.hook_rank(Timeline.SUBMISSION_LOCK)
		and cursor <= Timeline.hook_rank(Timeline.AFTERMATH)
	)
	var record = world.data.guard_orders[pid]
	if locked:
		if (
			record == null
			or record.round != current
			or record.moves != moves
			or (
				validate_order(context.presentation_world, pid, context.order, current).action
				== "invalid"
			)
		):
			return false
		for move in moves:
			for source in context.declarations:
				if move.card_id in source.cost.get("discard_ids", []):
					return false
			if (
				cursor <= Timeline.hook_rank(Timeline.DEVELOPMENT)
				and move.card_id not in world.data.card_zones.hands[pid]
			):
				return false
			if cursor == Timeline.hook_rank(Timeline.DEVELOPMENT) + 1:
				var found: bool = false
				for entity in world.entities.entities:
					if entity.id == move.card_id:
						found = (
							entity.owner == pid
							and entity.attributes.get("role") == "guard"
							and entity.attributes.get("lane") == move.lane
							and entity.attributes.get("slot") == move.slot
						)
				if not found:
					return false
	elif record != null:
		return false
	elif cursor <= Timeline.hook_rank(Timeline.SUBMISSION_LOCK) and not moves.is_empty():
		if validate_order(world, pid, context.order, current).action == "invalid":
			return false
	return true


# Powers already passed shared legality and paid their card costs on this owned
# baseline. Reuse Construction's exact bulk predicates for the stripped orders.
static func legal_orders(context: Dictionary) -> Dictionary:
	var trimmed: Dictionary = context.duplicate(true)
	var allowed: Dictionary = {}
	for index in range(context.orders.size()):
		var order = context.orders[index]
		if (
			typeof(order) == TYPE_DICTIONARY
			and Data.is_data(order)
			and (
				(
					validate_order(
						context.world,
						context.player_id,
						order,
						context.world.data.guard_public_round
					)
					. action
				)
				!= "invalid"
			)
		):
			allowed[index] = true
		trimmed.orders[index] = strip_order(order) if typeof(order) == TYPE_DICTIONARY else order
	# Submission reserves guards before paying Snare, then admits Castle actions.
	# Stage that same payment once for the whole isolated domain: Blood Conduit
	# can make a previously repairable Circle locked, or damage a full Circle.
	for raw_source in context.get("declarations", []):
		var source: Dictionary = Data.declaration_copy(raw_source)
		if source.get("power_id") == "Snare":
			var paid: Dictionary = SnareCost.pay(trimmed.world, source, context.get("round", context.world.data.guard_public_round))
			if paid.action == "invalid":
				return paid
			trimmed.world = paid.world
	var result: Dictionary = Construction.legal_orders(trimmed)
	if result.action == "invalid":
		return result
	result.indices = result.indices.filter(func(index: int) -> bool: return allowed.has(index))
	return result


# One bounded sample per existing combat order, keyed by its content rather
# than list position. Central legality filters joint power/Castle payments.
static func add_candidates(raw: Dictionary, view: Dictionary, seed_value: String) -> Dictionary:
	if raw.get("action") == "invalid":
		return raw
	var result: Dictionary = raw.duplicate(true)
	var pid: int = view.world.viewer_id
	var cells: Array = []
	for lane in LANES:
		for slot in range(SLOTS_PER_ZONE):
			var occupied: bool = false
			for entity in view.world.entities:
				if (
					entity.kind == "card"
					and entity.owner == pid
					and entity.attributes.get("role") == "guard"
					and entity.attributes.lane == lane
					and entity.attributes.slot == slot
				):
					occupied = true
			if not occupied:
				cells.append({"lane": lane, "slot": slot})
	var bases: Array = raw.orders.duplicate(true)
	if {} not in bases:
		bases.append({})
	for order in bases:
		var cards: Array = view.world.hand.duplicate()
		cards.sort()
		for used in order.get("card_ids", []):
			cards.erase(used)
		var available: Array = cells.duplicate(true)
		var maximum: int = mini(
			int(view.world.guard_placement_limits[pid]), mini(cards.size(), available.size())
		)
		if maximum == 0:
			continue
		var identity: String = Data.instance_id(
			"guard_candidate", "%d:%d" % [view.round, pid], JSON.stringify(order, "", true)
		)
		var count_roll: Dictionary = Rng.draw(seed_value, identity, "BOT_GUARD_AMOUNT", 0, maximum)
		if count_roll.action == "invalid":
			return count_roll
		var moves: Array = []
		for index in range(1 + int(count_roll.value)):
			var card_roll: Dictionary = Rng.draw(
				seed_value, identity, "BOT_GUARD_CARD", index, cards.size()
			)
			var cell_roll: Dictionary = Rng.draw(
				seed_value, identity, "BOT_GUARD_TARGET", index, available.size()
			)
			if card_roll.action == "invalid" or cell_roll.action == "invalid":
				return Data.invalid("guard_candidate_rng_invalid")
			var move: Dictionary = available.pop_at(cell_roll.value)
			move["card_id"] = cards.pop_at(card_roll.value)
			moves.append(move)
		var candidate: Dictionary = order.duplicate(true)
		candidate["guard_moves"] = moves
		result.orders.append(candidate)
	return result
