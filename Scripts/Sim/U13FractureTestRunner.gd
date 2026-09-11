extends "res://Scripts/Sim/U13BloodConduitTestRunner.gd"

const Fracture = preload("res://Scripts/Sim/U13Fracture.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")


func base(lord_name: String = "Gremory") -> Dictionary:
	return Economy.initialize(Game.Scenario.loadout_world(["Orias", lord_name], [Slots.TYPES, Slots.TYPES]), "fracture").world


func banish(world: Dictionary, category: String, seed_value: String = "fracture") -> Dictionary:
	var fact: Dictionary = Battle.apply(world, {"command_id": "test-banish", "kind": "banish_lord", "target_id": world.players[1].lord_entity_id, "fracture_target": category}, 1, Game.Timeline.COMBAT_RESOLUTION)
	if fact.action == "invalid":
		return fact
	return Game.Content.new().react(fact.world, fact.event, seed_value, [0, 1])


func guard(world: Dictionary, lane: String, value: int) -> String:
	if world.data.card_zones.hands[1].is_empty():
		Cards.draw(world, 1, "fixture", "guard")
	var id: String = world.data.card_zones.hands[1].pop_back()
	patch(world, id, {"role": "guard", "lane": lane, "slot": 0, "value": value})
	return id


func marcher(world: Dictionary, index: int, hp: int) -> String:
	var ids = Game.Content.Ids.new()
	ids.restore(world.entities)
	var attributes: Dictionary = Marching.profile("Penitent", "Lord" if index % 2 == 0 else "Castle", 1, 0, 1)
	attributes.hp = hp
	attributes.max_hp = hp
	attributes.armor = 9
	var created: Dictionary = ids.create("marcher", "fracture-fixture", index, 1, attributes)
	world.entities = ids.snapshot()
	return created.entity.id


func run() -> void:
	for lord_name in Game.LORDS:
		var world: Dictionary = base(lord_name)
		var result: Dictionary = banish(world, "infrastructure")
		check(result.action != "invalid" and Game.Content.new().valid_world(result.world), lord_name + " Fracture leaves valid state")
		check(result.events.filter(func(e): return e.event.type == "FRACTURE_HIT").size() == Fracture.VALUES[lord_name], lord_name + " printed Fracture count")
	var world: Dictionary = base()
	var subject: String = guard(world, "Castle", 5)
	var immune_hand: Array = world.data.card_zones.hands[1].duplicate()
	var before: Dictionary = world.duplicate(true)
	var hit: Dictionary = banish(world, "subjects")
	check(world == before and row(hit.world, subject).attributes.value == 1, "each point can revisit one Guard but stops at value one")
	check(hit.world.data.card_zones.hands[1] == immune_hand and hit.world.data.card_zones.discard == world.data.card_zones.discard, "Fracture leaves Hand/discard untouched")
	check(hit.events.filter(func(e): return e.event.type == "GUARD_DEFEATED").is_empty(), "Guard erosion creates no defeat reward")
	check(hit == banish(world, "subjects"), "same seed and state repeat exactly")
	var reversed: Dictionary = world.duplicate(true)
	reversed.entities.entities.reverse()
	check(hit == banish(reversed, "subjects"), "registry insertion order cannot change Fracture")
	var applied: Dictionary = Battle.apply(world, {"command_id": "test-banish", "kind": "banish_lord", "target_id": world.players[1].lord_entity_id}, 1, Game.Timeline.COMBAT_RESOLUTION)
	check(Game.Content.new().react(hit.world, applied.event, "fracture", [0, 1]).action == "invalid", "same banishment cannot fracture twice")
	check(Battle.apply(hit.world, {"command_id": "another-banish", "kind": "banish_lord", "target_id": world.players[1].lord_entity_id}, 1).action == "invalid", "already absent Lord cannot be banished again")
	world = base("Valak")
	var ids: Array = []
	for index in range(4):
		ids.append(marcher(world, index, 2))
	hit = banish(world, "subjects")
	check(hit.events.filter(func(e): return e.event.type == "MARCHER_DAMAGED").size() == 3, "one Marcher bucket hits exactly three distinct bodies")
	check(ids.filter(func(id): return row(hit.world, id).attributes.hp == 1).size() == 3 and ids.all(func(id): return row(hit.world, id).attributes.armor == 9), "direct HP bypasses Armor without consuming it")
	world = base("Valak")
	for index in range(3):
		marcher(world, index, 1)
	hit = banish(world, "subjects")
	check(hit.world.entities.entities.filter(func(e): return e.kind == "marcher").is_empty() and hit.events.filter(func(e): return e.event.type == "MARCHER_DEFEATED").size() == 3, "lethal Fracture uses shared Marcher death facts")
	check(hit.world.players[0].resources.souls == 0, "hazard deaths award no combat Souls")
	check(Game.Content.new().valid_world(hit.world), "shared deaths retain a valid world")
	world = base("Valak")
	guard(world, "Lord", 5)
	guard(world, "Castle", 5)
	var transferred: String = marcher(world, 0, 3)
	var registry = Game.Content.Ids.new()
	registry.restore(world.entities)
	var foreign: Dictionary = registry.get_entity(transferred)
	foreign.attributes.direction = 1
	registry.update(transferred, 0, foreign.attributes)
	world.entities = registry.snapshot()
	check(not Fracture.groups(world, 1).has("Marcher"), "transferred Marcher follows current ownership")
	marcher(world, 1, 3)
	var seen: Array = []
	for sample in range(12):
		hit = banish(world, "subjects", "bucket:%d" % sample)
		var hits: Array = hit.events.filter(func(e): return e.event.type == "FRACTURE_HIT")
		if hits[0].event.data.group not in seen:
			seen.append(hits[0].event.data.group)
		check(row(hit.world, transferred).attributes.hp == 3, "former owner's Fracture spares transferred body")
	check(seen.size() == 3, "keyed selection reaches all three live Subject groups")
	world = base()
	for slot in [0, 1, 2]:
		patch(world, Slots.castle_id(1, slot), {"integrity": 7})
	hit = banish(world, "infrastructure")
	check(row(hit.world, Slots.castle_id(1, 0)).attributes.integrity == 5 and row(hit.world, Slots.castle_id(1, 1)).attributes.integrity == 5 and row(hit.world, Slots.castle_id(1, 2)).attributes.integrity == 7, "equal-Integrity hits spread by physical slot")
	check(row(hit.world, Slots.castle_id(1, 0)).attributes.repair_lock_until_round == 2 and row(hit.world, Slots.castle_id(1, 3)).attributes.integrity == 0, "Fracture applies Repair lock and protects blueprints")
	for slot in [0, 1, 2]:
		patch(world, Slots.castle_id(1, slot), {"integrity": 2 if slot == 0 else 0, "status": "standing" if slot == 0 else "defunct"})
	hit = banish(world, "infrastructure")
	check(row(hit.world, Slots.castle_id(1, 0)).attributes.status == "ruined" and hit.world.players[0].resources.souls == 0, "Fracture ruination preserves identity and earns no Siege Souls")
	check(hit.events.filter(func(e): return e.event.type == "CASTLE_DESTROYED").size() == 1, "empty Infrastructure stops remaining points")
	check(Fracture.default_category(base(), 1, 2) == "infrastructure", "default category uses available capacity")
	world = base()
	guard(world, "Lord", 5)
	check(Fracture.default_category(world, 1, 2) == "subjects", "category score ties prefer Subjects")
	integration()
	print("U13 Fracture failures: %d" % failures)
	quit(failures)


func integration() -> void:
	for category in ["subjects", "infrastructure"]:
		var world: Dictionary = base()
		patch(world, Slots.castle_id(1, 0), {"integrity": 0, "status": "ruined"})
		patch(world, world.players[1].lord_entity_id, {"threat": 3})
		guard(world, "Castle", 5)
		var game = Game.new()
		game._owner = Game.Content.new().create_combat_match()
		if not check(game._owner.start("fracture-integration", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", category + " real Hunt fixture starts"):
			continue
		var order: Dictionary = {"action": "Hunt", "lane": "Lord", "card_ids": game.player_view(0).world.hand.duplicate(), "target_id": world.players[1].lord_entity_id, "fracture_target": category}
		var before: Dictionary = game.snapshot()
		var bad: Dictionary = order.duplicate(true)
		bad.fracture_target = "hand"
		check(game._owner.preview_submission(0, [], bad).action == "invalid" and game.snapshot() == before, "invalid category rejects atomically")
		if not check(game.submit([{"powers": [], "order": order}, {"powers": [], "order": {}}]).action != "invalid", "category seals with Hunt"):
			continue
		var saved = Game.new()
		check(saved.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", "sealed category survives JSON")
		check(game.finish_round().action != "invalid" and saved.finish_round().action != "invalid" and game.snapshot() == saved.snapshot(), "Hunt Fracture and full-round replay agree")
		var final: Dictionary = game.snapshot().world
		check(final.data.fracture_events.size() == 1 and not row(final, world.players[1].lord_entity_id).attributes.alive and row(final, world.players[1].lord_entity_id).attributes.threat == 0, "one banishment clears Threat and resolves one Fracture")
		check(saved.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid" and saved.snapshot() == game.snapshot(), "post-Fracture ledger survives exact JSON restoration")
		before = game.snapshot()
		var corrupt: Dictionary = before.duplicate(true)
		corrupt.world.data.fracture_events.values()[0].value = 99
		check(game.restore(corrupt).action == "invalid" and game.snapshot() == before, "forged printed value restore rejects atomically")
		corrupt = before.duplicate(true)
		corrupt.world.data.fracture_events.values()[0].category = "subjects" if category == "infrastructure" else "infrastructure"
		check(game.restore(corrupt).action == "invalid" and game.snapshot() == before, "restored category must match sealed Hunt")
		corrupt = before.duplicate(true)
		corrupt.world.data.fracture_events.clear()
		check(game.restore(corrupt).action == "invalid" and game.snapshot() == before, "resolved banishment cannot lose its Fracture ledger")
