extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

func run() -> void:
	for lord in Game.LORDS:
		var probe = Game.new()
		if not check(probe.start("opening-" + lord, [lord, "Gremory"], [Slots.TYPES, Slots.TYPES]).action != "invalid", lord + " opening"):
			continue
		check(planning_with_market_passes(probe).action != "invalid" and probe.player_view(0).world.hand.size() == 10, lord + " reaches planning with normal draws")
	var game = Game.new()
	if not check(game.start("conductor-replay", ["Gremory", "Deimos"], [Slots.TYPES, Slots.TYPES]).action != "invalid", "start conductor"):
		quit(1)
		return
	var before: Dictionary = game.snapshot()
	check(game.start("replacement", ["Gremory", "Deimos"], [Slots.TYPES, Slots.TYPES]).action == "invalid" and game.snapshot() == before, "cannot restart a running game")
	check(game.next_round().action == "invalid" and game.snapshot() == before, "cannot skip unfinished round")
	for round_number in range(1, 4):
		while game._owner.next_hook() != Game.Timeline.SUBMISSION_LOCK:
			if not checkpoint_step(game):
				quit(1)
				return
		before = game.snapshot()
		var pass_plan: Dictionary = {"powers": [], "order": {}}
		check(game.submit([pass_plan, {"powers": [], "order": {"action": "Bogus"}}]).action == "invalid" and game.snapshot() == before, "invalid second plan is atomic")
		if not check(game.submit([pass_plan, pass_plan]).action != "invalid", "submit complete round %d" % round_number):
			quit(1)
			return
		while not game._owner.next_hook().is_empty():
			if not checkpoint_step(game):
				quit(1)
				return
		var corrupt: Dictionary = game.snapshot()
		corrupt.world.data.game_economy.draw_round -= 1
		before = game.snapshot()
		check(game.restore(corrupt).action == "invalid" and game.snapshot() == before, "stale draw clock rejected without replacing live game")
		if round_number < 3:
			check(game.next_round().action != "invalid", "advance to next actual round")
	print("U13 game conductor failures: %d" % failures)
	quit(failures)

func checkpoint_step(game) -> bool:
	var restored = Game.new()
	var hook: String = game._owner.next_hook()
	if not check(restored.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", "restore before " + hook):
		return false
	var market: Dictionary = game.player_view(0).world.game_market
	var choosing: bool = hook == Game.Timeline.PRESENT_PUBLIC_STATE and market.seat != 2
	var result: Dictionary = game.choose_market(market.seat, {"market": "Pass"}) if choosing else game.step()
	var replay: Dictionary = restored.choose_market(market.seat, {"market": "Pass"}) if choosing else restored.step()
	return check(result.action != "invalid" and replay == result and restored.snapshot() == game.snapshot(), "same state and events after " + hook)
