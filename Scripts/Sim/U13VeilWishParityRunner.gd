extends "res://Scripts/Sim/U13PySimPowersTestRunner.gd"

# Focused explicit-input proof for the five new Breach Wish declarations.
func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 4:
		print("FAIL inputs, output, revision and source hash required")
		quit(1)
		return
	var inputs: Array = Data.copy_data(JSON.parse_string(FileAccess.get_file_as_string(args[0])))
	output = FileAccess.open(args[1], FileAccess.WRITE)
	if not check(output != null, "output opens"):
		quit(1)
		return
	for pass_index in range(2):
		replaying = pass_index == 1
		for spec in inputs:
			if not power_component(spec, args[2], args[3]):
				quit(1)
				return
		if pass_index == 0:
			output.flush()
			output.close()
	check(replay_index == digests.size(), "all Breach Wish records independently replayed")
	print("U13 Veil Wish parity checks: ", checks, "; failures: ", failures)
	quit(1 if failures else 0)
