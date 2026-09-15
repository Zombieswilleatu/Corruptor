extends SceneTree

# Isolated subsystem inputs, deliberately without implicit Lord reactions.
# Calls the production Marching phase; this exporter contains no tick loop.
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Gravity = preload("res://Scripts/Sim/U13GravityOrbs.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const INPUTS: String = "res://Scripts/Sim/u13_pysim/marching_inputs.json"
var checks: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func initial(spec: Dictionary) -> Dictionary:
	var ids = Ids.new()
	for unit in spec.units:
		var a: Dictionary = Marching.profile(unit.suit, unit.lane, unit.owner, unit.get("birth", 0), unit.get("ready", 1), spec.ranged)
		a.merge(unit.attributes, true)
		var created: Dictionary = ids.create("marcher", unit.origin, unit.ordinal, unit.owner, a)
		assert(created.action != "invalid")
	var state: Dictionary = ids.snapshot()
	if spec.get("reverse_registry", false):
		state.entities.reverse(); state.used_ids.reverse()
	var data: Dictionary = spec.data.duplicate(true)
	if spec.ranged: data["ranged_profile"] = Marching.Ranged.VERSION
	return {"entities": state, "data": data}

func context(spec: Dictionary, world: Dictionary, number: int, hook: String = "marching") -> Dictionary:
	return {"world": world, "seed": spec.seed, "round": number, "hook": hook,
		"player_order": spec.player_order, "persistent_effects": spec.effects}

static func reaction(world: Dictionary, _fact: Dictionary, _seed: String, _order: Array) -> Dictionary:
	return {"action": "resolved", "world": world, "events": []}

static func reject_reaction(_world: Dictionary, _fact: Dictionary, _seed: String, _order: Array) -> Dictionary:
	return {"action": "invalid", "reason": "deliberate_fixture_rejection"}

func apply(spec: Dictionary, raw: Dictionary, op: Dictionary) -> Dictionary:
	if op.kind in ["march", "regen"]:
		var ctx: Dictionary = context(spec, raw, op.round, op.get("hook", "marching" if op.kind == "march" else "round_start_automatic"))
		var result: Dictionary = Marching.resolve(ctx, Callable(self, "reject_reaction" if spec.get("reaction") == "reject" else "reaction")) if op.kind == "march" else Marching.regenerate(ctx)
		var world: Dictionary = result.get("world", raw)
		result.erase("world")
		return {"result": result, "world": world}
	var world: Dictionary = raw.duplicate(true)
	var ids = Ids.new(); ids.restore(world.entities)
	match op.kind:
		"fixture_retire": ids.retire(op.id)
		"fixture_owner":
			var unit: Dictionary = ids.get_entity(op.id)
			unit.attributes.direction = 1 if op.owner == 0 else -1
			ids.update(unit.id, op.owner, unit.attributes)
		"fixture_patch":
			var unit: Dictionary = ids.get_entity(op.id)
			unit.attributes.merge(op.attributes, true)
			ids.update(unit.id, unit.owner, unit.attributes)
	world.entities = ids.snapshot()
	return {"result": {"action": "fixture_prepared"}, "world": world}

func probe(spec: Dictionary, world: Dictionary, input: Dictionary) -> Dictionary:
	var ids = Ids.new(); ids.restore(world.entities)
	var ctx: Dictionary = context(spec, world, 1); ctx.seed = input.seed
	var selected: Array = Marching._contact_pair(ids, input.lane, ctx, input.clock)
	# Expose the key/candidate construction alongside the authoritative selector.
	var teams: Array = Marching._teams(Marching._units(ids))[input.lane]
	var candidates: Array = []
	var earliest: int = 9223372036854775807
	for left in teams[0]:
		for right in teams[1]:
			if Marching.Ranged.enabled(world) and (not Marching.Ranged.melee_ready(left, input.clock) or not Marching.Ranged.melee_ready(right, input.clock)): continue
			if Marching._distance(left.attributes, right.attributes) > 180 * 180: continue
			var arrived: int = maxi(input.clock if left.attributes.contact_tick < 0 else left.attributes.contact_tick, input.clock if right.attributes.contact_tick < 0 else right.attributes.contact_tick)
			if arrived < earliest:
				earliest = arrived; candidates = [[left.id, right.id]]
			elif arrived == earliest: candidates.append([left.id, right.id])
	var key: String = Data.instance_id("contact_queue", str(input.clock), input.lane)
	var value = null if candidates.is_empty() else Marching.Rng.draw(input.seed, key, "CONTACT_TIE", 0, candidates.size()).value
	return {"key": key, "purpose": "CONTACT_TIE", "roll_index": 0, "bound": candidates.size(), "value": value,
		"earliest": null if candidates.is_empty() else earliest, "candidates": candidates, "selected": selected}

func trace(spec: Dictionary) -> Dictionary:
	var world: Dictionary = initial(spec)
	check(Marching.valid(world), spec.name + " initial Marching state valid")
	check(Gravity.valid(world.data.get("valak_orbs", [])), spec.name + " Gravity actor inputs valid")
	var result: Dictionary = {"name": spec.name, "initial": world.duplicate(true), "probes": [], "records": []}
	for input in spec.contact_probes:
		var selected: Dictionary = probe(spec, world, input)
		result.probes.append({"input": input.duplicate(true), "result": selected})
		check(not selected.selected.is_empty(), spec.name + " contact probe")
	for op in spec.operations:
		var before: Dictionary = world.duplicate(true)
		var record: Dictionary = apply(spec, world, op)
		world = record.world
		record["operation"] = op.duplicate(true)
		result.records.append(record)
		check(record.result.action == op.expected_action, spec.name + " " + op.kind + " expected result")
		if record.result.action == "invalid": check(Codec.difference(before, world).is_empty(), spec.name + " whole operation rollback")
		if record.result.action == "resolved":
			check(Marching.valid(world), spec.name + " resulting Marching state valid")
			if op.kind == "march":
				var ticks: Array = record.result.events.filter(func(row): return row.event.type == "MARCHING_TICK")
				check(ticks.size() == 200, spec.name + " all 200 tick frames")
	return result

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3: print("FAIL output and source identity required"); quit(1); return
	var text: String = FileAccess.get_file_as_string(INPUTS).replace("\r\n", "\n")
	var input: Dictionary = Data.copy_data(JSON.parse_string(text))
	check(input.schema == "U13_MARCHING_INPUTS_V1", "input schema")
	var suite: Dictionary = {"schema": "U13_PYSIM_MARCHING_SUITE_V1", "inputs_sha256": text.sha256_text(),
		"identity": {"source_revision": args[1], "source_sha256": args[2], "runtime": Engine.get_version_info().string,
			"platform": OS.get_name(), "authority": "Godot U13Marching.resolve", "model": Marching.VERSION,
			"scope": "isolated phases; explicit fields/actors; no Lord reactions", "tick_profile": "complete MARCHING_TICK attribute_delta_v1"}, "cases": []}
	for spec in input.cases: suite.cases.append(trace(spec))
	var encoded: Dictionary = Codec.encode(suite)
	check(encoded.action == "encoded", "suite exact encode")
	if encoded.action == "invalid": quit(1); return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null: check(false, "output opens"); quit(1); return
	file.store_string(encoded.text + "\n"); file.close()
	var decoded: Dictionary = Codec.decode(FileAccess.get_file_as_string(args[0]))
	check(decoded.action == "decoded" and Codec.difference(decoded.value, suite).is_empty(), "exact transport round trip")
	for index in range(input.cases.size()):
		var replay: Dictionary = trace(input.cases[index])
		var delta: String = Codec.difference(suite.cases[index], replay)
		check(delta.is_empty(), "independent Godot replay " + input.cases[index].name + " " + delta)
	check(Codec.difference(suite.cases[2].records, suite.cases[3].records).is_empty(), "keyed front ties ignore registry insertion order")
	print("U13 PySim marching Godot checks: %d" % checks)
	print("U13 PySim marching Godot failures: %d" % failures)
	quit(0 if failures == 0 else 1)
