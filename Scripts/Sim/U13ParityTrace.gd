extends RefCounted

const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const VERSION: String = "U13_PARITY_TRACE_V1"
const PRODUCER: String = "U13_PARITY_EXPORT_V1"
const IDENTITY_KEYS: Array = ["schema_version", "engine_version", "policy_id", "rules_hash", "rng_version"]

static func identity(game, revision: String, source_hash: String) -> Dictionary:
	var result: Dictionary = {
		"trace_schema": VERSION, "producer": PRODUCER, "authority": "Godot U13",
		"source_revision": revision, "source_sha256": source_hash,
		"runtime": Engine.get_version_info().string, "platform": OS.get_name(),
		"event_profile": Game.Content.BATCH_EVENTS_VERSION,
		"excluded_visual_events": Game.Content.BATCH_SAMPLE_EVENTS.duplicate(),
		"choice_policy": "explicit inputs; fixture selection is not doctrine"
	}
	var state: Dictionary = game.snapshot()
	for key in IDENTITY_KEYS: result[key] = state[key]
	return result

static func begin(setup: Dictionary, revision: String, source_hash: String) -> Dictionary:
	if setup.size() != 3 or typeof(setup.get("seed")) != TYPE_STRING or typeof(setup.get("lords")) != TYPE_ARRAY or typeof(setup.get("castles")) != TYPE_ARRAY:
		return {"action": "invalid", "reason": "trace_setup_invalid"}
	var game = Game.new()
	var result: Dictionary = game.start(setup.seed, setup.lords, setup.castles, true)
	if result.action == "invalid": return result
	return {"action": "trace_started", "game": game, "trace": {
		"identity": identity(game, revision, source_hash), "setup": setup.duplicate(true),
		"opening": game.snapshot(), "records": []
	}}

static func apply(game, operation: Dictionary) -> Dictionary:
	match operation.get("kind"):
		"step":
			if operation.size() == 2 and operation.get("hook") == game._owner.next_hook(): return game.step()
		"stockpile":
			if operation.size() == 3 and typeof(operation.get("player_id")) == TYPE_INT and typeof(operation.get("keep_id")) == TYPE_STRING:
				return game.choose_stockpile(operation.player_id, operation.keep_id)
		"market":
			if operation.size() == 3 and typeof(operation.get("player_id")) == TYPE_INT and typeof(operation.get("choice")) == TYPE_DICTIONARY:
				return game.choose_market(operation.player_id, operation.choice)
		"submit":
			if operation.size() == 2 and typeof(operation.get("plans")) == TYPE_ARRAY: return game.submit(operation.plans)
		"next_round":
			if operation.size() == 1: return game.next_round()
	return {"action": "invalid", "reason": "trace_operation_invalid"}

static func record(session: Dictionary, operation: Dictionary) -> Dictionary:
	var game = session.game
	var before: Dictionary = game.snapshot()
	var result: Dictionary = apply(game, operation)
	if result.action == "invalid": return result
	var after: Dictionary = game.snapshot()
	session.trace.records.append({
		"index": session.trace.records.size(), "round": before.runtime.round,
		"hook_before": before.runtime, "operation": operation.duplicate(true),
		"result": result, "state": after, "outcome": game.outcome()
	})
	return result

static func replay(trace: Dictionary, revision: String, source_hash: String) -> Dictionary:
	if trace.size() != 4 or not trace.has_all(["identity", "setup", "opening", "records"]):
		return {"action": "invalid", "reason": "trace_shape_invalid"}
	if typeof(trace.identity) != TYPE_DICTIONARY or typeof(trace.setup) != TYPE_DICTIONARY or typeof(trace.opening) != TYPE_DICTIONARY or typeof(trace.records) != TYPE_ARRAY:
		return {"action": "invalid", "reason": "trace_shape_invalid"}
	var session: Dictionary = begin(trace.setup, revision, source_hash)
	if session.action == "invalid": return session
	var delta: String = Codec.difference(session.trace.identity, trace.identity, "identity")
	if delta.is_empty(): delta = Codec.difference(session.trace.opening, trace.opening, "opening")
	if not delta.is_empty(): return {"action": "invalid", "reason": delta}
	for index in range(trace.records.size()):
		if typeof(trace.records[index]) != TYPE_DICTIONARY or typeof(trace.records[index].get("operation")) != TYPE_DICTIONARY:
			return {"action": "invalid", "reason": "trace_record_invalid:%d" % index}
		var expected: Dictionary = trace.records[index]
		var result: Dictionary = record(session, expected.operation)
		if result.action == "invalid": return result
		delta = Codec.difference(expected, session.trace.records[-1], "records[%d]" % index)
		if not delta.is_empty(): return {"action": "invalid", "reason": delta}
	return {"action": "trace_replayed", "records": trace.records.size()}
