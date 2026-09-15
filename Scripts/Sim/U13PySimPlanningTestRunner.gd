extends SceneTree

const Trace = preload("res://Scripts/Sim/U13ParityTrace.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const Runtime = preload("res://Scripts/Sim/U13RoundRuntime.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Economy = preload("res://Scripts/Sim/U13GameEconomy.gd")
const Market = preload("res://Scripts/Sim/U13GameMarket.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
var failures: int = 0
var checks: int = 0
var revision: String
var source_hash: String
const MODES: Array = [
	["Keep", "Stockpile", "SummoningCircle", "Bastion", "SiegeEngine"],
	["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"],
	["Stockpile", "Stockpile", "SummoningCircle", "Bastion", "SiegeEngine"]]

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func apply_game(game, operation: Dictionary) -> Dictionary:
	if operation.kind == "submit_one":
		return game._owner.submit(operation.player_id, operation.plan.powers, operation.plan.order)
	return Trace.apply(game, operation)

func begin_game(config: Dictionary) -> Dictionary:
	var session: Dictionary = Trace.begin(config, revision, source_hash)
	if session.action != "invalid":
		session.trace.identity.trace_schema = "U13_PLANNING_TRACE_V1"
		session.trace.identity.producer = "U13_PYSIM_PLANNING_EXPORT_V1"
	return session

# Includes rejected attempts so rollback and private event retention are compared.
func record(session: Dictionary, operation: Dictionary, rejected: bool = false) -> void:
	var before: Dictionary = session.game.snapshot()
	var result: Dictionary = apply_game(session.game, operation)
	var after: Dictionary = session.game.snapshot()
	check((result.action == "invalid") == rejected, "%s %s" % [operation.kind, result.action])
	if rejected: check(Codec.difference(before, after).is_empty(), "rejection leaves entire match unchanged")
	session.trace.records.append({"index": session.trace.records.size(), "round": before.runtime.round,
		"hook_before": before.runtime, "operation": operation.duplicate(true), "result": result,
		"state": after, "outcome": session.game.outcome()})

func setup(index: int) -> Dictionary:
	return {"seed": "u13-python-planning:é:%d" % index,
		"lords": [Trace.Game.LORDS[index % 9], Trace.Game.LORDS[(index + 1) % 9]],
		"castles": [MODES[index % 3], MODES[(index + 1) % 3]]}

func plans_for(game, index: int) -> Array:
	var w: Dictionary = game.snapshot().world
	var plans: Array = []
	for pid in [0, 1]:
		var hand: Array = w.data.card_zones.hands[pid]
		var action: String = ["Pass", "Ward", "Hunt", "Siege", "Profane"][(index + pid) % 5]
		var order: Dictionary = {}
		if action != "Pass":
			order = {"action": action, "lane": "Lord" if action in ["Ward", "Hunt"] else "Castle", "card_ids": hand.slice(0, 1)}
			if action == "Ward" and index % 2 == 0: order.card_ids = []
			if action == "Hunt":
				order["target_id"] = w.players[1 - pid].lord_entity_id
				order["fracture_target"] = "subjects" if index % 2 == 0 else "infrastructure"
			elif action in ["Siege", "Profane"]:
				order["target_id"] = Trace.Game.Slots.castle_id(1 - pid if action == "Siege" else pid, 0)
		order["guard_moves"] = [{"card_id": hand[-1], "lane": "Lord" if pid == 0 else "Castle", "slot": 2}]
		order["castle_action"] = {"action": "Work", "target_id": Trace.Game.Slots.castle_id(pid, 3), "card_ids": [], "use_repair_token": false}
		plans.append({"powers": [], "order": order})
	return plans

func game_case(index: int) -> Dictionary:
	var session: Dictionary = begin_game(setup(index))
	check(session.action == "trace_started", "planning fixture starts %d" % index)
	var pass_plans: Array = [{"powers": [], "order": {}}, {"powers": [], "order": {}}]
	record(session, {"kind": "next_round"}, true)
	record(session, {"kind": "submit", "plans": pass_plans}, true)
	record(session, {"kind": "step", "hook": "aftermath"}, true)
	record(session, {"kind": "stockpile", "player_id": 0, "keep_id": "missing"}, true)
	for hook in ["round_start_scheduled", "persistent_advancement", "round_start_automatic"]:
		record(session, {"kind": "step", "hook": hook})
	for choice_index in range(2):
		var pending: Dictionary = session.game.snapshot().world.data.game_economy.stockpile_pending
		if pending.is_empty(): break
		record(session, {"kind": "step", "hook": "present_public_state"}, true)
		record(session, {"kind": "market", "player_id": 0, "choice": {"market": "Pass"}}, true)
		record(session, {"kind": "stockpile", "player_id": 1 - pending.player_id, "keep_id": pending.card_ids[0]}, true)
		record(session, {"kind": "stockpile", "player_id": pending.player_id, "keep_id": "missing"}, true)
		record(session, {"kind": "stockpile", "player_id": pending.player_id, "keep_id": pending.card_ids[index % 2]})
	for visit in range(2):
		var pid: int = session.game.snapshot().world.data.game_market.seat
		record(session, {"kind": "market", "player_id": 1 - pid, "choice": {"market": "Pass"}}, true)
		record(session, {"kind": "market", "player_id": pid, "choice": {"market": "Swap", "take_id": "missing", "give_id": "missing"}}, true)
		var choices: Array = session.game.market_choices(pid)
		record(session, {"kind": "market", "player_id": pid, "choice": choices[-1] if (index + visit) % 2 == 0 else choices[0]})
	record(session, {"kind": "step", "hook": "present_public_state"})
	record(session, {"kind": "step", "hook": "submission_lock"}, true)
	var plans: Array = plans_for(session.game, index)
	var bad: Array = plans.duplicate(true)
	bad[1].order.guard_moves[0].card_id = "missing"
	record(session, {"kind": "submit", "plans": bad}, true)
	bad = plans.duplicate(true)
	bad[0].order.guard_moves.append(bad[0].order.guard_moves[0].duplicate(true))
	record(session, {"kind": "submit", "plans": bad}, true)
	bad = plans.duplicate(true)
	bad[1].order.castle_action.target_id = Trace.Game.Slots.castle_id(0, 3)
	record(session, {"kind": "submit", "plans": bad}, true)
	var before: Dictionary = session.game.snapshot()
	if index % 2 == 0:
		record(session, {"kind": "submit", "plans": plans})
	else:
		record(session, {"kind": "submit_one", "player_id": 1, "plan": plans[1]})
		record(session, {"kind": "submit_one", "player_id": 1, "plan": plans[1]}, true)
		record(session, {"kind": "step", "hook": "submission_lock"}, true)
		record(session, {"kind": "submit_one", "player_id": 0, "plan": plans[0]})
	var after: Dictionary = session.game.snapshot()
	check(Codec.difference(before.world, after.world).is_empty() and Codec.difference(before.presentation_world, after.presentation_world).is_empty() and Codec.difference(before.events, after.events).is_empty(), "staging retains both worlds and all event rows")
	record(session, {"kind": "step", "hook": "submission_lock"})
	check(session.game._owner.next_hook() == "development", "stops before Development")
	return session.trace

func replay_game(trace: Dictionary) -> void:
	var session: Dictionary = begin_game(trace.setup)
	var delta: String = Codec.difference(session.trace.identity, trace.identity, "identity")
	if delta.is_empty(): delta = Codec.difference(session.trace.opening, trace.opening, "opening")
	for expected in trace.records:
		if not delta.is_empty(): break
		var before: Dictionary = session.game.snapshot()
		var result: Dictionary = apply_game(session.game, expected.operation)
		var actual: Dictionary = {"index": expected.index, "round": before.runtime.round, "hook_before": before.runtime,
			"operation": expected.operation, "result": result, "state": session.game.snapshot(), "outcome": session.game.outcome()}
		delta = Codec.difference(expected, actual, "records[%d]" % expected.index)
	check(delta.is_empty(), "Godot replays every accepted/rejected operation: " + delta)

# Directed component inputs repack physical cards without deleting identities.
# The large committed reserve is an isolated card/economy fixture, not a legal
# player plan or a claimed end-to-end match state.
func packed_world(spec: Dictionary) -> Dictionary:
	var session: Dictionary = Trace.begin(setup(0), revision, source_hash)
	var w: Dictionary = session.game.snapshot().world
	var z: Dictionary = w.data.card_zones
	var pool: Array = []
	for row in w.entities.entities:
		if row.kind == "card" and row.id not in z.market: pool.append(row.id)
	z.hands = [[], []]; z.deck = []; z.discard = []; z.committed = [[], []]
	var index: int = 0
	for pair in [[z.hands[0], spec.hand0], [z.hands[1], spec.hand1], [z.deck, spec.deck], [z.discard, spec.discard]]:
		for unused in range(pair[1]):
			pair[0].append(pool[index]); index += 1
	z.committed[0] = pool.slice(index)
	var ids = Ids.new()
	ids.restore(w.entities)
	for identity in pool:
		var owner_id: int = 1 if identity in z.hands[1] else (0 if identity in z.hands[0] or identity in z.committed[0] else -1)
		ids.update(identity, owner_id, ids.get_entity(identity).attributes)
	w.entities = ids.snapshot()
	w.data.game_market.round = spec.round - 1
	w.data.game_economy.draw_round = spec.round - 1
	return w

func component_apply(w: Dictionary, operation: Dictionary, round_number: int) -> Dictionary:
	var world: Dictionary = w.duplicate(true)
	var result: Dictionary
	var seed_value: String = setup(0).seed
	match operation.kind:
		"draw": result = Cards.draw(world, operation.player_id, seed_value, operation.event_id, operation.from_discard)
		"discard": result = Cards.discard(world, operation.player_id, operation.card_ids)
		"draw_start": result = Economy.on_hook({"world": world, "hook": "round_start_automatic", "seed": seed_value, "round": round_number})
		"stockpile": result = Economy.choose({"world": world, "hook": "present_public_state", "seed": seed_value, "round": round_number, "player_id": operation.player_id, "choice": {"keep_id": operation.keep_id}})
		"market_begin": result = Market.begin(world, seed_value, round_number)
		"market": result = Market.choose({"world": world, "hook": "present_public_state", "round": round_number, "player_id": operation.player_id, "choice": operation.choice})
	if result.action == "invalid": return {"result": result, "world": w}
	if result.has("world"): world = result.world
	var output_result: Dictionary = result.duplicate(true)
	output_result.erase("world")
	return {"result": output_result, "world": world}

func component_case(spec: Dictionary) -> Dictionary:
	var world: Dictionary = packed_world(spec)
	check(Cards.valid(world) and Economy.valid(world) and Market.valid(world), "directed component input valid " + spec.name)
	var trace: Dictionary = {"spec": spec, "initial": world.duplicate(true), "records": []}
	var ops: Array = []
	if spec.name in ["recycle_full_hand", "discard_only", "empty_piles"]:
		for pid in [0, 1]:
			ops.append({"kind": "draw", "player_id": pid, "event_id": "pysim-component:%s:%d" % [spec.name, pid], "from_discard": spec.name == "discard_only"})
	elif spec.name.begins_with("stockpile"):
		ops.append({"kind": "draw_start"})
	else:
		ops.append({"kind": "market_begin"})
	for iteration in range(12):
		if ops.is_empty(): break
		var operation: Dictionary = ops.pop_front()
		var applied: Dictionary = component_apply(world, operation, spec.round)
		world = applied.world
		trace.records.append({"operation": operation, "result": applied.result, "world": world.duplicate(true)})
		check(applied.result.action != "invalid" and Cards.valid(world), "component " + spec.name + " " + operation.kind)
		if operation.kind in ["draw_start", "stockpile"]:
			var pending: Dictionary = world.data.game_economy.stockpile_pending
			if not pending.is_empty(): ops.append({"kind": "stockpile", "player_id": pending.player_id, "keep_id": pending.card_ids[-1]})
			elif operation.kind != "market_begin": ops.append({"kind": "market_begin"})
		elif operation.kind in ["market_begin", "market"] and world.data.game_market.seat != 2:
			ops.append({"kind": "market", "player_id": world.data.game_market.seat, "choice": {"market": "Pass"}})
	return trace

func timeline_cases() -> Array:
	var clock = Runtime.new()
	var rows: Array = []
	var operations: Array = [{"kind": "run", "hook": "round_start_scheduled"}, {"kind": "begin", "round": 0}]
	for number in [1, 2]:
		operations.append({"kind": "begin", "round": number})
		operations.append({"kind": "run", "hook": "unknown"})
		operations.append({"kind": "run", "hook": "aftermath"})
		operations.append({"kind": "reject", "hook": "round_start_scheduled"})
		for hook in Trace.Game.Timeline.EXECUTION_HOOKS: operations.append({"kind": "run", "hook": hook})
		operations.append({"kind": "run", "hook": "aftermath"})
	for op in operations:
		var result: Dictionary
		if op.kind == "begin": result = clock.begin_round(op.round)
		elif op.kind == "reject": result = clock.run_hook(op.hook, func(_c): return {"action": "invalid", "reason": "fixture_rejection"})
		else: result = clock.run_hook(op.hook)
		rows.append({"operation": op, "result": result, "state": clock.snapshot()})
	check(clock.completed and clock.round_number == 2, "all 20 cursor hooks complete in two rounds")
	return rows

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3: quit(2); return
	revision = args[1]; source_hash = args[2]
	var suite: Dictionary = {"schema": "U13_PYSIM_PLANNING_SUITE_V1", "games": [], "components": [], "timeline": timeline_cases()}
	for index in range(9): suite.games.append(game_case(index))
	for spec in [
		{"name": "recycle_full_hand", "hand0": 10, "hand1": 0, "deck": 0, "discard": 8, "round": 1},
		{"name": "discard_only", "hand0": 0, "hand1": 0, "deck": 0, "discard": 1, "round": 1},
		{"name": "empty_piles", "hand0": 0, "hand1": 0, "deck": 0, "discard": 0, "round": 1},
		{"name": "stockpile_interseat", "hand0": 0, "hand1": 0, "deck": 7, "discard": 0, "round": 1},
		{"name": "stockpile_one_offer", "hand0": 4, "hand1": 0, "deck": 18, "discard": 0, "round": 1},
		{"name": "market_exhausted", "hand0": 0, "hand1": 0, "deck": 0, "discard": 0, "round": 2},
		{"name": "market_recycle", "hand0": 0, "hand1": 0, "deck": 1, "discard": 8, "round": 2}]:
		suite.components.append(component_case(spec))
	var encoded: Dictionary = Codec.encode(suite)
	check(encoded.action == "encoded", "planning suite encodes")
	if encoded.action == "invalid": quit(1); return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null: check(false, "export file opens"); quit(1); return
	file.store_string(encoded.text + "\n"); file.close()
	var decoded: Dictionary = Codec.decode(FileAccess.get_file_as_string(args[0]))
	check(decoded.action == "decoded" and Codec.difference(suite, decoded.value).is_empty(), "complete export round trips exactly")
	for trace in decoded.value.games: replay_game(trace)
	print("U13 PySim planning Godot checks: %d" % checks)
	print("U13 PySim planning Godot failures: %d" % failures)
	quit(0 if failures == 0 else 1)
