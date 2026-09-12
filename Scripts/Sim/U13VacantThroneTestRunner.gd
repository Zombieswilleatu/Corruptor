extends "res://Scripts/Sim/U13BloodConduitTestRunner.gd"

const Throne = preload("res://Scripts/Sim/U13VacantThrone.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")


func empty_throne(both: bool = false) -> Dictionary:
	var world: Dictionary = fixture()
	patch(world, world.players[0].lord_entity_id, {"alive": false})
	if both:
		patch(world, world.players[1].lord_entity_id, {"alive": false})
	return world


func run() -> void:
	var world: Dictionary = empty_throne()
	for round_number in range(1, 6):
		check(Throne.begin(world, round_number), "open vacant round %d" % round_number)
		var settled: Dictionary = Throne.finish(world, round_number)
		check(settled.action != "invalid" and world.data.vacant_throne.counts == [round_number, 0], "complete Lordless round increments one counter")
		check(world.players[1].resources.souls == maxi(0, round_number - 2), "two grace rounds then FLAT one Soul per round")
		check(settled.events[0].event.data.soul_gain == (1 if round_number > 2 else 0), "Vacant Throne event reports exact Soul award")
		var before: Dictionary = world.duplicate(true)
		check(Throne.finish(world, round_number).action == "invalid" and world == before, "duplicate end-round cannot award twice")
	check(Throne.valid(world), "five absent rounds retain a valid ledger")
	world = empty_throne(true)
	for round_number in range(1, 4):
		Throne.begin(world, round_number)
		Throne.finish(world, round_number)
	check(world.players[0].resources.souls == 1 and world.players[1].resources.souls == 1, "both absent players receive the other's flat award")
	check(world.data.neutral_tears == 0 and world.players.all(func(p): return p.resources.personal_tears == 0), "Vacant Throne creates no Tears")
	world = fixture()
	# Simulate a scheduled removal before the first ordinary round hook. The
	# public fact itself must preserve the fact that the Lord was present.
	var banished: Dictionary = Battle.apply(world, {"command_id": "scheduled-banish", "kind": "banish_lord", "target_id": world.players[0].lord_entity_id}, 1, Game.Timeline.ROUND_START_SCHEDULED)
	var reaction: Dictionary = Game.Content.new().react(banished.world, banished.event, "throne", [0, 1])
	if check(reaction.action != "invalid", "scheduled banishment initializes presence before ordinary hooks"):
		world = reaction.world
		Throne.finish(world, 1)
		check(world.data.vacant_throne.counts[0] == 0 and world.players[1].resources.souls == 0, "banishment round does not consume grace")
	world = empty_throne()
	for round_number in range(1, 4):
		Throne.begin(world, round_number)
		Throne.finish(world, round_number)
	Throne.begin(world, 4)
	patch(world, world.players[0].lord_entity_id, {"alive": true})
	Throne.observe(world)
	patch(world, world.players[0].lord_entity_id, {"alive": false})
	Throne.finish(world, 4)
	check(world.data.vacant_throne.counts[0] == 0 and world.players[1].resources.souls == 1, "return followed by another removal resets the whole streak")
	for round_number in [5, 6]:
		Throne.begin(world, round_number)
		Throne.finish(world, round_number)
	check(world.players[1].resources.souls == 1, "a later absence gets two new grace rounds")
	world.data.breach_lord = "Gremory"
	Throne.begin(world, 7)
	Throne.finish(world, 7)
	check(world.players[1].resources.souls == 2, "Breach identity cannot suppress Vacant Throne")
	for field in ["round", "counts", "present", "prior_counts"]:
		var forged: Dictionary = world.duplicate(true)
		forged.data.vacant_throne[field] = "bad"
		check(not Throne.valid(forged), "malformed " + field + " is rejected")
	live_replay()
	real_hunt()
	print("U13 Vacant Throne failures: %d" % failures)
	quit(failures)


func live_replay() -> void:
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match()
	if not check(game._owner.start("throne-live", empty_throne(), [0, 1]).action != "invalid", "full conductor accepts directed absent-Lord opening"):
		return
	var pass_plan: Dictionary = {"powers": [], "order": {}}
	for round_number in range(1, 5):
		if not check(planning_with_market_passes(game).action == "game_planning", "vacant round reaches planning"):
			return
		var order: Dictionary = {}
		if round_number == 4:
			order = {"summon": {"card_ids": game.player_view(0).world.hand.slice(0, 3)}}
		if not check(game.submit([{"powers": [], "order": order}, pass_plan]).action != "invalid", "absent Lord seals pass or return normally"):
			return
		while not game._owner.next_hook().is_empty():
			var hook: String = game._owner.next_hook()
			var restored = Game.new()
			if not check(restored.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", "vacancy JSON restore " + hook):
				return
			var step: Dictionary = game.step()
			if not check(step.action != "invalid" and restored.step().action != "invalid" and game.snapshot() == restored.snapshot(), "vacancy replay " + hook):
				print(step)
				return
			if hook == Game.Timeline.SUBMISSION_LOCK:
				var before: Dictionary = game.snapshot()
				var forged: Dictionary = before.duplicate(true)
				forged.world.data.vacant_throne.present[0] = not forged.world.data.vacant_throne.present[0]
				check(game.restore(forged).action == "invalid" and game.snapshot() == before, "forged presence rejects without replacing live owner")
		var state: Dictionary = game.snapshot().world
		check(state.data.vacant_throne.counts[0] == (0 if round_number == 4 else round_number), "real round counter and return reset")
		check(state.players[1].resources.souls == (1 if round_number >= 3 else 0), "real Aftermath awards exactly one Soul after grace")
		var before: Dictionary = game.snapshot()
		var forged: Dictionary = before.duplicate(true)
		forged.world.data.vacant_throne.counts[0] += 1
		check(game.restore(forged).action == "invalid" and game.snapshot() == before, "forged vacancy streak rejects atomically")
		if round_number < 4:
			check(game.next_round().action != "invalid", "advance vacancy round")
	check(game.snapshot().world.data.neutral_tears == 1 and Throne.alive(game.snapshot().world, 0), "actual return resets vacancy while retaining its one Neutral Tear")


func real_hunt() -> void:
	var world: Dictionary = fixture()
	# Remove the defending Keep screen; cards still come from the real deck.
	patch(world, Slots.castle_id(1, 0), {"status": "ruined", "integrity": 0})
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match()
	if not check(game._owner.start("throne-hunt", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "real Hunt starts from a living defender"):
		return
	var order: Dictionary = {"action": "Hunt", "lane": "Lord", "target_id": world.players[1].lord_entity_id, "card_ids": game.player_view(0).world.hand, "fracture_target": "subjects"}
	if not check(game.submit([{"powers": [], "order": order}, {"powers": [], "order": {}}]).action != "invalid" and game.finish_round().action != "invalid", "real Hunt and Aftermath finish"):
		return
	var after: Dictionary = game.snapshot().world
	check(not Throne.alive(after, 1) and after.data.vacant_throne.counts[1] == 0, "real Hunt banishment is not a full Lordless round")
	var restored = Game.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", "post-Hunt presence ledger restores")
