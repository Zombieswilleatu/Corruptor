extends "res://Scripts/Sim/U13BloodConduitTestRunner.gd"

const Bot = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const Counters = preload("res://Scripts/Sim/U13PlanningCounters.gd")
const Batch = preload("res://Scripts/Sim/U13FullMatchBatch.gd")

func run() -> void:
	for index in range(9):
		opening(index)
	snare_lock()
	directed_scores()
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
