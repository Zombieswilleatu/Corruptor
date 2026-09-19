extends SceneTree

# Read isolated range-trial phases through exact typed transport. No UI or Lords.
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")

func _initialize() -> void:
	call_deferred("run")

static func reaction(world: Dictionary, _fact: Dictionary, _seed: String, _order: Array) -> Dictionary:
	return {"action": "resolved", "world": world, "events": []}

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 4:
		push_error("Expected input contexts, output phases, Vulture range and tower range")
		quit(2)
		return
	if Marching.Ranged.RANGE_FP != int(args[2]) or Marching.Fort.TOWER_RANGE != int(args[3]):
		push_error("Native range settings do not match the requested trial")
		quit(1)
		return
	var source = FileAccess.open(args[0], FileAccess.READ)
	var output = FileAccess.open(args[1], FileAccess.WRITE)
	if source == null or output == null:
		push_error("Cannot open range replay files")
		quit(2)
		return
	var count: int = 0
	while not source.eof_reached():
		var line: String = source.get_line()
		if line.is_empty(): continue
		var decoded: Dictionary = Codec.decode(line)
		if decoded.action != "decoded":
			push_error("Invalid exact range input")
			quit(1)
			return
		var record: Dictionary = decoded.value
		var result: Dictionary = Marching.resolve(record.context, Callable(self, "reaction"))
		if result.action != "resolved":
			push_error(str(record.name) + ": " + str(result))
			quit(1)
			return
		var encoded: Dictionary = Codec.encode({"name": record.name, "context": record.context, "result": result})
		if encoded.action != "encoded":
			push_error("Cannot encode range result")
			quit(1)
			return
		output.store_line(encoded.text)
		count += 1
	output.close()
	print("Range replay phases: ", count)
	quit(0)
