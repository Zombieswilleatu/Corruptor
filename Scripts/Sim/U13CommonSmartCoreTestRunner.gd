extends SceneTree

const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Bot = preload("res://Scripts/Sim/U13CommonSmartCore.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const Play = preload("res://Scripts/Sim/U13PlayableSession.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
	return ok

func same(expected, actual, label: String) -> bool:
	var delta: String = Codec.difference(expected, actual, label)
	return check(delta.is_empty(), delta)

func contract(row: Dictionary) -> void:
	var game = Game.new()
	if not check(game.restore(row.state).action != "invalid", row.name + " native restore"): return
	var before: Dictionary = game.snapshot()
	var view: Dictionary = Bot.Observation.read(game._owner, row.seat)
	if not same(row.view, view, row.name + ".observation"): return
	var started: int = Time.get_ticks_msec()
	var result: Dictionary = Bot.decide(game._owner, row.seat) if row.mode == "plan" else Bot.exchange(view, row.mode, Callable())
	if not check(result.action == "decision", row.name + " worker: " + str(result)): return
	same(row.decision, result.decision, row.name + ".decision")
	same(before, game.snapshot(), row.name + ".read_only")
	if row.mode == "plan":
		check(result.previews <= 8 and result.previews > 0, "bounded native previews")
		# A real admitted opposing commitment may alter current authority. The
		# observation must still use the original simultaneous planning world.
		if check(game._owner.submit(1 - row.seat, [], {}).action != "invalid", "opponent seals a plan"):
			same(view, Bot.Observation.read(game._owner, row.seat), "sealed opponent cannot change planner input")
		# No hidden engine identity or undeployed enemy cards cross the pipe.
		check(not view.has("seed") and not view.has("submissions") and not view.data.has("card_zones"), "no private authority envelope")
		check(view.board.all(func(e): return e.kind != "card" or e.attributes.get("role") == "guard"), "board excludes undeployed cards")
	else:
		var pending: Dictionary = {"action": "game_draw_choice" if row.mode == "stockpile" else "game_market_choice", "player_id": row.seat}
		check(Bot.resolve_choice(game, pending).action != "invalid", "shared economy choice resolves natively")
	print("PASS ", row.name, " (", Time.get_ticks_msec() - started, " ms)")

func failure_paths(row: Dictionary) -> void:
	var game = Game.new()
	if not check(game.restore(row.state).action != "invalid", "failure fixture restores"): return
	var before: Dictionary = game.snapshot()
	var rejected: Dictionary = Bot.exchange(row.view, "plan", func(_plan): return {"action": "invalid", "reason": "directed_rejection"})
	check(rejected.action == "invalid", "exhausted previews fail without old-bot or Pass fallback")
	same(before, game.snapshot(), "rejected planning is atomic")
	var configured: String = OS.get_environment("CORRUPTOR_BOT_PYTHON")
	OS.set_environment("CORRUPTOR_BOT_PYTHON", "corruptor-missing-python-for-test")
	var missing: Dictionary = Bot.plan(game._owner, row.seat)
	OS.set_environment("CORRUPTOR_BOT_PYTHON", configured)
	check(missing.action == "invalid", "missing runtime fails visibly")
	same(before, game.snapshot(), "missing runtime is atomic")
	# Mutations of hidden identity/card faces/order never enter the projection.
	game._owner._seed = "private-seed-changed"
	for world in [game._owner._world, game._owner._presentation_world]:
		world.data.card_zones.deck.reverse()
		for entity in world.entities.entities:
			if entity.id in world.data.card_zones.hands[1 - row.seat]:
				entity.attributes.value = 1
	game._owner._submissions[1 - row.seat] = [{"secret": "sealed-private-order"}]
	same(row.view, Bot.Observation.read(game._owner, row.seat), "hidden information does not cross the pipe")
	var play = Play.new()
	var castles: Array = ["Keep", "Stockpile", "SummoningCircle", "Bastion", "SiegeEngine"]
	if check(play.configure_seed("playable-stockpile", ["Odradek", "Kanifous"], [castles, castles]).action == "game_draw_choice", "economy failure fixture"):
		var checkpoint: Dictionary = play.checkpoint()
		var card: String = play.board_view().world.game_economy.stockpile_pending.card_ids[0]
		OS.set_environment("CORRUPTOR_BOT_PYTHON", "corruptor-missing-python-for-test")
		var failed: Dictionary = play.choose_economy({"keep_id": card})
		OS.set_environment("CORRUPTOR_BOT_PYTHON", configured)
		check(failed.action == "invalid", "bot economy failure reaches the caller")
		same(checkpoint, play.checkpoint(), "bot economy failure preserves the human choice and checkpoint")
		check(play.choose_economy({"keep_id": card}).action != "invalid", "same human choice retries successfully")
	var process: Dictionary = OS.execute_with_pipe(Bot.runtime(), ["-c", "import time; time.sleep(60)"], true)
	if check(not process.is_empty(), "watchdog fixture starts"):
		var watchdog = Bot.Watchdog.new()
		var thread = Thread.new()
		thread.start(Callable(watchdog, "watch").bind(process.pid, 100))
		var output: String = process.stdio.get_line()
		thread.wait_to_finish()
		check(watchdog.expired and output.is_empty(), "watchdog kills stalled worker and unblocks its pipe")
		process.stdio.close()
		process.stderr.close()

func run() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() != 1:
		print("FAIL planner contract file required"); quit(1); return
	var file = FileAccess.open(args[0], FileAccess.READ)
	if not check(file != null, "contracts open"): quit(1); return
	var cases: int = 0
	var finished: bool = false
	var first_plan: Dictionary = {}
	while file.get_position() < file.get_length():
		var decoded: Dictionary = Codec.decode(file.get_line())
		if not check(decoded.action == "decoded", "exact contract decode"): break
		var row: Dictionary = decoded.value
		if row.get("finished", false):
			check(row.cases == cases and cases >= 23, "all declared contracts checked")
			finished = true
			break
		contract(row)
		if first_plan.is_empty() and row.mode == "plan": first_plan = row
		cases += 1
	check(finished, "complete contract stream")
	if not first_plan.is_empty(): failure_paths(first_plan)
	print("U13 shared playable planner: %d cases / %d checks; failures: %d" % [cases, checks, failures])
	quit(failures)
