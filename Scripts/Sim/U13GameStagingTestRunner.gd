extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

const Stage = Game.Content.Staging
const Trace = preload("res://Scripts/Sim/U13ParityTrace.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const Monsters = Game.Content.Monsters
const Marching = Stage.Marching
var operations: Array = []
var trace_game
var assertions: int = 0

func checked(ok: bool, label: String) -> bool:
	assertions += 1
	return check(ok, label)

func apply(operation: Dictionary) -> bool:
	var result: Dictionary = Trace.apply(trace_game, operation)
	if not checked(result.action != "invalid", "full-game " + str(operation.kind)):
		print(result)
		return false
	operations.append(operation.duplicate(true))
	return true

func planning() -> bool:
	while trace_game._owner.next_hook() != "submission_lock":
		var w: Dictionary = trace_game._owner.player_view(0, 0).world
		if not w.game_economy.stockpile_pending.is_empty():
			var pending: Dictionary = w.game_economy.stockpile_pending
			var pid: int = pending.player_id
			var choices: Array = trace_game._owner.player_view(pid, 0).world.game_economy.stockpile_pending.card_ids
			if not apply({"kind": "stockpile", "player_id": pid, "keep_id": choices[0]}): return false
		elif w.game_market.seat != 2:
			if not apply({"kind": "market", "player_id": w.game_market.seat, "choice": {"market": "Pass"}}): return false
		elif not apply({"kind": "step", "hook": trace_game._owner.next_hook()}): return false
	return true

func put(world: Dictionary, name: String, pid: int, lane: String, birth: int, ordinal: int = 0) -> Dictionary:
	var ids = Marching.Ids.new()
	ids.restore(world.entities)
	var a: Dictionary = Monsters.profile(name, lane, pid, birth, birth + 1) if name in Monsters.NAMES else Marching.profile(name, lane, pid, birth, birth + 1, true)
	var made: Dictionary = ids.create("marcher", "staging-fixture:" + name + lane + str(pid), ordinal, pid, a)
	world.entities = ids.snapshot()
	return made.entity

func fixtures() -> void:
	var schema: Dictionary = Game.Scenario.loadout_world(["Gremory", "Humbaba"], [Slots.TYPES, Slots.TYPES])
	var w: Dictionary = Economy.initialize(schema, "staging-fixtures").world
	Stage.configure(w)
	var first: Dictionary = put(w, "Butcher", 0, "Lord", 1)
	var other: Dictionary = put(w, "Wright", 0, "Castle", 1)
	Stage.capture(w, [Marching.public_event("MARCHER_SPAWNED", first), Marching.public_event("MARCHER_SPAWNED", other)], 1)
	checked(Stage.valid(w) and Game.Content.new().valid_world(w), "protected identities validate")
	Stage.prepare(w, 1, [{"staging":{"Lord":"March"}}, {}])
	checked(Stage.rows(w).size()==2 and w.data.game_staging.lanes.Lord.march_round==[0,0], "new recruits cannot march or schedule an automatic future release")
	var chosen: Array = [first.id]
	var late: Dictionary = put(w, "Butcher", 0, "Lord", 2, 99)
	Stage.capture(w, [Marching.public_event("MARCHER_SPAWNED", late)], 2)
	Stage.prepare(w, 2, [{"staging":{"Lord":"March"},"staging_ids":{"Lord":chosen}}, {}])
	checked(w.entities.entities.any(func(u):return u.id==first.id and u.attributes.deployed_round==2), "eligible clicked cohort deploys in the same round")
	checked(Stage.rows(w).map(func(u):return u.id).has(late.id), "recruit born after the click remains staged")
	checked(Stage.rows(w).map(func(u):return u.id).has(other.id), "unselected lane stays staged")
	var unchanged: Dictionary = w.duplicate(true)
	Stage.prepare(w, 2, [{"staging":{"Castle":"March"}}, {}])
	checked(w==unchanged, "deployment is idempotent within the round")
	Stage.prepare(w, 3, [{}, {}])
	checked(Stage.rows(w).size()==2, "later arrivals require a fresh MARCH")
	Stage.prepare(w, 4, [{"staging":{"Lord":"March","Castle":"March"}}, {}])
	checked(Stage.rows(w).is_empty() and Stage.valid(w), "fresh command deploys all old reserves immediately")
	checked(not Stage.order_valid(w,{"staging":{"Lord":"March"},"staging_ids":{"Lord":["duplicate","duplicate"]}}), "duplicate cohort ids are rejected")
	# Existing V2 saves can still carry a scheduled command; honor it once.
	var old: Dictionary = put(w,"Penitent",1,"Castle",4,71)
	Stage.capture(w,[Marching.public_event("MARCHER_SPAWNED",old)],4)
	w.data.game_staging.lanes.Castle.march_round=[0,5]
	checked(Stage.valid(w), "legacy pending command validates")
	Stage.release_due(w,5)
	checked(Stage.rows(w).is_empty() and w.data.game_staging.lanes.Castle.march_round==[0,0], "legacy pending command is consumed once")

func phase_checks() -> void:
	var w: Dictionary = Economy.initialize(Game.Scenario.loadout_world(["Gremory","Humbaba"],[Slots.TYPES,Slots.TYPES]),"opening-interval").world
	Stage.configure(w)
	var unit: Dictionary = put(w,"Butcher",0,"Lord",0)
	var initial: int = unit.attributes.x_fp
	var content = Game.Content.new()
	var context: Dictionary = {"world":w,"round":1,"seed":"opening-interval","player_order":[0,1],"hook":"marching","persistent_effects":[],"opening_marching":true}
	var begin: int = Time.get_ticks_usec()
	var opened: Dictionary = Marching.resolve(context,Callable(content,"react"))
	checked(opened.action=="resolved", "opening interval resolves")
	if opened.action=="invalid": print(opened); return
	var active: Dictionary = opened.world.entities.entities.filter(func(u):return u.id==unit.id)[0]
	checked(active.attributes.x_fp-initial==400, "unopposed Butcher moves exactly 100 ticks at opening")
	checked(opened.world.data.opening_marching_round==1 and opened.world.data.get("marching_round",0)==0 and opened.world.data.marching_clock==300, "opening has a separate once-only marker and continuous clock")
	var tape = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	checked(tape.build(opened.events.map(func(r):return r.event)) and absf(tape._move_seconds-7.5)<0.001, "opening builds a 7.5-second movement tape")
	context.world=opened.world
	checked(Marching.resolve(context,Callable(content,"react")).action=="invalid", "opening cannot resolve twice")
	context.opening_marching=false
	var closed: Dictionary = Marching.resolve(context,Callable(content,"react"))
	checked(closed.action=="resolved" and closed.world.data.marching_clock==500, "closing runs 200 more ticks without rewinding time")
	checked(tape.build(closed.events.map(func(r):return r.event)) and absf(tape._move_seconds-15.0)<0.001 and tape._spatial_clock_start==300, "closing tape uses local ticks and absolute effect timestamps")
	checked(closed.events.filter(func(r):return r.event.type=="MARCHING_TICK").size()==200, "closing retains all 200 ticks")
	context.world=closed.world;context.round=2;context.opening_marching=true
	var second: Dictionary = Marching.resolve(context,Callable(content,"react"))
	checked(second.action=="resolved" and second.world.data.marching_clock==600 and tape.build(second.events.map(func(r):return r.event)), "next opening continues cooldown clock and has a valid tape")
	checked(Marching.Incoming.regular_amount({"rout_round":2},3,500,2)==4 and Marching.Incoming.regular_amount({"rout_round":1},3,500,2)==3, "Rout uses the game round rather than dividing the combat clock")
	print("PHASE CHECK elapsed_ms=", (Time.get_ticks_usec()-begin)/1000.0)

func run() -> void:
	fixtures()
	phase_checks()
	var setup: Dictionary = {"seed":"live-staging-integration","lords":["Deimos","Gremory"],"castles":[Slots.TYPES,Slots.TYPES]}
	trace_game=Game.new()
	if not checked(trace_game.start(setup.seed,setup.lords,setup.castles,true).action!="invalid","new full game starts"): quit(1);return
	for n in range(1,5):
		if not planning(): quit(1);return
		var snapshot: Dictionary=trace_game.snapshot()
		checked(snapshot.world.data.opening_marching_round==n,"opening completes before planning round "+str(n))
		if n==2:
			checked(not Stage.rows(snapshot.world).is_empty() and snapshot.world.entities.entities.all(func(u):return u.kind!="marcher"),"round-one recruits remain visible in staging until a fresh command")
		var restored=Game.new()
		checked(restored.restore(snapshot).action!="invalid" and restored.snapshot()==snapshot,"planning snapshot round-trip "+str(n))
		var plans: Array=[]
		for pid in [0,1]:
			var view: Dictionary=trace_game._owner.player_view(pid,0).world
			var order: Dictionary={"action":"Ward","lane":"Lord" if n%2==1 else "Castle","card_ids":view.hand.duplicate(),"staging":{"Lord":"March","Castle":"March"},"staging_ids":{}}
			for lane in ["Lord","Castle"]:
				order.staging_ids[lane]=Stage.rows(snapshot.world).filter(func(u):return u.owner==pid and u.attributes.lane==lane and u.attributes.staged_round<n).map(func(u):return u.id)
			plans.append({"powers":[],"order":order})
		if not apply({"kind":"submit","plans":plans}): quit(1);return
		while not trace_game._owner.next_hook().is_empty():
			var hook: String=trace_game._owner.next_hook()
			var begin: int=Time.get_ticks_usec()
			if not apply({"kind":"step","hook":hook}): quit(1);return
			if hook=="marching": print("CLOSING PROFILE round=",n," ms=",(Time.get_ticks_usec()-begin)/1000.0)
			var w: Dictionary=trace_game.snapshot().world
			if hook=="marching_start":
				checked(Stage.rows(w).all(func(u):return u.attributes.staged_round==n),"only new recruits remain staged after same-round release "+str(n))
				if n>1: checked(w.entities.entities.any(func(u):return u.kind=="marcher" and u.attributes.get("deployed_round")==n),"prior-round recruits deploy before closing movement "+str(n))
		if n<4 and not apply({"kind":"next_round"}): quit(1);return
	var final: Dictionary=trace_game.snapshot()
	var restored=Game.new()
	checked(restored.restore(final).action!="invalid" and restored.snapshot()==final,"completed round snapshot round-trip")
	if not OS.get_cmdline_user_args().is_empty():
		var output=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
		output.store_string(Codec.encode({"setup":setup,"operations":operations,"state":final}).text)
		output.close()
	print("U13 game staging assertions: %d; failures: %d" % [assertions,failures])
	quit(failures)
