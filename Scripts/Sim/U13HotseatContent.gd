extends "res://Scripts/Sim/U13GameContent.gd"
const HotEconomy = preload("res://Scripts/Sim/U13HotseatEconomy.gd")
const HotMatch = preload("res://Scripts/Sim/U13HotseatMatch.gd")

func create_combat_match(compact_events: bool = false):
	var base = super.create_combat_match(compact_events)
	var owner = HotMatch.new(base._policy_id + ":" + HotEconomy.VERSION, base._rules, base._validators, base._resolvers, base._projector, base._hook_handler, base._context_hook, self, base._world_validator, base._order_handler, base._order_screen, base._order_validator)
	owner._cache_world_validation = true
	return owner
func valid_world(world: Dictionary) -> bool:
	return HotEconomy.valid(world) and super.valid_world(world)
func _draw_game_economy(context: Dictionary) -> Dictionary:
	return HotEconomy.begin(context)
func _begin_market(result: Dictionary, seed_value: String, round_number: int) -> Dictionary:
	return HotEconomy.begin_market(result, seed_value, round_number)
func resolve_choice(context: Dictionary) -> Dictionary:
	return HotEconomy.choose(context)
func accept_order(context: Dictionary) -> Dictionary:
	if context.phase != "snapshot": return super.accept_order(context)
	# The hotseat profile also permits a second-seat economy pause at
	# SUBMISSION_LOCK. Normalize only the legacy clock check's detached input.
	var checked: Dictionary = context.duplicate(true)
	var economy: Dictionary = checked.world.data.game_economy
	var market: Dictionary = checked.world.data.game_market
	if checked.next_hook_index == Timeline.hook_rank(Timeline.SUBMISSION_LOCK):
		economy.stockpile_pending = {}
		market.seat = 2
	if not economy.stockpile_pending.is_empty() and market.round == context.round:
		market.round = context.round - 1
	return super.accept_order(checked)
