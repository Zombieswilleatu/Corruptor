extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

func run() -> void:
	var game = Game.new()
	if not check(game.start("game-random-v1", ["Kanifous", "Orias"], [Slots.TYPES, Slots.TYPES]).action != "invalid", "random game opening"):
		quit(1)
		return
	for round_number in range(1, 4):
		if not check(game.to_planning(true).action != "invalid", "round %d draws and planning" % round_number):
			break
		var before: Dictionary = game.snapshot()
		var restored = Game.new()
		if not check(restored.restore(JSON.parse_string(JSON.stringify(before))).action != "invalid", "restore random planning"):
			break
		var plans: Array = [game.plan(0), game.plan(1)]
		if not check(plans.all(func(p): return p.action != "invalid"), "both seats produce legal plans from real hands"):
			print(plans)
			break
		check(plans == [restored.plan(0), restored.plan(1)] and before == game.snapshot(), "planning replays without state mutation")
		if not check(game.submit(plans).action != "invalid" and restored.submit(plans).action != "invalid", "random complete submission"):
			break
		if not check(game.finish_round().action != "invalid" and restored.finish_round().action != "invalid", "random round completes"):
			break
		check(game.snapshot() == restored.snapshot(), "all random results and private events replay")
		var view: Dictionary = game.player_view(0)
		print("ROUND %d complete: hand=%d opponent_hand=%d deck=%d discard=%d; outcome=%s" % [round_number, view.world.hand.size(), view.world.opponent_hand_count, view.world.deck_count, view.world.discard.size(), game.outcome().action])
		if game.is_finished():
			break
		if round_number < 3:
			check(game.next_round().action != "invalid", "begin next random round")
	print("U13 game random failures: %d" % failures)
	quit(failures)
