class_name U13Combat
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const LordStats = preload("res://Scripts/Sim/U13LordStats.gd")
const HUNT_VERSION: String = "U13_CORE_HUNT_V1"
const VERSION: String = "U13_GREMORY_BASIC_COMBAT_V1"


# Explicit first integration profile: Gremory mirrors, ordinary Siege/Ward,
# flat Sigils and plain Integrity targets. Basic Hunt is opt-in; named Castle powers, Keep,
# construction, Fracture and victory orchestration need their own migration.
# Refuse unsupported profiles instead of silently treating this as all U12 rules.
static func valid(world: Dictionary) -> bool:
	if (
		world.data.get("combat_profile") not in [VERSION, Structures.PROFILE]
		or not Cards.valid(world)
		or not Marching.valid(world)
		or not Slots.valid(world)
	):
		return false
	var core: bool = world.data.get("combat_profile") == Structures.PROFILE
	var lords: Array = ["Gremory", "Deimos"] if core else ["Gremory"]
	if world.data.has("humbaba_profile"):
		if not core or world.data.humbaba_profile != LordStats.HUMBABA_PROFILE:
			return false
		lords.append("Humbaba")
	if world.data.has("kalligan_profile"):
		if not core or world.data.kalligan_profile != LordStats.KALLIGAN_PROFILE:
			return false
		lords.append("Kalligan")
	if world.data.has("orias_profile"):
		if not core or world.data.orias_profile != LordStats.ORIAS_WEB_PROFILE:
			return false
		lords.append("Orias")
	if world.data.has("odradek_profile"):
		if not core or world.data.odradek_profile != LordStats.ODRADEK_PROFILE:
			return false
		lords.append("Odradek")
	if world.data.has("kroni_profile"):
		if not core or world.data.kroni_profile != "U13_KRONI_PLACED_RANDOM_V2":
			return false
		lords.append("Kroni")
	if world.data.has("hunt_profile") and (not core or world.data.hunt_profile != HUNT_VERSION):
		return false
	if core and not Structures.valid(world):
		return false
	if world.data.get("breach_lord") != "" and world.data.get("breach_lord") not in lords:
		return false
	var sigils = world.data.get("sigils")
	if typeof(sigils) != TYPE_ARRAY or sigils.size() != 2:
		return false
	for player_id in [0, 1]:
		if world.players[player_id].lord_id not in lords:
			return false
		if typeof(sigils[player_id]) != TYPE_DICTIONARY:
			return false
		for lane in Marching.LANES:
			if sigils[player_id].get(lane) not in ["", "fresh", "flipped"]:
				return false
	var slots: Dictionary = {}
	for entity in world.entities.entities:
		var a: Dictionary = entity.attributes
		if entity.kind == "castle":
			if (
				a.get("combat_profile")
				not in (["plain_integrity", "siege_engine"] if core else ["plain_integrity"])
			):
				return false
		if entity.kind != "card":
			continue
		if (
			a.get("suit") not in Marching.SUITS
			or not Data.is_integer(a.get("value"))
			or a.value < 1
			or a.value > 6
		):
			return false
		if a.get("role") == "guard":
			if (
				entity.owner not in [0, 1]
				or a.get("lane") not in Marching.LANES
				or not Data.is_integer(a.get("slot"))
				or a.slot < 0
			):
				return false
			var key: String = "%d:%s:%d" % [entity.owner, a.lane, a.slot]
			if slots.has(key):
				return false
			slots[key] = true
	for field in [
		"combat_reveal_round", "combat_resolved_round", "combat_cleanup_round", "castle_tear_round"
	]:
		if not Data.is_integer(world.data.get(field, 0)) or world.data.get(field, 0) < 0:
			return false
	return true


static func order_shape(order: Dictionary) -> bool:
	if order.is_empty():
		return true
	if not Data.is_data(order) or order.get("action") not in ["Siege", "Hunt", "Ward"]:
		return false
	var expected: Array = ["action", "lane", "card_ids"]
	if order.action in ["Siege", "Hunt"]:
		expected.append("target_id")
		if (
			typeof(order.get("target_id")) != TYPE_STRING
			or order.target_id.is_empty()
			or order.get("lane") != ("Lord" if order.action == "Hunt" else "Castle")
		):
			return false
	if order.keys().size() != expected.size():
		return false
	for key in expected:
		if not order.has(key):
			return false
	if order.lane not in Marching.LANES or typeof(order.card_ids) != TYPE_ARRAY:
		return false
	var seen: Dictionary = {}
	for card_id in order.card_ids:
		if typeof(card_id) != TYPE_STRING or card_id.is_empty() or seen.has(card_id):
			return false
		seen[card_id] = true
	return true


static func accept(context: Dictionary) -> Dictionary:
	var order: Dictionary = context.order
	if not order_shape(order):
		return Data.invalid("combat_order_invalid")
	var world: Dictionary = context.world
	if order.get("action") == "Hunt" and world.data.get("hunt_profile") != HUNT_VERSION:
		return Data.invalid("hunt_profile_required")
	if context.phase == "snapshot":
		return _snapshot_order(context)
	if order.is_empty():
		return {"action": "resolved", "world": world, "events": []}
	var player_id: int = context.player_id
	var entities = Ids.new()
	entities.restore(world.entities)
	var checked: Dictionary = validate_commit(
		world, player_id, order, entities, world.data.card_zones.hands[player_id]
	)
	if checked.action == "invalid":
		return checked
	if Cards.commit(world, player_id, order.card_ids).action == "invalid":
		return Data.invalid("combat_cards_unavailable")
	var event: Dictionary = {
		"type": "COMBAT_ORDER_SEALED",
		"text": "",
		"data": {"player_id": player_id, "round": context.round, "order": order.duplicate(true)}
	}
	var views: Array = [null, null]
	views[player_id] = event
	return {"action": "resolved", "world": world, "events": [{"event": event, "views": views}]}


# Shared by authoritative commit and batch legality on an owned valid world.
# Hand may exclude a staged Castle payment; this function never mutates it.
static func validate_commit(
	world: Dictionary, player_id: int, order: Dictionary, entities, hand: Array
) -> Dictionary:
	if not order_shape(order):
		return Data.invalid("combat_order_invalid")
	if order.get("action") == "Hunt" and world.data.get("hunt_profile") != HUNT_VERSION:
		return Data.invalid("hunt_profile_required")
	if order.is_empty():
		return {"action": "legal"}
	var lord: Dictionary = entities.get_entity(world.players[player_id].lord_entity_id)
	if not lord.attributes.alive:
		return Data.invalid("combat_source_banished")
	if order.action == "Siege":
		var target: Dictionary = entities.get_entity(order.target_id)
		if (
			target.is_empty()
			or target.kind != "castle"
			or target.owner != 1 - player_id
			or not Structures.targetable(target)
		):
			return Data.invalid("combat_target_invalid")
	if order.action == "Hunt":
		var target: Dictionary = entities.get_entity(order.target_id)
		if (
			target.is_empty()
			or target.kind != "lord"
			or target.owner != 1 - player_id
			or not target.attributes.alive
		):
			return Data.invalid("hunt_target_invalid")
	if not Cards.can_discard_from_hand(hand, order.card_ids, order.card_ids.size()):
		return Data.invalid("combat_cards_unavailable")
	if not world.data.card_zones.get("committed", [[], []])[player_id].is_empty():
		return Data.invalid("combat_cards_unavailable")
	return {"action": "legal"}


# Plain-combat owners have no Construction adapter. Reuse the same commit
# predicate on a once-validated registry and the Hand after staged power costs.
static func legal_orders(context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world
	var player_id: int = context.player_id
	if not Cards.valid(world):
		return Data.invalid("combat_batch_world_invalid")
	var entities = Ids.new()
	if entities.restore(world.entities).action == "invalid":
		return Data.invalid("combat_batch_entities_invalid")
	var hand: Array = world.data.card_zones.hands[player_id]
	var indices: Array = []
	for index in range(context.orders.size()):
		var order = context.orders[index]
		if typeof(order) != TYPE_DICTIONARY or not Data.is_data(order):
			continue
		if validate_commit(world, player_id, order, entities, hand).action != "invalid":
			indices.append(index)
	return {"action": "legal_orders", "indices": indices}


static func on_hook(context: Dictionary, reaction: Callable) -> Dictionary:
	match context.hook:
		Timeline.ROUND_START_AUTOMATIC:
			return Marching.regenerate(context)
		Timeline.COMMITMENT_REVEAL:
			return _reveal(context)
		Timeline.COMBAT_RESOLUTION:
			return _resolve(context, reaction)
		Timeline.MARCHING:
			return Marching.resolve(context, reaction)
		Timeline.AFTERMATH:
			var world: Dictionary = context.world.duplicate(true)
			if world.data.get("combat_cleanup_round", 0) >= context.round:
				return Data.invalid("combat_already_cleaned")
			var cleared: Dictionary = Cards.clear_commitments(world, context.player_order)
			if cleared.action == "invalid":
				return cleared
			world.data["combat_cleanup_round"] = context.round
			return {"action": "resolved", "world": world, "events": []}
	return {"action": "resolved", "world": context.world, "events": []}


static func _reveal(context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	if world.data.get("combat_reveal_round", 0) >= context.round:
		return Data.invalid("combat_already_revealed")
	var entities = Ids.new()
	entities.restore(world.entities)
	var events: Array = []
	for player_id in context.player_order:
		var order: Dictionary = context.combat_orders[player_id]
		if order.is_empty():
			continue
		var cards: Array = []
		var totals: Dictionary = {}
		for card_id in order.card_ids:
			var card: Dictionary = entities.get_entity(card_id)
			cards.append(card)
			totals[card.attributes.suit] = (
				totals.get(card.attributes.suit, 0) + int(card.attributes.value)
			)
		events.append(
			Marching.public_event(
				"COMBAT_ORDER_REVEALED",
				{"player_id": player_id, "round": context.round, "order": order, "cards": cards}
			)
		)
		# Baseline immutable commitment input, floor(printed suit total / 3).
		for suit in Marching.SUITS:
			var count: int = floori(float(totals.get(suit, 0)) / 3.0)
			var origin: String = Data.instance_id(
				"commitment", "%d:%d" % [context.round, player_id], suit
			)
			for ordinal in range(count):
				var created: Dictionary = entities.create(
					"marcher",
					origin,
					ordinal,
					player_id,
					Marching.profile(suit, order.lane, player_id, context.round, context.round + 1)
				)
				if created.action == "invalid":
					return created
				var placed: Dictionary = Marching.place_spawn(
					entities, created.entity.id, context.seed
				)
				if placed.action == "invalid":
					return placed
				events.append(Marching.public_event("MARCHER_SPAWNED", placed.entity))
	world.entities = entities.snapshot()
	world.data["combat_reveal_round"] = context.round
	return {"action": "resolved", "world": world, "events": events}


static func _resolve(context: Dictionary, reaction: Callable) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	if world.data.get("combat_resolved_round", 0) >= context.round:
		return Data.invalid("combat_already_resolved")
	var events: Array = []
	for player_id in context.player_order:
		var order: Dictionary = context.combat_orders[player_id]
		if order.get("action") not in ["Siege", "Hunt"]:
			continue
		var result: Dictionary = (
			_hunt(world, context, player_id, order, reaction)
			if order.action == "Hunt"
			else _siege(world, context, player_id, order, reaction)
		)
		if result.action == "invalid":
			return result
		world = result.world
		events.append_array(result.events)
	world.data["combat_resolved_round"] = context.round
	return {"action": "resolved", "world": world, "events": events}


static func _siege(
	world: Dictionary, context: Dictionary, player_id: int, order: Dictionary, reaction: Callable
) -> Dictionary:
	var entities = Ids.new()
	entities.restore(world.entities)
	var target: Dictionary = entities.get_entity(order.target_id)
	var events: Array = []
	# A vanished target is a spent order; cards still leave via Aftermath, and
	# its waiters remain. No retargeting or fresh decision after the joint lock.
	if not Structures.targetable(target):
		events.append(
			Marching.public_event(
				"COMBAT_ORDER_FIZZLED",
				{"player_id": player_id, "round": context.round, "target_id": order.target_id}
			)
		)
		return {"action": "resolved", "world": world, "events": events}
	var strength: int = _card_strength(entities, order.card_ids, "Butcher")
	var waiter_ids: Array = []
	for entity in entities.snapshot().entities:
		if (
			entity.kind == "marcher"
			and entity.owner == player_id
			and entity.attributes.lane == "Castle"
			and entity.attributes.waiting
		):
			strength += 1
			waiter_ids.append(entity.id)
			entities.retire(entity.id)
	world.entities = entities.snapshot()
	events.append(
		Marching.public_event(
			"SIEGE_STARTED",
			{
				"player_id": player_id,
				"round": context.round,
				"target_id": target.id,
				"strength": strength,
				"waiters_consumed": waiter_ids
			}
		)
	)
	if world.data.combat_profile == Structures.PROFILE:
		var reacted: Dictionary = reaction.call(
			world, events.back().event, context.seed, context.player_order
		)
		if reacted.action == "invalid":
			return reacted
		world = reacted.world
		events.append_array(reacted.events)
		entities.restore(world.entities)
	var ward: Dictionary = context.combat_orders[1 - player_id]
	var screen: int = 0
	if ward.get("action") == "Ward":
		screen = _card_strength(entities, ward.card_ids, "Penitent")
		if ward.lane != "Castle":
			screen = screen >> 1
	var remaining: int = strength
	if screen > 0:
		remaining = maxi(0, remaining - screen)
	var guards: Array = []
	for entity in entities.snapshot().entities:
		if (
			entity.kind == "card"
			and entity.owner == 1 - player_id
			and entity.attributes.get("role") == "guard"
			and entity.attributes.lane == "Castle"
		):
			guards.append(entity)
	guards.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a.attributes.value != b.attributes.value:
				return a.attributes.value > b.attributes.value
			return a.attributes.slot < b.attributes.slot
	)
	var guards_lost: int = 0
	for guard in guards:
		# Strictly greater defeats a Guard; equality leaves it in its slot.
		if remaining <= guard.attributes.value:
			remaining = 0
			break
		remaining -= int(guard.attributes.value)
		var command: Dictionary = {
			"command_id": "siege:%d:guard:%s" % [player_id, guard.id],
			"kind": "defeat_guard",
			"target_id": guard.id
		}
		var applied: Dictionary = _fact(world, command, context, reaction)
		if applied.action == "invalid":
			return applied
		world = applied.world
		events.append_array(applied.events)
		guards_lost += 1
	# Flat measured-profile Sigil: Fresh 2, Flipped 1. Equality stops it.
	var sigil: String = world.data.sigils[1 - player_id].Castle
	var sigil_broken: bool = false
	if remaining > 0 and not sigil.is_empty():
		var value: int = 2 if sigil == "fresh" else 1
		if remaining > value:
			remaining -= value
			world.data.sigils[1 - player_id].Castle = ""
			sigil_broken = true
		else:
			remaining = 0
	var integrity_before: int = target.attributes.integrity
	var damage: int = mini(integrity_before, remaining)
	var destroyed: bool = (
		damage == integrity_before
		and (
			remaining > 0
			if world.data.combat_profile == Structures.PROFILE
			else integrity_before > 0
		)
	)
	if destroyed:
		# Baseline unconsumed enemy Siege reward: 1/2 Souls, plus measured +1.
		world.players[player_id].resources["souls"] = (
			int(world.players[player_id].resources.get("souls", 0)) + (3 if guards_lost > 0 else 2)
		)
		if world.data.get("castle_tear_round", 0) != context.round:
			world.data.neutral_tears += 1
			world.data["castle_tear_round"] = context.round
			events.append(
				Marching.public_event(
					"NEUTRAL_TEAR_CREATED",
					{"amount": 1, "source": "CastleDestruction", "round": context.round}
				)
			)
		var command: Dictionary = {
			"command_id": "siege:%d:castle:%s" % [player_id, target.id],
			"kind":
			"ruin_castle" if world.data.combat_profile == Structures.PROFILE else "destroy_castle",
			"target_id": target.id,
			"player_id": player_id
		}
		var applied: Dictionary = _fact(world, command, context, reaction)
		if applied.action == "invalid":
			return applied
		world = applied.world
		events.append_array(applied.events)
	else:
		entities.restore(world.entities)
		target.attributes.integrity = integrity_before - damage
		Structures.note_integrity_loss(target, integrity_before, context.round)
		if target.attributes.integrity == 0:
			target.attributes.status = "defunct"
		entities.update(target.id, target.owner, target.attributes)
		world.entities = entities.snapshot()
		if sigil_broken and sigil == "fresh":
			var defender: Dictionary = world.players[1 - player_id]
			defender.resources["souls"] = int(defender.resources.get("souls", 0)) + 1
	events.append(
		Marching.public_event(
			"SIEGE_RESOLVED",
			{
				"player_id": player_id,
				"round": context.round,
				"target_id": target.id,
				"strength": strength,
				"ward_screen": screen,
				"guards_defeated": guards_lost,
				"sigil_broken": sigil_broken,
				"integrity_before": integrity_before,
				"damage": damage,
				"destroyed": destroyed
			}
		)
	)
	return {"action": "resolved", "world": world, "events": events}


static func _card_strength(entities, cards: Array, exempt: String) -> int:
	var strength: int = 0
	var suited: int = 0
	for card_id in cards:
		var a: Dictionary = entities.get_entity(card_id).attributes
		if a.suit == exempt:
			strength += int(a.value)
			suited += 1
		else:
			strength += maxi(1, int(a.value) - 1)
	return strength + (1 if suited >= 2 else 0)


static func _fact(
	world: Dictionary, command: Dictionary, context: Dictionary, reaction: Callable
) -> Dictionary:
	var applied: Dictionary = Battle.apply(world, command, context.round, context.hook)
	if applied.action == "invalid":
		return applied
	var fact: Dictionary = applied.event
	var reacted = reaction.call(applied.world, fact, context.seed, context.player_order)
	if typeof(reacted) != TYPE_DICTIONARY or reacted.get("action") != "resolved":
		return Data.invalid("combat_reaction_invalid")
	var events: Array = [{"event": fact, "views": [fact, fact]}]
	events.append_array(reacted.events)
	return {"action": "resolved", "world": reacted.world, "events": events}


static func _snapshot_order(context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world
	var order: Dictionary = context.order
	var phase: int = context.next_hook_index
	var player_id: int = context.player_id
	var selected: Array = order.get("card_ids", [])
	var entities = Ids.new()
	entities.restore(world.entities)
	for card_id in selected:
		var card: Dictionary = entities.get_entity(card_id)
		if card.is_empty() or card.kind != "card":
			return Data.invalid("combat_order_identity_missing")
	if order.get("action") in ["Siege", "Hunt"] and order.target_id not in world.entities.used_ids:
		return Data.invalid("combat_target_identity_missing")
	if order.get("action") in ["Siege", "Hunt"]:
		var target: Dictionary = entities.get_entity(order.target_id)
		var expected_kind: String = "lord" if order.action == "Hunt" else "castle"
		if (
			not target.is_empty()
			and (target.kind != expected_kind or target.owner != 1 - player_id)
		):
			return Data.invalid("combat_target_identity_invalid")
	var committed: Array = world.data.card_zones.get("committed", [[], []])[player_id]
	if phase <= Timeline.hook_rank(Timeline.SUBMISSION_LOCK):
		if (
			not committed.is_empty()
			or not Cards.can_discard(world, player_id, selected, selected.size())
		):
			return Data.invalid("sealed_order_cards_invalid")
	elif phase <= Timeline.hook_rank(Timeline.AFTERMATH):
		if committed != selected:
			return Data.invalid("committed_order_mismatch")
	elif not committed.is_empty():
		return Data.invalid("committed_cards_after_cleanup")
	var phases: Dictionary = {
		"marching_regen_round": Timeline.ROUND_START_AUTOMATIC,
		"combat_reveal_round": Timeline.COMMITMENT_REVEAL,
		"combat_resolved_round": Timeline.COMBAT_RESOLUTION,
		"marching_round": Timeline.MARCHING,
		"combat_cleanup_round": Timeline.AFTERMATH
	}
	if world.data.combat_profile == Structures.PROFILE:
		phases["artillery_round"] = Timeline.POST_REPAIR_ARTILLERY
	for field in phases:
		var expected: int = (
			context.round if phase > Timeline.hook_rank(phases[field]) else context.round - 1
		)
		if world.data.get(field, 0) != expected:
			return Data.invalid("combat_phase_ledger_mismatch")
	return {"action": "legal"}


# Opt-in basic Hunt for the direct board. U12 HuntResolutionEngine order:
# Ward -> Lord Guards -> flat Sigil -> Lord DEF, with strict > at the last layer.
# Gremory and Deimos have printed DEF 4 (GameSetup.LORD_CONTENT). Named Castle
# effects and Fracture remain separate migrations, as in the rest of this slice.
static func _hunt(
	world: Dictionary, context: Dictionary, player_id: int, order: Dictionary, reaction: Callable
) -> Dictionary:
	var entities = Ids.new()
	entities.restore(world.entities)
	var target: Dictionary = entities.get_entity(order.target_id)
	var events: Array = []
	if target.is_empty() or not target.attributes.alive:
		events.append(
			Marching.public_event(
				"COMBAT_ORDER_FIZZLED",
				{
					"player_id": player_id,
					"round": context.round,
					"target_id": order.target_id,
					"reason": "lord_banished"
				}
			)
		)
		return {"action": "resolved", "world": world, "events": events}
	var strength: int = _card_strength(entities, order.card_ids, "Butcher")
	var pursuit: int = 0
	if world.data.get("orias_profile") == LordStats.ORIAS_WEB_PROFILE:
		pursuit = LordStats.relentless_pursuit(
			entities.get_entity(world.players[player_id].lord_entity_id), target
		)
		strength += pursuit
	var waiter_ids: Array = []
	for entity in entities.snapshot().entities:
		if (
			entity.kind == "marcher"
			and entity.owner == player_id
			and entity.attributes.lane == "Lord"
			and entity.attributes.waiting
		):
			strength += 1
			waiter_ids.append(entity.id)
			entities.retire(entity.id)
	world.entities = entities.snapshot()
	events.append(
		Marching.public_event(
			"HUNT_STARTED",
			{
				"player_id": player_id,
				"round": context.round,
				"target_id": target.id,
				"strength": strength,
				"waiters_consumed": waiter_ids
			}
		)
	)
	if world.data.get("orias_profile") == LordStats.ORIAS_WEB_PROFILE:
		events.back().event.data["relentless_pursuit"] = pursuit
	if world.data.combat_profile == Structures.PROFILE:
		var reacted: Dictionary = reaction.call(
			world, events.back().event, context.seed, context.player_order
		)
		if reacted.action == "invalid":
			return reacted
		world = reacted.world
		events.append_array(reacted.events)
		entities.restore(world.entities)
	var ward: Dictionary = context.combat_orders[1 - player_id]
	var screen: int = 0
	if ward.get("action") == "Ward":
		screen = _card_strength(entities, ward.card_ids, "Penitent")
		if ward.lane != "Lord":
			screen = screen >> 1
	var remaining: int = strength
	if screen > 0:
		remaining = maxi(0, remaining - screen)
	var guards: Array = []
	for entity in entities.snapshot().entities:
		if (
			entity.kind == "card"
			and entity.owner == 1 - player_id
			and entity.attributes.get("role") == "guard"
			and entity.attributes.lane == "Lord"
		):
			guards.append(entity)
	guards.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a.attributes.value != b.attributes.value:
				return a.attributes.value > b.attributes.value
			return a.attributes.slot < b.attributes.slot
	)
	var guards_lost: int = 0
	for guard in guards:
		# Strictly greater defeats a Guard; equality leaves it in its slot.
		if remaining <= guard.attributes.value:
			remaining = 0
			break
		remaining -= int(guard.attributes.value)
		var command: Dictionary = {
			"command_id": "hunt:%d:guard:%s" % [player_id, guard.id],
			"kind": "defeat_guard",
			"target_id": guard.id
		}
		if world.data.get("orias_profile") == LordStats.ORIAS_WEB_PROFILE:
			command["attacker_id"] = world.players[player_id].lord_entity_id
			command["attack_kind"] = "Hunt"
		var applied: Dictionary = _fact(world, command, context, reaction)
		if applied.action == "invalid":
			return applied
		world = applied.world
		events.append_array(applied.events)
		guards_lost += 1
	# Flat measured-profile Sigil: Fresh 2, Flipped 1. Equality stops it.
	var sigil: String = world.data.sigils[1 - player_id].Lord
	var sigil_broken: bool = false
	if remaining > 0 and not sigil.is_empty():
		var value: int = 2 if sigil == "fresh" else 1
		if remaining > value:
			remaining -= value
			world.data.sigils[1 - player_id].Lord = ""
			sigil_broken = true
		else:
			remaining = 0
	# Guard reactions may have changed Threat during this same Hunt.
	entities.restore(world.entities)
	target = entities.get_entity(target.id)
	var defense: int = LordStats.defense(world, target)
	var banished: bool = remaining > defense
	if banished:
		world.players[player_id].resources.souls += 2
		world.players[1 - player_id].resources.souls = maxi(
			0, int(world.players[1 - player_id].resources.souls) - 1
		)
		world.data.neutral_tears += 1
		events.append(
			Marching.public_event(
				"NEUTRAL_TEAR_CREATED",
				{"amount": 1, "source": "LordBanishment", "round": context.round}
			)
		)
		for command in [
			{
				"command_id": "hunt:%d:lord:%s" % [player_id, target.id],
				"kind": "banish_lord",
				"target_id": target.id
			},
			{
				"command_id": "hunt:%d:breach:%s" % [player_id, target.id],
				"kind": "set_breach",
				"lord_id": world.players[1 - player_id].lord_id
			}
		]:
			if (
				world.data.get("orias_profile") == LordStats.ORIAS_WEB_PROFILE
				and command.kind == "banish_lord"
			):
				command["attacker_id"] = world.players[player_id].lord_entity_id
				command["attack_kind"] = "Hunt"
			if world.data.has("humbaba_profile") and command.kind == "set_breach":
				command["source_id"] = target.id
			var applied: Dictionary = _fact(world, command, context, reaction)
			if applied.action == "invalid":
				return applied
			world = applied.world
			events.append_array(applied.events)
		entities.restore(world.entities)
		target = entities.get_entity(target.id)
		if target.attributes.has("threat"):
			target.attributes.threat = 0
			entities.update(target.id, target.owner, target.attributes)
			world.entities = entities.snapshot()
	elif sigil_broken and sigil == "fresh":
		world.players[1 - player_id].resources.souls += 1
	events.append(
		Marching.public_event(
			"HUNT_RESOLVED",
			{
				"player_id": player_id,
				"round": context.round,
				"target_id": target.id,
				"strength": strength,
				"ward_screen": screen,
				"guards_defeated": guards_lost,
				"sigil_broken": sigil_broken,
				"lord_defense": defense,
				"banished": banished
			}
		)
	)
	if world.data.get("orias_profile") == LordStats.ORIAS_WEB_PROFILE:
		events.back().event.data["relentless_pursuit"] = pursuit
	return {"action": "resolved", "world": world, "events": events}
