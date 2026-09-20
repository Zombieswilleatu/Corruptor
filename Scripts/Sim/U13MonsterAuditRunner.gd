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
			if spec.group == "additive":
				count += export_additive(spec, index, seed_value, output)
				continue
			if spec.group == "monster_army":
				count += export_armies(spec, index, seed_value, output)
				continue
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

func export_additive(spec: Dictionary, index: int, seed_value: String, output) -> int:
	# Build the real commitment first, then omit only its monster for the
	# counterfactual. Companion/enemy IDs, positions and keyed RNG stay fixed.
	var sim = Sim.new(seed_value, true, true, false, 15)
	var deck = Sim.Enemy.new(seed_value + ":recipe:" + spec.recipe, 0)
	var hand: Array = []
	for suit in Sim.Monsters.ROSTER[spec.recipe].recipe:
		hand.append_array(deck.deck.filter(func(c): return c.attributes.suit == suit).slice(0, Sim.Monsters.ROSTER[spec.recipe].recipe[suit]))
	var ids = Sim.Ids.new(); ids.restore(sim.world.entities)
	var cards: Array = []
	for i in range(hand.size()):
		var made: Dictionary = ids.create("card", "audit:recipe:" + spec.recipe, i, 0, hand[i].attributes)
		assert(made.action != "invalid", str(made))
		cards.append(made.entity.id)
	sim.world.entities = ids.snapshot()
	var order: Dictionary = {"action": "Hunt", "lane": "Lord", "card_ids": cards, "monster_choice": spec.recipe}
	assert(Sim.Monsters.validate_choice(sim.world, 0, order).action == "legal")
	var revealed: Dictionary = Sim.Combat._reveal({"world": sim.world, "round": 1, "seed": seed_value, "player_order": [0], "combat_orders": {0: order}})
	assert(revealed.action == "resolved", str(revealed))
	sim.world = revealed.world
	ids.restore(sim.world.entities)
	for identity in cards: ids.retire(identity)
	sim.world.entities = ids.snapshot()
	# Confirm the recipe did not replace or consume any ordinary spawns.
	for suit in Sim.Marching.SUITS:
		var total: int = 0
		for card in hand:
			if card.attributes.suit == suit: total += int(card.attributes.value)
		assert(sim.units().filter(func(u): return u.attributes.suit == suit).size() == floori(float(total) / 3.0))
	var summoned: Array = sim.units().filter(func(u): return u.attributes.get("monster_id") == spec.recipe).map(func(u): return u.id)
	assert((summoned.size() >= 3 and summoned.size() <= 5) if spec.recipe == "Varn" else summoned.size() == 1)
	Sim.Staging.store_units(sim.world, sim.units().map(func(u): return u.id), 1)
	for who in spec.core:
		assert(sim.spawn(who, 0).action == "spawned")
	for who in spec.opposition:
		assert(sim.spawn(who, 1).action == "spawned")
	sim.round_number = 2
	sim.prepare_releases(["March", "March"])
	assert(sim.staged_units().is_empty())
	var augmented: Dictionary = sim.world.duplicate(true)
	var baseline: Dictionary = augmented.duplicate(true)
	ids.restore(baseline.entities)
	for identity in summoned: ids.retire(identity)
	baseline.entities = ids.snapshot()
	assert(baseline.entities.entities == augmented.entities.entities.filter(func(u): return u.id not in summoned))
	assert(Sim.Marching.valid(baseline) and Sim.Marching.valid(augmented))
	for variant in ["without", "with"]:
		var world: Dictionary = baseline if variant == "without" else augmented
		var teams: Array = []
		for pid in [0, 1]:
			teams.append(world.entities.entities.filter(func(u): return u.owner == pid).map(func(u): return u.attributes.get("monster_id", u.attributes.suit)))
		for reflected in [false, true]:
			write(output, {"case": spec.name + ":" + variant, "comparison": spec.name, "group": "additive", "focus": spec.recipe, "opponent": spec.opponent, "variant": variant, "added_bodies": summoned.size(), "teams": teams, "recipe_hand": hand, "seed": seed_value, "seed_index": index, "reflected": reflected, "round": 2, "world": Sim.mirror(world) if reflected else world})
	return 4

func export_armies(spec: Dictionary, index: int, seed_value: String, output) -> int:
	var sim = Sim.new(seed_value, true, true, false, 15)
	var ids = Sim.Ids.new(); ids.restore(sim.world.entities)
	var hands: Array = []
	var orders: Dictionary = {}
	var all_cards: Array = []
	for pid in [0, 1]:
		var who: String = spec.monsters[pid]
		var deck = Sim.Enemy.new(seed_value + ":recipe:" + who, 0)
		var hand: Array = []
		for suit in Sim.Monsters.ROSTER[who].recipe:
			hand.append_array(deck.deck.filter(func(c): return c.attributes.suit == suit).slice(0, Sim.Monsters.ROSTER[who].recipe[suit]))
		hands.append(hand)
		var cards: Array = []
		for i in range(hand.size()):
			var made: Dictionary = ids.create("card", "audit:army:%d:%s" % [pid, who], i, pid, hand[i].attributes)
			assert(made.action != "invalid", str(made))
			cards.append(made.entity.id)
		all_cards.append_array(cards)
		orders[pid] = {"action": "Hunt", "lane": "Lord", "card_ids": cards, "monster_choice": who}
	sim.world.entities = ids.snapshot()
	for pid in [0, 1]: assert(Sim.Monsters.validate_choice(sim.world, pid, orders[pid]).action == "legal")
	var revealed: Dictionary = Sim.Combat._reveal({"world": sim.world, "round": 1, "seed": seed_value, "player_order": [0, 1], "combat_orders": orders})
	assert(revealed.action == "resolved", str(revealed))
	sim.world = revealed.world
	ids.restore(sim.world.entities)
	for identity in all_cards: ids.retire(identity)
	sim.world.entities = ids.snapshot()
	for pid in [0, 1]:
		for suit in Sim.Marching.SUITS:
			var total: int = 0
			for card in hands[pid]:
				if card.attributes.suit == suit: total += int(card.attributes.value)
			assert(sim.units().filter(func(u): return u.owner == pid and u.attributes.suit == suit).size() == floori(float(total) / 3.0))
	Sim.Staging.store_units(sim.world, sim.units().map(func(u): return u.id), 1)
	for pid in [0, 1]:
		for who in spec.core: assert(sim.spawn(who, pid).action == "spawned")
	sim.round_number = 2
	sim.prepare_releases(["March", "March"])
	assert(sim.staged_units().is_empty() and Sim.Marching.valid(sim.world))
	var teams: Array = []
	for pid in [0, 1]: teams.append(sim.units().filter(func(u): return u.owner == pid).map(func(u): return u.attributes.get("monster_id", u.attributes.suit)))
	var capture: bool = "Kurchin" in spec.monsters and spec.monsters.any(func(who): return who in ["Fyra", "Muno", "Dotra", "Sinodek"])
	for reflected in [false, true]:
		write(output, {"case": spec.name, "group": "monster_army", "focus": spec.monsters[0], "capture": capture, "teams": teams, "recipe_hand": hands, "seed": seed_value, "seed_index": index, "reflected": reflected, "round": 2, "world": Sim.mirror(sim.world) if reflected else sim.world})
	return 2

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
