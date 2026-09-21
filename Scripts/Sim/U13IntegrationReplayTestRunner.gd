extends SceneTree

# Replay Python-selected explicit inputs through native rules. This deliberately
# does not claim the native BasicDoctrine chooses the same plans as CommonSmartCore.
const Trace = preload("res://Scripts/Sim/U13ParityTrace.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
var failure: String = ""
var checks: int = 0

func _init() -> void:
	call_deferred("run")

func same(expected, actual, label: String) -> bool:
	checks += 1
	var delta: String = Codec.difference(expected, actual, label)
	if not delta.is_empty(): failure = delta
	return delta.is_empty()

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		print("FAIL exact smoke trace path required"); quit(1); return
	var input = FileAccess.open(args[0], FileAccess.READ)
	if input == null:
		print("FAIL smoke trace cannot be opened"); quit(1); return
	var game = null
	var cases: int = 0
	var operations: int = 0
	var total_operations: int = 0
	var checkpoints: int = 0
	var header: bool = false
	var finished: bool = false
	while input.get_position() < input.get_length() and failure.is_empty():
		var decoded: Dictionary = Codec.decode(input.get_line())
		if decoded.action != "decoded" or typeof(decoded.value) != TYPE_DICTIONARY:
			failure = "invalid exact record"; break
		var row: Dictionary = decoded.value
		if finished:
			failure = "records after finish"; break
		if not header and row.get("kind") != "header":
			failure = "missing header"; break
		match row.get("kind"):
			"header":
				if header or row.get("schema") != "U13_INTEGRATION_SMOKE_V1" or row.get("cases") != 9 or row.get("round_limit") != 4:
					failure = "smoke header mismatch"; break
				header = true
				if not same(row.get("rules"), Trace.Game.Content.new().rules(), "declared_power_rules"): break
				print("Python policy: ", row.policy, "; native explicit-input resolution on ", Engine.get_version_info().string)
			"opening":
				if game != null or row.index != cases or cases >= 9 or row.setup.lords != [Trace.Game.LORDS[cases], Trace.Game.LORDS[(cases + 1) % 9]]:
					failure = "case order or Lord coverage mismatch"; break
				game = Trace.Game.new()
				if game.start(row.setup.seed, row.setup.lords, row.setup.castles, true).action == "invalid":
					failure = "native opening rejected"; break
				if not same(row.state, game.snapshot(), "case%d.opening" % cases): break
				operations = 0
			"operation":
				if game == null or row.index != operations + 1 or operations >= 200:
					failure = "operation sequence mismatch"; break
				var label: String = "case%d.operation%d" % [cases, row.index]
				if not same(row.result, Trace.apply(game, row.operation), label + ".result"): break
				operations += 1
				total_operations += 1
				if row.has("state"):
					if not same(row.state, game.snapshot(), label + ".state"): break
					if not same(row.outcome, game.outcome(), label + ".outcome"): break
					checkpoints += 1
			"case_end":
				if game == null or row.index != cases or row.operations != operations or row.rounds > 4 or (not game.is_finished() and (row.rounds != 4 or not game._owner.next_hook().is_empty())):
					failure = "incomplete case"; break
				print("PASS native replay case ", cases, ": ", operations, " operations")
				cases += 1
				game = null
			"finished":
				if game != null or cases != 9 or row.get("cases") != 9:
					failure = "incomplete nine-Lord trace"; break
				finished = true
			_:
				failure = "unknown record kind"
	if failure.is_empty() and not finished: failure = "truncated trace"
	if not failure.is_empty(): print("FAIL ", failure)
	print("U13 integration replay: %d cases, %d operations, %d round checkpoints, %d checks; failures: %d" % [cases, total_operations, checkpoints, checks, 0 if failure.is_empty() else 1])
	quit(0 if failure.is_empty() else 1)
