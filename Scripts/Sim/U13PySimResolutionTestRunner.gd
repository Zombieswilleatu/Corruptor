extends SceneTree

const Trace = preload("res://Scripts/Sim/U13ParityTrace.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const INPUTS: String = "res://Scripts/Sim/u13_pysim/resolution_inputs.json"
var checks: int = 0
var failures: int = 0
var revision: String
var source_hash: String

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func transport_problem(value, path: String = "suite") -> String:
	if typeof(value) == TYPE_DICTIONARY:
		for key in value:
			if typeof(key) != TYPE_STRING: return path + " key type " + str(typeof(key))
			var found: String = transport_problem(value[key], path + "." + key)
			if not found.is_empty(): return found
	elif typeof(value) == TYPE_ARRAY:
		for index in range(value.size()):
			var found: String = transport_problem(value[index], path + "[%d]" % index)
			if not found.is_empty(): return found
	elif typeof(value) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		return path + " value type " + str(typeof(value))
	return ""

func begin(spec: Dictionary) -> Dictionary:
	var session: Dictionary = Trace.begin(spec.setup, revision, source_hash)
	if session.action != "invalid":
		session.trace.identity.trace_schema = "U13_RESOLUTION_TRACE_V1"
		session.trace.identity.producer = "U13_PYSIM_RESOLUTION_EXPORT_V1"
	return session

func record(session: Dictionary, op: Dictionary) -> Dictionary:
	# Keep rejected operations too, with the entire unchanged state and cursor.
	var before: Dictionary = session.game.snapshot()
	var result: Dictionary = Trace.apply(session.game, op)
	var after: Dictionary = session.game.snapshot()
	var row: Dictionary = {"index": session.trace.records.size(), "round": before.runtime.round,
		"hook_before": before.runtime, "operation": op.duplicate(true), "result": result,
		"state": after, "outcome": session.game.outcome()}
	session.trace.records.append(row)
	return row

func fresh(spec: Dictionary) -> Dictionary:
	var session: Dictionary = begin(spec)
	check(session.action == "trace_started", spec.name + " opens")
	for op in spec.operations:
		var before: Dictionary = session.game.snapshot()
		var row: Dictionary = record(session, op)
		var rejected: bool = op.kind == "step" and op.hook != before.runtime.next_hook
		check((row.result.action == "invalid") == rejected, spec.name + " " + op.kind + " " + str(row.result))
		if rejected: check(Codec.difference(before, row.state).is_empty(), "rejected game operation is atomic")
	check(session.game.snapshot().runtime.next_hook == "post_resolution_spawns", "stops before post-resolution")
	return session.trace

func initial(spec: Dictionary) -> Dictionary:
	var session: Dictionary = begin(spec)
	for op in spec.initial_operations:
		var result: Dictionary = Trace.apply(session.game, op)
		check(result.action != "invalid", spec.name + " independent initial prefix")
	return session.game.snapshot().world

func component_apply(raw: Dictionary, op: Dictionary) -> Dictionary:
	var w: Dictionary = raw.duplicate(true)
	if op.kind == "resolve":
		var content = Trace.Game.Content.new()
		var transformed: Dictionary = content.on_hook({"world": w, "round": op.round,
			"seed": op.seed, "player_order": op.player_order, "hook": op.hook,
			"combat_orders": op.orders, "persistent_effects": []})
		if transformed.action == "invalid": return {"result": transformed, "world": raw}
		var result: Dictionary = transformed.duplicate(true); result.erase("world")
		return {"result": result, "world": transformed.world}
	var ids = Ids.new(); ids.restore(w.entities)
	match op.kind:
		"fixture_patch":
			var row: Dictionary = ids.get_entity(op.entity_id)
			row.attributes.merge(op.attributes, true)
			ids.update(row.id, row.owner, row.attributes); w.entities = ids.snapshot()
		"fixture_set":
			var parent = w
			for key in op.path.slice(0, -1): parent = parent[key]
			parent[op.path[-1]] = Data.copy_data(op.value)
		"fixture_card":
			var z: Dictionary = w.data.card_zones
			for pile in [z.deck, z.discard, z.hands[0], z.hands[1], z.committed[0], z.committed[1], z.market, z.market_reserve]: pile.erase(op.card_id)
			var card: Dictionary = ids.get_entity(op.card_id)
			for key in ["role", "lane", "slot"]: card.attributes.erase(key)
			card.attributes.merge(op.attributes, true)
			ids.update(card.id, op.player_id, card.attributes); w.entities = ids.snapshot()
			if not op.pile.is_empty(): z[op.pile][op.player_id].append(card.id)
		"fixture_spawn":
			var a: Dictionary = Marching.profile(op.suit, op.lane, op.player_id, op.birth, op.ready, true)
			a.merge(op.attributes, true)
			var created: Dictionary = ids.create("marcher", op.origin, op.ordinal, op.player_id, a)
			if created.action == "invalid": return {"result": created, "world": raw}
			w.entities = ids.snapshot()
		_: return {"result": Data.invalid("unknown_resolution_fixture"), "world": raw}
	return {"result": {"action": "fixture_prepared"}, "world": w}

func component(spec: Dictionary) -> Dictionary:
	var w: Dictionary = initial(spec)
	var trace: Dictionary = {"name": spec.name, "initial": w.duplicate(true), "records": []}
	var content = Trace.Game.Content.new()
	for op in spec.operations:
		var before: Dictionary = w.duplicate(true)
		var result: Dictionary = component_apply(w, op)
		w = result.world
		var row: Dictionary = result.duplicate(true); row["operation"] = op.duplicate(true)
		trace.records.append(row)
		var rejected: bool = (spec.name == "reveal_second_player_rejection" and op.kind == "resolve") or (op.kind == "resolve" and before.data.get({"post_repair_artillery": "artillery_round", "commitment_reveal": "combat_reveal_round", "combat_resolution": "combat_resolved_round"}[op.hook], 0) >= op.round)
		check((result.result.action == "invalid") == rejected, spec.name + " " + op.kind)
		if rejected: check(Codec.difference(before, w).is_empty(), "rejected component is atomic")
		check(content.valid_world(w), spec.name + " valid world")
	return trace

func facts(trace: Dictionary, kind: String) -> Array:
	var result: Array = []
	for row in trace.records:
		for event in row.result.get("events", []):
			if event.event.type == kind: result.append(event)
	return result

func coverage(suite: Dictionary) -> void:
	var cases: Dictionary = {}
	var counts: Dictionary = {}
	for trace in suite.components:
		cases[trace.name] = trace
		for row in trace.records:
			for event in row.result.get("events", []): counts[event.event.type] = counts.get(event.event.type, 0) + 1
	for kind in ["ARTILLERY_FIRED", "ARTILLERY_NO_TARGET", "MARCHER_SPAWNED", "GUARD_PAIR_SCREEN", "GUARD_PAIR_STRIKE", "BASTION_SCREENED", "KEEP_INTERPOSED", "PILLAGE_RETARGETED", "PROFANE_RESOLVED", "LORD_BANISHED", "FRACTURE_HIT", "CASTLE_CEILING_CHANGED", "THE_STONES_FORGET", "FEAR_AURA", "SIFTING_THE_RUINS", "GEM_DAGGER", "ACCELERATE", "BLOOD_CONDUIT", "ORIAS_MARKED", "VALAK_ESSENCE_GAINED", "VALAK_ESSENCE_REINFORCED"]:
		check(counts.get(kind, 0) > 0, "directed exposure " + kind)
	check(facts(cases.guard_threshold_5, "SIEGE_RESOLVED")[0].event.data.guards_defeated == 0, "Guard equality survives")
	check(facts(cases.guard_threshold_6, "SIEGE_RESOLVED")[0].event.data.guards_defeated == 1, "strict Guard excess defeats")
	check(facts(cases.artillery_disables_later_engine, "ARTILLERY_FIRED").size() == 1, "disabled later engine does not fire")
	check(facts(cases.fear_breaks_pair_before_screen, "GUARD_PAIR_SCREEN").is_empty(), "Fear breaks pair before screen")
	check(facts(cases.opposing_hunts_after_banishment, "HUNT_RESOLVED").all(func(row): return row.event.data.banished), "both opposing Hunts banish")
	for lord in Trace.Game.LORDS:
		check(facts(cases["banishment_" + lord], "LORD_BANISHED").size() == 1, "banishment reaction exercised " + lord)
	var spawned: Array = facts(cases.recruitment_ward_and_siege, "MARCHER_SPAWNED")
	check(spawned.filter(func(row): return row.event.data.owner == 0).size() == 2 and spawned.filter(func(row): return row.event.data.owner == 1).size() == 1, "Ward 2:1 and Siege 3:1 recruitment floors")
	var gems: Array = facts(cases.gem_dagger_private_draws, "GEM_DAGGER")
	check(gems.size() == 2, "Gem Dagger fires once for each player")
	for row in gems:
		var pid: int = row.event.data.player_id
		check(row.views[pid].data.has("card_id") and not row.views[1 - pid].data.has("card_id"), "Gem Dagger draw stays private")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3:
		print("FAIL output, source revision and fingerprint required"); quit(1); return
	revision = args[1]; source_hash = args[2]
	var text: String = FileAccess.get_file_as_string(INPUTS).replace("\r\n", "\n")
	var spec: Dictionary = Data.copy_data(JSON.parse_string(text))
	check(spec.schema == "U13_RESOLUTION_INPUTS_V1", "explicit input schema")
	var suite: Dictionary = {"schema": "U13_PYSIM_RESOLUTION_SUITE_V1", "inputs_sha256": text.sha256_text(), "games": [], "components": []}
	for game_spec in spec.games: suite.games.append(fresh(game_spec))
	for component_spec in spec.components: suite.components.append(component(component_spec))
	coverage(suite)
	var encoded: Dictionary = Codec.encode(suite)
	check(encoded.action == "encoded", "resolution suite encodes")
	if encoded.action == "invalid": print(transport_problem(suite)); quit(1); return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null: check(false, "output opens"); quit(1); return
	file.store_string(encoded.text + "\n"); file.close()
	var decoded: Dictionary = Codec.decode(FileAccess.get_file_as_string(args[0]))
	check(decoded.action == "decoded" and Codec.difference(suite, decoded.value).is_empty(), "exact transport round trip")
	for index in range(spec.games.size()):
		var session: Dictionary = begin(spec.games[index])
		for op in spec.games[index].operations: record(session, op)
		check(Codec.difference(suite.games[index], session.trace).is_empty(), "Godot replays complete game trace " + str(index))
	for index in range(spec.components.size()):
		var expected: Dictionary = suite.components[index]
		var w: Dictionary = initial(spec.components[index])
		var delta: String = Codec.difference(w, expected.initial)
		for row in expected.records:
			var actual: Dictionary = component_apply(w, row.operation)
			w = actual.world; actual["operation"] = row.operation
			delta = Codec.difference(row, actual)
			if not delta.is_empty(): break
		check(delta.is_empty(), "Godot replays component " + expected.name + " " + delta)
	print("U13 PySim resolution Godot checks: %d" % checks)
	print("U13 PySim resolution Godot failures: %d" % failures)
	quit(0 if failures == 0 else 1)
