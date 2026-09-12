extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Market = preload("res://Scripts/Sim/U13GameMarket.gd")
const Resummon = preload("res://Scripts/Sim/U13Resummoning.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const DrawEvents = preload("res://Scripts/Sim/U13Gremory.gd")
const VERSION: String = "U13_GAME_ECONOMY_V4"
# Transcribed from SeededGameSetup, GameSetup, RoundEngine and RuleConfig.
# No old Lord callbacks or sequential Python RNG enter the U13 rules path.
const SUITS: Array = ["Butcher", "Penitent", "Vulture", "Wright"]
const COUNTS: Array = [4, 4, 4, 3, 3]
const OPENING_CARDS: int = 5
const ROUND_CARDS: int = 5
const HAND_LIMIT: int = 10
const STARTING_CASTLES: int = 3
const BLOOD_OFFERING_INTEGRITY: int = 3
const BLOOD_OFFERING_DISCOUNT: int = 3


static func initialize(raw: Dictionary, seed_value: String) -> Dictionary:
	if seed_value.is_empty() or raw.get("action") == "invalid":
		return Data.invalid("game_opening_invalid")
	var world: Dictionary = raw.duplicate(true)
	# Reuse the nine-Lord setup schema, not its exercise cards/resources.
	var ids = Ids.new()
	for entity in world.entities.entities:
		if entity.kind in ["lord", "castle"]:
			ids.create(entity.kind, entity.origin, entity.ordinal, entity.owner, entity.attributes)
	for player in world.players:
		for resource in player.resources:
			player.resources[resource] = 0
	world.data.neutral_tears = 0
	world.data.breach_lord = ""
	world.data["blood_conduit_profile"] = preload("res://Scripts/Sim/U13BloodConduit.gd").VERSION
	world.data["castle_defense_profile"] = preload("res://Scripts/Sim/U13CastleDefenses.gd").VERSION
	world.entities = ids.snapshot()
	var castles: Dictionary = _prepare_opening_castles(world)
	if castles.action == "invalid":
		return castles
	ids.restore(world.entities)
	var deck: Array = []
	for suit in SUITS:
		var suit_cards: Array = []
		var ordinal: int = 0
		for value_index in range(COUNTS.size()):
			for copy_index in range(COUNTS[value_index]):
				var card: Dictionary = ids.create("card", "game:deck:" + suit, ordinal, -1, {"suit": suit, "value": value_index + 1}).entity
				suit_cards.append(card.id)
				ordinal += 1
		_shuffle(suit_cards, seed_value, "trim:" + suit)
		for card_id in suit_cards.slice(0, 3):
			ids.retire(card_id)
		deck.append_array(suit_cards.slice(3))
	_shuffle(deck, seed_value, "opening")
	world.entities = ids.snapshot()
	world.data.card_zones = {"hands": [[], []], "deck": deck, "discard": [], "committed": [[], []], "hand_limit": HAND_LIMIT}
	world.data["game_economy"] = {
		"version": VERSION,
		"opening_dealt": true,
		"draw_round": 0,
		"draw_player": 2,
		"stockpile_pending": {},
		"opening": {
			"active_castle_count": STARTING_CASTLES,
			"active_castle_ids": castles.active_castle_ids,
			"summons": []
		}
	}
	preload("res://Scripts/Sim/U13Sigils.gd").configure(world)
	preload("res://Scripts/Sim/U13Fracture.gd").configure(world)
	preload("res://Scripts/Sim/U13DominionRites.gd").configure(world)
	preload("res://Scripts/Sim/U13VacantThrone.gd").configure(world)
	Market.initialize(world, seed_value)
	# Setup draws are already represented in the initial saved state. Private
	# identities are exposed only by the existing per-player projection.
	for pid in [0, 1]:
		for index in range(OPENING_CARDS):
			var drawn: Dictionary = Cards.draw(world, pid, seed_value, "opening:%d:%d" % [pid, index])
			if drawn.action == "invalid" or not drawn.drawn:
				return Data.invalid("game_opening_deal_failed")
	var summons: Dictionary = _pay_opening_summons(world)
	if summons.action == "invalid":
		return summons
	world.data.game_economy.opening.summons = summons.records
	if not valid(world):
		return Data.invalid("game_opening_state_invalid")
	return {"action": "game_opening", "world": world}


# The loadout's physical order is meaningful: its first three slots are the
# player's starting Castles and the final two are protected blueprints. This
# carries the accepted any-three opening into U13's five sealed physical slots.
static func _prepare_opening_castles(world: Dictionary) -> Dictionary:
	var ids = Ids.new()
	if ids.restore(world.entities).action == "invalid":
		return Data.invalid("game_opening_castles_invalid")
	var active: Array = [[], []]
	for pid in [0, 1]:
		for slot in range(Slots.SLOT_COUNT):
			var castle: Dictionary = ids.get_entity(Slots.castle_id(pid, slot))
			if castle.is_empty() or castle.kind != "castle" or castle.owner != pid:
				return Data.invalid("game_opening_castle_missing")
			var starting: bool = slot < STARTING_CASTLES
			castle.attributes.integrity = (
				int(castle.attributes.max_integrity) if starting else 0
			)
			castle.attributes.status = "standing" if starting else "defunct"
			castle.attributes.construction_state = "active" if starting else "unbuilt"
			castle.attributes.artillery_target = ""
			castle.attributes.erase("repair_lock_until_round")
			ids.update(castle.id, pid, castle.attributes)
			if starting:
				active[pid].append(castle.id)
	world.entities = ids.snapshot()
	return {"action": "resolved", "active_castle_ids": active}


# Opening summons are forced setup, as in the verified playable controller:
# pay lowest-value cards until the current U13 Lord cost is met or Hand is
# exhausted. An operational starting Circle automatically makes one Blood
# Offering. Opening shortfall never creates Fracture and the first summon never
# creates a Tear.
static func _pay_opening_summons(world: Dictionary) -> Dictionary:
	if not Cards.valid(world):
		return Data.invalid("game_opening_summon_cards_invalid")
	var records: Array = []
	for pid in [0, 1]:
		var ids = Ids.new()
		if ids.restore(world.entities).action == "invalid":
			return Data.invalid("game_opening_summon_entities_invalid")
		var actor: Dictionary = Resummon.lord(world, pid)
		if (
			actor.is_empty()
			or actor.owner != pid
			or not Resummon.COSTS.has(actor.attributes.get("lord_id"))
		):
			return Data.invalid("game_opening_lord_invalid")
		var circles: Array = world.entities.entities.filter(
			func(row):
				return (
					row.kind == "castle"
					and row.owner == pid
					and row.attributes.get("castle_type") == "SummoningCircle"
					and Structures.operational(row)
					and int(row.attributes.integrity) >= BLOOD_OFFERING_INTEGRITY
				)
		)
		circles.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.attributes.castle_slot) < int(b.attributes.castle_slot)
		)
		var circle_id: String = ""
		var cost: int = int(Resummon.COSTS[actor.attributes.lord_id])
		if not circles.is_empty():
			var circle: Dictionary = circles[0]
			circle_id = circle.id
			circle.attributes.integrity -= BLOOD_OFFERING_INTEGRITY
			ids.update(circle.id, pid, circle.attributes)
			world.entities = ids.snapshot()
			cost = maxi(0, cost - BLOOD_OFFERING_DISCOUNT)
		var selected: Array = []
		var values: Array = []
		var paid_value: int = 0
		var available: Array = world.data.card_zones.hands[pid].duplicate()
		while paid_value < cost and not available.is_empty():
			ids.restore(world.entities)
			var lowest_index: int = 0
			var lowest: int = int(ids.get_entity(available[0]).attributes.value)
			for index in range(1, available.size()):
				var value: int = int(ids.get_entity(available[index]).attributes.value)
				if value < lowest:
					lowest = value
					lowest_index = index
			var card_id: String = available.pop_at(lowest_index)
			selected.append(card_id)
			values.append(lowest)
			paid_value += lowest
		var payment: Dictionary = Cards.discard(world, pid, selected)
		if payment.action == "invalid":
			return payment
		ids.restore(world.entities)
		actor = ids.get_entity(actor.id)
		actor.attributes.alive = true
		if actor.attributes.lord_id != "Humbaba":
			actor.attributes["threat"] = 0
		ids.update(actor.id, pid, actor.attributes)
		world.entities = ids.snapshot()
		records.append(
			{
				"player_id": pid,
				"lord_id": actor.attributes.lord_id,
				"lord_entity_id": actor.id,
				"cost": cost,
				"paid_value": paid_value,
				"shortfall": maxi(0, cost - paid_value),
				"card_ids": selected,
				"card_values": values,
				"circle_id": circle_id,
				"circle_exerted": BLOOD_OFFERING_INTEGRITY if not circle_id.is_empty() else 0
			}
		)
	return {"action": "resolved", "records": records}


static func _shuffle(cards: Array, seed_value: String, purpose: String) -> void:
	for index in range(cards.size() - 1, 0, -1):
		var pick: int = int(Rng.draw(seed_value, VERSION, purpose, index, index + 1).value)
		var held = cards[index]
		cards[index] = cards[pick]
		cards[pick] = held


static func valid(world: Dictionary) -> bool:
	var state = world.data.get("game_economy")
	return (
		typeof(state) == TYPE_DICTIONARY
		and state.get("version") == VERSION
		and state.get("opening_dealt") == true
		and Data.is_integer(state.get("draw_round"))
		and state.draw_round >= 0
		and world.data.card_zones.hand_limit == HAND_LIMIT
		and _opening_valid(world, state.get("opening"))
		and pending_valid(world, state)
	)


static func _opening_valid(world: Dictionary, opening) -> bool:
	if (
		typeof(opening) != TYPE_DICTIONARY
		or opening.keys().size() != 3
		or opening.get("active_castle_count") != STARTING_CASTLES
		or typeof(opening.get("active_castle_ids")) != TYPE_ARRAY
		or opening.active_castle_ids.size() != 2
		or typeof(opening.get("summons")) != TYPE_ARRAY
		or opening.summons.size() != 2
	):
		return false
	var ids = Ids.new()
	if ids.restore(world.entities).action == "invalid":
		return false
	var used = world.entities.get("used_ids", [])
	var all_cards: Dictionary = {}
	for pid in [0, 1]:
		var castles = opening.active_castle_ids[pid]
		if typeof(castles) != TYPE_ARRAY or castles.size() != STARTING_CASTLES:
			return false
		var expected_circle_id: String = ""
		for slot in range(STARTING_CASTLES):
			if castles[slot] != Slots.castle_id(pid, slot) or castles[slot] not in used:
				return false
			var castle: Dictionary = ids.get_entity(castles[slot])
			if (
				castle.is_empty()
				or castle.kind != "castle"
				or castle.owner != pid
				or castle.attributes.get("castle_slot") != slot
			):
				return false
			if (
				expected_circle_id.is_empty()
				and castle.attributes.get("castle_type") == "SummoningCircle"
			):
				expected_circle_id = castle.id
		var record = opening.summons[pid]
		if (
			typeof(record) != TYPE_DICTIONARY
			or record.keys().size() != 10
			or record.get("player_id") != pid
			or record.get("lord_id") != world.players[pid].lord_id
			or record.get("lord_entity_id") != world.players[pid].lord_entity_id
			or not Resummon.COSTS.has(record.get("lord_id"))
			or not Data.is_integer(record.get("cost"))
			or not Data.is_integer(record.get("paid_value"))
			or not Data.is_integer(record.get("shortfall"))
			or typeof(record.get("card_ids")) != TYPE_ARRAY
			or typeof(record.get("card_values")) != TYPE_ARRAY
			or record.card_ids.size() != record.card_values.size()
			or typeof(record.get("circle_id")) != TYPE_STRING
			or not Data.is_integer(record.get("circle_exerted"))
		):
			return false
		var expected_cost: int = int(Resummon.COSTS[record.lord_id])
		if record.circle_id != expected_circle_id:
			return false
		if not expected_circle_id.is_empty():
			if record.circle_exerted != BLOOD_OFFERING_INTEGRITY:
				return false
			expected_cost = maxi(0, expected_cost - BLOOD_OFFERING_DISCOUNT)
		elif record.circle_exerted != 0:
			return false
		if record.cost != expected_cost:
			return false
		var sorted: Array = record.card_values.duplicate()
		sorted.sort()
		if record.card_values != sorted:
			return false
		var total: int = 0
		for index in range(record.card_ids.size()):
			var card_id = record.card_ids[index]
			var value = record.card_values[index]
			if (
				typeof(card_id) != TYPE_STRING
				or card_id.is_empty()
				or card_id not in used
				or all_cards.has(card_id)
				or not Data.is_integer(value)
				or value < 1
				or value > 5
			):
				return false
			all_cards[card_id] = true
			total += value
		if (
			record.paid_value != total
			or record.shortfall != maxi(0, record.cost - total)
			or (
				total >= record.cost
				and not record.card_values.is_empty()
				and total - int(record.card_values[-1]) >= record.cost
			)
		):
			return false
	return true


static func on_hook(context: Dictionary) -> Dictionary:
	if context.hook != Timeline.ROUND_START_AUTOMATIC:
		return {"action": "resolved", "world": context.world, "events": []}
	if not valid(context.world) or not context.world.data.game_economy.stockpile_pending.is_empty() or context.world.data.game_economy.draw_round != context.round - 1:
		return Data.invalid("game_draw_clock_invalid")
	var world: Dictionary = context.world.duplicate(true)
	world.data.game_economy.draw_round = context.round
	world.data.game_economy.draw_player = 0
	return continue_draw(world, context.seed, context.round)


static func pending_valid(world: Dictionary, state: Dictionary) -> bool:
	if not Data.is_integer(state.get("draw_player")) or state.draw_player < 0 or state.draw_player > 2 or typeof(state.get("stockpile_pending")) != TYPE_DICTIONARY:
		return false
	var pending: Dictionary = state.stockpile_pending
	if pending.is_empty():
		return state.draw_player == 2
	if pending.get("player_id") not in [0, 1] or state.draw_player != pending.player_id + 1 or state.draw_round < 1:
		return false
	if not Cards.can_discard_from_hand(world.data.card_zones.hands[pending.player_id], pending.get("card_ids"), 2):
		return false
	return active_stockpile(world, pending.player_id).get("id") == pending.get("castle_id")


static func active_stockpile(world: Dictionary, pid: int) -> Dictionary:
	var choices: Array = world.entities.entities.filter(func(e): return e.kind == "castle" and e.owner == pid and e.attributes.get("castle_type") == "Stockpile" and Structures.operational(e))
	choices.sort_custom(func(a, b): return a.attributes.castle_slot < b.attributes.castle_slot)
	return {} if choices.is_empty() else choices[0]


# Stop between seats when a private choice is needed: its discard must be
# available for recycling before the next player's ordinary draw begins.
static func continue_draw(world: Dictionary, seed_value: String, round_number: int) -> Dictionary:
	var events: Array = []
	var state: Dictionary = world.data.game_economy
	while state.draw_player < 2:
		var pid: int = state.draw_player
		for index in range(ROUND_CARDS):
			var drawn: Dictionary = Cards.draw(world, pid, seed_value, "round:%d:draw:%d:%d" % [round_number, pid, index])
			if drawn.action == "invalid":
				return drawn
			events.append(DrawEvents._draw_event("ROUND_DRAW", drawn))
		state.draw_player += 1
		var stockpile: Dictionary = active_stockpile(world, pid)
		if stockpile.is_empty():
			continue
		var offered: Array = []
		for index in range(2):
			var drawn: Dictionary = Cards.draw(world, pid, seed_value, "round:%d:stockpile:%d:%d" % [round_number, pid, index])
			if drawn.action == "invalid":
				return drawn
			events.append(DrawEvents._draw_event("STOCKPILE_DRAW", drawn))
			if drawn.drawn:
				offered.append(drawn.card_id)
		if offered.size() == 2:
			state.stockpile_pending = {"player_id": pid, "castle_id": stockpile.id, "card_ids": offered}
			break
	return {"action": "resolved", "world": world, "events": events}


static func choose(context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	if context.hook != Timeline.PRESENT_PUBLIC_STATE or not valid(world):
		return Data.invalid("stockpile_choice_window_closed")
	var pending: Dictionary = world.data.game_economy.stockpile_pending
	var choice: Dictionary = context.choice
	if pending.is_empty() or context.player_id != pending.player_id or choice.keys().size() != 1 or choice.get("keep_id") not in pending.card_ids:
		return Data.invalid("stockpile_choice_invalid")
	var discarded: String = pending.card_ids[1] if choice.keep_id == pending.card_ids[0] else pending.card_ids[0]
	var result: Dictionary = Cards.discard(world, context.player_id, [discarded])
	if result.action == "invalid":
		return result
	world.data.game_economy.stockpile_pending = {}
	var event: Dictionary = {"type": "STOCKPILE_SELECTED", "text": "Stockpile selection resolved.", "data": {"player_id": context.player_id, "castle_id": pending.castle_id, "discard_id": discarded}}
	var private_event: Dictionary = event.duplicate(true)
	private_event.data["keep_id"] = choice.keep_id
	var views: Array = [event, event]
	views[context.player_id] = private_event
	var continued: Dictionary = continue_draw(world, context.seed, context.round)
	if continued.action != "invalid":
		continued.events.push_front({"event": private_event, "views": views})
	return continued
