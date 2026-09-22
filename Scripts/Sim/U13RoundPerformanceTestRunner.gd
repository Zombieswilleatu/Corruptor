extends SceneTree
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const OldIds = preload("res://Scripts/Sim/U13EntityIdsReference.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const OldData = preload("res://Scripts/Sim/U13RoundPerformanceDataReference.gd")
const Buffer = preload("res://Scripts/Sim/U13MarchingBuffer.gd")
const MatchOwner = preload("res://Scripts/Sim/U13Match.gd")
const Log = preload("res://Scripts/Sim/U13EventLog.gd")
var failures: int = 0
var checks: int = 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func exact(a, b) -> bool: return var_to_bytes(a) == var_to_bytes(b)
func nested(depth: int):
	var v = 1
	for i in range(depth): v = [v]
	return v
func thread_restore(raw: Dictionary) -> bool:
	for i in range(20):
		var ids = Ids.new()
		if ids.restore(raw).action == "invalid": return false
		var row: Dictionary = ids.snapshot().entities[0]
		row.attributes["worker"] = i
		ids.update(row.id, row.owner, row.attributes)
	return true
func run():
	var values: Array = [null, true, false, 1, 1.0, -0.0, 1.5, INF, NAN, 9007199254740992, "x", Vector2.ZERO, {"x_fp": 0.5}, {"x_fp": true}, {1: "bad"}, {"x_fp": 2.0, "a": [1.0, 1.5, {"b": false}]}]
	for depth in [62, 63, 64, 65, 66]: values.append(nested(depth))
	var object = RefCounted.new()
	values.append(object)
	for v in values:
		check(Data.is_data(v) == OldData.is_data(v), "plain-data acceptance")
		if OldData.is_data(v): check(exact(Data.copy_data(v), OldData.copy_data(v)), "normalization parity")
	var ids = Ids.new()
	var made: Dictionary = ids.create("marcher", "round-perf", 0, 0, {"x_fp": 2, "nested": {"list": [1, 2]}})
	var raw: Dictionary = ids.snapshot()
	var warm = Ids.new()
	check(warm.restore(raw).action != "invalid", "warm valid registry")
	for v in values:
		var changed: Dictionary = raw.duplicate(true)
		changed.entities[0].attributes["probe"] = v
		var fast = Ids.new()
		var old = OldIds.new()
		fast.restore(raw); old.restore(raw)
		check(exact(fast.restore(changed), old.restore(changed)), "restore acceptance/error parity")
		check(exact(fast.snapshot(), old.snapshot()), "restore canonical state or atomic rejection")
	for field in ["owner", "ordinal", "id", "origin", "kind", "attributes"]:
		var bad: Dictionary = raw.duplicate(true)
		bad.entities[0][field] = true
		var before: Dictionary = warm.snapshot()
		check(warm.restore(bad).action == "invalid" and exact(before, warm.snapshot()), "cached input mutation rejected " + field)
	var returned: Dictionary = warm.snapshot()
	returned.entities[0].attributes.nested.list.append(99)
	check(exact(warm.snapshot(), raw), "returned snapshot isolated")
	var loaded = Ids.new(); loaded.restore(raw)
	loaded.update(made.entity.id, 1, {"other": true})
	var another = Ids.new(); another.restore(raw)
	check(exact(another.snapshot(), raw), "cache not changed by caller writes")
	var threads: Array = []
	for i in range(4):
		var thread = Thread.new()
		thread.start(thread_restore.bind(raw.duplicate(true)))
		threads.append(thread)
	for thread in threads: check(thread.wait_to_finish(), "concurrent registry restores isolated")
	var buffer = Buffer.new(); buffer.restore(raw)
	var read: Array = buffer._read_marchers()
	var changed: Dictionary = buffer.get_entity(made.entity.id)
	changed.attributes.nested.list.append(3)
	buffer.update(changed.id, 1, changed.attributes)
	check(exact(read[0], raw.entities[0]), "retained read view survives update")
	changed.attributes.nested.list.append(4)
	check(buffer.get_entity(changed.id).attributes.nested.list == [1, 2, 3], "update owns nested attributes")
	var public_rows: Array = buffer.marchers()
	public_rows[0].attributes.nested.list.clear()
	check(buffer.get_entity(changed.id).attributes.nested.list == [1, 2, 3], "public marcher list isolated")
	buffer.retire(changed.id)
	check(buffer.marchers().is_empty() and exact(read[0], raw.entities[0]), "retired read view remains stable")
	buffer.restore(raw)
	check(exact(buffer.snapshot(), raw), "restore rebuilds read views")
	for v in values:
		var fact: Dictionary = {"type": "TEST", "text": "", "data": {"value": v}}
		for views in [[fact, fact], [null, fact], [fact.duplicate(true), null], [null, null], [v, v]]:
			var result: Dictionary = {"action": "resolved", "world": {}, "events": [{"event": fact, "views": views}]}
			check(MatchOwner._transform_data_valid(result) == OldData.is_data(result), "tape data/depth parity")
			if OldData.is_data(result):
				var log_a = Log.new(); var log_b = Log.new()
				check(exact(log_a.append(fact, views), log_b._append_validated(fact, views)) and exact(log_a.snapshot(), log_b.snapshot()), "event admission and projections parity")
	var fact: Dictionary = {"type": "TEST", "text": "", "data": {}}
	for extra in [{"bad_fp": 1.5}, {1: false}, {"views": 4}, {"event": 3}, {"other": object}]:
		var row: Dictionary = {"event": fact, "views": [fact, fact]}
		row.merge(extra, true)
		var result: Dictionary = {"action": "resolved", "events": [row]}
		check(MatchOwner._transform_data_valid(result) == OldData.is_data(result), "extra/malformed event fields parity")
	print("Round performance regression checks: ", checks, "; failures: ", failures)
	quit(1 if failures else 0)
