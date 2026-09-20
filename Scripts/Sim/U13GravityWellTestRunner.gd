extends "res://Scripts/Sim/U13PySimMarchingTestRunner.gd"

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1: print("FAIL output path required"); quit(1); return
	var specs: Array = Data.copy_data(JSON.parse_string(FileAccess.get_file_as_string("res://Scripts/Sim/u13_pysim/gravity_well_inputs.json")))
	var rows: Array = []
	for spec in specs:
		var first: Dictionary = trace(spec)
		check(Codec.difference(first, trace(spec)).is_empty(), "independent replay " + spec.name)
		rows.append(first)
	var encoded: Dictionary = Codec.encode({"cases": rows})
	check(encoded.action == "encoded", "exact packet encoding")
	var output := FileAccess.open(args[0], FileAccess.WRITE)
	check(output != null, "output opens")
	if output != null: output.store_string(encoded.text + "\n"); output.close()
	print("Gravity well checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
