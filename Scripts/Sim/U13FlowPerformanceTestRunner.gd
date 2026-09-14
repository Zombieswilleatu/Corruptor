extends SceneTree
const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Reference = preload("res://Scripts/Sim/U13FlowReference.gd")
const Batch = preload("res://Scripts/Sim/U13FullMatchBatch.gd")
var failures: int = 0
var checks: int = 0
var fast_ms: float = 0.0
var old_ms: float = 0.0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func same(a, b) -> bool:
	return var_to_bytes(a) == var_to_bytes(b)

func views(game) -> void:
	var before: Dictionary = game.snapshot()
	for pid in [0, 1]:
		var narrow: Dictionary = game._flow_view(pid)
		var full: Dictionary = game._owner.player_view(pid, 0).world
		check(same(narrow.game_economy.stockpile_pending, full.game_economy.stockpile_pending), "Stockpile visibility matches full projection")
		for key in ["game_market", "market", "hand", "victory"]:
			check(same(narrow[key], full[key]), "flow projection matches " + key)
		narrow.game_market.clear()
		narrow.market.clear()
		narrow.hand.clear()
		narrow.victory.clear()
		narrow.game_economy.stockpile_pending.clear()
	check(same(before, game.snapshot()), "flow output mutation cannot change authority")

func run() -> void:
	# Every lord appears in both seats; alternate full presentation / batch events.
	for index in [9, 19, 29, 39, 49, 59, 69, 79, 8]:
		var setup: Dictionary = Batch.setup(index)
		var game = Game.new()
		var old = Reference.new()
		check(same(game.start(setup.seed, setup.lords, setup.castles, index % 2 == 0), old.start(setup.seed, setup.lords, setup.castles, index % 2 == 0)), "identical setup " + str(index))
		# Check every paused choice, including enemy Stockpile redaction.
		while true:
			var result: Dictionary
			var previous: Dictionary
			for use_reference in ([true, false] if index % 2 == 0 else [false, true]):
				var started: int = Time.get_ticks_usec()
				if use_reference:
					previous = old.to_planning()
					old_ms += (Time.get_ticks_usec() - started) / 1000.0
				else:
					result = game.to_planning()
					fast_ms += (Time.get_ticks_usec() - started) / 1000.0
			check(result.action != "invalid" and same(result, previous) and same(game.snapshot(), old.snapshot()), "exact choice boundary " + str(index))
			views(game)
			if result.action == "game_planning": break
			if result.action == "game_draw_choice":
				var pid: int = result.player_id
				var card: String = game._flow_view(pid).game_economy.stockpile_pending.card_ids[0]
				check(same(game.choose_stockpile(pid, card), old.choose_stockpile(pid, card)), "exact Stockpile choice")
			elif result.action == "game_market_choice":
				var options: Array = game.market_choices(result.player_id)
				check(same(options, old.market_choices(result.player_id)), "exact Slaver choices and ordering")
				check(same(game.choose_market(result.player_id, options[-1]), old.choose_market(result.player_id, options[-1])), "exact Slaver submission")
			else:
				check(false, "unexpected boundary")
				quit(1)
				return
		# Three complete fixed-seed Random-Legal rounds, not a completion campaign.
		if index in [9, 49, 79]:
			var plans: Array = [game.plan(0), game.plan(1)]
			check(plans.all(func(p): return p.action == "bot_plan") and same(plans, [old.plan(0), old.plan(1)]), "identical Random-Legal plans")
			check(same(game.submit(plans), old.submit(plans)), "identical submissions")
			views(game)
			while not game._owner.next_hook().is_empty():
				check(same(game.step(), old.step()) and same(game.snapshot(), old.snapshot()), "exact full round hook")
			check(same(game.outcome(), old.outcome()), "exact outcome")
			var restored = Game.new()
			check(restored.restore_json(game.snapshot_json()).action != "invalid" and same(restored.snapshot(), game.snapshot()), "exact save restore")
			check(same(game.next_round(), old.next_round()) and same(game.to_planning(true), old.to_planning(true)) and same(game.snapshot(), old.snapshot()), "exact seeded automatic choices next round")
	print("Flow execution totals: optimized=", fast_ms, "ms reference=", old_ms, "ms")
	print("U13 flow performance checks: ", checks)
	print("U13 flow performance failures: ", failures)
	quit(failures)
