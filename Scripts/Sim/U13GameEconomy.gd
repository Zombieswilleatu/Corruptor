extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Market = preload("res://Scripts/Sim/U13GameMarket.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const DrawEvents = preload("res://Scripts/Sim/U13Gremory.gd")
const VERSION: String = "U13_GAME_ECONOMY_V3"
# Transcribed from SeededGameSetup, GameSetup, RoundEngine and RuleConfig.
# No old Lord callbacks or sequential Python RNG enter the U13 rules path.
const SUITS: Array = ["Butcher", "Penitent", "Vulture", "Wright"]
const COUNTS: Array = [4, 4, 4, 3, 3]
const OPENING_CARDS: int = 5
const ROUND_CARDS: int = 5
const HAND_LIMIT: int = 10


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
	world.data["castle_defense_profile"] = preload("res://Scripts/Sim/U13CastleDefenses.gd").VERSION
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
	world.data["game_economy"] = {"version": VERSION, "opening_dealt": true, "draw_round": 0, "draw_player": 2, "stockpile_pending": {}}
	Market.initialize(world)
	# Setup draws are already represented in the initial saved state. Private
	# identities are exposed only by the existing per-player projection.
	for pid in [0, 1]:
		for index in range(OPENING_CARDS):
			var drawn: Dictionary = Cards.draw(world, pid, seed_value, "opening:%d:%d" % [pid, index])
			if drawn.action == "invalid" or not drawn.drawn:
				return Data.invalid("game_opening_deal_failed")
	return {"action": "game_opening", "world": world}


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
		and pending_valid(world, state)
	)


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
