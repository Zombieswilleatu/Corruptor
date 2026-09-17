extends SceneTree

const Trace = preload("res://Scripts/Sim/U13ParityTrace.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		print("FAIL inputs and output required")
		quit(1)
		return
	var cases: Array = Data.copy_data(JSON.parse_string(FileAccess.get_file_as_string(args[0])))
	var output = FileAccess.open(args[1], FileAccess.WRITE)
	for spec in cases:
		var opened: Dictionary = Trace.begin(spec.setup, "working-tree", "directed-veil-game-check")
		if opened.action != "trace_started":
			print("FAIL opening ", spec.name, ": ", opened)
			quit(1)
			return
		var game = opened.game
		for i in range(spec.operations.size()):
			var result: Dictionary = Trace.apply(game, spec.operations[i])
			if result.action == "invalid":
				print("FAIL ", spec.name, " op ", i, " round ", game._owner.round_number(), ": ", result)
				quit(1)
				return
		if not game.is_finished():
			print("FAIL unfinished ", spec.name)
			quit(1)
			return
		var state: Dictionary = game.snapshot()
		var restored = Trace.Game.new()
		if restored.restore(state).action == "invalid" or restored.snapshot() != state:
			print("FAIL final save ", spec.name)
			quit(1)
			return
		output.store_line(Codec.encode({"name": spec.name, "state": state}).text)
		output.flush()
		print("PASS complete game ", spec.name, " · round ", game._owner.round_number(), " · ", state.world.data.veil_breaches.arrivals.size(), " arrivals")
	output.close()
	quit()
