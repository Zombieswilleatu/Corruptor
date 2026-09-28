extends RefCounted

const Economy = preload("res://Scripts/Sim/U13GameEconomy.gd")
const Market = preload("res://Scripts/Sim/U13GameMarket.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Draw = preload("res://Scripts/Sim/U13Gremory.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const VERSION: String = "U13_HOTSEAT_ECONOMY_V1"

static func initialize(world: Dictionary) -> void:
	world.data["hotseat_economy"] = {"version": VERSION, "round": 0, "first": 0, "actor": 0, "stage": "idle", "done": [false, false]}

static func valid(world: Dictionary) -> bool:
	var state = world.data.get("hotseat_economy")
	return typeof(state) == TYPE_DICTIONARY and state.get("version") == VERSION and Data.is_integer(state.get("round")) and state.round >= 0 and state.get("first") in [0, 1] and state.get("actor") in [0, 1] and state.get("stage") in ["idle", "economy", "planning", "complete"] and typeof(state.get("done")) == TYPE_ARRAY and state.done.size() == 2 and typeof(state.done[0]) == TYPE_BOOL and typeof(state.done[1]) == TYPE_BOOL

static func begin(context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	if not valid(world) or world.data.game_economy.draw_round != context.round - 1:
		return Data.invalid("hotseat_draw_clock_invalid")
	var first: int = (int(context.round) - 1) % 2
	world.data.hotseat_economy = {"version": VERSION, "round": context.round, "first": first, "actor": first, "stage": "economy", "done": [false, false]}
	world.data.game_economy.draw_round = context.round
	world.data.game_market.first_player = first
	return draw_seat(world, context.seed, context.round, first)

# Each seat's draw and Stockpile choice occur on its own turn. A first
# player's discarded Stockpile card can therefore recycle on the second draw.
static func draw_seat(world: Dictionary, seed_value: String, round_number: int, pid: int) -> Dictionary:
	var events: Array = []
	for index in range(Economy.ROUND_CARDS):
		var drawn: Dictionary = Cards.draw(world, pid, seed_value, "round:%d:draw:%d:%d" % [round_number, pid, index])
		if drawn.action == "invalid": return drawn
		events.append(Draw._draw_event("ROUND_DRAW", drawn))
	world.data.game_economy.draw_player = 2
	var stockpile: Dictionary = Economy.active_stockpile(world, pid)
	if not stockpile.is_empty():
		var offered: Array = []
		for index in range(2):
			var drawn: Dictionary = Cards.draw(world, pid, seed_value, "round:%d:stockpile:%d:%d" % [round_number, pid, index])
			if drawn.action == "invalid": return drawn
			events.append(Draw._draw_event("STOCKPILE_DRAW", drawn))
			if drawn.drawn: offered.append(drawn.card_id)
		if offered.size() == 2:
			world.data.game_economy.draw_player = pid + 1
			world.data.game_economy.stockpile_pending = {"player_id": pid, "castle_id": stockpile.id, "card_ids": offered}
	return {"action": "resolved", "world": world, "events": events}

static func begin_market(result: Dictionary, seed_value: String, round_number: int) -> Dictionary:
	var world: Dictionary = result.world
	if world.data.game_market.round < round_number:
		var begun: Dictionary = Market.begin(world, seed_value, round_number)
		if begun.action == "invalid": return begun
		result.events.append_array(begun.events)
	world.data.game_market.seat = world.data.hotseat_economy.actor
	return result

static func choose(context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	if not valid(world) or context.hook not in [Timeline.PRESENT_PUBLIC_STATE, Timeline.SUBMISSION_LOCK]: return Data.invalid("hotseat_choice_closed")
	var state: Dictionary = world.data.hotseat_economy
	var pid: int = context.player_id
	if pid != state.actor: return Data.invalid("hotseat_wrong_player")
	if context.choice == {"hotseat_handoff": true}:
		if context.hook != Timeline.SUBMISSION_LOCK or state.stage != "planning" or pid != state.first: return Data.invalid("hotseat_handoff_closed")
		state.actor = 1 - pid
		state.stage = "economy"
		var drawn: Dictionary = draw_seat(world, context.seed, context.round, state.actor)
		if drawn.action == "invalid": return drawn
		return begin_market(drawn, context.seed, context.round) if drawn.world.data.game_economy.stockpile_pending.is_empty() else drawn
	if state.stage != "economy": return Data.invalid("hotseat_economy_complete")
	var pending: Dictionary = world.data.game_economy.stockpile_pending
	if not pending.is_empty():
		if context.choice.keys().size() != 1 or context.choice.get("keep_id") not in pending.card_ids: return Data.invalid("stockpile_choice_invalid")
		var discarded: String = pending.card_ids[1] if context.choice.keep_id == pending.card_ids[0] else pending.card_ids[0]
		var result: Dictionary = Cards.discard(world, pid, [discarded])
		if result.action == "invalid": return result
		world.data.game_economy.stockpile_pending = {}
		world.data.game_economy.draw_player = 2
		var event: Dictionary = {"type": "STOCKPILE_SELECTED", "text": "Stockpile selection resolved.", "data": {"player_id": pid, "castle_id": pending.castle_id, "discard_id": discarded}}
		var private_event: Dictionary = event.duplicate(true)
		private_event.data["keep_id"] = context.choice.keep_id
		var views: Array = [event, event]
		views[pid] = private_event
		return begin_market({"action": "resolved", "world": world, "events": [{"event": private_event, "views": views}]}, context.seed, context.round)
	var choice_context: Dictionary = context.duplicate(true)
	choice_context.world = world
	choice_context.hook = Timeline.PRESENT_PUBLIC_STATE
	var chosen: Dictionary = Market.choose(choice_context)
	if chosen.action == "invalid": return chosen
	chosen.world.data.game_market.seat = 2
	chosen.world.data.hotseat_economy.done[pid] = true
	chosen.world.data.hotseat_economy.stage = "planning" if pid == state.first else "complete"
	return chosen
