extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const DrawEvents = preload("res://Scripts/Sim/U13Gremory.gd")
const VERSION: String = "U13_GAME_ECONOMY_V1"
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
	world.data["game_economy"] = {"version": VERSION, "opening_dealt": true, "draw_round": 0}
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
	)


static func on_hook(context: Dictionary) -> Dictionary:
	if context.hook != Timeline.ROUND_START_AUTOMATIC:
		return {"action": "resolved", "world": context.world, "events": []}
	if not valid(context.world) or context.world.data.game_economy.draw_round != context.round - 1:
		return Data.invalid("game_draw_clock_invalid")
	var world: Dictionary = context.world.duplicate(true)
	var events: Array = []
	# Seat order matches the old draw step. Resolution/Reflex order must not
	# change who receives which hidden card from the shared deck.
	for pid in [0, 1]:
		for index in range(ROUND_CARDS):
			var drawn: Dictionary = Cards.draw(world, pid, context.seed, "round:%d:draw:%d:%d" % [context.round, pid, index])
			if drawn.action == "invalid":
				return drawn
			events.append(DrawEvents._draw_event("ROUND_DRAW", drawn))
	world.data.game_economy.draw_round = context.round
	return {"action": "resolved", "world": world, "events": events}
