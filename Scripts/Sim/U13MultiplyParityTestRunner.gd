extends SceneTree

const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Trace = preload("res://Scripts/Sim/U13ParityTrace.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
	return ok

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty(): print("Generate a parity fixture with generate_u13_multiply_parity.py and pass its path."); quit(1); return
	var input: Dictionary = Codec.decode(FileAccess.get_file_as_string(args[0]))
	if not check(input.action == "decoded", "exact fixture decode"): quit(1); return
	for case in input.value:
		var game = Game.new()
		var restored: Dictionary = game.restore(case.initial)
		if not check(restored.action != "invalid", case.name + " restore: " + str(restored)): quit(1); return
		for step in case.steps:
			var result: Dictionary = game.submit(step.operation.plans) if step.operation.kind == "submit" else Trace.apply(game, step.operation)
			if not check(result.action != "invalid", case.name + " operation: " + str(result)): quit(1); return
			var delta: String = Codec.difference(step.result, result)
			if not check(delta.is_empty(), case.name + " result " + delta): quit(1); return
			delta = Codec.difference(step.state, game.snapshot())
			if not check(delta.is_empty(), case.name + " state " + delta): quit(1); return
			var copy = Game.new()
			if not check(copy.restore(game.snapshot()).action != "invalid", case.name + " save reload"): quit(1); return
		print("PASS ", case.name)
	print("U13 Multiply native parity: %d checks, failures: %d" % [checks, failures])
	quit(failures)
