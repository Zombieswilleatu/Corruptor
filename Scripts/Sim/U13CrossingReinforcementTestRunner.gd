extends SceneTree
const Model = preload("res://Prototype/U13/Encounters/U13EncounterModel.gd")
var checks: int = 0
var failed: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("PASS " if ok else "FAIL ") + message)
func _initialize() -> void: call_deferred("run")
func advance(m) -> Dictionary:
	m.phase = "resolving"
	var result: Dictionary = {"action":"resolved", "world":m.arena.world.duplicate(true)}
	check(m.accept(result), "resolved round accepted")
	return result
func run() -> void:
	for mode in ["gate", "lamp"]:
		for leader in ["", "Penitent", "Vulture", "Wright", "Butcher"]:
			var m = Model.new("reinforcement", mode, 2, 1, [], leader)
			var initial: Dictionary = m.ordinary.duplicate()
			var expected: int = 15 if mode == "gate" else 10
			check(m.reinforcement_round() == expected and m.pending_reinforcements() == 8, "schedule fixed at start")
			check(m.reinforcement_text().contains("round %d" % expected), "schedule visible before arrival")
			m.arena.round_number = expected - 2
			advance(m)
			check(m.ordinary == initial and not m.reinforcements_received, "no early grant")
			var power_before: int = m.power
			var result: Dictionary = advance(m)
			check(m.ordinary.values().reduce(func(total, value): return total + value, 0) == initial.values().reduce(func(total, value): return total + value, 0) + 8, "exactly eight added")
			for suit in Model.SUITS: check(m.ordinary[suit] == initial[suit] + 2, "fixed +2 " + suit)
			check(m.power == power_before + 2 and m.deployments == 0 and m.pending_reinforcements() == 0, "no power or deployment bonus")
			check(m.start_metrics.ordinary_left == m.ordinary_remaining() and m.metrics.player_reinforcement_round == expected, "arrival tracked before planning")
			check(not m.accept(result), "duplicate result cannot grant again")
			var arrived: Dictionary = m.ordinary.duplicate()
			check(m.deploy("Penitent", Vector2(200,300)).has("ok") and m.undo() and m.ordinary == arrived and m.reinforcements_received, "placement undo retains shipment exactly")
			for i in range(4): check(m.deploy(Model.SUITS[i], Vector2(100+i*80,180)).has("ok"), "ordinary deploy uses normal slot")
			check(m.deploy("Penitent",Vector2(200,400)).has("error"), "fifth deployment blocked")
			var after_deployment: Dictionary = m.ordinary.duplicate()
			advance(m)
			check(m.ordinary == after_deployment, "next round does not repeat grant")
			var ended = Model.new("terminal", mode)
			ended.arena.round_number = expected-1
			Model.Objectives.finish(ended.arena.world.data.encounter,"defeat","fixture",0)
			advance(ended)
			check(ended.phase == "finished" and not ended.reinforcements_received, "terminal result cannot be rescued by shipment")
	var lamp = Model.new("pending", "lamp", 2, 1, [])
	lamp.waves = []
	for suit in Model.SUITS: lamp.ordinary[suit] = 0
	var req: Dictionary = lamp.begin()
	var resolved: Dictionary = Model.resolve(req.world,req.seed,req.round)
	check(resolved.action == "resolved" and resolved.world.data.encounter.outcome.is_empty(), "pending shipment prevents false Lamp loss through real resolver")
	check(lamp.accept(resolved), "pending Lamp round accepted")
	lamp.reinforcements_received = true
	req = lamp.begin()
	resolved = Model.resolve(req.world,req.seed,req.round)
	check(resolved.world.data.encounter.outcome == "defeat" and resolved.world.data.encounter.winning_tick == 0, "exhausted shipment restores conservative Lamp loss")
	print("Reinforcement checks complete: %d passed, %d failed." % [checks-failed,failed])
	quit(1 if failed else 0)
