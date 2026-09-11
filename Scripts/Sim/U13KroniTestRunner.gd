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
var checks: int = 0
var verbose_checks: bool = "--verbose-checks" in OS.get_cmdline_user_args()
var profile_enabled: bool = "--profile" in OS.get_cmdline_user_args()

func _timing(label: String, started: int) -> void:
	if profile_enabled:
		print("KRONI_PROFILE ", label, " ms=", (Time.get_ticks_usec() - started) / 1000.0)
	elif not label.contains("/"):
		print("Kroni section complete: ", label)

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, name_value: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
	if not ok or verbose_checks:
		print(("PASS " if ok else "FAIL ") + name_value)
	return ok

func _run() -> void:
	if profile_enabled:
		print("KRONI_PROFILE runtime=", Engine.get_version_info().string, " os=", OS.get_name(), " cpu=", OS.get_processor_name())
	var suite_started: int = Time.get_ticks_usec()
	var section_started: int = suite_started
	var world: Dictionary = Scenario.world()
	check(Content.new().valid_world(world), "initial world valid")
	for lord in ["Gremory", "Deimos", "Humbaba", "Kalligan", "Orias", "Odradek", "Kroni"]:
		var session = Session.new()
		var result: Dictionary = session.configure(["Kroni", lord], world.data.castle_loadouts, true)
		if not check(result.action != "invalid", "configure Kroni vs " + lord + str(result)):
			continue
		var restored = Session.new()
		check(restored.restore_checkpoint(session.checkpoint()).action != "invalid", "restore " + lord)
	_timing("configure_restore", section_started)
	section_started = Time.get_ticks_usec()
	_hunger()
	_timing("hunger", section_started)
	section_started = Time.get_ticks_usec()
	_feeding()
	_timing("feeding", section_started)
	section_started = Time.get_ticks_usec()
	_hunger_growth()
	_timing("hunger_growth", section_started)
	section_started = Time.get_ticks_usec()
	_attack_commitment()
	_timing("attack_commitment", section_started)
	section_started = Time.get_ticks_usec()
	_flee()
	_timing("flee", section_started)
	section_started = Time.get_ticks_usec()
	_biased_launch()
	_timing("biased_launch", section_started)
	section_started = Time.get_ticks_usec()
	_angle_gradient()
	_timing("angle_gradient", section_started)
	section_started = Time.get_ticks_usec()
	_placement()
	_timing("placement", section_started)
	section_started = Time.get_ticks_usec()
	_actors()
	_timing("actors", section_started)
	section_started = Time.get_ticks_usec()
	_match()
	_timing("match", section_started)
	_timing("suite", suite_started)
	print("Kroni assertions: %d passed / %d checked" % [checks - failures, checks])
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
	var start: Dictionary = {"lane": "Castle", "field_position": {"x_fp": 0, "y_fp": 450}}
	var world: Dictionary = Scenario.world()
	var source: Dictionary = Scenario.source(0, 1, start)
	check(Content.new().validate(source, world, "declaration").legal, "chosen field start is legal")
	for target in [{"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}}, {"lane": "Lord", "field_position": {"x_fp": 2400, "y_fp": 300}}, {}, {"lane": "Lord", "field_position": {"x_fp": -1, "y_fp": 20}}, {"lane": "Castle", "field_position": {"x_fp": 20, "y_fp": 601}}, {"lane": "Lord", "field_position": {"x_fp": 20.5, "y_fp": 20}}, {"lane": "Lord", "field_position": {"x_fp": 20, "y_fp": 20}, "angle": 10}]:
		var bad: Dictionary = source.duplicate(true)
		bad.target = target
		check(not Content.new().validate(bad, world, "declaration").legal, "reject missing/invalid start and player-selected angle " + str(target))
	var enemy_start: Dictionary = {"lane": "Castle", "field_position": {"x_fp": 2400, "y_fp": 450}}
	check(Content.new().validate(Scenario.source(1, 1, enemy_start), Scenario.world("Kroni"), "declaration").legal, "enemy may start at top edge")
	check(not Content.new().validate(Scenario.source(1, 1, start), Scenario.world("Kroni"), "declaration").legal, "enemy cannot start at player edge")
	var pending = preload("res://Scripts/Sim/U13PendingEffects.gd").new()
	var record: Dictionary = pending.schedule(source).effect
	var result: Dictionary = Content.new().resolve(record, context(world, Timeline.POST_RESOLUTION_SPECIAL_ACTORS))
	check(result.action == "resolved" and result.world.data.kroni_actors[0].x_fp == 0 and result.world.data.kroni_actors[0].y_fp == 1050, "authoritative launch uses chosen Castle position")
	check(result == Content.new().resolve(record, context(JSON.parse_string(JSON.stringify(world)), Timeline.POST_RESOLUTION_SPECIAL_ACTORS)), "launch roll survives exact JSON replay")
	var angles: Dictionary = {}
	var round_angles: Dictionary = {}
	for index in range(24):
		for pid in [0, 1]:
			var actor: Dictionary = Actors.create("placed", pid, 1, 0, false, "seed-%d" % index, start)
			angles[actor.vy_fp] = true
			check(Actors.valid([actor]) and actor.x_fp == (0 if pid == 0 else 2400) and actor.y_fp == 1050 and actor.vx_fp * (1 if pid == 0 else -1) > 0, "placed actor valid and enemy-facing %d/%d" % [index, pid])
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
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = owner.run_next_hook()
		_timing("hook/" + hook, started)
		if not check(result.action != "invalid", "hook " + hook + " " + str(result.get("reason", ""))):
			return false
		if hook not in [Timeline.ROUND_START_SCHEDULED, Timeline.SUBMISSION_LOCK, Timeline.POST_RESOLUTION_SPECIAL_ACTORS, Timeline.MARCHING_START, Timeline.MARCHING, Timeline.AFTERMATH]:
			continue
		started = Time.get_ticks_usec()
		var restored = Content.new().create_combat_match()
		_timing("restore_create/" + hook, started)
		var stage_started: int = Time.get_ticks_usec()
		var raw: Dictionary = owner.snapshot()
		_timing("snapshot/" + hook, stage_started)
		stage_started = Time.get_ticks_usec()
		var decoded: Dictionary = JSON.parse_string(JSON.stringify(raw))
		_timing("json/" + hook, stage_started)
		stage_started = Time.get_ticks_usec()
		var loaded: Dictionary = restored.restore(decoded)
		_timing("restore_validate/" + hook, stage_started)
		_timing("restore/" + hook, started)
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
		var plan_started: int = Time.get_ticks_usec()
		check(Scenario.plan(owner, 0).action != "invalid", "random legal Kroni plan")
		_timing("plan/round_%d" % round_number, plan_started)
		check(owner.submit(0, powers, {}).action != "invalid", "submit Kroni")
		check(owner.submit(1, [], {}).action != "invalid", "submit opponent")
		if not _advance(owner, ""):
			return
		if round_number < 4:
			check(owner.begin_next_round([0, 1]).action != "invalid", "next round")

	if profile_enabled:
		print("KRONI_PROFILE final_snapshot_sha256=", JSON.stringify(owner.snapshot(), "", true).sha256_text())

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
		attack.combat_orders[0] = {"action": "Hunt", "lane": "Lord", "target_id": State.lord(world, 1).id, "card_ids": world.data.card_zones.hands[0].slice(0, 1)}
		result = content.on_hook(attack)
		if not check(result.action == "resolved", "Hunt round preserves fed Hunger"):
			print(result)
			return
		world = result.world
		check(State.hunger(world, 0) == round_number, "Hunger accumulates to %d without Ward/Pass" % round_number)
	check(world.players[0].resources.personal_tears == 1, "successive meals award Hunger-3 milestone once")


func _flee() -> void:
	var world: Dictionary = Scenario.world()
	for i in range(12):
		add_unit(world, i, i % 2, 300 if i < 6 else 100, 320)
	var buffer = Buffer.new()
	buffer.restore(world.entities)
	var actor: Dictionary = Actors.create("flee-test", 0, 1, 0)
	actor.x_fp = 250
	actor.y_fp = 300
	actor.vy_fp = 8
	var events: Array = Actors.step([actor], buffer, 1, 0)
	check(actor.consumed == 1 and buffer.marchers().size() == 11, "one victim per chomp lets survivors flee")
	var changes: Array = events.filter(func(e): return e.event.type == "MARCHER_DEVOURED")[0].event.data.flee
	check(changes.size() == 11, "all nearby survivors on both sides flee")
	for change in changes:
		var a: Dictionary = change.before.attributes
		var b: Dictionary = change.after.attributes
		var old_distance: float = Vector2(a.x_fp - actor.x_fp, a.y_fp - actor.y_fp).length()
		var new_distance: float = Vector2(b.x_fp - actor.x_fp, b.y_fp - actor.y_fp).length()
		check(new_distance > old_distance and absf(Vector2(b.x_fp - a.x_fp, b.y_fp - a.y_fp).length() - 22.0) < 1.0, "radial escape covers 30 percent speed during 550ms chomp")
	var replay_buffer = Buffer.new()
	replay_buffer.restore(world.entities)
	var replay_actor: Dictionary = Actors.create("flee-test", 0, 1, 0)
	replay_actor.x_fp = 250
	replay_actor.y_fp = 300
	replay_actor.vy_fp = 8
	check(events == Actors.step([replay_actor], replay_buffer, 1, 0), "flee result and tape deterministic")
	for tick in range(1, 30):
		Actors.step([actor], buffer, 1, tick)
	check(actor.consumed > 3 and actor.consumed < 12, "escape replaces the hard cap and leaves survivors")
	var boundary_world: Dictionary = Scenario.world()
	add_unit(boundary_world, 30, 0, 2400, 599)
	buffer.restore(boundary_world.entities)
	actor.x_fp = 2380
	actor.y_fp = 590
	actor.fleeing = {}
	actor.nearby = []
	Actors.notice(actor, buffer)
	var fled: Array = Actors.flee(actor, buffer)
	check(fled.size() == 1 and fled[0].after.attributes.lane == "Lord" and fled[0].after.attributes.y_fp == 600 and fled[0].after.attributes.x_fp == 2400, "escape stays in original lane and clamps boundaries")


	var castle_world: Dictionary = Scenario.world()
	add_unit(castle_world, 31, 1, 1200, 1)
	var castle_unit: Dictionary = castle_world.entities.entities.filter(func(u): return u.kind == "marcher")[0]
	castle_unit.attributes.lane = "Castle"
	buffer.restore(castle_world.entities)
	actor.fleeing = {}
	actor.nearby = []
	actor.x_fp = 1200
	actor.y_fp = 620
	Actors.notice(actor, buffer)
	var castle_fled: Array = Actors.flee(actor, buffer)
	check(castle_fled.size() == 1 and castle_fled[0].after.attributes.lane == "Castle" and castle_fled[0].after.attributes.y_fp == 0, "Castle fleers cannot cross into Lord lane")
	var approach_world: Dictionary = Scenario.world()
	add_unit(approach_world, 40, 1, 600, 300)
	buffer.restore(approach_world.entities)
	actor = Actors.create("approach", 0, 1, 0)
	actor.x_fp = 200
	actor.y_fp = 300
	actor.vy_fp = 8
	var approach_events: Array = Actors.step([actor], buffer, 1, 0)
	check(actor.consumed == 0 and approach_events.any(func(e): return e.event.type == "KRONI_FLEE_STARTED"), "proximity starts fleeing before a bite")
	var identity: String = buffer.marchers()[0].id
	check(actor.fleeing[identity].remaining_ms == 1100, "panic begins with independent 1.1 second timer")
	actor.fleeing[identity].remaining_ms = 50
	check(Actors.notice(actor, buffer).is_empty() and actor.fleeing[identity].remaining_ms == 1100, "nearby refreshes timer without repeating flee event")
	Actors.flee(actor, buffer, 550)
	check(actor.fleeing[identity].remaining_ms >= 1070, "proximity keeps refreshing throughout the chomp")
	Actors.notice(actor, buffer)
	var before_escape: int = buffer.get_entity(identity).attributes.x_fp
	actor.active = false
	Actors.step([actor], buffer, 1, 1)
	check(buffer.get_entity(identity).attributes.x_fp > before_escape and actor.fleeing[identity].remaining_ms == 1070, "flee continues during normal ticks even after Kroni leaves")
	Actors.flee(actor, buffer, 550)
	check(actor.fleeing[identity].remaining_ms == 520, "chomp spends the same timer without restarting it")
	Actors.flee(actor, buffer, 520)
	check(actor.fleeing.is_empty(), "panic expires after total 1.1 seconds")
	var stopped: Array = buffer.marchers()
	Actors.flee(actor, buffer, 550)
	check(buffer.marchers() == stopped, "expired fleeing adds no further movement")


func _attack_commitment() -> void:
	var session = Session.new()
	check(session.configure(["Kroni", "Gremory"], Scenario.world().data.castle_loadouts, true).action != "invalid", "commitment fixture starts")
	var owner = session._owner
	var before: Dictionary = owner.snapshot()
	var world: Dictionary = before.world
	var castle: String = ""
	for row in world.entities.entities:
		if row.kind == "castle" and row.owner == 1 and preload("res://Scripts/Sim/U13Structures.gd").targetable(row):
			castle = row.id
			break
	var hand: Array = world.data.card_zones.hands[0]
	for action in ["Hunt", "Siege"]:
		var order: Dictionary = {"action": action, "lane": "Lord" if action == "Hunt" else "Castle", "target_id": State.lord(world, 1).id if action == "Hunt" else castle, "card_ids": []}
		check(owner.preview_submission(0, [], order).action == "invalid", "zero-card " + action + " rejected by preview")
		check(owner.legal_order_candidates(0, [], [order]).is_empty(), "zero-card " + action + " excluded from bot legality")
		check(owner.submit(0, [], order).action == "invalid" and owner.snapshot() == before, "zero-card " + action + " rejected atomically by submission")
		order.card_ids = hand.slice(0, 1)
		check(owner.preview_submission(0, [], order).action != "invalid", "one-card " + action + " remains legal")
	check(owner.preview_submission(0, [], {"action": "Ward", "lane": "Lord", "card_ids": []}).action != "invalid", "zero-card Ward remains legal")
	check(owner.preview_submission(0, [], {}).action != "invalid", "Pass remains legal")

func _biased_launch() -> void:
	var world: Dictionary = Scenario.world()
	add_unit(world, 70, 1, 800, 100)
	add_unit(world, 71, 1, 1000, 150)
	var units: Array = world.entities.entities.filter(func(u): return u.kind == "marcher")
	var base: Dictionary = Actors.create("bias", 0, 1, 0)
	var routes: Array = Actors.favored_routes(base, units)
	check(not routes.is_empty() and routes.size() < 2 * (Actors.LATERAL_MAX - Actors.LATERAL_MIN + 1), "bias fixture separates qualifying and empty routes")
	var biased: int = 0
	var random_count: int = 0
	for i in range(64):
		var seed_value: String = "bias-seed-%d" % i
		var actor: Dictionary = Actors.create("bias", 0, 1, 0, false, seed_value, {}, units)
		var roll: int = int(preload("res://Scripts/Sim/U13KeyedRng.gd").draw(seed_value, "bias:1", "RAVENOUS_BIAS", 0, 4).value)
		if roll < 3:
			biased += 1
			check(actor.vy_fp in routes and actor.launch_mode == "favored", "75 percent branch selects a two-enemy route")
		else:
			random_count += 1
			check(actor.vy_fp == Actors.create("bias", 0, 1, 0, false, seed_value).vy_fp and actor.launch_mode == "random", "25 percent branch preserves original random launch")
		check(actor == Actors.create("bias", 0, 1, 0, false, seed_value, {}, units), "biased launch replays deterministically")
	check(biased > 0 and random_count > 0, "both launch branches exercised")
	var allies: Array = units.duplicate(true)
	for unit in allies:
		unit.owner = 0
	check(Actors.favored_routes(base, allies).is_empty(), "friendly units cannot qualify a favored route")
	check(Actors.favored_routes(base, [units[0]]).is_empty(), "fewer than two enemies falls back to random")
	var mirrored: Array = units.duplicate(true)
	for unit in mirrored:
		unit.owner = 0
		unit.attributes.x_fp = 2400 - int(unit.attributes.x_fp)
	var opponent: Dictionary = Actors.create("bias", 1, 1, 0)
	check(Actors.favored_routes(opponent, mirrored) == routes, "enemy launch uses the same bias toward player units")

func _angle_gradient() -> void:
	var total: int = 0
	var shallow: int = 0
	for magnitude in range(1, 25):
		var weight: int = Actors.route_weight(magnitude)
		total += weight
		if magnitude < 8:
			shallow += weight
		if magnitude > 1:
			check(weight > Actors.route_weight(magnitude - 1), "diagonal preference increases smoothly and sharply")
	check(float(shallow) / float(total) > 0.03 and float(shallow) / float(total) < 0.06, "near-forward range has a small nonzero share")
	var seen: Dictionary = {}
	for i in range(512):
		var actor: Dictionary = Actors.create("gradient", 0, 1, 0, false, "angle-%d" % i)
		seen[absi(actor.vy_fp)] = true
		check(Actors.valid([actor]), "weighted launch stays valid and enemy-facing")
	check(seen.has(1) and seen.has(24), "near-vertical and strong diagonal launches both reachable")
