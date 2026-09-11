extends RefCounted

const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const VERSION: String = "U13_GAME_MARKET_V1"
const SIZE: int = 3

static func initialize(world: Dictionary) -> void:
	world.data["game_market"] = {"version": VERSION, "round": 0, "seat": 2}
	world.data.card_zones["market"] = []
	world.data.card_zones["market_reserve"] = []
	for index in range(SIZE):
		world.data.card_zones.market.append(world.data.card_zones.deck.pop_back())

static func valid(world: Dictionary) -> bool:
	var state = world.data.get("game_market")
	var zones: Dictionary = world.data.card_zones
	return typeof(state) == TYPE_DICTIONARY and state.get("version") == VERSION and Data.is_integer(state.get("round")) and state.round >= 0 and Data.is_integer(state.get("seat")) and state.seat >= 0 and state.seat <= 2 and typeof(zones.get("market")) == TYPE_ARRAY and zones.market.size() <= SIZE and zones.get("market_reserve") == [] and (state.round > 0 or state.seat == 2)

static func public_event(type: String, data: Dictionary) -> Dictionary:
	var event: Dictionary = {"type": type, "text": type, "data": data}
	return {"event": event, "views": [event, event]}

static func begin(world: Dictionary, seed_value: String, round_number: int) -> Dictionary:
	if not valid(world) or world.data.game_market.round != round_number - 1 or world.data.game_market.seat != 2:
		return Data.invalid("market_round_clock_invalid")
	var zones: Dictionary = world.data.card_zones
	var events: Array = []
	if round_number > 1:
		zones.market_reserve = zones.market.duplicate()
		zones.market.clear()
		var old: Array = zones.market_reserve.duplicate()
		for index in range(SIZE):
			var drawn: Dictionary = Cards.take_neutral(world, seed_value, "market:%d:%d" % [round_number, index])
			if drawn.action == "invalid":
				return drawn
			if drawn.card_id.is_empty() and not zones.market_reserve.is_empty():
				_bottom(zones)
				drawn = Cards.take_neutral(world, seed_value, "market:%d:reuse:%d" % [round_number, index])
			if drawn.card_id.is_empty():
				break
			zones.market.append(drawn.card_id)
		_bottom(zones)
		events.append(public_event("MARKET_REFRESHED", {"round": round_number, "old_ids": old, "card_ids": zones.market.duplicate()}))
	world.data.game_market.round = round_number
	world.data.game_market.seat = 0
	return {"action": "resolved", "world": world, "events": events}

static func _bottom(zones: Dictionary) -> void:
	for id in zones.market_reserve:
		zones.deck.push_front(id)
	zones.market_reserve.clear()

static func choose(context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	if context.hook != Timeline.PRESENT_PUBLIC_STATE or not valid(world) or not world.data.game_economy.stockpile_pending.is_empty() or world.data.game_market.round != context.round or world.data.game_market.seat != context.player_id:
		return Data.invalid("market_choice_window_closed")
	var choice: Dictionary = context.choice
	var zones: Dictionary = world.data.card_zones
	var pid: int = context.player_id
	var passed: bool = choice == {"market": "Pass"}
	if not passed:
		if choice.keys().size() != 3 or choice.get("market") != "Swap" or choice.get("take_id") not in zones.market or choice.get("give_id") not in zones.hands[pid]:
			return Data.invalid("market_swap_invalid")
		zones.market.erase(choice.take_id)
		zones.hands[pid].erase(choice.give_id)
		zones.hands[pid].append(choice.take_id)
		zones.market.append(choice.give_id)
		var ids = Ids.new()
		ids.restore(world.entities)
		ids.update(choice.take_id, pid, ids.get_entity(choice.take_id).attributes)
		ids.update(choice.give_id, -1, ids.get_entity(choice.give_id).attributes)
		world.entities = ids.snapshot()
	world.data.game_market.seat += 1
	var data: Dictionary = {"player_id": pid, "round": context.round, "choice": choice.duplicate(true)}
	return {"action": "resolved", "world": world, "events": [public_event("MARKET_PASSED" if passed else "MARKET_SWAPPED", data)]}
