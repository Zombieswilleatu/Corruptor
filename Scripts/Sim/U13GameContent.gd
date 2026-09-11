extends "res://Scripts/Sim/U13Kanifous.gd"

const Market = preload("res://Scripts/Sim/U13GameMarket.gd")
const Economy = preload("res://Scripts/Sim/U13GameEconomy.gd")
const CastleDefenses = preload("res://Scripts/Sim/U13CastleDefenses.gd")


func create_combat_match():
	var validators: Dictionary = {}
	var resolvers: Dictionary = {}
	for power in rules():
		validators[power] = Callable(self, "validate")
		resolvers[power] = Callable(self, "resolve")
	return MatchOwner.new(CastleDefenses.VERSION + ":" + Economy.VERSION + ":" + Lamp.VERSION + ":" + Essence.VERSION + ":" + KRONI_POLICY + ":" + ODRADEK_POLICY + ":" + POLICY, rules(), validators, resolvers, Callable(self, "project"), Callable(), Callable(self, "on_hook"), self, Callable(self, "valid_world"), Callable(self, "accept_order"), Callable(), Callable(Guards, "legal_orders"))


func valid_world(world: Dictionary) -> bool:
	return super.valid_world(world) and Economy.valid(world) and Market.valid(world) and world.data.get("castle_defense_profile") == CastleDefenses.VERSION


func on_hook(context: Dictionary) -> Dictionary:
	if context.hook == Timeline.PRESENT_PUBLIC_STATE and (not context.world.data.game_economy.stockpile_pending.is_empty() or context.world.data.game_market.seat != 2):
		return Data.invalid("development_choice_required")
	var result: Dictionary = super.on_hook(context)
	if result.action == "invalid" or context.hook != Timeline.ROUND_START_AUTOMATIC:
		return result
	var ordinary: Dictionary = context.duplicate(true)
	ordinary.world = result.world
	var economy: Dictionary = Economy.on_hook(ordinary)
	if economy.action == "invalid":
		return economy
	if economy.world.data.game_economy.stockpile_pending.is_empty():
		economy = _begin_market(economy, context.seed, context.round)
		if economy.action == "invalid":
			return economy
	result.world = economy.world
	result.events.append_array(economy.events)
	return result


func accept_order(context: Dictionary) -> Dictionary:
	if context.phase == "snapshot":
		var expected: int = context.round - (1 if context.next_hook_index <= Timeline.hook_rank(Timeline.ROUND_START_AUTOMATIC) else 0)
		if context.world.data.game_economy.draw_round != expected:
			return Data.invalid("game_draw_snapshot_clock_invalid")
		if not context.world.data.game_economy.stockpile_pending.is_empty() and context.next_hook_index != Timeline.hook_rank(Timeline.PRESENT_PUBLIC_STATE):
			return Data.invalid("stockpile_snapshot_window_invalid")
		var market: Dictionary = context.world.data.game_market
		var ready: bool = context.next_hook_index > Timeline.hook_rank(Timeline.ROUND_START_AUTOMATIC) and context.world.data.game_economy.stockpile_pending.is_empty()
		if market.round != context.round - (0 if ready else 1) or (market.seat != 2 and context.next_hook_index != Timeline.hook_rank(Timeline.PRESENT_PUBLIC_STATE)):
			return Data.invalid("market_snapshot_clock_invalid")
	return super.accept_order(context)


func project(world: Dictionary, player_id: int) -> Dictionary:
	var result: Dictionary = super.project(world, player_id)
	result["game_economy"] = world.data.game_economy.duplicate(true)
	var pending: Dictionary = result.game_economy.stockpile_pending
	if not pending.is_empty() and pending.player_id != player_id:
		result.game_economy.stockpile_pending = {"player_id": pending.player_id}
	result["game_market"] = world.data.game_market.duplicate(true)
	result["market"] = world.data.card_zones.market.duplicate()
	result["castle_defense_profile"] = CastleDefenses.VERSION
	return result


func resolve_choice(context: Dictionary) -> Dictionary:
	if context.choice.has("market"):
		return Market.choose(context)
	var chosen: Dictionary = Economy.choose(context)
	if chosen.action != "invalid" and chosen.world.data.game_economy.stockpile_pending.is_empty():
		return _begin_market(chosen, context.seed, context.round)
	return chosen

func _begin_market(result: Dictionary, seed_value: String, round_number: int) -> Dictionary:
	var market: Dictionary = Market.begin(result.world, seed_value, round_number)
	if market.action == "invalid":
		return market
	result.world = market.world
	result.events.append_array(market.events)
	return result
