extends "res://Scripts/Sim/U13Kanifous.gd"

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
	return super.valid_world(world) and Economy.valid(world) and world.data.get("castle_defense_profile") == CastleDefenses.VERSION


func on_hook(context: Dictionary) -> Dictionary:
	var result: Dictionary = super.on_hook(context)
	if result.action == "invalid" or context.hook != Timeline.ROUND_START_AUTOMATIC:
		return result
	var ordinary: Dictionary = context.duplicate(true)
	ordinary.world = result.world
	var economy: Dictionary = Economy.on_hook(ordinary)
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
	return super.accept_order(context)


func project(world: Dictionary, player_id: int) -> Dictionary:
	var result: Dictionary = super.project(world, player_id)
	result["game_economy"] = world.data.game_economy.duplicate(true)
	result["castle_defense_profile"] = CastleDefenses.VERSION
	return result
