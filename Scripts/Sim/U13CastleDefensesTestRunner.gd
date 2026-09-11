extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Defenses = preload("res://Scripts/Sim/U13CastleDefenses.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")

func row(world: Dictionary, id: String) -> Dictionary:
	return world.entities.entities.filter(func(e): return e.id == id)[0]

func fixture(kind: String, integrity: int, state: String, strength: int, duplicate: bool = false) -> Dictionary:
	var choices: Array = Slots.TYPES.duplicate()
	if duplicate:
		choices[2] = kind
	var world: Dictionary = Economy.initialize(Game.Scenario.loadout_world(["Gremory", "Gremory"], [Slots.TYPES, choices]), "castle-defenses").world
	var ids = Ids.new()
	ids.restore(world.entities)
	var screen_id: String = Slots.castle_id(1, 0 if kind == "Keep" else 1)
	for slot in ([0, 2] if duplicate and kind == "Keep" else ([0, 1, 2] if duplicate else ([0] if kind == "Keep" else [0, 1]))):
		var castle: Dictionary = ids.get_entity(Slots.castle_id(1, slot))
		castle.attributes.integrity = integrity if castle.id == screen_id else (7 if slot == 2 else 9)
		castle.attributes.status = "standing" if castle.attributes.integrity > 0 else "defunct"
		castle.attributes.construction_state = state if castle.id == screen_id else "active"
		if state in ["ruined", "profaned"] and castle.id == screen_id:
			castle.attributes.status = state
			castle.attributes.construction_state = "active"
		ids.update(castle.id, 1, castle.attributes)
	var values: Array = []
	if strength <= 5:
		values = [strength]
	else:
		var remaining: int = strength - 1 # same-suit pair bonus
		while remaining > 0:
			var amount: int = mini(5, remaining)
			if values.is_empty() and amount == remaining:
				amount -= 1
			values.append(amount)
			remaining -= amount
	var cards: Array = world.data.card_zones.hands[0].slice(0, values.size())
	for index in range(cards.size()):
		ids.update(cards[index], 0, {"suit": "Butcher", "value": values[index]})
	world.entities = ids.snapshot()
	return {"world": world, "screen": screen_id, "cards": cards, "kind": kind}

func attack(f: Dictionary, direct: bool = false, ward: Dictionary = {}) -> Dictionary:
	var order: Dictionary = {"action": "Hunt" if f.kind == "Keep" else "Siege", "lane": "Lord" if f.kind == "Keep" else "Castle", "card_ids": f.cards, "target_id": f.world.players[1].lord_entity_id if f.kind == "Keep" else (f.screen if direct else Slots.castle_id(1, 0))}
	var content = Game.Content.new()
	var context: Dictionary = {"round": 1, "hook": Game.Timeline.COMBAT_RESOLUTION, "seed": "castle-defenses", "player_order": [0, 1], "combat_orders": [order, ward]}
	var result: Dictionary = Combat._hunt(f.world.duplicate(true), context, 0, order, Callable(content, "react")) if f.kind == "Keep" else Combat._siege(f.world.duplicate(true), context, 0, order, Callable(content, "react"))
	check(result.action != "invalid" and content.valid_world(result.world), "valid " + f.kind + " result")
	return result

func run() -> void:
	for selection in [["Keep", "Keep", "Bastion", "Stockpile", "SiegeEngine"], ["Bastion", "Bastion", "Stockpile", "SiegeEngine", "SummoningCircle"]]:
		var invalid_game = Game.new()
		check(invalid_game.start("invalid-keep", ["Gremory", "Gremory"], [selection, Slots.TYPES]).action == "invalid", "game rejects duplicate or missing Keep")
	for example in [[7, "active", 5, 5, false], [7, "active", 10, 0, false], [7, "active", 15, 0, true], [6, "active", 5, 1, false], [0, "active", 5, 0, true], [7, "building", 5, 7, true], [0, "ruined", 5, 0, true], [0, "profaned", 5, 0, true]]:
		var f: Dictionary = fixture("Keep", example[0], example[1], example[2])
		var result: Dictionary = attack(f)
		check(row(result.world, f.screen).attributes.integrity == example[3] and not row(result.world, f.world.players[1].lord_entity_id).attributes.alive == example[4], "Keep reduction, damage and overflow %s" % str(example))
		if example[1] == "active" and example[0] == 7 and example[2] == 10:
			check(result.events.any(func(e): return e.event.type == "SIFTING_THE_RUINS"), "Keep ruination still triggers current Gremory passive")
		check(result.world.players[0].resources.souls == (2 if example[4] else 0) and result.world.data.neutral_tears == (1 if example[4] else 0), "Keep break adds no Siege rewards")
	for example in [[7, "active", 5, 2, 9, 0], [7, "active", 7, 0, 9, 2], [7, "active", 10, 0, 6, 2], [7, "active", 16, 0, 0, 4], [0, "active", 5, 0, 4, 2], [7, "building", 5, 7, 4, 0], [0, "ruined", 5, 0, 4, 0]]:
		var f: Dictionary = fixture("Bastion", example[0], example[1], example[2])
		var result: Dictionary = attack(f)
		check(row(result.world, f.screen).attributes.integrity == example[3] and row(result.world, Slots.castle_id(1, 0)).attributes.integrity == example[4], "Bastion absorbs before target %s" % str(example))
		check(result.world.players[0].resources.souls == example[5] and result.world.data.neutral_tears == (1 if example[5] > 0 else 0), "Bastion/target rewards use normal once-per-round Tear cap")
	var direct: Dictionary = fixture("Bastion", 7, "active", 16, true)
	var hit: Dictionary = attack(direct, true)
	check(row(hit.world, Slots.castle_id(1, 0)).attributes.integrity == 9 and row(hit.world, Slots.castle_id(1, 2)).attributes.integrity == 7, "direct Bastion Siege never spills or uses another Bastion")
	for kind in ["Bastion"]:
		var doubled: Dictionary = fixture(kind, 7, "active", 16, true)
		var after: Dictionary = attack(doubled)
		check(row(after.world, Slots.castle_id(1, 2)).attributes.integrity == 7 and Defenses.screen(after.world, 1, kind).id == Slots.castle_id(1, 2), "duplicate screen takes over next attack, no stacking")
	var layered: Dictionary = fixture("Keep", 7, "active", 10)
	var ids = Ids.new()
	ids.restore(layered.world.entities)
	var hand: Array = layered.world.data.card_zones.hands[1]
	ids.update(hand[0], 1, {"suit": "Penitent", "value": 5})
	ids.update(hand[1], 1, {"suit": "Penitent", "value": 2, "role": "guard", "lane": "Lord", "slot": 0})
	var ward_id: String = hand[0]
	layered.world.data.card_zones.hands[1].erase(hand[1])
	layered.world.entities = ids.snapshot()
	layered.world.data.sigils[1].Lord = "fresh"
	var layers: Dictionary = attack(layered, false, {"action": "Ward", "lane": "Lord", "card_ids": [ward_id]})
	check(row(layers.world, layered.screen).attributes.integrity == 7 and layers.events.any(func(e): return e.event.type == "GUARD_DEFEATED") and layers.world.data.sigils[1].Lord == "", "Ward, guards and Sigil resolve before Keep")
	var bombardment: Dictionary = fixture("Bastion", 7, "active", 5)
	ids.restore(bombardment.world.entities)
	var engine: Dictionary = ids.get_entity(Slots.castle_id(0, 4))
	engine.attributes.integrity = 21
	engine.attributes.status = "standing"
	engine.attributes.construction_state = "active"
	engine.attributes.artillery_target = Slots.castle_id(1, 0)
	ids.update(engine.id, 0, engine.attributes)
	bombardment.world.entities = ids.snapshot()
	var content = Game.Content.new()
	var shot: Dictionary = Structures.fire(bombardment.world, engine.id, "bypass", 1, "test", Callable(content, "react"), [0, 1])
	check(shot.action != "invalid" and row(shot.world, bombardment.screen).attributes.integrity == 7 and row(shot.world, Slots.castle_id(1, 0)).attributes.integrity == 7 and shot.world.players[0].resources.souls == 0, "artillery bypasses Bastion and earns no Siege reward")
	var humbaba: Dictionary = fixture("Keep", 7, "active", 13)
	ids.restore(humbaba.world.entities)
	var actor: Dictionary = ids.get_entity(humbaba.world.players[1].lord_entity_id)
	actor.attributes.lord_id = "Humbaba"
	actor.attributes.erase("threat")
	ids.update(actor.id, 1, actor.attributes)
	humbaba.world.entities = ids.snapshot()
	humbaba.world.players[1].lord_id = "Humbaba"
	var hum_hit: Dictionary = attack(humbaba)
	check(not row(hum_hit.world, actor.id).attributes.alive, "Humbaba defense recalculates after Keep falls before overflow")
	integration()
	print("U13 castle defenses failures: %d" % failures)
	quit(failures)

func integration() -> void:
	var f: Dictionary = fixture("Bastion", 7, "active", 16)
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match()
	if not check(game._owner.start("castle-defenses", f.world, [0, 1]).action != "invalid" and game.to_planning().action != "invalid", "screening match starts"):
		return
	var order: Dictionary = {"action": "Siege", "lane": "Castle", "target_id": Slots.castle_id(1, 0), "card_ids": f.cards}
	if not check(game.submit([{"powers": [], "order": order}, {"powers": [], "order": {}}]).action != "invalid", "screening joint submission"):
		return
	while game._owner.next_hook() != Game.Timeline.COMBAT_RESOLUTION:
		if not check(game.step().action != "invalid", "before screened combat"):
			return
	var replay = Game.new()
	if not check(replay.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", "restore before screened combat"):
		return
	check(game.finish_round().action != "invalid" and replay.finish_round().action != "invalid" and game.snapshot() == replay.snapshot(), "screened combat replays through all Lord and Marching hooks")
