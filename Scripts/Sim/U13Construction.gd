extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const VERSION: String = "U13_CASTLE_DEVELOPMENT_V2"
const PASSIVE: int = 3
const CARD_VALUE_PER_INTEGRITY: int = 3
const REPAIR_TOKEN: int = 3


static func enabled(world: Dictionary) -> bool:
	return world.data.get("construction_profile", "") == VERSION


static func valid(world: Dictionary) -> bool:
	if not enabled(world) or not Structures.valid(world):
		return false
	for field in ["construction_round"]:
		if not Data.is_integer(world.data.get(field)) or world.data[field] < 0:
			return false
	for field in ["castle_orders", "construction_targets"]:
		if typeof(world.data.get(field)) != TYPE_ARRAY or world.data[field].size() != 2:
			return false
	var entities = Ids.new()
	entities.restore(world.entities)
	for player_id in [0, 1]:
		var tokens = world.players[player_id].resources.get("repair_tokens")
		if not Data.is_integer(tokens) or tokens < 0:
			return false
		var target = world.data.construction_targets[player_id]
		if typeof(target) != TYPE_STRING:
			return false
		if not target.is_empty():
			var castle: Dictionary = entities.get_entity(target)
			if (
				castle.is_empty()
				or castle.kind != "castle"
				or castle.owner != player_id
				or castle.attributes.get("construction_state") != "building"
				or castle.attributes.status in ["ruined", "profaned"]
			):
				return false
		var record = world.data.castle_orders[player_id]
		if record != null and not record_shape(record):
			return false
	for castle in world.entities.entities:
		if castle.kind != "castle":
			continue
		var lock_round = castle.attributes.get("repair_lock_until_round", 0)
		if not Data.is_integer(lock_round) or lock_round < 0:
			return false
		var state = castle.attributes.get("construction_state")
		if state not in ["unbuilt", "building", "ready", "active"]:
			return false
		if state in ["building", "ready"] and castle.attributes.status != "standing":
			return false
		if (
			state != "active"
			and (not castle.attributes.artillery_target.is_empty() or lock_round != 0)
		):
			return false
		if (
			state == "unbuilt"
			and (castle.attributes.status != "defunct" or castle.attributes.integrity != 0)
		):
			return false
	return true


static func choice_shape(choice) -> bool:
	if typeof(choice) != TYPE_DICTIONARY:
		return false
	if choice.is_empty():
		return true
	if choice.keys().size() != 4 or choice.get("action") not in ["Construct", "Repair", "Activate"]:
		return false
	if (
		typeof(choice.get("target_id")) != TYPE_STRING
		or choice.target_id.is_empty()
		or typeof(choice.get("card_ids")) != TYPE_ARRAY
		or typeof(choice.get("use_repair_token")) != TYPE_BOOL
	):
		return false
	var seen: Dictionary = {}
	for card_id in choice.card_ids:
		if typeof(card_id) != TYPE_STRING or card_id.is_empty() or seen.has(card_id):
			return false
		seen[card_id] = true
	return true


static func record_shape(record) -> bool:
	return (
		typeof(record) == TYPE_DICTIONARY
		and record.keys().size() == 4
		and choice_shape(record.get("choice"))
		and Data.is_integer(record.get("round"))
		and record.round > 0
		and Data.is_integer(record.get("paid_value"))
		and record.paid_value >= 0
		and typeof(record.get("reconstruction")) == TYPE_BOOL
	)


static func combat_order(order: Dictionary) -> Dictionary:
	var result: Dictionary = order.duplicate(true)
	result.erase("castle_action")
	return result


static func validate_choice(world: Dictionary, player_id: int, choice: Dictionary) -> Dictionary:
	if not choice_shape(choice):
		return Data.invalid("castle_action_shape_invalid")
	if choice.is_empty():
		return {"action": "legal", "paid_value": 0, "reconstruction": false}
	var entities = Ids.new()
	entities.restore(world.entities)
	var target: Dictionary = entities.get_entity(choice.target_id)
	if target.is_empty() or target.kind != "castle" or target.owner != player_id:
		return Data.invalid("castle_action_target_invalid")
	if not Cards.can_discard(world, player_id, choice.card_ids, choice.card_ids.size()):
		return Data.invalid("castle_payment_unavailable")
	var target_check: Dictionary = _validate_target(world, player_id, choice, entities)
	if target_check.action == "invalid":
		return target_check
	if choice.use_repair_token and world.players[player_id].resources.repair_tokens < 1:
		return Data.invalid("repair_token_unavailable")
	return {
		"action": "legal",
		"paid_value": payment_value(world, choice),
		"reconstruction": target_check.reconstruction
	}


static func validate_target(world: Dictionary, player_id: int, choice: Dictionary) -> Dictionary:
	var entities = Ids.new()
	entities.restore(world.entities)
	return _validate_target(world, player_id, choice, entities)


static func _validate_target(
	world: Dictionary, player_id: int, choice: Dictionary, entities
) -> Dictionary:
	var target: Dictionary = entities.get_entity(choice.target_id)
	if target.is_empty() or target.kind != "castle" or target.owner != player_id:
		return Data.invalid("castle_action_target_invalid")
	var a: Dictionary = target.attributes
	var reconstruction: bool = a.status == "ruined"
	if choice.action == "Construct":
		if choice.use_repair_token:
			return Data.invalid("repair_tokens_do_not_accelerate_construction")
		if reconstruction:
			var eligible: Dictionary = Structures.reconstruction_eligibility(
				world, player_id, target.id
			)
			if eligible.action == "invalid":
				return eligible
		elif (
			a.status == "profaned"
			or a.construction_state not in ["unbuilt", "building", "ready"]
			or a.integrity >= a.max_integrity
		):
			return Data.invalid("castle_not_under_construction")
	elif choice.action == "Activate":
		if (
			a.status != "standing"
			or a.construction_state not in ["building", "ready"]
			or a.integrity < Structures.FLOOR
		):
			return Data.invalid("castle_not_ready_to_activate")
		if not choice.card_ids.is_empty() or choice.use_repair_token:
			return Data.invalid("activation_does_not_accept_payment")
	else:
		if (
			a.status not in ["standing", "defunct"]
			or a.construction_state != "active"
			or a.integrity >= a.max_integrity
		):
			return Data.invalid("castle_not_repairable")
		if int(a.get("repair_lock_until_round", 0)) >= int(world.data.construction_round) + 1:
			return Data.invalid("castle_repair_locked_this_round")
		if choice.card_ids.is_empty() and not choice.use_repair_token:
			return Data.invalid("repair_payment_required")
	return {"action": "legal", "reconstruction": reconstruction}


static func payment_value(world: Dictionary, choice: Dictionary) -> int:
	if choice.is_empty():
		return 0
	var entities = Ids.new()
	entities.restore(world.entities)
	var total: int = 0
	for card_id in choice.card_ids:
		var card: Dictionary = entities.get_entity(card_id)
		if card.is_empty() or card.kind != "card":
			return -1
		var value: int = int(card.attributes.value)
		if choice.action == "Repair" and card.attributes.suit != "Wright":
			value = maxi(1, value - 1)
		total += value
	return total


# Costs are reserved at joint lock, after powers and before combat commitments.
# Progress happens only at Development; invalid complete plans roll back together.
static func accept(context: Dictionary) -> Dictionary:
	var order: Dictionary = context.order
	var choice = order.get("castle_action", {})
	if not choice_shape(choice) or not Combat.order_shape(combat_order(order)):
		return Data.invalid("castle_order_invalid")
	if context.phase == "snapshot":
		return snapshot_order(context)
	var world: Dictionary = context.world.duplicate(true)
	var player_id: int = context.player_id
	if world.data.castle_orders[player_id] != null:
		return Data.invalid("castle_action_already_reserved")
	var checked: Dictionary = validate_choice(world, player_id, choice)
	if checked.action == "invalid":
		return checked
	var record: Dictionary = {
		"choice": choice.duplicate(true),
		"round": context.round,
		"paid_value": checked.paid_value,
		"reconstruction": checked.reconstruction
	}
	var events: Array = []
	if not choice.is_empty():
		var paid: Dictionary = Cards.discard(world, player_id, choice.card_ids)
		if paid.action == "invalid":
			return paid
		if choice.use_repair_token:
			world.players[player_id].resources.repair_tokens -= 1
		var event: Dictionary = {
			"type": "CASTLE_ACTION_SEALED",
			"text": "",
			"data":
			{"player_id": player_id, "round": context.round, "choice": choice.duplicate(true)}
		}
		var views: Array = [null, null]
		views[player_id] = event
		events.append({"event": event, "views": views})
	world.data.castle_orders[player_id] = record
	var combat_context: Dictionary = context.duplicate(true)
	combat_context.world = world
	combat_context.order = combat_order(order)
	var accepted: Dictionary = Combat.accept(combat_context)
	if accepted.action == "invalid":
		return accepted
	events.append_array(accepted.events)
	return {"action": "resolved", "world": accepted.world, "events": events}


static func snapshot_order(context: Dictionary) -> Dictionary:
	var phase: int = context.next_hook_index
	var world: Dictionary = context.world
	var player_id: int = context.player_id
	var choice: Dictionary = context.order.get("castle_action", {})
	var record = world.data.castle_orders[player_id]
	if not choice.is_empty():
		var identities = Ids.new()
		identities.restore(world.entities)
		var target: Dictionary = identities.get_entity(choice.target_id)
		if target.is_empty() or target.kind != "castle" or target.owner != player_id:
			return Data.invalid("castle_order_identity_invalid")
		var other_cards: Array = combat_order(context.order).get("card_ids", []).duplicate()
		for raw_source in context.declarations:
			var source: Dictionary = Data.declaration_copy(raw_source)
			if source.is_empty():
				return Data.invalid("castle_order_declaration_invalid")
			var selected = source.cost.get("discard_ids", [])
			if typeof(selected) != TYPE_ARRAY:
				return Data.invalid("castle_order_declaration_cost_invalid")
			other_cards.append_array(selected)
		for card_id in choice.card_ids:
			if card_id in other_cards:
				return Data.invalid("castle_payment_shared_with_other_action")
	var locked: bool = (
		phase > Timeline.hook_rank(Timeline.SUBMISSION_LOCK)
		and phase <= Timeline.hook_rank(Timeline.AFTERMATH)
	)
	if locked:
		if not record_shape(record) or record.round != context.round or record.choice != choice:
			return Data.invalid("castle_order_snapshot_mismatch")
		var prior: Dictionary = context.presentation_world
		var check: Dictionary = validate_choice(prior, player_id, choice)
		if (
			check.action == "invalid"
			or check.paid_value != record.paid_value
			or check.reconstruction != record.reconstruction
		):
			return Data.invalid("castle_payment_snapshot_mismatch")
		var spent_tokens: int = 1 if not choice.is_empty() and choice.use_repair_token else 0
		if (
			world.players[player_id].resources.repair_tokens
			!= prior.players[player_id].resources.repair_tokens - spent_tokens
		):
			return Data.invalid("repair_token_snapshot_mismatch")
		if not choice.is_empty():
			if phase <= Timeline.hook_rank(Timeline.DEVELOPMENT):
				for card_id in choice.card_ids:
					if card_id not in world.data.card_zones.discard:
						return Data.invalid("castle_reserved_card_missing")
	elif record != null:
		return Data.invalid("castle_order_outside_locked_round")
	elif phase <= Timeline.hook_rank(Timeline.SUBMISSION_LOCK):
		if validate_choice(world, player_id, choice).action == "invalid":
			return Data.invalid("sealed_castle_order_invalid")
	var expected: int = (
		context.round if phase > Timeline.hook_rank(Timeline.DEVELOPMENT) else context.round - 1
	)
	if world.data.construction_round != expected:
		return Data.invalid("construction_phase_ledger_mismatch")
	var combat_context: Dictionary = context.duplicate(true)
	combat_context.order = combat_order(context.order)
	return Combat.accept(combat_context)


static func resolve(context: Dictionary) -> Dictionary:
	if context.hook != Timeline.DEVELOPMENT:
		return Data.invalid("construction_wrong_hook")
	var world: Dictionary = context.world.duplicate(true)
	if world.data.construction_round >= context.round:
		return Data.invalid("construction_already_resolved")
	var entities = Ids.new()
	entities.restore(world.entities)
	var events: Array = []
	var advanced: Dictionary = {}
	for player_id in context.player_order:
		var record = world.data.castle_orders[player_id]
		if not record_shape(record) or record.round != context.round:
			return Data.invalid("castle_order_missing")
		var choice: Dictionary = record.choice
		if choice.is_empty():
			continue
		var checked: Dictionary = validate_target(world, player_id, choice)
		if checked.action == "invalid" or checked.reconstruction != record.reconstruction:
			events.append(
				Structures.public_event(
					"CASTLE_ACTION_FIZZLED",
					{
						"player_id": player_id,
						"round": context.round,
						"castle_id": choice.target_id,
						"reason": checked.get("reason", "castle_state_changed")
					}
				)
			)
			continue
		var target: Dictionary = entities.get_entity(choice.target_id)
		if choice.action == "Construct":
			world.data.construction_targets[player_id] = target.id
			events.append_array(
				_advance_build(
					world,
					entities,
					target,
					context.round,
					int(record.paid_value),
					bool(record.reconstruction),
					false
				)
			)
			advanced[player_id] = true
			continue
		var a: Dictionary = target.attributes
		var before: int = int(a.integrity)
		var bonus: int = (
			REPAIR_TOKEN if choice.action == "Repair" and choice.use_repair_token else 0
		)
		a.integrity = mini(int(a.max_integrity), before + bonus + int(record.paid_value))
		a.status = "standing" if a.integrity > 0 else "defunct"
		if choice.action == "Activate":
			a.construction_state = "active"
			if world.data.construction_targets[player_id] == target.id:
				world.data.construction_targets[player_id] = ""
		entities.update(target.id, target.owner, a)
		events.append(
			Structures.public_event(
				"CASTLE_ACTIVATED" if choice.action == "Activate" else "CASTLE_REPAIRED",
				{
					"player_id": player_id,
					"round": context.round,
					"castle_id": target.id,
					"before": before,
					"after": a.integrity,
					"passive_bonus": 0,
					"paid_value": record.paid_value,
					"paid_gain": record.paid_value,
					"token_bonus": bonus,
					"reconstruction": false,
					"complete": false,
					"activated": a.construction_state == "active",
					"operational": Structures.operational(target)
				}
			)
		)
	# A selected project advances once per Development even on a pass, combat,
	# powers, or repair elsewhere. Payments are never remembered or repeated.
	for player_id in context.player_order:
		var id: String = world.data.construction_targets[player_id]
		if advanced.has(player_id) or id.is_empty():
			continue
		var target: Dictionary = entities.get_entity(id)
		if (
			target.is_empty()
			or target.attributes.construction_state != "building"
			or target.attributes.status != "standing"
		):
			return Data.invalid("continuing_construction_target_invalid")
		events.append_array(_advance_build(world, entities, target, context.round, 0, false, true))
	world.entities = entities.snapshot()
	world.data.construction_round = context.round
	return {"action": "resolved", "world": world, "events": events}


static func _advance_build(
	world: Dictionary,
	entities,
	target: Dictionary,
	round_number: int,
	paid_value: int,
	reconstruction: bool,
	continuing: bool
) -> Array:
	var a: Dictionary = target.attributes
	var before: int = int(a.integrity)
	var paid_gain: int = floori(float(paid_value) / float(CARD_VALUE_PER_INTEGRITY))
	a.construction_state = "building"
	if reconstruction:
		a.artillery_target = ""
		a.erase("repair_lock_until_round")
	a.integrity = mini(int(a.max_integrity), before + PASSIVE + paid_gain)
	a.status = "standing"
	var complete: bool = a.integrity == a.max_integrity
	if complete:
		a.construction_state = "active"
		world.data.construction_targets[target.owner] = ""
	entities.update(target.id, target.owner, a)
	var fact: Dictionary = {
		"player_id": target.owner,
		"round": round_number,
		"castle_id": target.id,
		"before": before,
		"after": a.integrity,
		"passive_bonus": PASSIVE,
		"paid_value": paid_value,
		"paid_gain": paid_gain,
		"token_bonus": 0,
		"reconstruction": reconstruction,
		"complete": complete,
		"activated": complete,
		"operational": Structures.operational(target),
		"continuing": continuing
	}
	var events: Array = [Structures.public_event("CONSTRUCTION_PROGRESS", fact)]
	if complete:
		var activation: Dictionary = fact.duplicate(true)
		activation.reconstruction = false
		activation["automatic"] = true
		events.append(Structures.public_event("CASTLE_ACTIVATED", activation))
	return events


# Optional owner-side enumeration screen. It can reject but cannot authorize.
# Shared target predicates and Hand selection rules are reused; no bot rule copy.
static func screen_orders(context: Dictionary) -> Array:
	var world: Dictionary = context.world
	var orders: Array = context.orders
	var player_id: int = context.player_id
	if not enabled(world) or not Cards.valid(world):
		return range(orders.size())
	var entities = Ids.new()
	entities.restore(world.entities)
	var hand: Array = world.data.card_zones.hands[player_id]
	var power_cards: Array = []
	for raw_source in context.declarations:
		var source: Dictionary = Data.declaration_copy(raw_source)
		if source.is_empty() or typeof(source.cost.get("discard_ids", [])) != TYPE_ARRAY:
			return []
		power_cards.append_array(source.cost.get("discard_ids", []))
	var result: Array = []
	for index in range(orders.size()):
		var order = orders[index]
		if typeof(order) != TYPE_DICTIONARY or not Data.is_data(order):
			continue
		var choice = order.get("castle_action", {})
		var combat: Dictionary = combat_order(order)
		if not choice_shape(choice) or not Combat.order_shape(combat):
			continue
		var selected: Array = power_cards.duplicate()
		selected.append_array(combat.get("card_ids", []))
		if not choice.is_empty():
			if _validate_target(world, player_id, choice, entities).action == "invalid":
				continue
			if choice.use_repair_token and world.players[player_id].resources.repair_tokens < 1:
				continue
			selected.append_array(choice.card_ids)
		if not Cards.can_discard_from_hand(hand, selected, selected.size()):
			continue
		result.append(index)
	return result
