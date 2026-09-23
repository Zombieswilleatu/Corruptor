extends SceneTree

const Observation = preload("res://Scripts/Sim/U13CommonObservation.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
var failures: int = 0
var checks: int = 0

func same(expected, actual, label: String) -> void:
	checks += 1
	var difference: String = Codec.difference(expected, actual, label)
	if not difference.is_empty():
		failures += 1
		print("FAIL ", difference)

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Usage: --script Scripts/Sim/U13OpponentMemoryTestRunner.gd -- exact-fixture.json")
		quit(2)
		return
	var decoded: Dictionary = Codec.decode(FileAccess.get_file_as_string(args[0]))
	if decoded.action != "decoded":
		quit(2)
		return
	for row in decoded.value:
		var before: Array = row.rows.duplicate(true)
		same(row.expected, Observation.opponent_history(row.rows, row.seat, row.round), row.name)
		same(before, row.rows, row.name + " immutable events")
	print("Opponent memory: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
