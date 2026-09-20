extends SceneTree

# Offline audit: production sandbox spawning/staging, plus exact replay hashes.
const Sim = preload("res://Scripts/Sim/U13LaneSandbox.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")

func _initialize() -> void:
	call_deferred("run")

func write(file, value: Dictionary) -> void:
	var encoded: Dictionary = Codec.encode(value)
	assert(encoded.action == "encoded")
	file.store_line(encoded.text)

func export_cases(config: Dictionary, path: String) -> void:
	var output = FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	var count: int = 0
	for spec in config.cases:
		for index in range(int(config.seeds)):
			var seed_value: String = "monster-audit:%d" % index
			var sim = Sim.new(seed_value, true, true, false, 15)
			var teams: Array = spec.get("teams", [[], []]).duplicate(true)
			var hand: Array = []
			if spec.has("recipe"):
				var deck = Sim.Enemy.new(seed_value + ":recipe:" + spec.recipe, 0)
				var ordinary: Array = []
				for suit in Sim.Monsters.ROSTER[spec.recipe].recipe:
					var cards: Array = deck.deck.filter(func(card): return card.attributes.suit == suit).slice(0, Sim.Monsters.ROSTER[spec.recipe].recipe[suit])
					hand.append_array(cards)
					var total: int = 0
					for card in cards: total += int(card.attributes.value)
					for i in range(floori(float(total) / 3.0)): ordinary.append(suit)
				# Artificial replacement benchmark, not an actual commitment choice:
				# production reveal summons the regular troops AND the monster.
				teams = [spec.get("core", []) + [spec.recipe], spec.get("core", []) + ordinary]
			for pid in [0, 1]:
				for name in teams[pid]:
					var spawned: Dictionary = sim.spawn(name, pid)
					assert(spawned.action == "spawned", str(spawned))
			# Reserves cannot act during their empty birth interval. Start these
			# controlled fights at their first legal release, using real deploy().
			sim.round_number = 2
			sim.prepare_releases(["March", "March"])
			assert(sim.staged_units().is_empty())
			for reflected in [false, true]:
				write(output, {"case": spec.name, "group": spec.group, "focus": spec.get("focus", spec.get("recipe", "")), "teams": teams, "recipe_hand": hand, "seed": seed_value, "seed_index": index, "reflected": reflected, "round": 2, "world": Sim.mirror(sim.world) if reflected else sim.world})
				count += 1
		print("EXPORTED ", spec.name, " · ", count)
	output.close()

func waves(seed_value: String, rounds: int, swapped: bool, path: String) -> void:
	var sim = Sim.new(seed_value, true, true, swapped, 15)
	var output = FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	write(output, {"kind": "meta", "seed": seed_value, "swapped": swapped, "rounds": rounds, "capacity": 15, "policy": "Auto", "balance_preview": true})
	for n in range(1, rounds + 1):
		var wave: Dictionary = sim.random_waves([0, 1])
		assert(wave.action != "invalid", str(wave))
		var decisions: Array = sim.prepare_releases().duplicate(true)
		var before: Array = sim.units().duplicate(true)
		var reserves: Array = sim.staged_units().duplicate(true)
		var raw: Dictionary = sim.world.duplicate(true)
		var result: Dictionary = Sim.resolve_round(sim.world, sim.seed_value, n)
		assert(result.action == "resolved", str(result))
		var events: Array = result.events.filter(func(row): return row.event.type != "MARCHING_TICK").map(func(row): return row.event)
		var record: Dictionary = {"kind": "round", "round": n, "before": before, "staged": reserves, "decisions": decisions, "waves": sim.last_waves.duplicate(true), "events": events}
		if n in [5, 20]:
			record["parity"] = {"world": raw, "round": n, "seed": sim.seed_value, "result_sha256": Codec.encode(result).text.sha256_text()}
		sim.finish(result)
		var retired: int = 0
		for total in sim.totals: retired += total.defeated + total.banished + total.escaped
		assert(sim.totals[0].spawned + sim.totals[1].spawned == retired + sim.units().size() + sim.staged_units().size(), "Body conservation")
		record["totals"] = sim.totals.duplicate(true)
		record["after"] = sim.units().duplicate(true)
		write(output, record)
		output.flush()
		if n % 5 == 0: print("WAVES ", seed_value, " swap=", swapped, " round=", n, " goals=", [sim.totals[0].reached_goal, sim.totals[1].reached_goal])
	write(output, {"kind": "finished", "world": sim.world, "totals": sim.totals})
	output.close()

func hashes(input_path: String, output_path: String, full_result: bool = false) -> void:
	var input = FileAccess.open(input_path, FileAccess.READ)
	var output = FileAccess.open(output_path, FileAccess.WRITE)
	assert(input != null and output != null)
	while not input.eof_reached():
		var line: String = input.get_line()
		if line.is_empty(): continue
		var record: Dictionary = Codec.decode(line).value
		var result: Dictionary = Sim.resolve_round(record.world, record.seed, record.round)
		assert(result.action == "resolved", str(result))
		var record_result: Dictionary = {"name": record.name, "result_sha256": Codec.encode(result).text.sha256_text()}
		if full_result: record_result["result"] = result
		write(output, record_result)
		output.flush()
		print("HASHED ", record.name)
	output.close()

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 3 and args[0] == "export":
		export_cases(JSON.parse_string(FileAccess.get_file_as_string(args[1])), args[2])
	elif args.size() == 5 and args[0] == "waves":
		waves(args[1], int(args[2]), args[3] == "swap", args[4])
	elif args.size() == 3 and args[0] in ["hashes", "replays"]:
		hashes(args[1], args[2], args[0] == "replays")
	else:
		push_error("Expected export config.json output.jsonl; waves seed rounds normal/swap output.jsonl; or hashes/replays input.jsonl output.jsonl")
		quit(2)
		return
	quit(0)
