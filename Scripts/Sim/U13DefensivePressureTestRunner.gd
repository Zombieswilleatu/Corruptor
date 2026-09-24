extends "res://Scripts/Sim/U13GameStagingTestRunner.gd"

const Embolden = preload("res://Scripts/Sim/U13Embolden.gd")
const Conversion = preload("res://Scripts/Sim/U13WardConversion.gd")

func run() -> void:
	var w: Dictionary = {"data": {}, "entities": {"entities": []}}
	Embolden.configure(w)
	for n in range(1, 6):
		Embolden.observe(w, n)
		checked(Embolden.pressures(w)[0].Lord == [0, 30, 45, 60, 60][n - 1], "vacancy ramp round %d" % n)
	var guard: Dictionary = {"kind": "card", "owner": 1, "attributes": {"role": "guard", "lane": "Lord", "slot": 0}}
	w.entities.entities.append(guard)
	Embolden.observe(w, 5)
	checked(Embolden.pressures(w)[0].Lord == 40, "filling one slot immediately cancels that slot's bonus")
	w.entities.entities.clear()
	Embolden.observe(w, 5)
	Embolden.observe(w, 6)
	checked(w.data.embolden_guard_history.slots[1].Lord[0].age == 0, "lost Guard gets one whole following round of grace")
	Embolden.observe(w, 7)
	checked(w.data.embolden_guard_history.slots[1].Lord[0].age == 1, "bonus resumes after the full empty round")
	var a: Dictionary = Marching.profile("Wright", "Lord", 0, 1, 1, true)
	Embolden.apply(a, 60)
	a.hp = 4; a.armor = 0
	Embolden.apply(a, 40)
	checked(a.hp == 3.5 and a.armor == 0, "bonus changes preserve wounds and spent armor")
	var held: Dictionary = a.duplicate(true)
	for n in range(20): Embolden.apply(a, 40)
	checked(a == held, "refresh never compounds bonuses")
	Embolden.apply(a, 0)
	a.hp = 2.1; a.armor = 0
	Marching._attack(a, 1.2, false)
	checked(a.hp == 0.9, "fractional damage keeps the real survivor alive")
	Marching._attack(a, 0.9, false)
	checked(a.hp == 0, "lethal fractional hit leaves no ghost HP")
	var distance: int = 0
	for tick in range(100): distance += preload("res://Scripts/Sim/U13LaneAuras.gd").speed(4, 0, false, tick, false, false, 60)
	checked(distance == 640, "speed distributes fractional movement exactly")
	var schema: Dictionary = Game.Scenario.loadout_world(["Gremory", "Humbaba"], [Slots.TYPES, Slots.TYPES])
	w = Economy.initialize(schema, "conversion-fixture").world
	Stage.configure(w)
	Game.Content.SplitWard.configure(w)
	Embolden.configure(w)
	var regular: Dictionary = put(w, "Butcher", 0, "Lord", 1)
	var monster: Dictionary = put(w, "Lemek", 0, "Lord", 1)
	var reserve: Dictionary = put(w, "Penitent", 0, "Lord", 1)
	var old: Dictionary = put(w, "Vulture", 0, "Lord", 0)
	var births: Array = [Marching.public_event("MARCHER_SPAWNED", regular), Marching.public_event("MARCHER_SPAWNED", monster)]
	Conversion.record(w, 0, {"action": "Hunt", "lane": "Lord"}, 1, births)
	Stage.capture(w, births + [Marching.public_event("MARCHER_SPAWNED", reserve)], 1)
	var events: Array = Conversion.convert(w, 0, {"lane": "Lord"}, 1, "conversion-fixture")
	checked(events.size() == 1 and events[0].event.data.regular_count == 1 and events[0].event.data.monster_count == 0, "only the surviving regular attack cohort converts")
	var unit: Dictionary = w.entities.entities.filter(func(u): return u.id == regular.id)[0]
	checked(unit.owner == 1 and unit.attributes.direction == -1 and unit.attributes.x_fp >= 2280, "converted body starts at the defender's side")
	checked(unit.attributes.movement_ready_round == 1 and not unit.attributes.has("staged_round"), "converted body launches this phase")
	checked(Stage.rows(w).size() == 2 and Stage.rows(w).all(func(u): return u.owner == 0), "monster and unrelated staged reserve stay with attacker")
	checked(w.entities.entities.filter(func(u): return u.id == old.id)[0].owner == 0, "existing field units never convert")
	checked(Conversion.convert(w, 0, {"lane": "Lord"}, 1, "conversion-fixture").is_empty(), "conversion is once only")
	checked(Game.Content.new().valid_world(w), "converted full-game world validates")
	checked(Embolden.valid(Codec.decode(Codec.encode(w).text).value), "vacancy schema survives exact serialization")
	var legacy = Game.new()
	checked(legacy.start("legacy", ["Gremory", "Humbaba"], [Slots.TYPES, Slots.TYPES], true, true, false).action != "invalid" and not legacy.snapshot().world.data.has("defensive_pressure_profile"), "legacy promoted profile remains available")
	var current = Game.new()
	checked(current.start("current", ["Gremory", "Humbaba"], [Slots.TYPES, Slots.TYPES], true, true).action != "invalid" and current.snapshot().world.data.defensive_pressure_profile == Embolden.VERSION, "new playable game enables defensive pressure")
	var restored = Game.new()
	checked(restored.restore(current.snapshot()).action != "invalid", "new profile saves restore")
	var opening_game = Game.new()
	opening_game.start("opening-interlock", ["Odradek", "Humbaba"], [Slots.TYPES, Slots.TYPES], true, true)
	checked(opening_game.to_planning(true).action != "invalid", "opening marching reaches planning")
	var opening_save: Dictionary = opening_game.snapshot()
	opening_save.world.data.interlock_rounds[0] = 1
	checked(Game.new().restore(opening_save).action != "invalid", "opening-march Interlock does not invalidate saves")
	opening_save.world.data.interlock_rounds[0] = 2
	checked(Game.new().restore(opening_save).action == "invalid", "future Interlock trigger is still rejected")
	print("Defensive pressure assertions: %d; failures: %d" % [assertions, failures])
	quit(1 if failures else 0)
