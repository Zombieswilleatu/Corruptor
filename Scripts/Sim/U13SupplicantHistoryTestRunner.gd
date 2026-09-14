extends SceneTree
const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Log = preload("res://Scripts/Sim/U13EventLog.gd")
const Work = preload("res://Scripts/Sim/U13GuardWork.gd")
const Kanifous = preload("res://Scripts/Sim/U13Kanifous.gd")
const Rites = preload("res://Scripts/Sim/U13DominionRites.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func _initialize() -> void:
	history()
	for pid in [0, 1]: gate(pid)
	prices()
	print("U13 Supplicant history failures: ", failures)
	quit(failures)
func world(lords: Array = ["Deimos", "Gremory"]) -> Dictionary:
	return Game.Economy.initialize(Game.Scenario.loadout_world(lords, [Game.Slots.TYPES, Game.Slots.TYPES]), "supplicant-fixture").world
func history() -> void:
	var log = Log.new()
	for spec in [["MARCHING_TICK", 1], ["MARCHER_DEFEATED", 1], ["KRONI_ACTOR_TICK", 1], ["MARCHING_TICK", 2]]:
		var e: Dictionary = {"type": spec[0], "text": "", "data": {"round": spec[1], "units": [{"id": "sample"}]}}
		log.append(e, [e, e])
	var hidden: Dictionary = {"type": "HIDDEN_FIXTURE", "text": "", "data": {"secret": 7}}
	log.append(hidden, [hidden, null])
	var before: Dictionary = log.snapshot()
	var child = log._fork()
	check(child._retire_visual_samples(1) == 2, "only completed Marching and actor samples retire")
	check(log.snapshot() == before, "retirement does not mutate fork parent")
	check(child._cursor() == log._cursor(), "retirement preserves feedback cursors")
	check(child.for_player(0).map(func(e): return e.type) == ["MARCHER_DEFEATED", "MARCHING_TICK", "HIDDEN_FIXTURE"], "state changes and current tape survive")
	check(child.for_player(1).size() == 2, "hidden projections remain hidden")
	check(child._retire_visual_samples(1) == 0, "retirement is idempotent")
	var restored = Log.new()
	check(restored.restore(bytes_to_var(var_to_bytes(child.snapshot()))).action != "invalid" and restored.snapshot() == child.snapshot(), "retired history saves and restores exactly")
	check(restored.for_player(0, 3).size() == 2, "existing cursor reads correct later events")
func gate(pid: int) -> void:
	var w: Dictionary = world()
	var ids = Game.Content.Ids.new(); ids.restore(w.entities)
	for index in range(13):
		var a: Dictionary = Marching.profile("Penitent", "Castle", pid, 0, 0)
		a.x_fp = (Marching.LANE_FP if pid == 0 else 0) + (-1 if pid == 0 else 1) * (0 if index < 5 else 90 + (index - 5) * 85)
		a.y_fp = 50 + (index % 5) * 100
		a.waiting = index < 5
		a.waiting_since_round = 1 if a.waiting else 0
		ids.create("marcher", "gate-fixture", index, pid, a)
	w.entities = ids.snapshot()
	var context: Dictionary = {"world": w, "round": 2, "hook": Game.Timeline.MARCHING, "seed": "gate", "player_order": [0, 1], "combat_orders": [{}, {}]}
	var result: Dictionary = Marching.resolve(context, Callable(Game.Content.new(), "react"))
	check(result.action != "invalid", "crowded gate resolves for seat %d" % pid)
	if result.action == "invalid": return
	var arrived: int = result.world.entities.entities.filter(func(e): return e.kind == "marcher" and e.attributes.waiting).size()
	check(arrived > 5, "friendly gate queue admits followers for seat %d (%d arrived)" % [pid, arrived])
	var unit: Dictionary = {"id": "moving", "owner": pid, "attributes": Marching.profile("Butcher", "Castle", pid, 0, 0)}
	unit.attributes.x_fp = 1000; unit.attributes.y_fp = 300
	var other: Dictionary = unit.duplicate(true); other.id = "ally"; other.attributes.x_fp = 1080
	var proposed: Dictionary = unit.attributes.duplicate(true); proposed.x_fp = 1004
	check(not Marching._space_free(unit, proposed, [other], true), "ordinary friendly spacing remains enforced")
	other.owner = 1 - pid
	check(Marching._touches_enemy(unit, [other]), "hostile contact still prevents uncontested arrival")
func prices() -> void:
	var w: Dictionary = world(["Kanifous", "Gremory"])
	var ids = Game.Content.Ids.new(); ids.restore(w.entities)
	for e in w.entities.entities:
		if e.kind == "castle" and e.owner == 0 and e.attributes.status == "standing":
			e.attributes.integrity = 5; ids.update(e.id, e.owner, e.attributes)
	w.entities = ids.snapshot()
	var found: Dictionary = {}
	for index in range(500):
		var result: Dictionary = Kanifous.new()._price(w, {"id": "price-test", "owner": 0}, {"seed": str(index), "round": 2, "hook": Game.Timeline.ROUND_START_SCHEDULED, "player_order": [0, 1]})
		var resolved: Array = result.events.filter(func(e): return e.event.type == "KANIFOUS_PRICE_RESOLVED")
		if resolved.is_empty(): continue
		var outcome: String = resolved[0].event.data.outcome
		if outcome not in ["Stone", "Ruin"] or found.has(outcome): continue
		found[outcome] = true
		ids.restore(result.world.entities)
		var castle: Dictionary = ids.get_entity(resolved[0].event.data.targets[0])
		check(castle.attributes.integrity == 0 and castle.attributes.status == "ruined", "%s price produces a real ruin at zero Integrity" % outcome)
		check(not Work.eligible(result.world, 0, castle), "Kanifous cannot repair a ruined Castle")
		check(not Kanifous.longevity_target(castle, 0), "Wish Longevity cannot restore a ruin")
		var rites_world: Dictionary = result.world.duplicate(true)
		var ruins_ids = Game.Content.Ids.new(); ruins_ids.restore(rites_world.entities)
		for other in rites_world.entities.entities:
			if other.kind == "castle" and other.owner == 0 and other.id != castle.id:
				other.attributes.integrity = 0; other.attributes.status = "ruined"
				ruins_ids.update(other.id, 0, other.attributes)
				break
		rites_world.entities = ruins_ids.snapshot()
		rites_world.players[0].resources.souls = Rites.RUINS_SOUL_COST
		check(Rites.validate(rites_world, 0, {"rites": {"profane_ruins": {"castle_id": castle.id}}}).action != "invalid", "Wish-price ruin qualifies for Profane Ruins when costs are met")
		check(result.world.data.neutral_tears == w.data.neutral_tears + 1, "price keeps its single neutral Tear")
		check(result.events.any(func(e): return e.event.type == "CASTLE_RUINED"), "ruin has an explicit Aftermath event")
		if found.size() == 2: break
	check(found.size() == 2, "both zero-Integrity price paths exercised")

	var gremory = preload("res://Scripts/Sim/U13Gremory.gd").new()
	var target: String = Game.Slots.castle_id(0, 1)
	var doomed: Dictionary = gremory.resolve({"declaration": {"power_id": "InevitableRuin", "player_id": 1, "target": {"entity_id": target}, "declaration_id": "doom-fixture"}}, {"world": w, "round": 2})
	ids.restore(doomed.world.entities)
	check(ids.get_entity(target).attributes.status == "ruined" and doomed.events[0].type == "CASTLE_RUINED", "Inevitable Ruin also creates a real ruin")
