extends "res://Scripts/Sim/U13PySimFullMatchTestRunner.gd"

# Reuse the exact complete-game exporter and its independent native replay.
# Fixture mutations below belong ONLY to the separately labeled components.
const PaidRites = preload("res://Scripts/Sim/U13DominionRites.gd")
const ReturnLord = preload("res://Scripts/Sim/U13Resummoning.gd")
const Registry = preload("res://Scripts/Sim/U13EntityIds.gd")
const PAID_INPUTS: String = "res://Scripts/Sim/u13_pysim/paid_inputs.json"

func component_apply(raw: Dictionary, op: Dictionary) -> Dictionary:
	var w: Dictionary = raw.duplicate(true)
	var result: Dictionary = {"action":"fixture_prepared"}
	var pid: int = op.get("player_id",0)
	var number: int = op.get("round",1)
	var ids = Registry.new(); ids.restore(w.entities)
	match op.kind:
		"fixture_give":
			var z: Dictionary = w.data.card_zones
			for pile in [z.deck,z.discard,z.hands[0],z.hands[1],z.committed[0],z.committed[1],z.market,z.market_reserve]: pile.erase(op.card_id)
			var card: Dictionary = ids.get_entity(op.card_id)
			for key in ["role","lane","slot"]: card.attributes.erase(key)
			ids.update(card.id,pid,card.attributes)
			w.entities = ids.snapshot()
			z.hands[pid].append(card.id)
		"fixture_patch":
			var row: Dictionary = ids.get_entity(op.entity_id)
			row.attributes.merge(op.attributes,true)
			ids.update(row.id,op.get("owner",row.owner),row.attributes)
			w.entities = ids.snapshot()
		"fixture_retire":
			ids.retire(op.entity_id); w.entities = ids.snapshot()
		"fixture_data": w.data.merge(op.data.duplicate(true),true)
		"fixture_resources": w.players[pid].resources.merge(op.resources,true)
		"fixture_waiters":
			for i in range(op.count):
				var attributes: Dictionary = Marching.profile("Butcher",op.lane,pid,0,1)
				attributes.merge({"waiting":true,"waiting_since_round":1,"x_fp":2400 if pid==0 else 0},true)
				var made: Dictionary = ids.create("marcher","paid-waiters:%d:%s" % [pid,op.lane],i,pid,attributes)
				if not check(made.action!="invalid","fixture marcher created"): return {"result":made,"world":raw}
			w.entities = ids.snapshot()
		"quote": result = ReturnLord.quote(w,pid,op.card_ids)
		"validate_rites": result = PaidRites.validate(w,pid,op.order)
		"validate_summon": result = ReturnLord.validate_order(w,pid,op.order)
		"reserve_rites": result = PaidRites.reserve({"world":w,"round":number,"player_id":pid,"order":op.order})
		"reserve_summon": result = ReturnLord.reserve(w,pid,op.order,number)
		"resolve_rites": result = PaidRites.resolve({"world":w,"round":number,"player_order":op.get("player_order",[0,1]),"hook":op.get("hook","development")})
		"resolve_summon": result = ReturnLord.resolve({"world":w,"round":number,"player_order":op.get("player_order",[0,1]),"hook":op.get("hook","development")})
		"accept":
			var content = Trace.Game.Content.new()
			result = content.accept_order({"world":w,"round":number,"phase":"commit","player_id":pid,"order":op.order,"declarations":[]})
		"development":
			var content = Trace.Game.Content.new()
			result = content.on_hook({"world":w,"round":number,"hook":"development","seed":op.seed,"player_order":op.get("player_order",[0,1]),"combat_orders":op.orders,"persistent_effects":[]})
		_: result = {"action":"invalid","reason":"unknown_paid_component"}
	if result.action=="invalid": return {"result":result,"world":raw}
	if result.has("world"): w=result.world
	result.erase("world")
	return {"result":result,"world":w}

func paid_component(spec: Dictionary, revision: String, source_hash: String) -> bool:
	var session: Dictionary = Trace.begin(spec.setup,revision,source_hash)
	if not check(session.action=="trace_started","component starts "+spec.name): return false
	var w: Dictionary = session.game.snapshot().world
	if not emit({"kind":"paid_opening","name":spec.name,"setup":spec.setup,"world":w}): return false
	for i in range(spec.operations.size()):
		var entry: Dictionary = spec.operations[i]
		var changed: Dictionary = component_apply(w,entry.operation)
		if not check((changed.result.action=="invalid")==entry.rejected,"component expectation "+spec.name+" "+str(i)+" "+str(changed.result)): return false
		if entry.rejected and not check(Codec.difference(w,changed.world).is_empty(),"component rollback"): return false
		if not emit({"kind":"paid_component","name":spec.name,"index":i,"operation":entry.operation,"result":changed.result,"world":changed.world}): return false
		w=changed.world
	return true

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size()!=3: print("FAIL output and source identity required"); quit(1); return
	var source: String = FileAccess.get_file_as_string(PAID_INPUTS).replace("\r\n","\n")
	var inputs: Dictionary = Data.copy_data(JSON.parse_string(source))
	if not check(inputs.schema=="U13_PAID_DEVELOPMENT_INPUTS_V1","paid input schema"): quit(1); return
	var first: Dictionary = Trace.begin(inputs.cases[0].setup,args[1],args[2])
	if not check(first.action=="trace_started","identity setup"): quit(1); return
	var header: Dictionary = {"kind":"header","schema":"U13_PYSIM_PAID_DEVELOPMENT_STREAM_V1",
		"inputs_sha256":source.sha256_text(),"identity":first.trace.identity,
		"event_transport":"full state except append-only event prefix; all semantic rows and views retained",
		"scope_lords":["Gremory","Deimos","Humbaba","Kalligan"]}
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
			if not paid_component(spec,args[1],args[2]): quit(1); return
		if pass_index==0: output.close()
	check(replay_index==digests.size(),"all paid records independently replayed")
	print("U13 PySim paid-development Godot checks: %d" % checks)
	print("U13 PySim paid-development Godot failures: %d" % failures)
	quit(0 if failures==0 else 1)
