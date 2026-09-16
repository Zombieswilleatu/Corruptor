extends "res://Scripts/Sim/U13PySimPaidDevelopmentTestRunner.gd"

const POWER_INPUTS: String = "res://Scripts/Sim/u13_pysim/power_inputs.json"
const LORDS: Array = ["Gremory","Deimos","Humbaba","Kalligan","Orias","Odradek","Kroni","Valak","Kanifous"]

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size()!=3: print("FAIL output and source identity required"); quit(1); return
	var source: String = FileAccess.get_file_as_string(POWER_INPUTS).replace("\r\n","\n")
	var inputs: Dictionary = Data.copy_data(JSON.parse_string(source))
	if not check(inputs.schema=="U13_NINE_LORD_INPUTS_V1","power input schema"): quit(1); return
	var first: Dictionary = Trace.begin(inputs.cases[0].setup,args[1],args[2])
	if not check(first.action=="trace_started","identity setup"): quit(1); return
	var header: Dictionary = {"kind":"header","schema":"U13_PYSIM_NINE_LORD_STREAM_V1",
		"inputs_sha256":source.sha256_text(),"identity":first.trace.identity,
		"event_transport":"full state except append-only event prefix; all semantic rows and views retained",
		"scope_lords":LORDS}
	output=FileAccess.open(args[0],FileAccess.WRITE)
	if not check(output!=null,"output opens"): quit(1); return
	for pass_index in range(2):
		replaying=pass_index==1
		if not emit(header): quit(1); return
		for spec in inputs.cases:
			if not game_trace(spec,args[1],args[2],inputs.round_cap): quit(1); return
		for spec in inputs.settlements:
			if not settlement_trace(inputs.cases[0].setup,spec): quit(1); return
		for spec in inputs.components:
			if not power_component(spec,args[1],args[2]): quit(1); return
		if pass_index==0: output.flush(); output.close()
	check(replay_index==digests.size(),"all nine-Lord records independently replayed")
	print("U13 PySim powers Godot checks: %d" % checks)
	print("U13 PySim powers Godot failures: %d" % failures)
	quit(0 if failures==0 else 1)

func power_component(spec: Dictionary, revision: String, source_hash: String) -> bool:
	var session: Dictionary = Trace.begin(spec.setup,revision,source_hash)
	if not check(session.action=="trace_started","power component starts "+spec.name): return false
	var game = session.game
	if not emit({"kind":"component_opening","name":spec.name,"setup":spec.setup,"state":game.snapshot()}): return false
	var previous: Array = []
	for i in range(spec.operations.size()):
		var entry: Dictionary = spec.operations[i]
		var op: Dictionary = entry.operation
		var result: Dictionary
		var before: Dictionary = game.snapshot()
		if op.kind == "fixture_prepare":
			var state: Dictionary = before.duplicate(true)
			var w: Dictionary = state.world
			for change in op.changes:
				if change.kind == "fixture_guard":
					var z: Dictionary = w.data.card_zones
					for pile in [z.deck,z.discard,z.hands[0],z.hands[1],z.committed[0],z.committed[1],z.market,z.market_reserve]: pile.erase(change.card_id)
					var ids = Registry.new(); ids.restore(w.entities)
					var row: Dictionary = ids.get_entity(change.card_id)
					row.attributes.merge({"role":"guard","lane":change.lane,"slot":change.slot},true)
					ids.update(row.id,change.player_id,row.attributes); w.entities=ids.snapshot()
				elif change.kind == "fixture_marcher":
					var ids = Registry.new(); ids.restore(w.entities)
					var a: Dictionary = Marching.profile(change.get("suit","Butcher"),change.lane,change.player_id,0,1,true)
					a.merge(change.attributes,true)
					var made: Dictionary = ids.create("marcher",change.origin,change.ordinal,change.player_id,a)
					if not check(made.action!="invalid","power fixture marcher"): return false
					w.entities=ids.snapshot()
				else:
					var changed: Dictionary = component_apply(w,change)
					if not check(changed.result.action!="invalid","power fixture operation"): return false
					w=changed.world
			state.world=w
			if op.get("refresh",true): state.presentation_world=w.duplicate(true)
			var restored: Dictionary = game.restore(state)
			if not check(restored.action!="invalid","power fixture restore "+spec.name+": "+str(restored)): return false
			result={"action":"fixture_prepared"}
		elif op.kind == "phase_probe":
			var context: Dictionary = {"world":before.world,"round":before.runtime.round,"seed":before.seed,"hook":"marching","player_order":before.player_order,"persistent_effects":before.persistent.active}
			var content = Trace.Game.Content.new()
			result=Marching.resolve(context,Callable(content,"react"))
		else: result=Trace.apply(game,op)
		if not check((result.action=="invalid")==entry.rejected,"power component expectation "+spec.name+" "+str(i)+": "+str(result)): return false
		var state: Dictionary = game.snapshot()
		if entry.rejected and not check(var_to_bytes(before)==var_to_bytes(state),"power rejection is atomic"): return false
		var rows: Array = state.events.rows
		if not check(var_to_bytes(previous)==var_to_bytes(rows.slice(0,previous.size())),"power component history immutable"): return false
		var added: Dictionary = state.events.duplicate(false); added.rows=rows.slice(previous.size())
		state.erase("events")
		if not emit({"kind":"component_transition","name":spec.name,"index":i,"operation":op,"result":result,"state":state,"event_prefix":previous.size(),"events":added}): return false
		previous=rows
	print("PASS ","replay " if replaying else "export ",spec.name)
	return true
