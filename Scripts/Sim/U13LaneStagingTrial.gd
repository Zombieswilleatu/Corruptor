extends SceneTree

const Sim = preload("res://Scripts/Sim/U13LaneSandbox.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 6:
		push_error("Expected seed, rounds, staging capacity (0/12/15), Auto/March, normal/swap, output.json")
		quit(2); return
	var sim = Sim.new(args[0], true, true, args[4] == "swap", int(args[2]))
	var history: Array = []
	var started: int = Time.get_ticks_msec()
	for n in range(int(args[1])):
		var wave: Dictionary = sim.random_waves([0, 1])
		if wave.action == "invalid": push_error(str(wave)); quit(1); return
		var decisions: Array = sim.prepare_releases([args[3], args[3]]).duplicate(true)
		var result: Dictionary = Sim.resolve_round(sim.world, sim.seed_value, sim.round_number)
		if result.action != "resolved": push_error(str(result)); quit(1); return
		sim.finish(result)
		# Fyra can temporarily change ownership, so check global conservation.
		var retired: int = 0
		for t in sim.totals: retired += t.defeated + t.banished + t.escaped
		if sim.totals[0].spawned + sim.totals[1].spawned != sim.units().size() + sim.staged_units().size() + retired:
			push_error("Body conservation failed at round %d" % (n + 1)); quit(1); return
		history.append({"round": n + 1, "totals": sim.totals.duplicate(true), "field": sim.units().size(), "staged": sim.staged_units().size(), "decisions": decisions})
		if (n + 1) % 5 == 0: print(args[0], " cap=", args[2], " policy=", args[3], " round=", n + 1, " goals=", [sim.totals[0].reached_goal, sim.totals[1].reached_goal])
	var output := FileAccess.open(args[5], FileAccess.WRITE)
	output.store_string(JSON.stringify({"seed": sim.seed_value, "capacity": int(args[2]), "policy": args[3], "swapped": sim.seats_swapped, "history": history, "totals": sim.totals, "world": sim.world, "elapsed_ms": Time.get_ticks_msec() - started}))
	output.close()
	quit()
