extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Stats = preload("res://Scripts/Sim/U13LordStats.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const VERSION: String = "U13_RESUMMON_V1"
# Existing U12 agency profile: raw card value, +3 Breach cost, Circle blood
# offering (-3 cost for 3 Integrity), up to four Threat of payment shortfall.
const COSTS: Dictionary = {"Orias": 6, "Deimos": 7, "Gremory": 6, "Humbaba": 6, "Kalligan": 4, "Odradek": 8, "Kroni": 5, "Valak": 6, "Kanifous": 4}
const MAX_RETURN_THREAT: int = 4


static func configure(world: Dictionary) -> void:
	world.data["resummon_profile"] = VERSION
	world.data["summon_orders"] = [null, null]
	world.data["summon_round"] = 0
	world.data["summon_counts"] = [1, 1]
	world.data["orias_marks"] = [null, null]


static func lord(world: Dictionary, pid: int) -> Dictionary:
	for row in world.entities.entities:
		if row.id == world.players[pid].lord_entity_id:
			return row
	return {}


static func strip(order: Dictionary) -> Dictionary:
	var result: Dictionary = order.duplicate(true)
	result.erase("summon")
	return result


static func choice_shape(choice) -> bool:
	return (
		typeof(choice) == TYPE_DICTIONARY
		and choice.size() == 1
		and typeof(choice.get("card_ids")) == TYPE_ARRAY
		and Data.is_data(choice)
	)


static func quote(world: Dictionary, pid: int, selected: Array) -> Dictionary:
	var actor: Dictionary = lord(world, pid)
	if actor.is_empty() or actor.attributes.alive:
		return Data.invalid("summon_requires_banished_lord")
	if not Cards.can_discard(world, pid, selected, selected.size()):
		return Data.invalid("summon_payment_unavailable")
	var cost: int = int(COSTS[actor.attributes.lord_id])
	if world.data.breach_lord == actor.attributes.lord_id:
		cost += 3
	var circle_id: String = ""
	# Stable slot order chooses one Circle; duplicate Castles do not stack.
	var circles: Array = []
	for row in world.entities.entities:
		if (
			row.kind == "castle"
			and row.owner == pid
			and row.attributes.get("castle_type") == "SummoningCircle"
			and Structures.operational(row)
			and row.attributes.integrity >= 3
		):
			circles.append(row)
	circles.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.attributes.castle_slot < b.attributes.castle_slot
	)
	if not circles.is_empty():
		circle_id = circles[0].id
		cost = maxi(0, cost - 3)
	var paid: int = 0
	for row in world.entities.entities:
		if row.id in selected:
			paid += int(row.attributes.value)
	var shortfall: int = maxi(0, cost - paid)
	var affordable: bool = (
		shortfall <= MAX_RETURN_THREAT
		and not (actor.attributes.lord_id == "Humbaba" and shortfall > 0)
	)
	var marked: bool = world.data.orias_marks[pid] != null
	return {
		"action": "legal" if affordable else "invalid",
		"reason": "" if affordable else "summon_payment_shortfall",
		"lord_id": actor.id,
		"cost": cost,
		"paid_value": paid,
		"circle_id": circle_id,
		"shortfall": shortfall,
		"return_threat": mini(MAX_RETURN_THREAT, shortfall + (1 if marked else 0)),
		"marked": marked
	}


static func validate_order(world: Dictionary, pid: int, order: Dictionary) -> Dictionary:
	if not order.has("summon"):
		return {"action": "legal"}
	if not choice_shape(order.summon):
		return Data.invalid("summon_choice_invalid")
	# A Lord absent at public submission cannot declare combat/powers this round.
	if order.has("action"):
		return Data.invalid("summon_combat_unavailable")
	var selected: Array = order.summon.card_ids
	var castle = order.get("castle_action", {})
	var moves = order.get("guard_moves", [])
	if (
		typeof(castle) != TYPE_DICTIONARY
		or typeof(castle.get("card_ids", [])) != TYPE_ARRAY
		or typeof(moves) != TYPE_ARRAY
	):
		return Data.invalid("summon_order_shape_invalid")
	var spent: Array = castle.get("card_ids", []).duplicate()
	for move in moves:
		if typeof(move) != TYPE_DICTIONARY:
			return Data.invalid("guard_moves_invalid")
		spent.append(move.get("card_id"))
	for id in selected:
		if id in spent:
			return Data.invalid("summon_card_already_reserved")
	return quote(world, pid, selected)


static func reserve(
	world: Dictionary, pid: int, order: Dictionary, round_number: int
) -> Dictionary:
	if world.data.summon_orders[pid] != null:
		return Data.invalid("summon_already_reserved")
	var checked: Dictionary = validate_order(world, pid, order)
	if checked.action == "invalid":
		return checked
	var record: Dictionary = {
		"round": round_number, "choice": order.get("summon", {}).duplicate(true), "quote": checked
	}
	world.data.summon_orders[pid] = record
	if order.has("summon"):
		var payment: Dictionary = Cards.discard(world, pid, order.summon.card_ids)
		if payment.action == "invalid":
			return payment
	return {"action": "resolved", "world": world, "events": []}


static func resolve(context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	if context.hook != Timeline.DEVELOPMENT or world.data.summon_round >= context.round:
		return Data.invalid("summon_phase_invalid")
	var entities = Ids.new()
	entities.restore(world.entities)
	var events: Array = []
	for pid in context.player_order:
		var record = world.data.summon_orders[pid]
		if record == null or record.round != context.round:
			return Data.invalid("summon_reservation_missing")
		if record.choice.is_empty():
			continue
		var actor: Dictionary = entities.get_entity(record.quote.lord_id)
		if actor.is_empty() or actor.attributes.alive:
			return Data.invalid("summon_reserved_lord_invalid")
		var circle_id: String = record.quote.circle_id
		if not circle_id.is_empty():
			var circle: Dictionary = entities.get_entity(circle_id)
			if circle.is_empty() or circle.attributes.integrity < 3:
				return Data.invalid("summon_circle_missing")
			var before: int = circle.attributes.integrity
			circle.attributes.integrity -= 3
			Structures.note_integrity_loss(circle, before, context.round)
			if circle.attributes.integrity == 0:
				circle.attributes.status = "defunct"
			entities.update(circle.id, pid, circle.attributes)
		actor.attributes.alive = true
		if actor.attributes.lord_id != "Humbaba":
			actor.attributes["threat"] = record.quote.return_threat
		entities.update(actor.id, pid, actor.attributes)
		world.data.summon_counts[pid] += 1
		# Accepted U13 addendum: a resummoned Lord adds one Neutral Tear.
		world.data.neutral_tears += 1
		events.append(
			event(
				"LORD_RESUMMONED",
				{
					"player_id": pid,
					"lord_id": actor.id,
					"round": context.round,
					"hook": context.hook,
					"card_ids": record.choice.card_ids,
					"cost": record.quote.cost,
					"return_threat": record.quote.return_threat,
					"marked": record.quote.marked
				}
			)
		)
		events.append(
			event(
				"NEUTRAL_TEAR_CREATED", {"amount": 1, "source": "Resummon", "round": context.round}
			)
		)
	world.entities = entities.snapshot()
	world.data.summon_round = context.round
	return {"action": "resolved", "world": world, "events": events}


static func event(kind: String, details: Dictionary) -> Dictionary:
	var fact: Dictionary = {"type": kind, "text": "", "data": details}
	return {"event": fact, "views": [fact, fact]}


static func valid(world: Dictionary) -> bool:
	if (
		world.data.get("resummon_profile") != VERSION
		or not Data.is_integer(world.data.get("summon_round"))
		or world.data.summon_round < 0
	):
		return false
	for key in ["summon_orders", "summon_counts", "orias_marks"]:
		if typeof(world.data.get(key)) != TYPE_ARRAY or world.data[key].size() != 2:
			return false
	for pid in [0, 1]:
		if not Data.is_integer(world.data.summon_counts[pid]) or world.data.summon_counts[pid] < 1:
			return false
		var mark = world.data.orias_marks[pid]
		if mark != null:
			if (
				typeof(mark) != TYPE_DICTIONARY
				or mark.size() != 4
				or mark.get("lord_id") != world.players[pid].lord_entity_id
				or mark.get("marked_by") != world.players[1 - pid].lord_entity_id
				or world.players[1 - pid].lord_id != "Orias"
				or not Data.is_integer(mark.get("round"))
				or mark.round < 1
			):
				return false
			var expected: String = Data.instance_id(
				"battle", str(mark.round), "hunt:%d:lord:%s" % [1 - pid, mark.lord_id]
			)
			if (
				mark.get("event_id") != expected
				or not world.data.get("battle_commands", {}).has(expected)
			):
				return false
		var record = world.data.summon_orders[pid]
		if (
			record != null
			and (
				typeof(record) != TYPE_DICTIONARY
				or record.size() != 3
				or not Data.is_integer(record.get("round"))
				or record.round < 1
				or typeof(record.get("quote")) != TYPE_DICTIONARY
				or typeof(record.get("choice")) != TYPE_DICTIONARY
				or (not record.choice.is_empty() and not choice_shape(record.choice))
			)
		):
			return false
	return true


static func snapshot_valid(context: Dictionary) -> bool:
	var world: Dictionary = context.world
	var current: int = context.round
	var cursor: int = context.next_hook_index
	if (
		world.data.summon_round
		!= (current if cursor > Timeline.hook_rank(Timeline.DEVELOPMENT) else current - 1)
	):
		return false
	for mark in world.data.orias_marks:
		if (
			mark != null
			and (
				mark.round > current
				or (
					mark.round == current
					and cursor <= Timeline.hook_rank(Timeline.COMBAT_RESOLUTION)
				)
			)
		):
			return false
	var pid: int = context.player_id
	var locked: bool = (
		cursor > Timeline.hook_rank(Timeline.SUBMISSION_LOCK)
		and cursor <= Timeline.hook_rank(Timeline.AFTERMATH)
	)
	var record = world.data.summon_orders[pid]
	if locked:
		if (
			record == null
			or record.round != current
			or record.choice != context.order.get("summon", {})
		):
			return false
		var quoted: Dictionary = validate_order(context.presentation_world, pid, context.order)
		if quoted.action == "invalid" or record.quote != quoted:
			return false
		for source in context.declarations:
			for id in record.choice.get("card_ids", []):
				if id in source.cost.get("discard_ids", []):
					return false
		if not record.choice.is_empty() and cursor <= Timeline.hook_rank(Timeline.DEVELOPMENT):
			for id in record.choice.card_ids:
				if id not in world.data.card_zones.discard:
					return false
		if not record.choice.is_empty() and cursor == Timeline.hook_rank(Timeline.DEVELOPMENT) + 1:
			var actor: Dictionary = lord(world, pid)
			if (
				not actor.attributes.alive
				or (
					actor.attributes.lord_id != "Humbaba"
					and actor.attributes.threat != record.quote.return_threat
				)
			):
				return false
	elif record != null:
		return false
	elif cursor <= Timeline.hook_rank(Timeline.SUBMISSION_LOCK):
		if validate_order(world, pid, context.order).action == "invalid":
			return false
	if cursor > Timeline.hook_rank(Timeline.PRESENT_PUBLIC_STATE):
		var expected: int = context.presentation_world.data.summon_counts[pid]
		if (
			locked
			and not record.choice.is_empty()
			and cursor > Timeline.hook_rank(Timeline.DEVELOPMENT)
		):
			expected += 1
		# Aftermath clears orders; accepted order remains in the match snapshot.
		if (
			not locked
			and cursor > Timeline.hook_rank(Timeline.AFTERMATH)
			and context.order.has("summon")
		):
			expected += 1
		if world.data.summon_counts[pid] != expected:
			return false
	return true


static func add_candidates(raw: Dictionary, world: Dictionary, pid: int) -> Dictionary:
	if raw.get("action") == "invalid" or lord(world, pid).attributes.alive:
		return raw
	var result: Dictionary = raw.duplicate(true)
	var hand: Array = world.data.card_zones.hands[pid].duplicate()
	hand.sort()
	# Bounded payment vocabulary, then the same whole-plan legality filter.
	for count in range(hand.size() + 1):
		var candidate: Dictionary = {"summon": {"card_ids": hand.slice(0, count)}}
		if validate_order(world, pid, candidate).action != "invalid":
			result.orders.append(candidate)
	return result
