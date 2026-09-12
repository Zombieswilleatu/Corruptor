extends "res://Scripts/Sim/U13BloodConduitTestRunner.gd"

const Bot = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const Counters = preload("res://Scripts/Sim/U13PlanningCounters.gd")
const Batch = preload("res://Scripts/Sim/U13FullMatchBatch.gd")

func run() -> void:
	for index in range(9):
		opening(index)
	snare_lock()
	directed_scores()
	hidden_guard_boundary()
	coordinated_powers()
	session_isolation()
	print("U13 basic doctrine failures: %d" % failures)
	quit(failures)

func opening(index: int) -> void:
	var chosen: Dictionary = Batch.setup(index + 9 * ((index + 1) % 9))
	var game = Game.new()
	if not check(game.start(chosen.seed, chosen.lords, chosen.castles, true).action != "invalid" and Bot.to_planning(game).action == "game_planning", "doctrine opening " + str(chosen.lords)):
		return
	var before: Dictionary = game.snapshot()
	var plans: Array = []
	for pid in [0, 1]:
		var counter = Counters.new(game._owner)
		var plan: Dictionary = Bot.plan(counter, pid)
		if not check(plan.get("action") == "bot_plan", "legal plan " + str(chosen.lords[pid])):
			return
		plans.append(plan)
		check(Bot.plan(game._owner, pid) == plan and before == game.snapshot(), "deterministic, read-only doctrine")
		check(Bot.plan(game._owner, pid, false) == plan and before == game.snapshot(), "planning session matches uncached authority")
		check(counter.calls.filter(func(call): return call.kind == "planning_setup").size() == 1, "one checked planning baseline per player")
		check(counter.calls.all(func(call): return call.candidates <= Bot.CANDIDATE_LIMIT), "bounded validation batches")
		check(counter.calls.all(func(call): return call.kind != "snapshot"), "policy reads projection, never server snapshot")
		var reserved: Array = Bot.Context.Development.reserved_cards(plan.powers, plan.order)
		var unique: Dictionary = {}
		for id in reserved: unique[id] = true
		check(unique.size() == reserved.size(), "one reservation per physical card")
	var restored = Game.new()
	if not check(restored.restore_json(game.snapshot_json()).action != "invalid", "save before doctrine submission"):
		return
	check(game.submit(plans).action != "invalid" and restored.submit(plans).action != "invalid", "whole plan commits")
	check(game.finish_round().action != "invalid" and restored.finish_round().action != "invalid" and game.snapshot() == restored.snapshot(), "Lord pair exact resolution replay")

func snare_lock() -> void:
	var world: Dictionary = fixture("Orias", 7, 2)
	patch(world, world.players[0].lord_entity_id, {"threat": 1})
	world.players[0].resources.repair_tokens = 1
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	if not check(game._owner.start("conduit", world, [0, 1]).action != "invalid" and Bot.to_planning(game).action == "game_planning", "Snare doctrine fixture"):
		return
	var before: Dictionary = game.snapshot()
	var c = Bot.Context.new(game._owner.player_view(0, 0))
	var powers: Array = [Candidates.snare_source(0, 1)]
	var order: Dictionary = Bot.choose(game._owner, 0, powers, {}, Bot.Common.castles(c, powers, {}))
	check(game._owner.preview_submission(0, powers, order).action != "invalid" and before == game.snapshot(), "shared admission respects post-Snare Repair lock")

func directed_scores() -> void:
	var game = Game.new()
	game.start("doctrine-scores", ["Gremory", "Deimos"], [Slots.TYPES, Slots.TYPES], true)
	Bot.to_planning(game)
	var view: Dictionary = game._owner.player_view(0, 0)
	var c = Bot.Context.new(view)
	for options in [Bot.Common.castles(c, [], {}), Bot.Common.combat(c, [], {}), Bot.Common.guards(c, [], {})]:
		check(options.all(func(x): return Bot.Data.is_data(x.payload)), "candidate payloads use canonical data and String keys")
	var planned: Dictionary = Bot.plan(game._owner, 0)
	check(planned.order.has("action") or planned.order.has("castle_action"), "purposeful opening includes admitted combat/development")
	var base: Dictionary = {"action": "Siege", "lane": "Castle", "target_id": "castle_zone:1", "card_ids": [c.w.hand[0]]}
	c.w.souls[0] = 11
	# Directed public views are scoring fixtures only, never match results.
	for e in c.w.entities:
		if e.owner == 1 and e.kind == "castle":
			e.attributes.construction_state = "building"
	check(Bot.Common.combat(c, [], {}).any(func(x): return x.payload.get("target_id") == "castle_zone:1"), "Pillage candidates include protected/unbuilt castle zone")
	check(Bot.Common.combat_score(c, base) > 100, "prioritize immediate Ritual opportunity")
	c.w.personal_tears = [4, 2]
	c.w.veil_total = 11
	check(c.tear_value() > 100, "prioritize winning Dominion Tear")
	var own: Dictionary = c.select("lord", 0)[0]
	own.attributes.alive = false
	check(not Bot.Common.summon(c, [], {}).is_empty(), "banished Lord proposes resummoning")
	var empty_points: Array = Bot.Powers.points(c, 300)
	check(empty_points.is_empty(), "empty field has no damaging area targets")

func guarded_game(lord_name: String, hidden_value: int):
	var world: Dictionary = fixture(lord_name)
	for slot in range(2):
		var id: String = world.data.card_zones.hands[1][0]
		world.data.card_zones.hands[1].erase(id)
		patch(world, id, {"role": "guard", "lane": "Lord" if slot == 0 else "Castle", "slot": 0, "value": hidden_value, "suit": "Wright" if hidden_value == 1 else "Penitent"})
	if lord_name == "Valak":
		world.players[0].resources.life_essence = 5
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	if not check(game._owner.start("conduit", world, [0, 1]).action != "invalid" and Bot.to_planning(game).action == "game_planning", "hidden-guard fixture " + lord_name):
		return null
	return game

func hidden_guard_boundary() -> void:
	for lord_name in ["Valak", "Gremory", "Odradek", "Kroni"]:
		var low = guarded_game(lord_name, 1)
		var high = guarded_game(lord_name, 5)
		if low == null or high == null:
			continue
		var low_view: Dictionary = Bot.BotPlanning.new(low._owner, 0).player_view(0)
		var high_view: Dictionary = Bot.BotPlanning.new(high._owner, 0).player_view(0)
		check(low_view == high_view, "hidden guard values do not change bot input " + lord_name)
		var guards: Array = low_view.world.entities.filter(func(e): return e.owner == 1 and e.attributes.get("role") == "guard")
		check(guards.size() == 2 and guards.all(func(e): return not e.attributes.has("value") and not e.attributes.has("suit") and e.id.begins_with("hidden_guard:") and e.origin == "concealed_guard"), "hidden faces and physical identity metadata are absent")
		var planned: Dictionary = Bot.plan(low._owner, 0)
		check(planned.action == "bot_plan" and planned == Bot.plan(high._owner, 0), "concealed face changes cannot alter doctrine plan " + lord_name)
		check(low._owner.preview_submission(0, planned.powers, planned.order).action != "invalid", "opaque targets translate to a legal real submission")
		# Explicitly exercise a guard-targeting power through the opaque handle.
		if lord_name == "Kroni":
			var boundary = Bot.BotPlanning.new(low._owner, 0)
			var c = Bot.Context.new(boundary.player_view(0))
			var sources: Array = Bot.Powers.options(c, {}).filter(func(x): return x.payload.power_id == "Consume").map(func(x): return x.payload)
			var legal: Array = boundary.legal_power_candidates(0, sources)
			check(not legal.is_empty() and legal[0].target.entity_id.begins_with("hidden_guard:"), "admission does not reveal physical guard IDs")
			if not legal.is_empty():
				var canonical: Dictionary = boundary.canonical_plan({"powers": [legal[0]], "order": {}})
				check(low._owner.preview_submission(0, canonical.powers, {}).action != "invalid", "guard target mapping round trips through authority")

func coordinated_powers() -> void:
	var game = guarded_game("Valak", 5)
	if game == null: return
	var c = Bot.Context.new(Bot.BotPlanning.new(game._owner, 0).player_view(0))
	c.w.life_essence[0] = 2
	check(Bot.Powers.valak(c).all(func(x): return x.payload.power_id != "Projection"), "Projection banks rather than underfunding a concealed guard estimate")
	c.w.life_essence[0] = 5
	var options: Array = Bot.Powers.valak(c).filter(func(x): return x.payload.power_id == "Projection")
	check(options.size() == 2 and options.all(func(x): return x.payload.parameters.spend == 3), "Projection spends for one estimated guard, never a zone total")
	var ids: Array = c.w.hand.slice(0, 4)
	for id in ids:
		c.rows[id].attributes.suit = "Butcher"
		c.rows[id].attributes.value = 5
	var castle: Dictionary = c.castles(1).filter(func(x): return x.attributes.castle_type == "Bastion")[0]
	castle.attributes.integrity = 3
	var strong: Dictionary = {"action": "Siege", "lane": "Castle", "target_id": castle.id, "card_ids": ids}
	var castle_projection: Dictionary = options.filter(func(x): return x.payload.target.zone == "Castle")[0].payload
	var lord_projection: Dictionary = options.filter(func(x): return x.payload.target.zone == "Lord")[0].payload
	check(Bot.Powers.redundant(c, castle_projection, strong) and not Bot.Powers.redundant(c, lord_projection, strong), "Projection avoids the lane our attack is expected to clear")
	var ruin: Dictionary = {"power_id": "InevitableRuin", "target": {"entity_id": castle.id}}
	check(Bot.Powers.redundant(c, ruin, strong), "Ruin avoids a castle our own Siege is expected to destroy")
	var weak: Dictionary = strong.duplicate(true)
	weak.card_ids = []
	check(not Bot.Powers.redundant(c, ruin, weak), "Ruin remains useful with a nonlethal Siege")
	ruin.target.entity_id = c.castles(1)[0].id
	check(not Bot.Powers.redundant(c, ruin, strong), "Siege leaves other Ruin targets available")

func session_isolation() -> void:
	var game = guarded_game("Kroni", 3)
	if game == null: return
	var before: Dictionary = game.snapshot()
	var session = game._owner.planning_session(0)
	var c = Bot.Context.new(game._owner.player_view(0, 0))
	var sources: Array = Bot.Powers.options(c, {}).map(func(x): return x.payload)
	sources.append_array([{}, null, "bad"])
	check(session.legal_power_candidates(0, sources) == game._owner.legal_power_candidates(0, sources), "session power admission matches independent authority including malformed inputs")
	var orders: Array = [{}, {"action": "Siege", "lane": "Castle", "target_id": "missing", "card_ids": []}, null]
	for powers in [[], [sources[0]]]:
		check(session.legal_order_candidates(0, powers, orders) == game._owner.legal_order_candidates(0, powers, orders), "session batches preserve staged declaration costs")
		for order in orders.slice(0, 2):
			check(session.preview_submission(0, powers, order) == game._owner.preview_submission(0, powers, order), "complete preview agrees including rejection reason")
	check(session.legal_order_candidates(1, [], [{}]).is_empty(), "planning session cannot validate another player's cart")
	var view: Dictionary = session.player_view(0, 0)
	view.world.entities.clear()
	check(not session.player_view(0, 0).world.entities.is_empty() and game.snapshot() == before, "view/candidate mutation cannot change baseline or live match")
	var adapter: Callable = game._owner._order_validator
	for fallback in [Callable(), Callable(self, "malformed_session_adapter")]:
		game._owner._order_validator = fallback
		var fallback_session = game._owner.planning_session(0)
		check(fallback_session.legal_order_candidates(0, [], orders) == game._owner.legal_order_candidates(0, [], orders), "session preserves missing/malformed adapter fallback")
	game._owner._order_validator = adapter
	check(game._owner.submit(0, [], {}).action != "invalid" and game._owner.planning_session(0) == null, "new session rejects a sealed player")
	check(session.preview_submission(0, [], {}).action == "legal", "existing session remains an isolated snapshot, never a live commit cache")

func malformed_session_adapter(_context: Dictionary) -> Dictionary:
	return {"action": "legal_orders", "indices": ["invalid"]}
