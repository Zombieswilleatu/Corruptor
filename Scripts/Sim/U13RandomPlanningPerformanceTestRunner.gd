extends SceneTree
const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Batch = preload("res://Scripts/Sim/U13FullMatchBatch.gd")
const Old = preload("res://Scripts/Sim/U13GameRandomLegalReference.gd")
const Lazy = preload("res://Scripts/Sim/U13RandomPowerChoice.gd")
var failures: int = 0
var samples: Array = []
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func same(a, b): return var_to_bytes(a) == var_to_bytes(b)
func compare(game, label: String, resolve_round: bool):
	if game.to_planning(true).action != "game_planning":
		check(false, label + " reach planning")
		return
	var snapshot: Dictionary = game.snapshot()
	var old_plans: Array = []
	var fast_plans: Array = []
	for pid in [0, 1]:
		var fast: Dictionary
		var old: Dictionary
		var row: Dictionary = {"case": label, "player": pid}
		for reference in ([true, false] if pid == 0 else [false, true]):
			var begin = Time.get_ticks_usec()
			if reference:
				old = Old.plan(game._owner, pid)
				row.reference_ms = (Time.get_ticks_usec()-begin)/1000.0
			else:
				fast = Game.GameBot.plan(game._owner, pid)
				row.optimized_ms = (Time.get_ticks_usec()-begin)/1000.0
		check(fast.action == "bot_plan" and same(fast, old) and same(snapshot, game.snapshot()), label + " identical read-only plan seat " + str(pid))
		old_plans.append(old); fast_plans.append(fast)
		samples.append(row)
		print("PROFILE ", JSON.stringify(row))
	if resolve_round and failures == 0:
		var mirror = Game.new()
		check(mirror.restore(snapshot).action != "invalid", label + " restore replay")
		check(same(game.submit(fast_plans), mirror.submit(old_plans)), label + " exact submissions")
		while not game._owner.next_hook().is_empty():
			check(same(game.step(), mirror.step()) and same(game.snapshot(), mirror.snapshot()), label + " exact hook")
		check(same(game.outcome(), mirror.outcome()), label + " exact outcome")
		var saved = Game.new()
		check(saved.restore_json(game.snapshot_json()).action != "invalid" and same(saved.snapshot(), game.snapshot()), label + " exact final save")

func domains(game):
	var owner = game._owner
	var before = game.snapshot()
	for pid in [0, 1]:
		var raw: Array = Game.Scenario.enumerate(owner, pid).powers
		if not raw.is_empty():
			var malformed = raw[0].duplicate(true)
			malformed.declaration_id = "wrong"
			raw.append_array([raw[0].duplicate(true), malformed, null, {}, "invalid"])
		for source in raw.duplicate():
			if typeof(source) == TYPE_DICTIONARY and source.get("cost", {}).has("discard_ids"):
				var reversed = source.duplicate(true)
				reversed.cost.discard_ids.reverse()
				raw.append(reversed)
				break
		var expected: Array = Old.Legality.legal_power_groups(owner, pid, raw)
		var actual: Array = []
		for row in Lazy.groups(owner, pid, raw):
			actual.append({"power": row.power, "candidates": Lazy.candidates(owner, pid, row)})
		check(same(expected, actual) and same(before, game.snapshot()), "complete sorted domains, malformed rejection and duplicate normalization seat " + str(pid))

func run():
	var checkpoints: Array = []
	var output: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--checkpoint="): checkpoints.append(arg.trim_prefix("--checkpoint="))
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		else: check(false, "unknown argument")
	for index in [9,19,29,39,49,59,69,79,8]:
		var setup: Dictionary = Batch.setup(index)
		var game = Game.new()
		check(game.start(setup.seed,setup.lords,setup.castles,true).action != "invalid", "start " + str(index))
		check(game.to_planning(true).action == "game_planning", "planning " + str(index))
		domains(game)
		compare(game,"opening-"+str(index),false)
	for path in checkpoints:
		var source = JSON.parse_string(FileAccess.get_file_as_string(path))
		var game = Game.new()
		if typeof(source) != TYPE_DICTIONARY or typeof(source.get("save_json")) != TYPE_STRING:
			check(false,"checkpoint envelope")
			continue
		check(game.restore_json(source.save_json).action != "invalid", "restore " + path)
		compare(game,path.get_file(),true)
	var report: Dictionary = {"failures": failures, "runtime": Engine.get_version_info().string, "samples": samples}
	if not output.is_empty():
		var file = FileAccess.open(output,FileAccess.WRITE)
		if file == null: check(false,"report write")
		else: file.store_string(JSON.stringify(report,"\t"))
	print("U13 random planning performance failures: ",failures)
	quit(failures)
