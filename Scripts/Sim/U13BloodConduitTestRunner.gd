extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

const Conduit = preload("res://Scripts/Sim/U13BloodConduit.gd")
const Candidates = preload("res://Scripts/Sim/U13OriasCandidates.gd")
const Return = preload("res://Scripts/Sim/U13Resummoning.gd")

func fixture(lord_name: String = "Orias", integrity: int = 7, copies: int = 1) -> Dictionary:
	var choices: Array = Slots.TYPES.duplicate()
	if copies == 2:
		choices[4] = "SummoningCircle"
	var world: Dictionary = Economy.initialize(Game.Scenario.loadout_world([lord_name, "Gremory"], [choices, Slots.TYPES]), "conduit").world
	var ids = Game.Content.Ids.new()
	ids.restore(world.entities)
	for slot in ([2, 4] if copies == 2 else [2]):
		var circle: Dictionary = ids.get_entity(Slots.castle_id(0, slot))
		circle.attributes.integrity = integrity
		circle.attributes.construction_state = "active"
		circle.attributes.status = "standing"
		ids.update(circle.id, 0, circle.attributes)
	world.entities = ids.snapshot()
	return world

func patch(world: Dictionary, id: String, changes: Dictionary) -> void:
	var ids = Game.Content.Ids.new()
	ids.restore(world.entities)
	var row: Dictionary = ids.get_entity(id)
	row.attributes.merge(changes, true)
	ids.update(id, row.owner, row.attributes)
	world.entities = ids.snapshot()

func row(world: Dictionary, id: String) -> Dictionary:
	return world.entities.entities.filter(func(e): return e.id == id)[0]

func run() -> void:
	for before in [0, 1, 2, 3, 4]:
		var world: Dictionary = fixture()
		var actor: String = world.players[0].lord_entity_id
		patch(world, actor, {"threat": before})
		var hit: Dictionary = Conduit.gain(world, actor, 1, 2)
		var prevented: bool = before in [1, 2, 3]
		check(row(hit.world, actor).attributes.threat == before + (0 if prevented else 1) and row(hit.world, Slots.castle_id(0, 2)).attributes.integrity == (4 if prevented else 7), "actual DEF breakpoint %d" % before)
		check(Game.Content.new().valid_world(hit.world), "Conduit leaves valid Castle and Lord state")
		if prevented:
			check(row(hit.world, Slots.castle_id(0, 2)).attributes.repair_lock_until_round == 3 and hit.events.size() == 1, "exertion sets vulnerability lock and emits one event")
	for lord_name in ["Humbaba", "Kroni"]:
		var world: Dictionary = fixture(lord_name)
		var actor: String = world.players[0].lord_entity_id
		if lord_name != "Humbaba":
			patch(world, actor, {"threat": 1})
		var hit: Dictionary = Conduit.gain(world, actor, 1, 1)
		check(hit.events.is_empty() and row(hit.world, Slots.castle_id(0, 2)).attributes.integrity == 7, lord_name + " does not exert for non-Threat defense")
	var doubled: Dictionary = fixture("Orias", 7, 2)
	var actor: String = doubled.players[0].lord_entity_id
	patch(doubled, actor, {"threat": 1})
	Conduit.gain(doubled, actor, 1, 1)
	check(row(doubled, Slots.castle_id(0, 4)).attributes.integrity == 7, "duplicate Circles do not stack")
	Conduit.gain(doubled, actor, 1, 1)
	check(row(doubled, Slots.castle_id(0, 4)).attributes.integrity == 4 and row(doubled, actor).attributes.threat == 1, "next operational Circle handles next gain")
	for state in ["building", "ruined", "profaned", "defunct"]:
		var world: Dictionary = fixture()
		patch(world, world.players[0].lord_entity_id, {"threat": 1})
		patch(world, Slots.castle_id(0, 2), {"construction_state": "building"} if state == "building" else {"status": state})
		check(Conduit.gain(world, world.players[0].lord_entity_id, 1, 1).events.is_empty(), state + " Circle does not exert")
	snare_replay()
	marked_return()
	accelerate()
	print("U13 Blood Conduit failures: %d" % failures)
	quit(failures)

func snare_replay() -> void:
	var world: Dictionary = fixture()
	patch(world, world.players[0].lord_entity_id, {"threat": 1})
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match()
	if not check(game._owner.start("conduit", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "Conduit game reaches planning"):
		return
	var before: Dictionary = game.snapshot()
	var source: Dictionary = Candidates.snare_source(0, 1)
	check(game._owner.preview_submission(0, [source], {}).action != "invalid" and game.snapshot() == before, "preview does not exert Circle")
	if not check(game.submit([{"powers": [source], "order": {}}, {"powers": [], "order": {}}]).action != "invalid" and game.step().action != "invalid", "Snare commits through Conduit"):
		return
	var locked: Dictionary = game.snapshot()
	var forged: Dictionary = locked.duplicate(true)
	patch(forged.world, Slots.castle_id(0, 2), {"integrity": 7})
	check(game.restore(forged).action == "invalid" and game.snapshot() == locked, "cannot restore prevented Threat without Circle payment")
	var saved = Game.new()
	check(saved.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", "Conduit-reduced Snare payment restores after lock")
	check(game.finish_round().action != "invalid" and saved.finish_round().action != "invalid" and game.snapshot() == saved.snapshot(), "Snare round replays with Conduit")

func marked_return() -> void:
	for integrity in [7, 10]:
		var world: Dictionary = fixture("Gremory", integrity)
		patch(world, world.players[0].lord_entity_id, {"alive": false})
		world.data.orias_marks[0] = {"round": 0, "event_id": "directed-mark"}
		var card: String = world.data.card_zones.hands[0][0]
		patch(world, card, {"value": 2})
		var quote: Dictionary = Return.quote(world, 0, [card])
		world.data.summon_orders = [{"round": 1, "choice": {"card_ids": [card]}, "quote": quote}, {"round": 1, "choice": {}, "quote": {}}]
		var returned: Dictionary = Return.resolve({"world": world, "round": 1, "hook": Game.Timeline.DEVELOPMENT, "player_order": [0, 1]})
		check(returned.action != "invalid" and row(returned.world, world.players[0].lord_entity_id).attributes.threat == quote.return_threat and row(returned.world, Slots.castle_id(0, 2)).attributes.integrity == 4, "marked return resolution agrees with quote after both exertions")
		check(quote.shortfall == 1 and quote.return_threat == (1 if integrity == 10 else 2), "Blood Offering resolves before marked return Conduit %d" % integrity)

func accelerate() -> void:
	var world: Dictionary = fixture()
	var victim: String = world.players[1].lord_entity_id
	patch(world, victim, {"threat": 1})
	patch(world, Slots.castle_id(1, 2), {"integrity": 7, "status": "standing", "construction_state": "active"})
	var guard: String = world.data.card_zones.hands[1][0]
	world.data.card_zones.hands[1].erase(guard)
	patch(world, guard, {"role": "guard", "lane": "Lord", "slot": 0, "suit": "Butcher", "value": 1})
	var cards: Array = world.data.card_zones.hands[0].slice(0, 3)
	for card in cards:
		patch(world, card, {"suit": "Butcher", "value": 1})
	var content = Game.Content.new()
	var result: Dictionary = preload("res://Scripts/Sim/U13Combat.gd")._hunt(world, {"round": 1, "seed": "conduit", "combat_orders": [{}, {}], "player_order": [0, 1], "hook": Game.Timeline.COMBAT_RESOLUTION}, 0, {"action": "Hunt", "lane": "Lord", "target_id": victim, "card_ids": cards}, Callable(content, "react"))
	check(result.action != "invalid" and result.events.any(func(e): return e.event.type == "ACCELERATE") and result.events.any(func(e): return e.event.type == "BLOOD_CONDUIT") and row(result.world, Slots.castle_id(1, 2)).attributes.integrity == 4, "credited Orias Hunt triggers defender Conduit")
