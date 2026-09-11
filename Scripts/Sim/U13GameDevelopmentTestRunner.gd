extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

const Development = preload("res://Scripts/Sim/U13GameDevelopment.gd")
const Construction = preload("res://Scripts/Sim/U13Construction.gd")
const Resummon = preload("res://Scripts/Sim/U13Resummoning.gd")

func run() -> void:
	construction_lifecycle()
	return_and_deploy()
	reconstruction()
	print("U13 game development failures: %d" % failures)
	quit(failures)

func choice(action: String, id: String, cards: Array = []) -> Dictionary:
	return {"action": action, "target_id": id, "card_ids": cards, "use_repair_token": false}

func entity(game, id: String) -> Dictionary:
	return game.snapshot().world.entities.entities.filter(func(e): return e.id == id)[0]

func finish(game, order: Dictionary) -> bool:
	if not check(game.submit([{"powers": [], "order": order}, {"powers": [], "order": {}}]).action != "invalid", "whole Development submission accepted"):
		return false
	if not check(game.step().action != "invalid", "joint submission lock"):
		return false
	var restored = Game.new()
	if not check(restored.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", "restore sealed Development choices"):
		return false
	if not check(game.finish_round().action != "invalid" and restored.finish_round().action != "invalid", "Development and remaining hooks finish"):
		return false
	return check(game.snapshot() == restored.snapshot(), "sealed choices replay to identical state/events")

func construction_lifecycle() -> void:
	var game = Game.new()
	if not check(game.start("development-build", ["Gremory", "Deimos"], [Slots.TYPES, Slots.TYPES]).action != "invalid", "construction game starts"):
		return
	var project: String = Slots.castle_id(0, 3)
	for round_number in range(1, 6):
		if not check(planning_with_market_passes(game).action != "invalid", "Development planning %d" % round_number):
			return
		var order: Dictionary = {}
		if round_number == 1:
			var hand: Array = game.player_view(0).world.hand
			order = {"castle_action": choice("Construct", project), "action": "Ward", "lane": "Lord", "card_ids": hand.slice(0, 2), "guard_moves": [{"card_id": hand[2], "lane": "Lord", "slot": 0}, {"card_id": hand[3], "lane": "Castle", "slot": 0}]}
			var bad: Dictionary = order.duplicate(true)
			bad.guard_moves[0].card_id = hand[0]
			var before: Dictionary = game.snapshot()
			check(game._owner.preview_submission(0, [], bad).action == "invalid" and game.snapshot() == before, "combat/deployment double spend rejected atomically")
		elif round_number == 4:
			order = {"castle_action": choice("Activate", project)}
		elif round_number == 5:
			var hand: Array = game.player_view(0).world.hand
			order = {"castle_action": choice("Repair", project, [hand[0]]), "guard_moves": [{"card_id": hand[1], "lane": "Lord", "slot": 1}]}
		if not finish(game, order):
			return
		var castle: Dictionary = entity(game, project)
		if round_number <= 3:
			check(castle.attributes.integrity == 3 * round_number and castle.attributes.construction_state == "building", "automatic project advances once during mixed/pass round")
		elif round_number == 4:
			check(castle.attributes.integrity == 9 and castle.attributes.construction_state == "active" and game.snapshot().world.data.construction_targets[0] == "", "commission activates selected castle and stops free progress")
		else:
			check(castle.attributes.integrity > 9 and entity(game, order.guard_moves[0].card_id).attributes.get("role") == "guard", "repair and separate guard deployment resolve together")
		if round_number < 5:
			check(game.next_round().action != "invalid", "next Development round")

func fixture(lords: Array, mode: String):
	var world: Dictionary = Economy.initialize(Game.Scenario.loadout_world(lords, [Slots.TYPES, Slots.TYPES]), "development-" + mode).world
	var ids = Game.Content.Ids.new()
	ids.restore(world.entities)
	if mode == "return":
		var actor: Dictionary = ids.get_entity(world.players[0].lord_entity_id)
		actor.attributes.alive = false
		ids.update(actor.id, 0, actor.attributes)
	else:
		var castle: Dictionary = ids.get_entity(Slots.castle_id(0, 4))
		castle.attributes.status = "ruined"
		castle.attributes.construction_state = "active"
		ids.update(castle.id, 0, castle.attributes)
	world.entities = ids.snapshot()
	var game = Game.new()
	# Explicit pre-match states isolate return/reconstruction; never patch a
	# running owner or count these fixtures as autonomously reached full games.
	game._owner = Game.Content.new().create_combat_match()
	if not check(game._owner.start("development-" + mode, world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action != "invalid", mode + " directed opening"):
		return null
	return game

func return_and_deploy() -> void:
	var game = fixture(["Kanifous", "Gremory"], "return")
	if game == null:
		return
	var view: Dictionary = game.player_view(0)
	var return_plan: Dictionary = game.plan(0)
	check(return_plan.action != "invalid" and return_plan.powers.is_empty() and not return_plan.order.has("action"), "banished Lord planner returns a legal non-combat submission")
	var legal: Array = game._owner.legal_order_candidates(0, [], Development.summon_orders(view, [], {}))
	if not check(not legal.is_empty(), "return candidates from public hand"):
		return
	var order: Dictionary = legal[0]
	var castles: Array = game._owner.legal_order_candidates(0, [], Development.castle_orders(view, [], order))
	if not check(not castles.is_empty(), "return can include construction"):
		return
	order = castles[0]
	var guards: Array = game._owner.legal_order_candidates(0, [], Development.guard_orders(view, [], order))
	if not check(not guards.is_empty(), "return plus construction can include guards"):
		return
	order = guards[0]
	var move_id: String = order.guard_moves[0].card_id
	var conflict: Dictionary = order.duplicate(true)
	conflict.summon.card_ids = [move_id]
	check(game._owner.preview_submission(0, [], conflict).action == "invalid", "return/deployment card reuse rejected")
	if not finish(game, order):
		return
	check(Resummon.lord(game.snapshot().world, 0).attributes.alive and entity(game, move_id).attributes.get("role") == "guard", "Lord returns and guard deploys in same Development")
	check(game.snapshot().world.data.summon_counts[0] == 2 and game.snapshot().world.data.neutral_tears == 1, "return counted and charged exactly once")

func reconstruction() -> void:
	var game = fixture(["Deimos", "Gremory"], "reconstruct")
	if game == null:
		return
	var engine: String = Slots.castle_id(0, 4)
	var view: Dictionary = game.player_view(0)
	var candidates: Array = Development.castle_orders(view, [], {})
	var legal: Array = game._owner.legal_order_candidates(0, [], candidates)
	var rebuilding: Array = legal.filter(func(o): return o.castle_action.target_id == engine and o.castle_action.action == "Construct" and o.castle_action.card_ids.is_empty())
	if not check(rebuilding.size() == 1, "Deimos reconstruction uses ordinary construction candidate"):
		return
	if finish(game, rebuilding[0]):
		check(entity(game, engine).attributes.integrity == 3 and entity(game, engine).attributes.construction_state == "building", "ruined engine enters protected reconstruction")
