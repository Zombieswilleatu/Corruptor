extends SceneTree

# Controlled attrition probes: replenish two rank-3 Guards each round and
# supply the same attack. This isolates defenses/repair, not deck availability,
# marching, artillery, other powers, Sigils, Ward or victory timing.
const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Work = preload("res://Scripts/Sim/U13GuardWork.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Kalligan = preload("res://Scripts/Sim/U13Kalligan.gd")
const Rules = preload("res://Scripts/Sim/U13Kanifous.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
var failures: int = 0

func _initialize() -> void:
	var cases: Array = []
	for spec in [[12, false, false, false], [12, false, true, false], [12, true, false, false], [12, true, true, false], [14, true, false, false], [14, true, true, false], [12, false, false, true], [14, false, false, true], [15, false, true, true], [16, false, false, true], [16, false, true, true], [17, false, true, true]]:
		cases.append(probe(spec[0], spec[1], spec[2], spec[3]))
	var expected: Array = [4, 4, 7, 0, 3, 4, 13, 5, 4, 3, 3, 3]
	for i in range(cases.size()):
		var ok: bool = cases[i].destroyed_round == expected[i]
		if not ok: failures += 1
		print("PASS " if ok else "FAIL ", "castle pressure ", cases[i])
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var f = FileAccess.open(args[0], FileAccess.WRITE)
		f.store_string(JSON.stringify({"cases": cases, "rules": Rules.rules(), "rules_hash": JSON.stringify(Rules.rules(), "", true).sha256_text()}, "\t") + "\n")
	print("U13 castle pressure failures: ", failures)
	quit(1 if failures else 0)

func probe(strength: int, wrights: bool, forge: bool, penitents: bool) -> Dictionary:
	var world: Dictionary = Game.Economy.initialize(Game.Scenario.loadout_world(["Gremory", "Kalligan" if forge else "Valak"], [Game.Slots.TYPES, Game.Slots.TYPES]), "castle-pressure").world
	var target: String = Game.Slots.castle_id(1, 1)
	var content = Game.Content.new()
	var upkeep = Kalligan.new()
	var health: Array = []
	var repairs: Array = []
	var destroyed_round: int = 0
	for number in range(1, 16):
		var context: Dictionary = {"round": number, "seed": "castle-pressure", "hook": "combat_resolution", "player_order": [0, 1], "combat_orders": [{}, {}]}
		var before: int = row(world, target).attributes.integrity
		context.world = world
		world = upkeep._upkeep(context, {"world": world, "events": [], "action": "resolved"}).world
		var ids = Ids.new(); ids.restore(world.entities)
		var moves: Array = []
		for slot in range(2):
			var guard: Dictionary = ids.create("card", "pressure_guard:" + str(number), slot, 1, {"suit": "Penitent" if penitents else ("Wright" if wrights else ("Butcher" if slot == 0 else "Vulture")), "value": 3, "role": "guard", "lane": "Castle", "slot": slot}).entity
			moves.append({"card_id": guard.id, "lane": "Castle", "slot": slot})
		var cards: Array = []
		var values: Array = []
		var remaining: int = strength
		while remaining > 0:
			var value: int = mini(5, remaining)
			values.append(value); remaining -= value
		for index in range(values.size()):
			var card: Dictionary = ids.create("card", "pressure_attack:" + str(number), index, 0, {"suit": "Butcher", "value": values[index]}).entity
			world.data.card_zones.hands[0].append(card.id)
			cards.append(card.id)
		world.entities = ids.snapshot()
		world.data.guard_orders = [{"round": number, "moves": []}, {"round": number, "moves": moves}]
		world.data.castle_orders = [{"choice": {}}, {"choice": Work.choice(target)}]
		Work.develop(world, number, [0, 1])
		repairs.append(row(world, target).attributes.integrity - before)
		var order: Dictionary = {"action": "Siege", "lane": "Castle", "target_id": target, "card_ids": cards}
		context.world = world
		context.combat_orders = [order, {}]
		var result: Dictionary = Combat._siege(world, context, 0, order, Callable(content, "react"))
		if result.action == "invalid":
			failures += 1; push_error(str(result)); break
		world = result.world
		for card in cards:
			world.data.card_zones.hands[0].erase(card)
			var discard_ids = Ids.new(); discard_ids.restore(world.entities)
			var paid: Dictionary = discard_ids.get_entity(card)
			discard_ids.update(card, -1, paid.attributes); world.entities = discard_ids.snapshot()
			world.data.card_zones.discard.append(card)
		health.append(row(world, target).attributes.integrity)
		if row(world, target).attributes.status == "ruined":
			destroyed_round = number; break
	return {"attack": strength, "wright_pair": wrights, "penitent_pair": penitents, "forge": forge, "health_after_siege": health, "repair_before_siege": repairs, "destroyed_round": destroyed_round}

func row(world: Dictionary, id: String) -> Dictionary:
	return world.entities.entities.filter(func(e): return e.id == id)[0]
