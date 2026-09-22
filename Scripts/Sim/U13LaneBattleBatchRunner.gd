extends SceneTree
const Sim = preload("res://Scripts/Sim/U13LaneSandbox.gd")
const Metrics = preload("res://Scripts/Sim/U13LaneBattleMetrics.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")

func _initialize() -> void: call_deferred("run")

func write(output: FileAccess, value: Dictionary) -> void:
	output.store_line(JSON.stringify(value))
	output.flush()

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected config.json output.jsonl"); quit(2); return
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not config is Dictionary or int(config.get("rounds", 0)) < 1:
		push_error("Invalid batch config"); quit(2); return
	var output: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	if output == null: push_error("Cannot write output"); quit(2); return
	var sim = Sim.new(config.seed, true, true, config.swapped, 15)
	var metrics = Metrics.new()
	write(output, {"kind": "meta", "schema": "U13_LANE_BATTLE_BATCH_V1", "seed": config.seed, "swapped": config.swapped, "rounds": int(config.rounds), "capacity": 15, "release": "Auto", "goal_advance": true, "godot": Engine.get_version_info().string, "roster": Array(Sim.Marching.SUITS) + Array(Sim.Monsters.NAMES), "rules_version": Sim.Monsters.VERSION})
	for n in range(1, int(config.rounds) + 1):
		var wave: Dictionary = sim.random_waves([0, 1])
		if wave.action == "invalid": push_error(str(wave)); quit(1); return
		var decisions: Array = sim.prepare_releases().duplicate(true)
		metrics.observe(sim.units()); metrics.observe(sim.staged_units(), true)
		var sample: bool = config.get("capture", false) and n == mini(10, int(config.rounds))
		var before: Dictionary = sim.world.duplicate(true) if sample else {}
		var result: Dictionary = Sim.resolve_round(sim.world, sim.seed_value, n)
		if result.action != "resolved": push_error(str(result)); quit(1); return
		var digest: String = Codec.encode(result).text.sha256_text() if sample else ""
		metrics.consume(result.events, n)
		if sample and Codec.encode(result).text.sha256_text() != digest:
			push_error("Observer changed authoritative combat result"); quit(1); return
		sim.finish(result)
		var retired: int = 0
		for total in sim.totals: retired += total.defeated + total.banished + total.escaped
		if sim.totals[0].spawned + sim.totals[1].spawned != retired + sim.units().size() + sim.staged_units().size():
			push_error("Body conservation failed"); quit(1); return
		var record: Dictionary = {"kind": "round", "round": n, "totals": sim.totals.duplicate(true), "active": sim.units().size(), "staged": sim.staged_units().size(), "decisions": decisions, "waves": sim.last_waves.duplicate(true)}
		if sample:
			var encoded: Dictionary = Codec.encode({"world": before, "seed": sim.seed_value, "round": n, "result_sha256": digest, "name": str(config.seed) + ":" + str(config.swapped) + ":" + str(n)})
			record["replay"] = encoded.text
		write(output, record)
		print("ROUND ", n, "/", int(config.rounds), " goals=", [sim.totals[0].reached_goal, sim.totals[1].reached_goal])
	var report: Dictionary = metrics.finish(sim.units(), sim.staged_units(), Sim.Marching.Fort.rows(sim.world))
	if metrics.ticks != int(config.rounds) * 200:
		push_error("Incomplete tick capture"); quit(1); return
	report.merge({"kind": "finished", "totals": sim.totals, "rounds": int(config.rounds)})
	write(output, report)
	output.close()
	quit(0)
