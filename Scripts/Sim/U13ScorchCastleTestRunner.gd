extends "res://Scripts/Sim/U13PySimPowersTestRunner.gd"


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 4:
		print("FAIL output, inputs and source identity required"); quit(1); return
	var source: String = FileAccess.get_file_as_string(args[1]).replace("\r\n", "\n")
	var inputs: Dictionary = Data.copy_data(JSON.parse_string(source))
	if not check(inputs.get("schema") == "U13_SCORCH_CASTLE_CASES_V1", "Scorch input schema"):
		quit(1); return
	var header: Dictionary = {"kind": "header", "schema": "U13_SCORCH_CASTLE_EXACT_V1",
		"inputs_sha256": source.sha256_text(), "source_revision": args[2], "source_sha256": args[3],
		"runtime": Engine.get_version_info().string, "platform": OS.get_name()}
	output = FileAccess.open(args[0], FileAccess.WRITE)
	if not check(output != null, "Scorch output opens"): quit(1); return
	for pass_index in range(2):
		replaying = pass_index == 1
		if not emit(header): quit(1); return
		for spec in inputs.cases:
			if not power_component(spec, args[2], args[3]): quit(1); return
		if pass_index == 0: output.flush(); output.close()
	check(replay_index == digests.size(), "all Scorch records independently replayed")
	print("U13 Scorch Castle Godot checks: %d" % checks)
	print("U13 Scorch Castle Godot failures: %d" % failures)
	quit(0 if failures == 0 else 1)
