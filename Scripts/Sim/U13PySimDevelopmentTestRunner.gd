extends SceneTree

const Trace = preload("res://Scripts/Sim/U13ParityTrace.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const Work = preload("res://Scripts/Sim/U13GuardWork.gd")
const Guards = preload("res://Scripts/Sim/U13GuardDeployment.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const SUITS: Array = ["Butcher", "Penitent", "Wright", "Vulture"]
const ATTEMPTS: Array = [0, 0, 0, 3, 2, 0, 0, 1, 0]
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

func setup(index: int) -> Dictionary:
	return {"seed": "u13-python-development:é:%d:%d" % [index, ATTEMPTS[index]],
		"lords": [Trace.Game.LORDS[index], Trace.Game.LORDS[(index + 1) % 9]],
		"castles": [Trace.Game.Slots.TYPES, Trace.Game.Slots.TYPES]}

func begin_game(index: int) -> Dictionary:
	var session: Dictionary = Trace.begin(setup(index), revision, source_hash)
	if session.action != "invalid":
		session.trace.identity.trace_schema = "U13_DEVELOPMENT_TRACE_V1"
		session.trace.identity.producer = "U13_PYSIM_DEVELOPMENT_EXPORT_V1"
	return session

func record(session: Dictionary, op: Dictionary) -> void:
	var result: Dictionary = Trace.record(session, op)
	check(result.action != "invalid", op.kind + " " + str(result))

func game_case(index: int) -> Dictionary:
	var session: Dictionary = begin_game(index)
	check(session.action == "trace_started", "fresh Development case " + str(index))
	for hook in ["round_start_scheduled", "persistent_advancement", "round_start_automatic"]:
		record(session, {"kind": "step", "hook": hook})
	for visit in range(2):
		record(session, {"kind": "market", "player_id": session.game.snapshot().world.data.game_market.seat, "choice": {"market": "Pass"}})
	record(session, {"kind": "step", "hook": "present_public_state"})
	var plans: Array = []
	var w: Dictionary = session.game.snapshot().world
	var ids = Ids.new(); ids.restore(w.entities)
	for pid in [0, 1]:
		var suit: String = SUITS[(index + 2 * pid) % 4]
		var hand: Array = w.data.card_zones.hands[pid]
		var picked: Array = hand.filter(func(id): return ids.get_entity(id).attributes.suit == suit).slice(0, 2)
		check(picked.size() == 2, "directed hand contains pair " + suit)
		var lane: String = ["Lord", "Castle"][(int(index / 4.0) + pid) % 2]
		var moves: Array = [{"card_id": picked[0], "lane": lane, "slot": 2}, {"card_id": picked[1], "lane": lane, "slot": 0}]
		plans.append({"powers": [], "order": {"guard_moves": moves, "castle_action": Work.choice(Trace.Game.Slots.castle_id(pid, 3))}})
	record(session, {"kind": "submit", "plans": plans})
	record(session, {"kind": "step", "hook": "submission_lock"})
	var before: Dictionary = session.game.snapshot()
	record(session, {"kind": "step", "hook": "development"})
	var after: Dictionary = session.game.snapshot()
	check(after.runtime.next_hook == "post_repair_artillery", "stops before artillery")
	check(Codec.difference(before.presentation_world, after.presentation_world).is_empty(), "Development preserves presentation baseline")
	check(after.world.data.guard_work.pairs.size() == 2, "both deployed pairs formed")
	return session.trace

func row(w: Dictionary, identity: String) -> Dictionary:
	for entity in w.entities.entities:
		if entity.id == identity: return entity
	return {}

func install(w: Dictionary, entity: Dictionary) -> void:
	var ids = Ids.new(); ids.restore(w.entities)
	ids.update(entity.id, entity.owner, entity.attributes)
	w.entities = ids.snapshot()

func component_apply(raw: Dictionary, op: Dictionary) -> Dictionary:
	var w: Dictionary = raw.duplicate(true)
	var result: Dictionary = {"action": "fixture_prepared"}
	match op.kind:
		"fixture_give":
			var z: Dictionary = w.data.card_zones
			for pile in [z.deck, z.discard, z.hands[0], z.hands[1], z.committed[0], z.committed[1], z.market, z.market_reserve]: pile.erase(op.card_id)
			var card: Dictionary = row(w, op.card_id)
			card.owner = op.player_id
			for key in ["role", "lane", "slot"]: card.attributes.erase(key)
			install(w, card)
			z.hands[op.player_id].append(op.card_id)
		"fixture_patch":
			var entity: Dictionary = row(w, op.entity_id).duplicate(true)
			entity.owner = op.get("owner", entity.owner)
			entity.attributes.merge(op.attributes, true)
			install(w, entity)
		"fixture_retire":
			var ids = Ids.new(); ids.restore(w.entities)
			ids.retire(op.entity_id); w.entities = ids.snapshot()
		"fixture_exhaust_deck":
			w.data.card_zones.discard.append_array(w.data.card_zones.deck)
			w.data.card_zones.deck.clear()
		"fixture_stage":
			w.data.guard_public_round = op.round
			for pid in [0, 1]:
				w.data.guard_orders[pid] = {"round": op.round, "moves": op.moves[pid].duplicate(true)}
				w.data.castle_orders[pid] = {"round": op.round, "choice": op.choices[pid].duplicate(true), "paid_value": 0, "reconstruction": false}
		"deploy":
			result = Guards.resolve({"world": w, "round": op.round, "hook": "development", "player_order": op.player_order})
		"work": result = {"action": "resolved", "events": Work.develop(w, op.round, op.player_order)}
		"pair_draw": result = {"action": "resolved", "events": Work.draw_pairs(w, op.round, "u13-development-components:é")}
		"reconcile":
			Work.reconcile(w); result = {"action": "resolved", "events": []}
		"validate_work": result = Work.validate_choice(w, op.player_id, op.choice)
		"discard": result = Cards.discard(w, op.player_id, op.card_ids)
	if result.action == "invalid": return {"result": result, "world": raw}
	if result.has("world"): w = result.world
	var visible_result: Dictionary = result.duplicate(true); visible_result.erase("world")
	return {"result": visible_result, "world": w}

func component_record(trace: Dictionary, op: Dictionary, invalid: bool = false) -> void:
	var before: Dictionary = trace.current
	var applied: Dictionary = component_apply(before, op)
	trace.current = applied.world
	trace.records.append({"operation": op, "result": applied.result, "world": applied.world.duplicate(true)})
	check((applied.result.action == "invalid") == invalid, trace.name + " " + op.kind)
	if invalid: check(Codec.difference(before, applied.world).is_empty(), "component rejection is atomic")
	if not op.kind.begins_with("fixture") and op.kind != "deploy":
		check(Cards.valid(applied.world) and Work.valid(applied.world), "physical identities and pair ledger remain valid")

func component(name: String) -> Dictionary:
	var w: Dictionary = Trace.Game.Economy.initialize(Trace.Game.Scenario.loadout_world(["Deimos", "Gremory"], [Trace.Game.Slots.TYPES, Trace.Game.Slots.TYPES]), "u13-development-components:é").world
	return {"name": name, "initial": w.duplicate(true), "current": w, "records": []}

func give(trace: Dictionary, suit: String, pid: int = 0) -> String:
	# Select neutral physical cards in stable entity order; no synthetic Guards.
	for card in trace.current.entities.entities:
		if card.kind == "card" and card.owner == -1 and card.attributes.suit == suit:
			component_record(trace, {"kind": "fixture_give", "card_id": card.id, "player_id": pid})
			return card.id
	check(false, "fixture ran out of neutral " + suit)
	return ""

func move(identity: String, lane: String, slot: int) -> Dictionary:
	return {"card_id": identity, "lane": lane, "slot": slot}

func stage(t: Dictionary, number: int, moves: Array = [], selected: Dictionary = {}, other_moves: Array = [], other_choice: Dictionary = {}) -> void:
	component_record(t, {"kind": "fixture_stage", "round": number, "moves": [moves, other_moves], "choices": [selected, other_choice]})

func settle(t: Dictionary, number: int, order: Array = [0, 1]) -> void:
	component_record(t, {"kind": "deploy", "round": number, "player_order": order})
	component_record(t, {"kind": "work", "round": number, "player_order": order})

func work_case() -> Dictionary:
	var t: Dictionary = component("work_lifecycle")
	var target: String = Trace.Game.Slots.castle_id(0, 3)
	stage(t, 1, [move(give(t, "Wright"), "Lord", 2), move(give(t, "Wright"), "Lord", 0), move(give(t, "Butcher"), "Castle", 1)], Work.choice(target))
	settle(t, 1)
	check(row(t.current, target).attributes.integrity == 11, "fresh Guards plus Wright pair plus passive Work")
	stage(t, 2); settle(t, 2)
	component_record(t, {"kind": "work", "round": 2, "player_order": [0, 1]})
	check(row(t.current, target).attributes.integrity == 14, "survivors do not repeat Work or Wright bonus")
	stage(t, 3, [move(give(t, "Wright"), "Castle", 2), move(give(t, "Wright"), "Castle", 0)])
	settle(t, 3)
	check(row(t.current, target).attributes.integrity == 21 and t.current.data.guard_work.targets[0].is_empty(), "completion clamps, activates and clears target")
	var keep: String = Trace.Game.Slots.castle_id(0, 0)
	component_record(t, {"kind": "fixture_patch", "entity_id": keep, "attributes": {"integrity": 8, "repair_lock_until_round": 4}})
	stage(t, 4, [move(give(t, "Vulture"), "Lord", 1)], Work.choice(keep)); settle(t, 4)
	check(row(t.current, keep).attributes.integrity == 8, "repair lock includes its final round")
	stage(t, 5); settle(t, 5)
	check(row(t.current, keep).attributes.integrity == 8, "active Castle gains no passive repair")
	# Free the unpaired Lord Vulture, then place a new Subject after the lock.
	for card in t.current.entities.entities:
		if card.kind == "card" and card.attributes.get("role") == "guard" and card.attributes.get("suit") == "Vulture":
			component_record(t, {"kind": "fixture_retire", "entity_id": card.id}); break
	stage(t, 6, [move(give(t, "Butcher"), "Lord", 1)]); settle(t, 6)
	check(row(t.current, keep).attributes.integrity == 9, "new Guard repairs after lock expires")
	stage(t, 7, [], Work.choice("")); settle(t, 7)
	check(t.current.data.guard_work.targets[0].is_empty(), "explicit clear cancels target")
	t.erase("current"); return t

func pair_case(suit: String, lane: String) -> Dictionary:
	var t: Dictionary = component("pair_" + suit + "_" + lane)
	var first: String = give(t, suit)
	var second: String = give(t, suit)
	var third: String = give(t, suit)
	stage(t, 1, [move(third, lane, 2), move(second, lane, 1), move(first, lane, 0)])
	settle(t, 1)
	check(t.current.data.guard_work.pairs[0].ids == [first, second], "three fresh Guards pair by slot")
	component_record(t, {"kind": "pair_draw", "round": 1})
	if suit == "Vulture": component_record(t, {"kind": "fixture_exhaust_deck"})
	component_record(t, {"kind": "pair_draw", "round": 2})
	component_record(t, {"kind": "pair_draw", "round": 2})
	component_record(t, {"kind": "fixture_patch", "entity_id": first, "owner": 1, "attributes": {}})
	component_record(t, {"kind": "reconcile"})
	component_record(t, {"kind": "fixture_patch", "entity_id": first, "owner": 0, "attributes": {}})
	component_record(t, {"kind": "reconcile"})
	check(not t.current.data.guard_work.pairs[0].active, "returning original identity does not repair bond")
	component_record(t, {"kind": "fixture_retire", "entity_id": first})
	stage(t, 2, [move(give(t, suit), lane, 0)]); settle(t, 2)
	component_record(t, {"kind": "pair_draw", "round": 3})
	check(t.current.data.guard_work.pairs.size() == 1 and not t.current.data.guard_work.pairs[0].active, "replacement plus survivor does not form a new bond")
	t.erase("current"); return t

func reconstruction_case() -> Dictionary:
	var t: Dictionary = component("reconstruction")
	var engine: String = Trace.Game.Slots.castle_id(0, 4)
	component_record(t, {"kind": "fixture_patch", "entity_id": engine, "attributes": {"status": "ruined", "integrity": 0, "construction_state": "active", "repair_lock_until_round": 9}})
	component_record(t, {"kind": "validate_work", "player_id": 0, "choice": Work.choice(engine)})
	var lord: String = t.current.players[0].lord_entity_id
	component_record(t, {"kind": "fixture_patch", "entity_id": lord, "attributes": {"alive": false}})
	component_record(t, {"kind": "validate_work", "player_id": 0, "choice": Work.choice(engine)}, true)
	component_record(t, {"kind": "fixture_patch", "entity_id": lord, "attributes": {"alive": true}})
	component_record(t, {"kind": "validate_work", "player_id": 1, "choice": Work.choice(engine)}, true)
	var other_engine: String = Trace.Game.Slots.castle_id(1, 4)
	component_record(t, {"kind": "fixture_patch", "entity_id": other_engine, "attributes": {"status": "ruined", "integrity": 0, "construction_state": "active"}})
	component_record(t, {"kind": "validate_work", "player_id": 1, "choice": Work.choice(other_engine)}, true)
	var ordinary: String = Trace.Game.Slots.castle_id(0, 0)
	component_record(t, {"kind": "fixture_patch", "entity_id": ordinary, "attributes": {"status": "ruined", "integrity": 0}})
	component_record(t, {"kind": "validate_work", "player_id": 0, "choice": Work.choice(ordinary)}, true)
	stage(t, 1, [move(give(t, "Wright"), "Lord", 0), move(give(t, "Wright"), "Lord", 1)], Work.choice(engine)); settle(t, 1)
	check(row(t.current, engine).attributes.integrity == 10 and not row(t.current, engine).attributes.has("repair_lock_until_round"), "Deimos reconstructs same Engine identity as protected building")
	component_record(t, {"kind": "fixture_patch", "entity_id": ordinary, "attributes": {"status": "standing", "integrity": 8}})
	component_record(t, {"kind": "validate_work", "player_id": 0, "choice": Work.choice(ordinary)})
	stage(t, 2, [], Work.choice(ordinary))
	component_record(t, {"kind": "fixture_patch", "entity_id": ordinary, "attributes": {"status": "ruined", "integrity": 0}})
	settle(t, 2)
	check(t.current.data.guard_work.targets[0].is_empty(), "invalidated Work target clears without gain")
	component_record(t, {"kind": "fixture_patch", "entity_id": engine, "attributes": {"status": "profaned", "integrity": 0, "construction_state": "active"}})
	component_record(t, {"kind": "validate_work", "player_id": 0, "choice": Work.choice(engine)}, true)
	t.erase("current"); return t

func atomic_case() -> Dictionary:
	var t: Dictionary = component("atomic_deployment")
	var a: String = give(t, "Wright", 0)
	var b: String = give(t, "Penitent", 1)
	stage(t, 1, [move(a, "Lord", 0)], {}, [move(b, "Castle", 2)])
	component_record(t, {"kind": "discard", "player_id": 1, "card_ids": [b]})
	component_record(t, {"kind": "deploy", "round": 1, "player_order": [0, 1]}, true)
	component_record(t, {"kind": "fixture_give", "card_id": b, "player_id": 1})
	settle(t, 1, [1, 0])
	component_record(t, {"kind": "deploy", "round": 1, "player_order": [1, 0]}, true)
	t.erase("current"); return t

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3: quit(2); return
	revision = args[1]; source_hash = args[2]
	var suite: Dictionary = {"schema": "U13_PYSIM_DEVELOPMENT_SUITE_V1", "games": [], "components": []}
	for index in range(9): suite.games.append(game_case(index))
	suite.components.append(work_case())
	for suit in SUITS:
		for lane in ["Lord", "Castle"]: suite.components.append(pair_case(suit, lane))
	suite.components.append(reconstruction_case())
	suite.components.append(atomic_case())
	var encoded: Dictionary = Codec.encode(suite)
	check(encoded.action == "encoded", "Development suite encodes")
	if encoded.action == "invalid": quit(1); return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null: check(false, "export opens"); quit(1); return
	file.store_string(encoded.text + "\n"); file.close()
	var decoded: Dictionary = Codec.decode(FileAccess.get_file_as_string(args[0]))
	check(decoded.action == "decoded" and Codec.difference(suite, decoded.value).is_empty(), "exact export round trips")
	for index in range(decoded.value.games.size()):
		var expected: Dictionary = decoded.value.games[index]
		var session: Dictionary = begin_game(index)
		for entry in expected.records: Trace.record(session, entry.operation)
		check(Codec.difference(expected, session.trace).is_empty(), "Godot replays complete Development trace " + str(index))
	for expected in decoded.value.components:
		var w: Dictionary = expected.initial.duplicate(true)
		var delta: String = ""
		for entry in expected.records:
			var actual: Dictionary = component_apply(w, entry.operation)
			w = actual.world
			actual["operation"] = entry.operation
			delta = Codec.difference(entry, actual)
			if not delta.is_empty(): break
		check(delta.is_empty(), "Godot replays component " + expected.name + " " + delta)
	print("U13 PySim development Godot checks: %d" % checks)
	print("U13 PySim development Godot failures: %d" % failures)
	quit(0 if failures == 0 else 1)
