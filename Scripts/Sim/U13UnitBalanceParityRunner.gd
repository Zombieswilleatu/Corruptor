extends SceneTree

# Replay explicit audit inputs through the native sandbox, with no bot, Lord,
# Castle or economy layer. Production rules are never patched by this runner.
const Sandbox = preload("res://Scripts/Sim/U13LaneSandbox.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected input JSONL and output JSONL paths")
		quit(1)
		return
	var inputs = FileAccess.open(args[0], FileAccess.READ)
	var output = FileAccess.open(args[1], FileAccess.WRITE)
	if inputs == null or output == null:
		push_error("Could not open parity files")
		quit(1)
		return
	var phases: int = 0
	while not inputs.eof_reached():
		var line: String = inputs.get_line()
		if line.is_empty(): continue
		var spec: Dictionary = Data.copy_data(JSON.parse_string(line))
		var result: Dictionary = Sandbox.resolve_round(spec.world, spec.seed, spec.round)
		if result.action != "resolved":
			push_error(str(result))
			quit(1)
			return
		result.events = result.events.filter(func(row): return row.event.type != "MARCHING_TICK")
		var encoded: Dictionary = Codec.encode(result)
		if not encoded.has("text"):
			push_error(str(encoded))
			quit(1)
			return
		output.store_line(encoded.text)
		output.flush()
		phases += 1
	print("U13 unit balance native phases: ", phases)
	quit(0)
