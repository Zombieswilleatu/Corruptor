extends "res://Scripts/Sim/U13BasicDoctrineTestRunner.gd"

const Victory = preload("res://Scripts/Sim/U13Victory.gd")

func run() -> void:
	var game = Game.new()
	var loadout: Array = ["Keep", "Stockpile", "SummoningCircle", "Bastion", "Stockpile"]
	if not check(game.start("round-pressure", ["Gremory", "Deimos"], [loadout, loadout], true).action != "invalid", "quiet match starts"): quit(1); return
	var legacy: Dictionary = game.snapshot()
	legacy.policy_id = String(legacy.policy_id).replace(Victory.VERSION, "U13_VICTORY_V1")
	legacy.world.data.victory.version = "U13_VICTORY_V1"
	check(Game.new().restore(legacy).action == "invalid", "old no-pressure history cannot silently enter the new policy")
	var expected: int = 0
	for r in range(1, 30):
		if not check(Bot.to_planning(game).action == "game_planning", "planning round " + str(r)): quit(1); return
		var view: Dictionary = game._owner.player_view(0, 0)
		check(view.world.veil_drift_enabled and not view.world.veil_effects_enabled, "round pressure enabled with threshold effects still disabled")
		var replay = Game.new()
		var verify: bool = r in [12, 13, 20, 21, 29]
		if verify and not check(replay.restore_json(game.snapshot_json()).action != "invalid", "boundary planning save restores: " + str(r)): quit(1); return
		var plans: Array = [{"powers": [], "order": {}}, {"powers": [], "order": {}}]
		if not check(game.submit(plans).action != "invalid" and game.finish_round().action != "invalid", "pass round resolves: " + str(r)): quit(1); return
		expected += 0 if r <= 12 else (1 if r <= 20 else 2)
		var snap: Dictionary = game.snapshot()
		check(snap.world.data.neutral_tears == expected, "exact cumulative neutral tears: round " + str(r))
		check(snap.world.players.all(func(p): return p.resources.personal_tears == 0), "automatic tears are neutral only")
		var events: Array = game._owner.player_view(0).events.filter(func(e): return e.type == "NEUTRAL_TEAR_CREATED" and e.data.source == "RoundPressure" and e.data.round == r)
		check(events.size() == (0 if r <= 12 else 1) and (events.is_empty() or events[0].data.amount == (1 if r <= 20 else 2)), "one correctly sized pressure event per eligible round")
		if verify:
			check(replay.submit(plans).action != "invalid" and replay.finish_round().action != "invalid" and replay.snapshot() == snap, "boundary resolution replays exactly: " + str(r))
			check(replay.restore_json(game.snapshot_json()).action != "invalid" and replay.snapshot() == snap, "settled boundary save restores without adding tears")
			var isolated: Dictionary = snap.world.duplicate(true)
			check(Victory.finish(isolated, r).action == "invalid" and isolated == snap.world, "duplicate finish cannot add neutral tears")
		if r < 29:
			check(not game.is_finished(), "no premature victory in quiet round " + str(r))
			if game.next_round().action == "invalid": check(false, "next round accepted"); quit(1); return
		else:
			check(expected == 26 and game.is_finished() and game.outcome().win_by == "FinalCollapse", "zero-action game reaches Final Collapse at round 29")
			check(game.next_round().get("reason") == "match_finished" and game.snapshot() == snap, "finished match cannot accrue more tears")
	# A pressure tick can also activate Dominion at that same Aftermath.
	var world: Dictionary = game.snapshot().world.duplicate(true)
	world.data.victory = {"version": Victory.VERSION, "checked_round": 12, "winner": -1, "win_by": ""}
	world.data.neutral_tears = 6
	world.players[0].resources.personal_tears = 5
	world.players[1].resources.personal_tears = 0
	var result: Dictionary = Victory.finish(world, 13)
	check(result.action != "invalid" and world.data.victory.win_by == "Dominion" and world.data.victory.winner == 0, "round-13 neutral tear triggers Dominion in the same victory check")
	print("U13 round pressure failures: %d" % failures)
	quit(1 if failures else 0)
