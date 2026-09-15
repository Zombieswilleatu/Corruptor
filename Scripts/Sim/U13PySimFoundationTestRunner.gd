extends SceneTree

const Trace = preload("res://Scripts/Sim/U13ParityTrace.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
var failures: int = 0
var checks: int = 0
var revision: String
var source_hash: String
var output: String

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures += 1
	print("PASS " if condition else "FAIL ", label)
	return condition

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3:
		print("FAIL expected output path, source revision, source SHA-256")
		quit(2)
		return
	output = args[0]
	revision = args[1]
	source_hash = args[2]
	var suite: Dictionary = {"schema": "U13_PYSIM_FOUNDATION_SUITE_V1", "rng": [], "ids": [], "openings": [], "traces": []}
	# Obtain negative zero from bits; GDScript may fold a -0.0 literal to +0.0.
	var negative_zero: float = "0000000000000080".hex_decode().decode_double(0)
	var codec_value: Dictionary = {"float": 0.1, "negative_zero": negative_zero, "whole_float": 1.0,
		"large_int": 9007199254740993, "min_int": -9223372036854775807 - 1,
		"max_int": 9223372036854775807, "tiny_float": "0100000000000000".hex_decode().decode_double(0),
		"unicode": "s:é/龍/🕷", "empty_key": {"": [null, false, true, 0]}, "tag_like_data": ["f", "arbitrary"]}
	suite["codec_probe"] = codec_value
	var encoded: Dictionary = Codec.encode(codec_value)
	var decoded: Dictionary = Codec.decode(encoded.text)
	check(decoded.action == "decoded" and Codec.difference(codec_value, decoded.value).is_empty(), "exact int/float/Unicode transport round trip")
	for node in [["i", "01"], ["i", "9223372036854775808"], ["f", "000000000000f07f"], ["b", 1], ["x", 0], ["d", [["x", ["n"]], ["x", ["n"]]]]]:
		check(Codec.unpack(node).action == "invalid", "malformed exact data rejected")
	check(not Codec.difference(0.0, negative_zero).is_empty() and not Codec.difference(true, 1).is_empty(), "comparison preserves float bits and bool identity")
	for vector in [["seed", "effect", "PRICE_DELAY", 0, 6, 5], ["seed", "effect", "PRICE_TYPE", 0, 17, 6],
		["s:é", "龍", "target", 42, 4294967296, 3876510453], ["seed", "effect", "PRICE_TARGET", 3, 2147483649, 169728365],
		["seed", "effect", "one", 0, 1, 0]]:
		var result: Dictionary = Rng.draw(vector[0], vector[1], vector[2], vector[3], vector[4])
		check(result.get("value") == vector[5], "existing RNG vector " + vector[2])
		suite.rng.append({"input": vector.slice(0, 5), "value": result.value})
	for vector in [["card", "deck:Butcher:1", 0], ["marcher", "龍:é:🕷", 12], ["castle", "rebuild:0", 1], ["lord", "a:b", 0]]:
		suite.ids.append({"input": vector, "value": Ids.identity(vector[0], vector[1], vector[2])})
	var entities = Ids.new()
	var guard: Dictionary = entities.create("card", "deck:Butcher:1", 0, 0, {"value": 3, "suit": "Butcher", "role": "guard", "slot": 0, "lane": "Lord"})
	entities.create("card", "deck:Butcher:1", 1, 0, {"value": 3, "suit": "Butcher"})
	entities.update(guard.entity.id, 1, {"value": 3, "suit": "Butcher", "role": "guard", "slot": 2, "lane": "Castle"})
	var castle: Dictionary = entities.create("castle", "setup:p0:Keep", 0, 0)
	entities.retire(castle.entity.id)
	entities.create("castle", "rebuild_effect_17", 0, 0)
	suite["registry"] = entities.snapshot()
	check(entities.create("castle", "setup:p0:Keep", 0, 0).action == "invalid", "retired identity cannot be recreated")
	var restored = Ids.new()
	check(restored.restore(suite.registry).action != "invalid" and restored.snapshot() == suite.registry, "registry and retired IDs restore exactly")
	var modes: Array = [
		["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"],
		["Keep", "Stockpile", "SiegeEngine", "SummoningCircle", "Bastion"],
		["Keep", "SummoningCircle", "SummoningCircle", "Stockpile", "Bastion"],
		["Keep", "Bastion", "Bastion", "SiegeEngine", "SiegeEngine"]]
	for index in range(12):
		var lords: Array = [Trace.Game.LORDS[index % 9], Trace.Game.LORDS[(index + 1) % 9]]
		var setup: Dictionary = {"seed": "u13-python-opening:é:%d" % index, "lords": lords,
			"castles": [modes[index % 4], modes[(index + 1) % 4]]}
		var session: Dictionary = Trace.begin(setup, revision, source_hash)
		if not check(session.action != "invalid", "production opening %d %s" % [index, str(lords)]): continue
		suite.openings.append(session.trace)
		var repeated: Dictionary = Trace.replay(session.trace, revision, source_hash)
		check(repeated.action == "trace_replayed", "opening repeats exactly %d" % index)
	var shortfall: Dictionary = Trace.begin({"seed": "u13-python-shortfall:23", "lords": ["Odradek", "Humbaba"], "castles": [modes[1], modes[1]]}, revision, source_hash)
	if check(shortfall.action != "invalid", "opening payment shortfall fixture starts"):
		suite.openings.append(shortfall.trace)
		var w: Dictionary = shortfall.trace.opening.world
		check(w.data.game_economy.opening.summons[0].shortfall == 1 and w.data.card_zones.hands[0].is_empty(), "opening shortfall exhausts the hand without inventing payment")
		var actor: Dictionary = Trace.Game.Content.Resummon.lord(w, 0)
		check(actor.attributes.alive and actor.attributes.threat == 0 and w.data.neutral_tears == 0, "forced first summon grants no shortfall Threat or Tear")
	var trace_setup: Dictionary = {"seed": "u13-python-explicit-choices", "lords": ["Gremory", "Valak"],
		"castles": [["Keep", "Stockpile", "SummoningCircle", "Bastion", "SiegeEngine"], ["Keep", "Stockpile", "SummoningCircle", "Bastion", "SiegeEngine"]]}
	var session: Dictionary = Trace.begin(trace_setup, revision, source_hash)
	if check(session.action != "invalid", "explicit-choice trace starts"):
		var submitted_round: int = 0
		for iteration in range(100):
			var game = session.game
			var state: Dictionary = game.snapshot()
			var hook: String = game._owner.next_hook()
			var operation: Dictionary
			var pending: Dictionary = state.world.data.game_economy.stockpile_pending
			if not pending.is_empty():
				operation = {"kind": "stockpile", "player_id": pending.player_id, "keep_id": pending.card_ids[-1]}
			elif hook == Trace.Game.Timeline.PRESENT_PUBLIC_STATE and state.world.data.game_market.seat != 2:
				var pid: int = state.world.data.game_market.seat
				var options: Array = game.market_choices(pid)
				operation = {"kind": "market", "player_id": pid, "choice": options[-1] if pid == 0 else options[0]}
			elif hook == Trace.Game.Timeline.SUBMISSION_LOCK and submitted_round != state.runtime.round:
				operation = {"kind": "submit", "plans": [{"order": {}, "powers": []}, {"order": {}, "powers": []}]}
				submitted_round = state.runtime.round
			elif hook.is_empty():
				if state.runtime.round == 2: break
				operation = {"kind": "next_round"}
			else:
				operation = {"kind": "step", "hook": hook}
			var result: Dictionary = Trace.record(session, operation)
			if result.action == "invalid":
				check(false, "explicit operation " + str(operation) + " " + str(result))
				break
		check(session.game._owner.next_hook().is_empty() and session.game.snapshot().runtime.round == 2, "two rounds captured through every hook")
		suite.traces.append(session.trace)
		var wrong: Dictionary = session.trace.duplicate(true)
		wrong.identity.source_revision = "wrong"
		check(Trace.replay(wrong, revision, source_hash).action == "invalid", "wrong trace identity rejected before replay")
		wrong = session.trace.duplicate(true)
		wrong.records[0].state.world.players[0].resources.souls += 1
		var mismatch: Dictionary = Trace.replay(wrong, revision, source_hash)
		check(mismatch.action == "invalid" and "records[0]" in str(mismatch.get("reason")), "replay identifies first altered phase state")
		wrong = session.trace.duplicate(true)
		wrong.records[0].operation.hook = "aftermath"
		check(Trace.replay(wrong, revision, source_hash).action == "invalid", "out-of-order recorded operation rejected")
	encoded = Codec.encode(suite)
	if not check(encoded.action == "encoded", "full suite encodes"): quit(1); return
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null: check(false, "export file opens"); quit(1); return
	file.store_string(encoded.text + "\n")
	file.close()
	decoded = Codec.decode(FileAccess.get_file_as_string(output))
	if check(decoded.action == "decoded", "export reads through portable data boundary"):
		check(Codec.difference(suite, decoded.value).is_empty(), "full suite round trips exactly")
		for trace in decoded.value.traces:
			var replayed: Dictionary = Trace.replay(trace, revision, source_hash)
			check(replayed.action == "trace_replayed", "Godot replays exported explicit choices and every phase: " + str(replayed))
	print("U13 PySim foundation Godot checks: %d" % checks)
	print("U13 PySim foundation Godot failures: %d" % failures)
	quit(0 if failures == 0 else 1)
