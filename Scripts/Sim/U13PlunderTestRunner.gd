extends "res://Scripts/Sim/U13BloodConduitTestRunner.gd"

const Plunder = preload("res://Scripts/Sim/U13Plunder.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")

func prepared(lord_name: String = "Orias") -> Dictionary:
	var world: Dictionary = fixture(lord_name)
	for castle in world.entities.entities:
		if castle.kind == "castle":
			patch(world, castle.id, {"status": "ruined", "integrity": 0, "construction_state": "active", "artillery_target": ""})
	patch(world, Slots.castle_id(0, 0), {"status": "standing", "integrity": row(world, Slots.castle_id(0, 0)).attributes.max_integrity})
	return world

func profane(pid: int = 0) -> Dictionary:
	return {"action": "Profane", "lane": "Castle", "target_id": Slots.castle_id(pid, 0), "card_ids": []}

func siege(world: Dictionary, pid: int, target: String, amount: int = 5) -> Dictionary:
	var card: String = world.data.card_zones.hands[pid][0]
	patch(world, card, {"suit": "Butcher", "value": amount})
	return {"action": "Siege", "lane": "Castle", "target_id": target, "card_ids": [card]}

func context(world: Dictionary, orders: Array, priority: Array = [0, 1]) -> Dictionary:
	return {"world": world, "round": 1, "hook": Game.Timeline.COMBAT_RESOLUTION, "combat_orders": orders, "seed": "plunder", "player_order": priority}

func resolve_combat(world: Dictionary, orders: Array, priority: Array = [0, 1]) -> Dictionary:
	return Combat.on_hook(context(world, orders, priority), Callable(Game.Content.new(), "react"))

func legal(world: Dictionary, pid: int, order: Dictionary) -> bool:
	var ids = Game.Content.Ids.new()
	ids.restore(world.entities)
	return Combat.validate_commit(world, pid, order, ids, world.data.card_zones.hands[pid]).action != "invalid"

func facts(result: Dictionary, kind: String) -> Array:
	var rows: Array = []
	for event in result.events:
		if event.event.type == kind:
			rows.append(event.event.data)
	return rows

func run() -> void:
	var world: Dictionary = prepared()
	check(Game.Content.new().valid_world(world), "directed Profane opening is valid")
	check(legal(world, 0, profane()), "full active own Castle can be Profaned without cards")
	for changes in [{"integrity": 20}, {"status": "defunct", "integrity": 0}, {"status": "ruined", "integrity": 0}, {"status": "profaned", "integrity": 0}, {"construction_state": "building"}, {"construction_state": "ready"}]:
		var altered: Dictionary = world.duplicate(true)
		patch(altered, Slots.castle_id(0, 0), changes)
		check(not legal(altered, 0, profane()), "Profane rejects " + str(changes))
	var wrong: Dictionary = profane()
	wrong.target_id = Slots.castle_id(1, 0)
	check(not legal(world, 0, wrong), "Profane cannot sacrifice enemy Castle")
	world.data.sigils[1].Lord = "fresh"
	world.data.sigils[0].Castle = "fresh"
	var before: Dictionary = world.duplicate(true)
	var result: Dictionary = resolve_combat(world, [profane(), {}])
	if not check(result.action != "invalid", "Profane resolves with opposing fresh Sigil"):
		print(result)
		quit(1)
		return
	check(world == before, "combat resolution does not mutate input")
	check(row(result.world, Slots.castle_id(0, 0)).attributes.status == "profaned" and result.world.players[0].resources.personal_tears == 1, "Profane sacrifices exactly one Castle and awards one personal Tear")
	check(result.world.players[0].resources.souls == 0 and result.world.data.neutral_tears == 0 and facts(result, "CASTLE_RUINED").is_empty(), "Profane is not a ruination and creates no Souls or neutral Tear")
	check(result.world.data.sigils[0].Castle == "" and result.world.data.sigils[1].Lord == "fresh", "last Castle removes only its Castle Sigil")
	check(Game.Content.new().valid_world(result.world), "Profaned world remains valid")
	check(resolve_combat(result.world, [profane(), {}]).action == "invalid", "duplicate resolution cannot mint another Tear")
	world = prepared()
	var attack: Dictionary = siege(world, 1, Slots.castle_id(0, 0))
	result = resolve_combat(world, [profane(), attack])
	check(result.action != "invalid" and result.world.players[1].resources.souls == 1 and facts(result, "SIEGE_RESOLVED")[0].pillage, "earlier Profane converts locked Siege to Pillage when last Castle disappears")
	var kinds: Array = result.events.map(func(e): return e.event.type)
	check(kinds.find("PERSONAL_TEAR_CREATED") > kinds.find("SIEGE_RESOLVED"), "Profane Tear arrives after both ordinary combat actions")
	result = resolve_combat(world, [profane(), attack], [1, 0])
	check(result.action != "invalid" and not facts(result, "PROFANE_RESOLVED")[0].profaned and result.world.players[0].resources.personal_tears == 0, "earlier Siege damage makes sealed Profane fizzle")
	check(row(result.world, Slots.castle_id(0, 0)).attributes.status == "standing", "failed Profane retains damaged Castle")
	world = prepared()
	attack = siege(world, 0, Plunder.zone_id(1))
	check(legal(world, 0, attack), "castleless opponent can be targeted through Castle zone")
	var altered: Dictionary = world.duplicate(true)
	patch(altered, Slots.castle_id(1, 0), {"status": "defunct"})
	check(not legal(altered, 0, attack), "zero-Integrity active Castle still requires Siege")
	patch(altered, Slots.castle_id(1, 0), {"status": "standing", "integrity": 10, "construction_state": "building"})
	check(legal(altered, 0, attack), "protected construction does not block Pillage")
	world.data.sigils[1].Castle = "fresh"
	result = resolve_combat(world, [attack, {}])
	check(result.world.players[0].resources.souls == 1 and result.world.players[0].resources.personal_tears == 0 and result.world.data.neutral_tears == 0, "Pillage grants exactly one Soul and no Tears")
	check(facts(result, "SIEGE_RESOLVED")[0].damage == 0 and not facts(result, "SIEGE_RESOLVED")[0].destroyed, "Pillage causes no structural damage or destruction")
	var ward_card: String = world.data.card_zones.hands[1][0]
	patch(world, ward_card, {"suit": "Penitent", "value": 5})
	result = resolve_combat(world, [attack, {"action": "Ward", "lane": "Castle", "card_ids": [ward_card]}])
	check(result.world.players[0].resources.souls == 0 and not facts(result, "SIEGE_RESOLVED")[0].pillage_success, "equal Castle Ward stops Pillage")
	development_edges()
	guard_and_waiter()
	live_replay(false)
	live_replay(true)
	print("U13 Profane Pillage failures: %d" % failures)
	quit(failures)

func guard_and_waiter() -> void:
	var world: Dictionary = prepared("Deimos")
	var attack: Dictionary = siege(world, 0, Plunder.zone_id(1), 2)
	var guard: String = world.data.card_zones.hands[1][0]
	world.data.card_zones.hands[1].erase(guard)
	patch(world, guard, {"role": "guard", "lane": "Castle", "slot": 0, "value": 2})
	# Orias has no Fear; strict equality leaves the defender standing.
	var ordinary: Dictionary = prepared()
	attack = siege(ordinary, 0, Plunder.zone_id(1), 2)
	guard = ordinary.data.card_zones.hands[1][0]
	ordinary.data.card_zones.hands[1].erase(guard)
	patch(ordinary, guard, {"role": "guard", "lane": "Castle", "slot": 0, "value": 2})
	var result: Dictionary = resolve_combat(ordinary, [attack, {}])
	check(result.world.players[0].resources.souls == 0 and facts(result, "GUARD_DEFEATED").is_empty(), "equal Castle Guard stops Pillage and survives")
	var ids = Game.Content.Ids.new()
	ids.restore(ordinary.entities)
	var body: Dictionary = Combat.Marching.profile("Vulture", "Castle", 0, 0, 1, true)
	body.waiting = true
	body.waiting_since_round = 1
	body.x_fp = 2400
	var waiter: String = ids.create("marcher", "pillage_waiter", 0, 0, body).entity.id
	ordinary.entities = ids.snapshot()
	result = resolve_combat(ordinary, [attack, {}])
	check(result.world.players[0].resources.souls == 1 and facts(result, "GUARD_DEFEATED").size() == 1 and not result.world.entities.entities.any(func(e): return e.id == waiter), "Pillage consumes Castle waiter and uses its strength through Guard")
	check(facts(result, "SIEGE_STARTED")[0].waiters_consumed == [waiter], "Pillage reports exact waiter consumption")
	attack = siege(world, 0, Plunder.zone_id(1), 2)
	result = resolve_combat(world, [attack, {}])
	check(result.world.players[0].resources.souls == 1 and result.world.data.card_zones.hands[1].has(guard), "Pillage preserves current Deimos Fear reaction")

func live_replay(zone_attack: bool) -> void:
	var world: Dictionary = prepared()
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match()
	if not check(game._owner.start("plunder-live", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "full game reaches Profane/Pillage planning"):
		return
	var orders: Array = [profane(), {}]
	if zone_attack:
		orders[0] = {"action": "Siege", "lane": "Castle", "target_id": Plunder.zone_id(1), "card_ids": [game.player_view(0).world.hand[0]]}
	else:
		orders[1] = {"action": "Siege", "lane": "Castle", "target_id": Slots.castle_id(0, 0), "card_ids": [game.player_view(1).world.hand[0]]}
	var unchanged: Dictionary = game.snapshot()
	var raw: Dictionary = Game.Scenario.enumerate(game._owner, 0)
	var choices: Array = game._owner.legal_order_candidates(0, [], raw.orders)
	check(choices.any(func(o): return o.get("action") == "Profane") and choices.any(func(o): return o.get("target_id") == Plunder.zone_id(1)), "shared enumeration exposes legal Profane and castleless Siege")
	check(game._owner.preview_submission(0, [], orders[0]).action != "invalid" and game.snapshot() == unchanged, "Profane/Pillage preview leaves live state unchanged")
	if not check(game.submit([{"powers": [], "order": orders[0]}, {"powers": [], "order": orders[1]}]).action != "invalid", "joint submission accepts Profane/Pillage"):
		return
	while not game._owner.next_hook().is_empty():
		var hook: String = game._owner.next_hook()
		var restored = Game.new()
		if not check(restored.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", "Profane/Pillage JSON restore " + hook):
			return
		var step: Dictionary = game.step()
		if not check(step.action != "invalid" and restored.step().action != "invalid" and game.snapshot() == restored.snapshot(), "Profane/Pillage replay " + hook):
			print(step)
			return
		if hook == Game.Timeline.COMBAT_RESOLUTION:
			var original: Dictionary = game.snapshot()
			var forged: Dictionary = original.duplicate(true)
			forged.world.data.plunder.results[0].tear_gain += 1
			check(game.restore(forged).action == "invalid" and game.snapshot() == original, "forged combat reward ledger rejected atomically")
	check(game.next_round().action != "invalid" and planning_with_market_passes(game).action == "game_planning", "next planning retains correct Castle and reward state")
	var saved = Game.new()
	check(saved.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", "previous Plunder results survive next-round planning save")

func development_edges() -> void:
	var world: Dictionary = prepared()
	# Commitment still produces Marchers even though Profane itself costs no cards.
	var card: String = world.data.card_zones.hands[0][0]
	patch(world, card, {"suit": "Vulture", "value": 3})
	var order: Dictionary = profane()
	order.card_ids = [card]
	var reveal: Dictionary = context(world, [order, {}])
	reveal.hook = Game.Timeline.COMMITMENT_REVEAL
	var result: Dictionary = Combat.on_hook(reveal, Callable(Game.Content.new(), "react"))
	var spawns: Array = facts(result, "MARCHER_SPAWNED")
	check(spawns.size() == 1 and spawns[0].attributes.lane == "Castle" and spawns[0].attributes.suit == "Vulture", "Profane commitment produces normal Castle-lane Marchers")
	# Real Engine fire sits before the Profane resolution boundary.
	world = prepared()
	var engine: String = Slots.castle_id(1, 4)
	patch(world, engine, {"status": "standing", "integrity": row(world, engine).attributes.max_integrity, "artillery_target": Slots.castle_id(0, 0)})
	var artillery: Dictionary = context(world, [profane(), {}])
	artillery.hook = Game.Timeline.POST_REPAIR_ARTILLERY
	result = Combat.Structures.normal_fire(artillery, Callable(Game.Content.new(), "react"))
	if check(result.action != "invalid", "ordinary pre-combat artillery fires"):
		result = resolve_combat(result.world, [profane(), {}])
		check(not facts(result, "PROFANE_RESOLVED")[0].profaned and result.world.players[0].resources.personal_tears == 0, "artillery-damaged Profane target fizzles without reward")
	# A locked zone attack cannot pick a freshly activated Castle after planning.
	world = prepared()
	var attack: Dictionary = siege(world, 0, Plunder.zone_id(1))
	patch(world, Slots.castle_id(1, 0), {"status": "standing", "integrity": 21})
	result = resolve_combat(world, [attack, {}])
	check(result.world.players[0].resources.souls == 0 and facts(result, "COMBAT_ORDER_FIZZLED").size() == 1, "new active Castle prevents previously planned Pillage without retargeting")
	# Castleless Ward remains a frontline defense but cannot leave a Castle Sigil.
	world = prepared()
	var ward: Dictionary = {"action": "Ward", "lane": "Castle", "card_ids": []}
	world.data.sigil_lifecycle.aged_round = 1
	var ward_context: Dictionary = context(world, [{}, ward])
	ward_context.hook = Game.Timeline.COMMITMENT_REVEAL
	result = Game.Content.Sigils.on_hook(ward_context)
	check(result.action != "invalid" and result.world.data.sigils[1].Castle == "", "castleless Ward does not create persistent Castle Sigil")
