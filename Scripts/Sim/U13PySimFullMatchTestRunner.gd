extends SceneTree

# Explicit input replay only. All rules, including victory, run in production
# U13GameConductor. There are no fixture mutations or mirrored rules here.
const Trace = preload("res://Scripts/Sim/U13ParityTrace.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Throne = preload("res://Scripts/Sim/U13VacantThrone.gd")
const Victory = preload("res://Scripts/Sim/U13Victory.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const INPUTS: String = "res://Scripts/Sim/u13_pysim/full_match_inputs.json"
var checks: int = 0
var failures: int = 0
var output: FileAccess
var digests: Array = []
var replay_index: int = 0
var replaying: bool = false

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
	return ok

func emit(value: Dictionary) -> bool:
	var encoded: Dictionary = Codec.encode(value)
	if not check(encoded.action == "encoded", "exact record encode"): return false
	if replaying:
		if not check(replay_index < digests.size() and digests[replay_index] == encoded.text.sha256_text(), "independent Godot replay record %d" % replay_index): return false
		replay_index += 1
	else:
		digests.append(encoded.text.sha256_text())
		output.store_line(encoded.text)
	return true

func game_trace(spec: Dictionary, revision: String, source_hash: String, round_cap: int) -> bool:
	var session: Dictionary = Trace.begin(spec.setup, revision, source_hash)
	if not check(session.action == "trace_started", spec.name + " starts"): return false
	var game = session.game
	if not emit({"kind":"opening", "name":spec.name, "setup":spec.setup, "state":game.snapshot()}): return false
	var previous_events: Array = []
	var content = Trace.Game.Content.new()
	var operations: Array = spec.operations.duplicate(true)
	# Terminal rejection is tested after the genuine setup-to-victory input path.
	operations.append({"kind":"next_round"})
	operations.append({"kind":"step", "hook":""})
	for index in range(operations.size()):
		var op: Dictionary = operations[index]
		if index in spec.marching_probes:
			var before: Dictionary = game.snapshot()
			var context: Dictionary = {"world":before.world,"round":before.runtime.round,"seed":before.seed,
				"hook":before.runtime.next_hook,"player_order":before.player_order,"persistent_effects":before.persistent.active}
			var phase: Dictionary = Marching.resolve(context,Callable(content,"react"))
			if not check(phase.action == "resolved","directed full-world tick probe"): return false
			if not emit({"kind":"marching_probe","name":spec.name,"index":index,"context":context,"result":phase}): return false
		var result: Dictionary = Trace.apply(game,op)
		var terminal_probe: bool = index >= spec.operations.size()
		if not check((result.action == "invalid") == terminal_probe, "%s operation %d %s: %s" % [spec.name,index,str(op),str(result)]): return false
		var state: Dictionary = game.snapshot()
		if not check(state.runtime.round <= round_cap, "complete game round cap"): return false
		if not check(content.valid_world(state.world), "authoritative world validity"): return false
		var rows: Array = state.events.rows
		# Native exact serialization preserves Variant types and float bits. This
		# avoids walking the ever-growing prefix in interpreted GDScript per hook;
		# the exported additions still use the cross-language exact codec.
		if not check(rows.size() >= previous_events.size() and var_to_bytes(previous_events) == var_to_bytes(rows.slice(0,previous_events.size())), "event history is append-only"): return false
		var appended: Dictionary = state.events.duplicate(false)
		appended.rows = rows.slice(previous_events.size())
		state.erase("events")
		if not emit({"kind":"transition", "name":spec.name, "index":index, "operation":op,
			"result":result, "state":state, "event_prefix":previous_events.size(), "events":appended,
			"outcome":game.outcome()}): return false
		previous_events = rows
		if op.kind == "step" and op.hook == "aftermath":
			print("PASS ", "replay " if replaying else "export ", spec.name, " round ",state.runtime.round, " ",game.outcome().win_by)
	if not check(game.is_finished(), spec.name + " reaches actual victory"): return false
	if not emit({"kind":"finished", "name":spec.name, "operations":spec.operations.size(),
		"outcome":game.outcome(), "event_rows":previous_events.size()}): return false
	return true

func settlement_trace(setup: Dictionary, spec: Dictionary) -> bool:
	# These directed component fixtures never modify either complete game.
	var game = Trace.Game.new()
	if not check(game.start(setup.seed,setup.lords,setup.castles,true).action != "invalid","component opens"): return false
	var world: Dictionary = game.snapshot().world
	for pid in [0,1]:
		world.players[pid].resources.souls = spec.souls[pid]
		world.players[pid].resources.personal_tears = spec.personal_tears[pid]
		for row in world.entities.entities:
			if row.id == world.players[pid].lord_entity_id: row.attributes.alive = spec.alive[pid]
	world.data.neutral_tears = spec.neutral_tears
	world.data.vacant_throne.merge({"round":spec.round,"completed_round":spec.round-1,
		"counts":spec.prior_counts.duplicate(),"prior_counts":spec.prior_counts.duplicate(),"present":spec.present.duplicate()},true)
	world.data.victory.checked_round = spec.round-1
	var initial: Dictionary = world.duplicate(true)
	var throne: Dictionary = Throne.finish(world,spec.round)
	if not check(throne.action == "resolved",spec.name + " throne settles"): return false
	var victory: Dictionary = Victory.finish(throne.world,spec.round)
	if not check(victory.action == "resolved",spec.name + " victory settles"): return false
	var events: Array = throne.events + victory.events
	return emit({"kind":"settlement", "name":spec.name, "initial":initial,"world":victory.world,"events":events})

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3: print("FAIL output and source identity required"); quit(1); return
	# Construct negative zero from bits; a GDScript -0.0 literal can fold to +0.
	var negative_zero: float = "0000000000000080".hex_decode().decode_double(0)
	if not check(var_to_bytes(1) != var_to_bytes(1.0) and var_to_bytes(true) != var_to_bytes(1) and var_to_bytes(0.0) != var_to_bytes(negative_zero),"native prefix comparison retains types and float bits"): quit(1); return
	var source: String = FileAccess.get_file_as_string(INPUTS).replace("\r\n","\n")
	var inputs: Dictionary = Data.copy_data(JSON.parse_string(source))
	if not check(inputs.schema == "U13_FULL_MATCH_INPUTS_V1", "input schema"): quit(1); return
	var first: Dictionary = Trace.begin(inputs.cases[0].setup,args[1],args[2])
	if not check(first.action == "trace_started", "identity setup"): quit(1); return
	var header: Dictionary = {"kind":"header", "schema":"U13_PYSIM_FULL_MATCH_STREAM_V1",
		"inputs_sha256":source.sha256_text(), "identity":first.trace.identity,
		"event_transport":"full state except append-only event prefix; all semantic rows and views retained",
		"scope_lords":["Gremory","Deimos","Humbaba","Kalligan"]}
	output = FileAccess.open(args[0],FileAccess.WRITE)
	if not check(output != null,"output opens"): quit(1); return
	if not emit(header): quit(1); return
	for spec in inputs.cases:
		if not game_trace(spec,args[1],args[2],inputs.round_cap): output.close(); quit(1); return
	for spec in inputs.settlements:
		if not settlement_trace(inputs.cases[0].setup,spec): output.close(); quit(1); return
	output.close()
	# Start each match again and compare the exact encoded record at every step.
	# Replay uses setup + decisions, never a restored expected world.
	replaying = true
	if not emit(header): quit(1); return
	for spec in inputs.cases:
		if not game_trace(spec,args[1],args[2],inputs.round_cap): quit(1); return
	for spec in inputs.settlements:
		if not settlement_trace(inputs.cases[0].setup,spec): quit(1); return
	check(replay_index == digests.size(),"all records independently replayed")
	print("U13 PySim full-match Godot checks: %d" % checks)
	print("U13 PySim full-match Godot failures: %d" % failures)
	quit(0 if failures == 0 else 1)
