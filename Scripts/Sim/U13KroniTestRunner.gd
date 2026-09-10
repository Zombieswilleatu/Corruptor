extends SceneTree

const Content = preload("res://Scripts/Sim/U13Kroni.gd")
const Scenario = preload("res://Scripts/Sim/U13KroniScenario.gd")
const Session = preload("res://Scripts/Sim/U13LoadoutBoardSession.gd")
const State = preload("res://Scripts/Sim/U13KroniState.gd")
const Actors = preload("res://Scripts/Sim/U13KroniActors.gd")
const Buffer = preload("res://Scripts/Sim/U13MarchingBuffer.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, name_value: String) -> bool:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + name_value)
	return ok

func _run() -> void:
	var world: Dictionary = Scenario.world()
	check(Content.new().valid_world(world), "initial world valid")
	for lord in ["Gremory", "Deimos", "Humbaba", "Kalligan", "Orias", "Odradek", "Kroni"]:
		var session = Session.new()
		var result: Dictionary = session.configure(["Kroni", lord], world.data.castle_loadouts, true)
		if not check(result.action != "invalid", "configure Kroni vs " + lord + str(result)):
			continue
		var restored = Session.new()
		check(restored.restore_checkpoint(session.checkpoint()).action != "invalid", "restore " + lord)
	_hunger()
	_feeding()
	_hunger_growth()
	_meal_limit()
	_placement()
	_actors()
	_match()
	print("U13 Kroni failures: %d" % failures)
	quit(0 if failures == 0 else 1)

func context(world: Dictionary, hook: String, round_number: int = 1) -> Dictionary:
	return {"world": world, "hook": hook, "round": round_number, "seed": "kroni-tests", "player_order": [0, 1], "combat_orders": [{}, {}], "persistent_effects": []}

func _hunger() -> void:
	var world: Dictionary = Scenario.world()
	for amount in [0, 1, 2, 3, 7]:
		State.feed(world, 0, amount - State.hunger(world, 0), 1, "test")
		check(Content.Stats.defense(world, State.lord(world, 0)) == (8 if amount >= 3 else (6 if amount >= 1 else 4)), "Hunger Defense band %d" % amount)
	check(world.players[0].resources.personal_tears == 1, "milestone pays once")
	State.feed(world, 0, -100, 2, "test")
	check(State.hunger(world, 0) == 0, "Hunger never negative")
	State.feed(world, 0, 3, 3, "test")
	check(world.players[0].resources.personal_tears == 1, "recrossing milestone cannot pay again")
	var invalid: Dictionary = world.duplicate(true)
	invalid.entities.entities.filter(func(e: Dictionary) -> bool: return e.kind == "lord" and e.owner == 0)[0].attributes.hunger_milestone = false
	check(not Content.new().valid_world(invalid), "reject impossible milestone ledger")
	var result: Dictionary = Content.new().on_hook(context(world, Timeline.COMBAT_RESOLUTION))
	if check(result.action != "invalid", "Pass resolves"):
		check(State.hunger(result.world, 0) == 2, "Pass loses Hunger before combat")
	var ward_context: Dictionary = context(world, Timeline.COMBAT_RESOLUTION)
	ward_context.combat_orders[0] = {"action": "Ward", "lane": "Lord", "card_ids": []}
	result = Content.new().on_hook(ward_context)
	if check(result.action != "invalid", "Ward resolves"):
		check(State.hunger(result.world, 0) == 2, "Ward loses one Hunger")

func guards(world: Dictionary, pid: int) -> Array:
	var rows: Array = world.entities.entities.filter(func(e: Dictionary) -> bool: return e.kind == "card" and e.owner == pid and e.attributes.get("role") == "guard")
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.attributes.value < b.attributes.value if a.attributes.value != b.attributes.value else a.id < b.id)
	return rows

func _feeding() -> void:
	var world: Dictionary = Scenario.world()
	var before: Dictionary = world.duplicate(true)
	var own: Array = guards(world, 0)
	var enemy: Array = guards(world, 1)
	if not check(not own.is_empty() and not enemy.is_empty(), "feeding fixtures include Guards"):
		return
	var result: Dictionary = Content.new().on_hook(context(world, Timeline.ROUND_START_SCHEDULED))
	if check(result.action != "invalid", "automatic feeding resolves"):
		check(State.guard(result.world, own[0].id).is_empty(), "absent Consume devours lowest friendly Guard")
		check(guards(result.world, 0).size() == own.size() - 1 and State.hunger(result.world, 0) == 0, "friendly meal neither feeds nor consumes extra Guards")
		check(Content.new().valid_world(result.world), "Devoured card world remains valid")
	check(world == before, "feeding leaves caller world untouched")
	var source: Dictionary = Scenario.source(0, 1, {"entity_id": enemy[0].id}, 0, Content.CONSUME)
	check(Content.new().validate(source, world, "declaration").legal, "Consume enemy Guard legal")
	var bad: Dictionary = source.duplicate(true)
	bad.target.entity_id = own[0].id
	check(not Content.new().validate(bad, world, "declaration").legal, "Consume rejects friendly Guard")
	var pending = preload("res://Scripts/Sim/U13PendingEffects.gd").new()
	var record: Dictionary = pending.schedule(source).effect
	result = Content.new().resolve(record, context(world, Timeline.ROUND_START_SCHEDULED, 2))
	if check(result.action == "resolved", "prepared Consume fires"):
		check(State.guard(result.world, enemy[0].id).is_empty() and State.hunger(result.world, 0) == 1, "Consume devours specific target and gains Hunger")
		var fed: Dictionary = Content.new().on_hook(context(result.world, Timeline.ROUND_START_SCHEDULED, 2))
		check(fed.action != "invalid" and guards(fed.world, 0).size() == own.size(), "successful Consume suppresses Cannibal Hunger")
		check(not Content.new().validate(source, result.world, "firing").legal, "lost target never retargets")
	var empty: Dictionary = world.duplicate(true)
	for victim in own:
		State.devour_guard(empty, victim, 0, 0, "fixture")
	State.feed(empty, 0, 2, 0, "fixture")
	result = Content.new().on_hook(context(empty, Timeline.ROUND_START_SCHEDULED))
	check(result.action != "invalid" and State.hunger(result.world, 0) == 1, "no friendly Guard costs one Hunger")

func add_unit(world: Dictionary, index: int, pid: int, x: int, y: int, lane: String = "Lord") -> String:
	var ids = Content.Ids.new()
	ids.restore(world.entities)
	var a: Dictionary = Marching.profile("Butcher", lane, pid, 0, 1)
	a.x_fp = x
	a.y_fp = y
	a.armor = 500
	var row: Dictionary = ids.create("marcher", "kroni-test", index, pid, a)
	world.entities = ids.snapshot()
	return row.entity.id

func _placement() -> void:
	var start: Dictionary = {"lane": "Castle", "field_position": {"x_fp": 650, "y_fp": 450}}
	var world: Dictionary = Scenario.world()
	var source: Dictionary = Scenario.source(0, 1, start)
	check(Content.new().validate(source, world, "declaration").legal, "chosen field start is legal")
	for target in [{}, {"lane": "Lord", "field_position": {"x_fp": -1, "y_fp": 20}}, {"lane": "Castle", "field_position": {"x_fp": 20, "y_fp": 601}}, {"lane": "Lord", "field_position": {"x_fp": 20.5, "y_fp": 20}}, {"lane": "Lord", "field_position": {"x_fp": 20, "y_fp": 20}, "angle": 10}]:
		var bad: Dictionary = source.duplicate(true)
		bad.target = target
		check(not Content.new().validate(bad, world, "declaration").legal, "reject missing/invalid start and player-selected angle " + str(target))
	var pending = preload("res://Scripts/Sim/U13PendingEffects.gd").new()
	var record: Dictionary = pending.schedule(source).effect
	var result: Dictionary = Content.new().resolve(record, context(world, Timeline.POST_RESOLUTION_SPECIAL_ACTORS))
	check(result.action == "resolved" and result.world.data.kroni_actors[0].x_fp == 650 and result.world.data.kroni_actors[0].y_fp == 1050, "authoritative launch uses chosen Castle position")
	check(result == Content.new().resolve(record, context(JSON.parse_string(JSON.stringify(world)), Timeline.POST_RESOLUTION_SPECIAL_ACTORS)), "launch roll survives exact JSON replay")
	var angles: Dictionary = {}
	var round_angles: Dictionary = {}
	for index in range(24):
		for pid in [0, 1]:
			var actor: Dictionary = Actors.create("placed", pid, 1, 0, false, "seed-%d" % index, start)
			angles[actor.vy_fp] = true
			check(Actors.valid([actor]) and actor.x_fp == 650 and actor.y_fp == 1050 and actor.vx_fp * (1 if pid == 0 else -1) > 0, "placed actor valid and enemy-facing %d/%d" % [index, pid])
			var buffer = Buffer.new()
			buffer.restore(world.entities)
			var previous: int = actor.x_fp
			var forward_only: bool = true
			for tick in range(200):
				Actors.step([actor], buffer, 1, tick)
				forward_only = forward_only and (actor.x_fp - previous) * (1 if pid == 0 else -1) >= 0
				previous = actor.x_fp
			check(forward_only and not actor.active and actor.x_fp == (2400 if pid == 0 else 0), "random route always reaches enemy boundary %d/%d" % [index, pid])
		var next: Dictionary = Actors.create("placed", 0, index + 1, 0, false, "same-match", start)
		round_angles[next.vy_fp] = true
	check(angles.size() > 4 and angles.keys().any(func(v: int) -> bool: return v < 0) and angles.keys().any(func(v: int) -> bool: return v > 0), "same placement produces varied launch angles in both lateral directions")
	check(round_angles.size() > 4, "later activations in same match roll fresh directions")

func _actors() -> void:
	check(Actors.touches(0, 0, 100, 0, 50, 10, 10), "swept collision includes boundary")
	check(not Actors.touches(0, 0, 100, 0, 50, 11, 10), "swept collision excludes outside")
	check(Actors.touches(0, 0, 100, 0, 50, 0, 1), "swept collision catches intervening body")
	check([Actors.radius(0), Actors.radius(1), Actors.radius(2), Actors.radius(3)] == [220, 242, 264, 297], "Hunger changes real footprint")
	var world: Dictionary = Scenario.world()
	for index in range(8):
		add_unit(world, index, index % 2, 16 if index < 4 else 960, 322 if index < 4 else 180, "Lord" if index < 4 else "Castle")
	var outside: String = add_unit(world, 20, 0, 2399, 0)
	world.data.kroni_actors = [Actors.create("ravenous-test", 0, 1, 0)]
	# Fixed path fixture tests consumption independently of launch randomness.
	world.data.kroni_actors[0].vy_fp = 22
	var result: Dictionary = Content.new().on_hook(context(world, Timeline.MARCHING))
	if not check(result.action == "resolved", "Ravenous integrated Marching resolves"):
		print(result)
		return
	var actor: Dictionary = result.world.data.kroni_actors[0]
	check(actor.consumed >= 6 and actor.rewarded and not actor.active and actor.x_fp == 2400, "friendly and enemy Devour, then stop at far boundary")
	check(result.world.players[0].resources.souls == world.players[0].resources.souls + 1 and result.world.data.neutral_tears == world.data.neutral_tears + 1 and State.hunger(result.world, 0) == 1, "6-plus pays exactly one full reward")
	check(result.world.entities.entities.any(func(e: Dictionary) -> bool: return e.id == outside), "off-path Marcher survives")
	check(Content.new().valid_world(result.world), "post-Ravenous world validates")
	var replay: Dictionary = Content.new().on_hook(context(JSON.parse_string(JSON.stringify(world)), Timeline.MARCHING))
	check(replay == result, "Ravenous JSON replay exact")
	check(result.events.any(func(e: Dictionary) -> bool: return e.event.type == "KRONI_WALL_BOUNCE"), "wall bounce recorded")
	var buffer = Buffer.new()
	buffer.restore(world.entities)
	var b: Dictionary = Actors.create("breach", -1, 1, 0, true, "seed")
	check(b == Actors.create("breach", -1, 1, 0, true, "seed"), "Breach point and direction keyed deterministic")
	b.x_fp = 16
	b.y_fp = 322
	world.data.kroni_actors = [b]
	result = Content.new().on_hook(context(world, Timeline.MARCHING))
	check(result.action != "invalid" and result.world.data.kroni_actors[0].consumed > 0, "Breach can Devour both sides")
	check(result.world.players[0].resources == world.players[0].resources and result.world.data.neutral_tears == world.data.neutral_tears and State.hunger(result.world, 0) == 0, "Breach gives no Hunger Souls Tears or Ravenous reward")
	check(result.world.data.kroni_actors[0].age == Actors.BREACH_TICKS, "Breach lifetime is fixed")
	var reverse: Array = [Actors.create("reverse", 1, 1, 0)]
	for tick in range(200):
		Actors.step(reverse, buffer, 1, tick)
	check(reverse[0].x_fp == 0 and not reverse[0].active, "opponent traverses toward human boundary")

func _advance(owner, target: String) -> bool:
	for index in range(25):
		if owner.next_hook() == target:
			return true
		var hook: String = owner.next_hook()
		if hook.is_empty():
			return target.is_empty()
		var result: Dictionary = owner.run_next_hook()
		if not check(result.action != "invalid", "hook " + hook + " " + str(result.get("reason", ""))):
			return false
		if hook not in [Timeline.ROUND_START_SCHEDULED, Timeline.SUBMISSION_LOCK, Timeline.POST_RESOLUTION_SPECIAL_ACTORS, Timeline.MARCHING_START, Timeline.MARCHING, Timeline.AFTERMATH]:
			continue
		var restored = Content.new().create_combat_match()
		var loaded: Dictionary = restored.restore(JSON.parse_string(JSON.stringify(owner.snapshot())))
		if not check(loaded.action != "invalid", "restore after " + hook + " " + str(loaded.get("reason", ""))):
			return false
	return false

func _match() -> void:
	var owner = Content.new().create_combat_match()
	var world: Dictionary = Scenario.world()
	check(owner.start("kroni-full-round", world, [0, 1]).action != "invalid", "full match starts")
	for round_number in range(1, 5):
		if not _advance(owner, Timeline.SUBMISSION_LOCK):
			return
		if round_number == 2:
			check(State.hunger(owner.snapshot().world, 0) == 1, "Consume fires before second-round planning")
		var powers: Array = []
		if round_number in [1, 4]:
			powers.append(Scenario.source(0, round_number))
		else:
			check(owner.preview_submission(0, [Scenario.source(0, round_number)], {}).action == "invalid", "two-round Ravenous cooldown blocks round %d" % round_number)
		if round_number == 1:
			var victim: Dictionary = guards(owner.snapshot().world, 1)[0]
			powers.append(Scenario.source(0, 1, {"entity_id": victim.id}, 1, Content.CONSUME))
		check(owner.preview_submission(0, powers, {}).action != "invalid", "Kroni powers can queue together")
		check(Scenario.plan(owner, 0).action != "invalid", "random legal Kroni plan")
		check(owner.submit(0, powers, {}).action != "invalid", "submit Kroni")
		check(owner.submit(1, [], {}).action != "invalid", "submit opponent")
		if not _advance(owner, ""):
			return
		if round_number < 4:
			check(owner.begin_next_round([0, 1]).action != "invalid", "next round")

func _hunger_growth() -> void:
	var world: Dictionary = Scenario.world()
	var content = Content.new()
	for round_number in [1, 2, 3]:
		var enemy: Array = guards(world, 1)
		if enemy.is_empty():
			var replacement: Dictionary = preload("res://Scripts/Sim/U13DebugActions.gd").apply(world, "guard", 1, "Castle", round_number, "hunger-growth", content)
			world = replacement.world
			enemy = guards(world, 1)
		if not check(not enemy.is_empty(), "enemy meal available for Hunger growth"):
			return
		var source: Dictionary = Scenario.source(0, round_number - 1, {"entity_id": enemy[0].id}, 0, Content.CONSUME)
		var record: Dictionary = {"declaration": source, "fire_hook": Timeline.ROUND_START_SCHEDULED}
		var result: Dictionary = content.resolve(record, context(world, Timeline.ROUND_START_SCHEDULED, round_number))
		if not check(result.action == "resolved", "successive Consume resolves"):
			return
		world = result.world
		result = content.on_hook(context(world, Timeline.ROUND_START_SCHEDULED, round_number))
		if not check(result.action == "resolved", "successful Consume survives Cannibal check"):
			return
		world = result.world
		var attack: Dictionary = context(world, Timeline.COMBAT_RESOLUTION, round_number)
		attack.combat_orders[0] = {"action": "Hunt", "lane": "Lord", "target_id": State.lord(world, 1).id, "card_ids": []}
		result = content.on_hook(attack)
		if not check(result.action == "resolved", "Hunt round preserves fed Hunger"):
			print(result)
			return
		world = result.world
		check(State.hunger(world, 0) == round_number, "Hunger accumulates to %d without Ward/Pass" % round_number)
	check(world.players[0].resources.personal_tears == 1, "successive meals award Hunger-3 milestone once")


func _meal_limit() -> void:
	var world: Dictionary = Scenario.world()
	for i in range(12):
		add_unit(world, i, i % 2, 16, 322)
	var buffer = Buffer.new()
	buffer.restore(world.entities)
	var actor: Dictionary = Actors.create("meal-limit", 0, 1, 0)
	actor.vy_fp = 22
	var events: Array = Actors.step([actor], buffer, 1, 0)
	check(actor.consumed == 3 and buffer.marchers().size() == 9, "dense pile consumes only three on first contact")
	Actors.step([actor], buffer, 1, 1)
	check(actor.consumed == 3 and actor.x_fp == 32, "next tick moves on instead of eating the same pile again")
	var restored: Dictionary = Content.Data.copy_data(JSON.parse_string(JSON.stringify(actor)))
	check(Actors.valid([restored]) and restored.meal_count == 3, "feeding-spot quota persists through JSON")
	var next_world: Dictionary = Scenario.world()
	for i in range(8):
		add_unit(next_world, i, i % 2, 960, 180, "Castle")
	buffer.restore(next_world.entities)
	for tick in range(2, 65):
		Actors.step([actor], buffer, 1, tick)
	check(actor.consumed == 6, "another feeding spot can supply three more")
