extends SceneTree
const Content = preload("res://Scripts/Sim/U13Kanifous.gd")
const Scenario = preload("res://Scripts/Sim/U13KanifousScenario.gd")
const Session = preload("res://Scripts/Sim/U13LoadoutBoardSession.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, title: String) -> bool:
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + title)
	return value
func run() -> void:
	mechanics()
	interactions()
	mirror_marching()
	var world: Dictionary = Scenario.world()
	if check(Content.new().valid_world(world), "Kanifous world valid"):
		var owner = Content.new().create_combat_match()
		check(owner.start("kanifous-test", world, [0, 1]).action != "invalid", "start")
		for round_number in range(1, 5):
			while owner.next_hook() != Timeline.SUBMISSION_LOCK:
				var result: Dictionary = owner.run_next_hook()
				if not check(result.action != "invalid", "opening " + str(result)):
					quit(1)
					return
			var public: Dictionary = owner.player_view(0, 0)
			check(public.world.wishmaster_objects.any(func(row: Dictionary) -> bool: return row.phase == "smoke" and row.due_round == round_number + 1), "smoke visible before submission")
			check(owner.submit(0, [Scenario.source(0, round_number, {}, 0, "WishWealth")]).action != "invalid", "submit wish")
			owner.submit(1, [])
			while not owner.next_hook().is_empty():
				var hook: String = owner.next_hook()
				var result: Dictionary = owner.run_next_hook()
				if not check(result.action != "invalid", hook + " " + str(result)):
					quit(1)
					return
				var restored = Content.new().create_combat_match()
				if not check(restored.restore(owner.snapshot()).action != "invalid", "restore " + hook):
					quit(1)
					return
			if round_number < 4:
				check(owner.begin_next_round([0, 1]).action != "invalid", "next round")
	print("U13 Kanifous failures: ", failures)
	quit(failures)

func mechanics() -> void:
	var lamp = Content.Lamp
	var marching = Content.Marching
	var content = Content.new()
	var fixture: Dictionary = Scenario.world()
	var ids = Content.Ids.new()
	ids.restore(fixture.entities)
	for suit in marching.SUITS:
		for owner in [0, 1]:
			var single = Content.Ids.new()
			var a: Dictionary = marching.profile(suit, "Lord", owner, 1, 1)
			a.x_fp = 1200
			var unit: Dictionary = single.create("marcher", "claim-" + suit, owner, owner, a).entity
			var seed_value: String = ""
			for i in range(100):
				if lamp.draw(str(i), "lamp:" + unit.id, "WISHMASTER_REJECTION", 10) != 0:
					seed_value = str(i)
					break
			var buffer = preload("res://Scripts/Sim/U13MarchingBuffer.gd").new()
			buffer.restore(single.snapshot())
			var rows: Array = [{"id": "lamp", "phase": "lamp", "target": {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}}}]
			var events: Array = lamp.claim(rows, buffer, buffer.marchers(), seed_value, 1, 0)
			check(rows.is_empty() and events.any(func(e: Dictionary) -> bool: return e.event.type == "WISHMASTER_WISH_GRANTED"), "single claim " + suit + str(owner))
			var after: Dictionary = buffer.get_entity(unit.id).attributes
			match suit:
				"Butcher":
					check(lamp.attack_amount(after) == 6 and lamp.attack_amount(after) == 3, "Blood doubles exactly one attack")
				"Penitent":
					check(after.armor == 5, "Iron adds two Armor")
				"Vulture":
					check(after.ghost_wishes == 2, "Ghost grants two bypasses")
				"Wright":
					var copies: Array = buffer.marchers().filter(func(row: Dictionary) -> bool: return row.id != unit.id)
					check(copies.size() == 1 and copies[0].owner == owner and copies[0].attributes.hp == 5 and copies[0].attributes.armor == 2 and not copies[0].attributes.has("ghost_wishes"), "Mirror fresh base copy / current owner")
			var rejection_seed: String = ""
			for i in range(100):
				if lamp.draw(str(i), "lamp:" + unit.id, "WISHMASTER_REJECTION", 10) == 0:
					rejection_seed = str(i)
					break
			buffer.restore(single.snapshot())
			rows = [{"id": "lamp", "phase": "lamp", "target": {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}}}]
			lamp.claim(rows, buffer, buffer.marchers(), rejection_seed, 1, 0)
			check(rows.is_empty() and buffer.marchers().is_empty(), "rejection destroys claimant and removes lamp")
	check(lamp.contact_time({"x_fp": 900, "y_fp": 300}, {"x_fp": 1500, "y_fp": 300}, {"x_fp": 1200, "y_fp": 300}) >= 0, "swept Lamp contact")
	# All five active Wishes execute against real world/zone state.
	fixture.players[0].resources.souls = 2
	var castle_id: String = ""
	for row in fixture.entities.entities:
		if row.kind == "castle" and row.owner == 0:
			row.attributes.integrity = 7
			row.attributes.status = "standing"
			row.attributes.construction_state = "active"
			castle_id = row.id
	ids.restore(fixture.entities)
	for owner in [0, 1]:
		var a: Dictionary = marching.profile("Butcher", "Lord", owner, 1, 1)
		a.x_fp = 1200
		ids.create("marcher", "wish-test", owner, owner, a)
	fixture.entities = ids.snapshot()
	var context: Dictionary = {"world": fixture, "round": 1, "seed": "wishes", "hook": Timeline.POST_RESOLUTION_DIRECT, "player_order": [0, 1]}
	for power in ["WishPower", "WishLongevity", "WishDeath", "WishWealth"]:
		var target: Dictionary = {"lane": "Lord"} if power == "WishPower" else ({"entity_id": castle_id} if power == "WishLongevity" else ({"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}} if power == "WishDeath" else {}))
		var source: Dictionary = Scenario.source(0, 1, target, 0, power)
		var result: Dictionary = content.resolve({"declaration": source, "fire_hook": Content.rules()[power].fire_hook}, context)
		check(result.action != "invalid" and content.valid_world(result.world), power + " valid result")
		check(result.world.data.kanifous_prices.size() == 1, power + " schedules Price")
	var guard: Dictionary = {}
	for row in fixture.entities.entities:
		if row.kind == "card" and row.owner == 0 and row.attributes.get("role") == "guard":
			guard = row
			break
	if not guard.is_empty():
		var hit: Dictionary = Content.Battle.apply(fixture, {"command_id": "resurrection", "kind": "defeat_guard", "target_id": guard.id}, 1, Timeline.COMBAT_RESOLUTION)
		var reacted: Dictionary = content.react(hit.world, hit.event, "wishes", [0, 1])
		context.world = reacted.world
		var source: Dictionary = Scenario.source(0, 1, {"kind": "guard_zone", "zone": guard.attributes.lane}, 0, "WishResurrection")
		var result: Dictionary = content.resolve({"declaration": source}, context)
		check(result.action != "invalid" and content.valid_world(result.world) and Content._entity(result.world, guard.id).owner == 0, "Resurrection restores defeated guard")
		context.world = fixture
	# Select every weighted Price through keyed RNG, then validate effects.
	var seen: Dictionary = {}
	for i in range(300):
		context.seed = str(i)
		var price: Dictionary = {"id": "price-test", "owner": 0, "created_round": 0, "due_round": 1}
		var result: Dictionary = content._price(fixture, price, context)
		if not check(result.action != "invalid", "Price executes " + str(i)):
			break
		var outcome: String = result.events.back().event.data.outcome
		if not seen.has(outcome):
			check(content.valid_world(result.world), "valid Price " + outcome)
			check(result.world.data.neutral_tears - fixture.data.neutral_tears == (1 if outcome in ["Stone", "Soul", "Ruin", "Wishmaster"] else 0), "Price Tear " + outcome)
			if outcome == "Wishmaster":
				check(result.world.data.breach_lord == "Kanifous", "catastrophic Price enters Void")
		seen[outcome] = true
		if seen.size() == 7:
			break
	check(seen.size() == 7, "all seven Price outcomes exercised")

func interactions() -> void:
	var world: Dictionary = Scenario.world()
	var ids = Content.Ids.new()
	ids.restore(world.entities)
	var a: Dictionary = Content.Marching.profile("Vulture", "Lord", 0, 1, 1)
	a.x_fp = 1200
	a["ghost_wishes"] = 2
	var ghost: Dictionary = ids.create("marcher", "ghost", 0, 0, a).entity
	for i in range(3):
		var b: Dictionary = Content.Marching.profile("Butcher", "Lord", 1, 1, 1)
		b.x_fp = 1200
		b.y_fp = 280 + i * 20
		ids.create("marcher", "enemy", i, 1, b)
	world.entities = ids.snapshot()
	var ctx: Dictionary = {"world": world, "round": 1, "hook": Timeline.MARCHING, "seed": "ghost", "player_order": [0, 1], "combat_orders": [{}, {}], "persistent_effects": []}
	var result: Dictionary = Content.Marching.resolve(ctx, Callable(Content.new(), "react"))
	check(result.action != "invalid", "Ghost actual Marching resolves")
	if result.action != "invalid":
		var bypasses: Array = result.events.filter(func(e: Dictionary) -> bool: return e.event.type == "WISHMASTER_VULTURE_BYPASS")
		check(bypasses.size() == 2, "exactly two enemy contacts bypassed")
		var enemies: Array = []
		for event in bypasses:
			enemies.append(event.event.data.other_id)
		for event in result.events:
			if event.event.type == "MARCHER_CONTACT":
				var pair: Array = event.event.data.units
				if pair.any(func(row: Dictionary) -> bool: return row.id == ghost.id):
					check(not pair.any(func(row: Dictionary) -> bool: return row.id in enemies), "bypassed enemies cannot attack claimant")
	var session = Session.new()
	var choices: Array = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]
	check(session.configure(["Kanifous", "Odradek"], [choices, choices], true).action != "invalid", "mixed Lord setup")
	var wealth: Dictionary = session.declaration("WishWealth", 0, {})
	var power: Dictionary = session.declaration("WishPower", 1, {"lane": "Lord"})
	check(session.choose([wealth, power], {}).action == "invalid", "whole-plan one Wish limit")
	var smoke: Dictionary = session.board_view().world.wishmaster_objects[0].duplicate(true)
	var restored = Session.new()
	check(restored.restore_checkpoint(session.checkpoint()).action != "invalid" and restored.board_view().world.wishmaster_objects[0] == smoke, "smoke checkpoint identical")
	var snapshot: Dictionary = session.checkpoint()
	var content = Content.new()
	var model: Dictionary = snapshot.match.world.duplicate(true)
	var events: Array = Content.Lamp.advance(model, Timeline.MARCHING_START, 2, "lamp-spawn")
	var again: Dictionary = snapshot.match.world.duplicate(true)
	Content.Lamp.advance(again, Timeline.MARCHING_START, 2, "lamp-spawn")
	check(model.data.kanifous_objects == again.data.kanifous_objects, "keyed spawn replay")
	var spawned: Dictionary = model.data.kanifous_objects[0]
	check(spawned.phase == "lamp" and spawned.target.lane == smoke.target.lane and Content.Lamp.distance(spawned.target.field_position, smoke.target.field_position) <= 180 * 180, "spawn within telegraphed lane and radius")
	Content.Lamp.advance(model, Timeline.END_MARCHING_CHECKS, 2, "lamp-spawn")
	check(model.data.kanifous_objects.is_empty(), "unclaimed lamp expires")

func mirror_marching() -> void:
	var world: Dictionary = Scenario.world()
	var ids = Content.Ids.new()
	ids.restore(world.entities)
	var a: Dictionary = Content.Marching.profile("Wright", "Lord", 1, 1, 1)
	a.x_fp = 1200
	var unit: Dictionary = ids.create("marcher", "mirror-test", 0, 1, a).entity
	var seed_value: String = ""
	for i in range(100):
		if Content.Lamp.draw(str(i), "lamp:" + unit.id, "WISHMASTER_REJECTION", 10) != 0:
			seed_value = str(i)
			break
	world.entities = ids.snapshot()
	world.data.kanifous_objects = [{"id": "lamp", "owner": 0, "phase": "lamp", "created_round": 1, "due_round": 2, "target": {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}}}]
	var ctx: Dictionary = {"world": world, "round": 2, "hook": Timeline.MARCHING, "seed": seed_value, "player_order": [0, 1], "combat_orders": [{}, {}], "persistent_effects": []}
	var content = Content.new()
	var result: Dictionary = Content.Marching.resolve(ctx, Callable(content, "react"))
	if check(result.action != "invalid", "Mirror actual Marching resolves"):
		check(content.valid_world(result.world), "Mirror final world valid")
		check(result.world.data.kanifous_objects.is_empty(), "claimed Lamp stays removed after Marching")
		var replay: Dictionary = Content.Marching.resolve(ctx, Callable(content, "react"))
		check(result == replay, "Mirror spawn and complete Marching replay identical")
		var playback = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
		var events: Array = []
		for row in result.events:
			events.append(row.event)
		check(playback.build(events), "Mirror fresh identity supported by playback tape")
