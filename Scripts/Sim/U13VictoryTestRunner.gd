extends "res://Scripts/Sim/U13PlunderTestRunner.gd"

const Victory = preload("res://Scripts/Sim/U13Victory.gd")

func run() -> void:
	var world: Dictionary = prepared()
	check(Victory.evaluate(world) == {"winner": -1, "win_by": ""}, "opening has no winner")
	world.players[0].resources.souls = 11
	check(Victory.evaluate(world).winner == -1, "eleven Souls is below Ritual")
	world.players[0].resources.souls = 12
	check(Victory.evaluate(world) == {"winner": 0, "win_by": "Ritual"}, "twelve Souls with living Lord wins Ritual")
	world.players[1].resources.souls = 13
	check(Victory.evaluate(world).winner == 0, "simultaneous Ritual preserves seat-zero tie priority")
	patch(world, world.players[0].lord_entity_id, {"alive": false})
	check(Victory.evaluate(world).winner == 1, "absent Lord cannot win Ritual")
	patch(world, world.players[1].lord_entity_id, {"alive": false})
	check(Victory.evaluate(world).winner == -1, "both absent prevents Ritual")
	world.players[0].resources.personal_tears = 5
	world.data.neutral_tears = 6
	check(Victory.evaluate(world).winner == -1, "Dominion waits for total Veil twelve")
	world.data.neutral_tears = 7
	check(Victory.evaluate(world) == {"winner": 0, "win_by": "Dominion"}, "Dominion needs no living Lord")
	world.players[1].resources.personal_tears = 5
	check(Victory.evaluate(world).winner == -1, "tied personal Tears do not win Dominion")
	world.players[1].resources.personal_tears = 6
	check(Victory.evaluate(world).winner == 1, "strict personal Tear leader wins Dominion")
	world.players[0].resources.personal_tears = 4
	world.players[1].resources.personal_tears = 3
	world.data.neutral_tears = 5
	check(Victory.evaluate(world).winner == -1, "four personal Tears cannot win Dominion")
	world.players[0].resources.personal_tears = 5
	world.data.neutral_tears = 18
	check(Victory.evaluate(world) == {"winner": 1, "win_by": "FinalCollapse"}, "Final Collapse takes precedence over Dominion and uses Souls")
	world.players[0].resources.souls = 13
	check(Victory.evaluate(world).winner == 0, "Final Collapse Soul tie preserves seat-zero priority")
	patch(world, world.players[1].lord_entity_id, {"alive": true})
	check(Victory.evaluate(world) == {"winner": 1, "win_by": "Ritual"}, "Ritual takes precedence over Final Collapse")
	for kind in ["Ritual", "Dominion", "FinalCollapse"]:
		live_victory(kind)
	throne_reward()
	print("U13 victory failures: %d" % failures)
	quit(failures)

func live_victory(kind: String) -> void:
	var world: Dictionary = prepared()
	if kind == "Ritual":
		world.players[0].resources.souls = 11
	elif kind == "Dominion":
		world.players[0].resources.personal_tears = 4
		world.data.neutral_tears = 7
	else:
		world.players[0].resources.souls = 1
		world.data.neutral_tears = 25
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match()
	if not check(game._owner.start("victory-" + kind, world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", kind + " directed round starts"):
		return
	var attack: Dictionary = profane()
	if kind == "Ritual":
		attack = {"action": "Siege", "lane": "Castle", "target_id": Plunder.zone_id(1), "card_ids": [game.player_view(0).world.hand[0]]}
	if not check(game.submit([{"powers": [], "order": attack}, {"powers": [], "order": {}}]).action != "invalid", kind + " submits real scoring action"):
		return
	while game._owner.next_hook() != Game.Timeline.AFTERMATH:
		if not check(game.step().action != "invalid", kind + " settles " + game._owner.next_hook()):
			return
	check(not game.is_finished() and game.outcome().winner == -1, kind + " waits for Aftermath")
	var replay = Game.new()
	if not check(replay.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", kind + " restores before winning hook"):
		return
	var result: Dictionary = game.finish_round()
	check(result == {"action": "game_finished", "round": 1, "winner": 0, "win_by": kind}, kind + " conductor reports winner")
	check(replay.to_planning(true) == result and replay.snapshot() == game.snapshot(), kind + " planning advancement reports winning hook and replays exactly")
	var before: Dictionary = game.snapshot()
	check(replay.restore(JSON.parse_string(JSON.stringify(before))).action != "invalid" and replay.is_finished(), kind + " terminal JSON restore")
	check(game.next_round().action == "invalid" and game._owner.begin_next_round([1, 0]).action == "invalid", kind + " blocks next round at both entry points")
	check(game.step().action == "invalid" and game.submit([{ "powers": [], "order": {} }, { "powers": [], "order": {} }]).action == "invalid" and game.choose_market(0, {"market": "Pass"}).action == "invalid", kind + " blocks further play")
	check(game.finish_round() == result and game.to_planning(true) == result and game.snapshot() == before, kind + " outcome reads are idempotent")
	for pid in [0, 1]:
		var view: Dictionary = game.player_view(pid)
		check(view.world.victory.winner == 0 and view.world.victory.win_by == kind and not view.world.veil_effects_enabled and not view.world.veil_drift_enabled, kind + " both players see result with Veil effects disabled")
	for changes in [{"winner": 1}, {"winner": -1, "win_by": ""}, {"checked_round": 0}, {"win_by": "Fake"}]:
		var forged: Dictionary = before.duplicate(true)
		forged.world.data.victory.merge(changes, true)
		check(game.restore(forged).action == "invalid" and game.snapshot() == before, kind + " rejects forged result " + str(changes))
	check(before.events.rows.filter(func(e): return e.event.type == "MATCH_FINISHED").size() == 1, kind + " emits exactly one finish event")

func throne_reward() -> void:
	var world: Dictionary = prepared()
	patch(world, world.players[1].lord_entity_id, {"alive": false})
	world.players[0].resources.souls = 11
	for round_number in range(1, 4):
		check(Victory.Throne.begin(world, round_number), "Throne begins grace round")
		Victory.Throne.finish(world, round_number)
		Victory.finish(world, round_number)
		check(world.data.victory.winner == (0 if round_number == 3 else -1), "Throne reward counts before victory in round %d" % round_number)
