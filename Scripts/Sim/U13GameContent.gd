extends "res://Scripts/Sim/U13Kanifous.gd"

# Veil redesign hold (2026-09-12): threshold penalties and automatic drift
# stay off. Tear accounting, Dominion rites and Lord Breach powers remain live.
# These report the current profile; no Veil effect resolver is installed.
const VEIL_EFFECTS_ENABLED: bool = false
const VEIL_DRIFT_ENABLED: bool = false
const BATCH_EVENTS_VERSION: String = "U13_BATCH_EVENTS_V1"
const BATCH_SAMPLE_EVENTS: Array = ["MARCHING_TICK", "KRONI_ACTOR_TICK"]
var batch_events: bool = false

const Victory = preload("res://Scripts/Sim/U13Victory.gd")
const Plunder = preload("res://Scripts/Sim/U13Plunder.gd")
const Throne = preload("res://Scripts/Sim/U13VacantThrone.gd")

const Rites = preload("res://Scripts/Sim/U13DominionRites.gd")

const Fracture = preload("res://Scripts/Sim/U13Fracture.gd")

const Sigils = preload("res://Scripts/Sim/U13Sigils.gd")
const Market = preload("res://Scripts/Sim/U13GameMarket.gd")
const Economy = preload("res://Scripts/Sim/U13GameEconomy.gd")
const CastleDefenses = preload("res://Scripts/Sim/U13CastleDefenses.gd")


func create_combat_match(compact_events: bool = false):
	batch_events = compact_events
	var validators: Dictionary = {}
	var resolvers: Dictionary = {}
	for power in rules():
		validators[power] = Callable(self, "validate")
		resolvers[power] = Callable(self, "resolve")
	return MatchOwner.new(Victory.VERSION + ":" + Plunder.VERSION + ":" + Marching.Ranged.VERSION + ":" + Throne.VERSION + ":" + Rites.VERSION + ":" + Fracture.VERSION + ":" + Sigils.VERSION + ":" + Conduit.VERSION + ":" + Market.VERSION + ":" + CastleDefenses.VERSION + ":" + Economy.VERSION + ":" + Lamp.VERSION + ":" + Essence.VERSION + ":" + KRONI_POLICY + ":" + ODRADEK_POLICY + ":" + POLICY + (":" + BATCH_EVENTS_VERSION if batch_events else ""), rules(), validators, resolvers, Callable(self, "project"), Callable(), Callable(self, "on_hook"), self, Callable(self, "valid_world"), Callable(self, "accept_order"), Callable(), Callable(Rites, "legal_orders"))


func valid_world(world: Dictionary) -> bool:
	return super.valid_world(world) and Victory.valid(world) and Plunder.valid(world) and Throne.valid(world) and Rites.valid(world) and Fracture.valid(world) and Economy.valid(world) and Market.valid(world) and Sigils.valid(world) and world.data.get("blood_conduit_profile") == Conduit.VERSION and world.data.get("castle_defense_profile") == CastleDefenses.VERSION


func react(raw: Dictionary, fact: Dictionary, seed_value: String, player_order: Array) -> Dictionary:
	var result: Dictionary = super.react(raw, fact, seed_value, player_order)
	if result.action == "invalid" or fact.type != "LORD_BANISHED":
		return result
	if not Throne.note_banishment(result.world, fact):
		return Data.invalid("vacant_throne_banishment_clock_invalid")
	var fractured: Dictionary = Fracture.resolve(result.world, fact, seed_value, player_order, Callable(self, "react"))
	if fractured.action == "invalid":
		return fractured
	fractured.events = result.events + fractured.events
	return fractured


func on_hook(context: Dictionary) -> Dictionary:
	if context.hook == Timeline.PRESENT_PUBLIC_STATE and (not context.world.data.game_economy.stockpile_pending.is_empty() or context.world.data.game_market.seat != 2):
		return Data.invalid("development_choice_required")
	var ordinary_context: Dictionary = context.duplicate(true)
	if context.hook == Timeline.ROUND_START_SCHEDULED and not Throne.begin(ordinary_context.world, context.round):
		return Data.invalid("vacant_throne_round_clock_invalid")
	ordinary_context.combat_orders = [Rites.strip(context.combat_orders[0]), Rites.strip(context.combat_orders[1])]
	var rite_events: Array = []
	if context.hook == Timeline.DEVELOPMENT:
		var rites: Dictionary = Rites.resolve(context)
		if rites.action == "invalid":
			return rites
		ordinary_context.world = rites.world
		rite_events = rites.events
	var sigils: Dictionary = Sigils.on_hook(ordinary_context)
	if sigils.action == "invalid":
		return sigils
	var prepared: Dictionary = ordinary_context.duplicate()
	prepared.world = sigils.world
	var result: Dictionary = super.on_hook(prepared)
	if result.action != "invalid":
		result.events = rite_events + sigils.events + result.events
		result.events.append_array(Plunder.clear_castle_sigils(result.world, context.round))
		Throne.observe(result.world)
		if context.hook == Timeline.AFTERMATH:
			result.world.data.dominion_rites.orders = [null, null]
			var settled: Dictionary = Throne.finish(result.world, context.round)
			if settled.action == "invalid":
				return settled
			result.events.append_array(settled.events)
			var victory: Dictionary = Victory.finish(result.world, context.round)
			if victory.action == "invalid":
				return victory
			result.events.append_array(victory.events)
	if batch_events and result.action != "invalid":
		result.events = result.events.filter(func(row): return row.event.type not in BATCH_SAMPLE_EVENTS)
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
		if not Victory.snapshot_valid(context):
			return Data.invalid("victory_snapshot_invalid")
		if not Plunder.snapshot_valid(context):
			return Data.invalid("plunder_snapshot_invalid")
		if not Throne.snapshot_valid(context):
			return Data.invalid("vacant_throne_snapshot_invalid")
		if not Rites.snapshot_valid(context):
			return Data.invalid("rites_snapshot_invalid")
		if context.order.get("action") == "Hunt" and context.next_hook_index > Timeline.hook_rank(Timeline.COMBAT_RESOLUTION):
			var banishment: String = Data.instance_id("battle", str(context.round), "hunt:%d:lord:%s" % [context.player_id, context.order.target_id])
			if context.world.data.get("battle_commands", {}).has(banishment):
				var fracture: Dictionary = context.world.data.fracture_events.get(banishment, {})
				if fracture.is_empty() or fracture.player_id != 1 - context.player_id or (context.order.has("fracture_target") and fracture.category != context.order.fracture_target):
					return Data.invalid("fracture_snapshot_order_invalid")
		for entry in [["aged_round", Timeline.ROUND_START_AUTOMATIC], ["created_round", Timeline.COMMITMENT_REVEAL]]:
			var sigil_round: int = context.round - (1 if context.next_hook_index <= Timeline.hook_rank(entry[1]) else 0)
			if context.world.data.sigil_lifecycle[entry[0]] != sigil_round:
				return Data.invalid("sigil_snapshot_clock_invalid")
		var expected: int = context.round - (1 if context.next_hook_index <= Timeline.hook_rank(Timeline.ROUND_START_AUTOMATIC) else 0)
		if context.world.data.game_economy.draw_round != expected:
			return Data.invalid("game_draw_snapshot_clock_invalid")
		if not context.world.data.game_economy.stockpile_pending.is_empty() and context.next_hook_index != Timeline.hook_rank(Timeline.PRESENT_PUBLIC_STATE):
			return Data.invalid("stockpile_snapshot_window_invalid")
		var market: Dictionary = context.world.data.game_market
		var ready: bool = context.next_hook_index > Timeline.hook_rank(Timeline.ROUND_START_AUTOMATIC) and context.world.data.game_economy.stockpile_pending.is_empty()
		if market.round != context.round - (0 if ready else 1) or (market.seat != 2 and context.next_hook_index != Timeline.hook_rank(Timeline.PRESENT_PUBLIC_STATE)):
			return Data.invalid("market_snapshot_clock_invalid")
	var ordinary: Dictionary = context.duplicate(true)
	ordinary.order = Rites.strip(context.order)
	if context.phase != "snapshot":
		var reserved: Dictionary = Rites.reserve(context)
		if reserved.action == "invalid":
			return reserved
		ordinary.world = reserved.world
	return super.accept_order(ordinary)


func project(world: Dictionary, player_id: int) -> Dictionary:
	var result: Dictionary = super.project(world, player_id)
	result["victory"] = world.data.victory.duplicate(true)
	result["plunder"] = world.data.plunder.duplicate(true)
	result["vacant_throne"] = world.data.vacant_throne.duplicate(true)
	result["dominion_rites"] = {"version": Rites.VERSION, "invocation_rounds": world.data.dominion_rites.invocation_rounds.duplicate(), "resolved_round": world.data.dominion_rites.resolved_round}
	result["veil_total"] = Rites.veil(world)
	result["veil_effects_enabled"] = VEIL_EFFECTS_ENABLED
	result["veil_drift_enabled"] = VEIL_DRIFT_ENABLED
	result["game_economy"] = world.data.game_economy.duplicate(true)
	var pending: Dictionary = result.game_economy.stockpile_pending
	if not pending.is_empty() and pending.player_id != player_id:
		result.game_economy.stockpile_pending = {"player_id": pending.player_id}
	result["sigil_lifecycle"] = world.data.sigil_lifecycle.duplicate(true)
	result["blood_conduit_profile"] = Conduit.VERSION
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


func is_finished(world: Dictionary) -> bool:
	return world.data.victory.winner != -1
