extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

const Play = preload("res://Scripts/Sim/U13PlayableSession.gd")
const Bot = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const Batch = preload("res://Scripts/Sim/U13FullMatchBatch.gd")
const Job = preload("res://Prototype/U13/U13BoardJob.gd")

func run() -> void:
	var play = Play.new()
	var castles: Array = ["Keep", "Stockpile", "SummoningCircle", "Bastion", "SiegeEngine"]
	var configured: Dictionary = play.configure_seed("playable-stockpile", ["Odradek", "Kanifous"], [castles, castles])
	if not check(configured.action == "game_draw_choice", "production opening pauses for human Stockpile"):
		quit(failures); return
	check(play.pending_choice.player_id == 0, "bot never chooses human economy decisions")
	var snapshot: Dictionary = play._owner.snapshot()
	var restored = Play.new()
	check(restored.restore_checkpoint(play.checkpoint()).action != "invalid" and restored._owner.snapshot() == snapshot, "save restores pending Stockpile exactly")
	check(play.choose_economy({"keep_id": "stale-card"}).action == "invalid" and play._owner.snapshot() == snapshot, "stale draw choice is atomic")
	var id: String = play.board_view().world.game_economy.stockpile_pending.card_ids[0]
	check(play.choose_economy({"keep_id": id}).action != "invalid" and restored.choose_economy({"keep_id": id}).action != "invalid" and play._owner.snapshot() == restored._owner.snapshot(), "resumed draws and bot choice replay exactly")
	check(play.pending_choice.action == "game_market_choice" and play.pending_choice.player_id == 0, "Slaver waits for human seat")
	check(restored.restore_checkpoint(play.checkpoint()).action != "invalid", "save between market seats")
	snapshot = play._owner.snapshot()
	check(play.choose_economy({"market": "Swap", "give_id": "stale", "take_id": "stale"}).action == "invalid" and play._owner.snapshot() == snapshot, "stale Slaver offer is atomic")
	check(play.choose_economy({"market": "Pass"}).action == "game_planning", "human Slaver choice unlocks planning after bot seat")
	var selected: Dictionary = Bot.plan(play._owner, 0)
	check(play.choose(selected.powers, selected.order).action != "invalid", "human whole plan stages through production admission")
	check(restored.restore_checkpoint(play.checkpoint()).action != "invalid" and restored.plans() == play.plans(), "save preserves the complete unsubmitted human cart")
	var opponent: Dictionary = Bot.plan(play._owner, 1)
	var reference = Game.new()
	reference.restore(play._owner.snapshot())
	reference.submit([selected, opponent])
	reference.finish_round()
	var marched: Dictionary = Job.new()._run(play._fork_for_job(), "marching", selected.powers, selected.order)
	if check(marched.action != "invalid", "playable worker builds a real Marching tape"):
		check(play.next_hook() == "submission_lock", "worker never changes the live session before adoption")
		var finished: Dictionary = Job.new()._run(marched.session, "aftermath", [], {})
		if check(finished.action != "invalid", "playable Aftermath completes all hooks"):
			play = finished.session
			check(play._owner.snapshot() == reference.snapshot(), "animated session exactly matches independent production resolution")
			check(restored.restore_checkpoint(play.checkpoint()).action != "invalid" and restored._owner.snapshot() == play._owner.snapshot(), "save restores completed round without replaying Marching")
	if not OS.get_cmdline_user_args().has("--fixtures-only"):
		full_match()
	print("U13 playable session failures: %d" % failures)
	quit(failures)

func full_match() -> void:
	var setup: Dictionary = Batch.setup(19)
	var game = Game.new()
	game.start(setup.seed, setup.lords, setup.castles)
	var play = Play.new()
	play._owner = game._owner
	play.setup_lords = setup.lords
	play.setup_castles = setup.castles
	play.hunt_enabled = true
	play._to_planning()
	for round_index in range(40):
		for attempt in range(12):
			if play.pending_choice.is_empty(): break
			var choice: Dictionary = play.pending_choice.duplicate(true)
			var g = play.game()
			if not check(Bot.resolve_choice(g, choice).action != "invalid" and play._to_planning().action != "invalid", "human-choice driver round " + str(play.round_number())): return
		var selected: Dictionary = Bot.plan(play._owner, 0)
		if not check(play.choose(selected.powers, selected.order).action != "invalid" and play.run_to_marching().action != "invalid", "full playable round " + str(play.round_number())): return
		while not play.next_hook().is_empty():
			if not check(play.step().action != "invalid", "Aftermath hook"): return
		if play.is_finished():
			var before: Dictionary = play._owner.snapshot()
			check(play.next_round().action == "game_finished" and play._owner.snapshot() == before, "victory stops round advancement")
			var restored = Play.new()
			check(restored.restore_checkpoint(play.checkpoint()).action != "invalid" and restored.outcome() == play.outcome(), "terminal save restores the actual winner")
			print("PLAYABLE COMPLETE " + JSON.stringify(play.outcome()))
			return
		if not check(play.next_round().action != "invalid", "next full round"): return
	check(false, "representative playable game must reach a winner within 40 rounds")
