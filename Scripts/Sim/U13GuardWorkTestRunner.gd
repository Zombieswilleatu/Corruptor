extends SceneTree

const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Work = preload("res://Scripts/Sim/U13GuardWork.gd")
const Bot = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Slots = Game.Slots
var failures: int = 0
var serial: int = 0

func check(ok: bool, label: String) -> bool:
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
	return ok

func _initialize() -> void:
	work_rules()
	pair_rules()
	scheduled_consume_pairs()
	conversion()
	conductor()
	print("U13 Guard work failures: ", failures)
	quit(0 if failures == 0 else 1)

func world() -> Dictionary:
	var w: Dictionary = Game.Economy.initialize(Game.Scenario.loadout_world(["Deimos", "Gremory"], [Slots.TYPES, Slots.TYPES]), "work-fixture").world
	reset_orders(w, 1)
	return w

func reset_orders(w: Dictionary, round_number: int) -> void:
	for pid in [0, 1]:
		w.data.guard_orders[pid] = {"round": round_number, "moves": []}
		w.data.castle_orders[pid] = {"choice": {}}

func entity(w: Dictionary, id: String) -> Dictionary:
	var ids = Ids.new(); ids.restore(w.entities)
	return ids.get_entity(id)

func install(w: Dictionary, e: Dictionary) -> void:
	var ids = Ids.new(); ids.restore(w.entities)
	ids.update(e.id, e.owner, e.attributes)
	w.entities = ids.snapshot()

func guard(w: Dictionary, suit: String, lane: String, slot: int) -> String:
	serial += 1
	var ids = Ids.new(); ids.restore(w.entities)
	var made: Dictionary = ids.create("card", "work-fixture-guard", serial, 0, {"suit": suit, "value": 3, "role": "guard", "lane": lane, "slot": slot})
	w.entities = ids.snapshot()
	w.data.guard_orders[0].moves.append({"card_id": made.entity.id, "lane": lane, "slot": slot})
	return made.entity.id

func work_rules() -> void:
	var w: Dictionary = world()
	var target: String = Slots.castle_id(0, 4)
	w.data.castle_orders[0].choice = Work.choice(target)
	guard(w, "Wright", "Lord", 0); guard(w, "Wright", "Lord", 1)
	var events: Array = Work.develop(w, 1, [0, 1])
	check(entity(w, target).attributes.integrity == 8, "new Lord Wright pair supplies 5 work plus 3 passive construction")
	check(events.filter(func(e): return e.event.type == "GUARD_PAIR_FORMED")[0].views[1] != null, "deployed bond formation is public to both players")
	check(Work.develop(w, 1, [0, 1]).is_empty(), "Development work cannot run twice")
	reset_orders(w, 2); Work.develop(w, 2, [0, 1])
	check(entity(w, target).attributes.integrity == 11, "persistent project gains passive 3; surviving Guards do not repeat deployment work")
	reset_orders(w, 3); guard(w, "Wright", "Castle", 0); guard(w, "Wright", "Castle", 1); Work.develop(w, 3, [0, 1])
	check(entity(w, target).attributes.construction_state == "active" and w.data.guard_work.targets[0].is_empty(), "full construction activates and clears target")
	var repaired: String = Slots.castle_id(0, 1)
	var castle: Dictionary = entity(w, repaired); castle.attributes.integrity = 5; install(w, castle)
	reset_orders(w, 4); w.data.castle_orders[0].choice = Work.choice(repaired)
	guard(w, "Butcher", "Lord", 2); Work.develop(w, 4, [0, 1])
	check(entity(w, repaired).attributes.integrity == 6, "Castle Guard repairs selected standing Castle by 1 with no passive repair")
	reset_orders(w, 5); w.data.castle_orders[0].choice = Work.choice(""); Work.develop(w, 5, [0, 1])
	check(w.data.guard_work.targets[0].is_empty() and entity(w, repaired).attributes.integrity == 6, "explicit clear cancels persistent work")
	castle = entity(w, repaired); castle.attributes.status = "ruined"; castle.attributes.integrity = 0; install(w, castle)
	check(not Work.eligible(w, 0, castle), "ruined ordinary Castle cannot be repaired")
	var engine: Dictionary = w.entities.entities.filter(func(e): return e.owner == 0 and e.kind == "castle" and e.attributes.combat_profile == "siege_engine")[0]
	engine.attributes.status = "ruined"; engine.attributes.integrity = 0; install(w, engine)
	check(Work.eligible(w, 0, engine), "living Deimos can reconstruct his ruined Siege Engine")
	var lock_target: String = Slots.castle_id(0, 0)
	var locked: Dictionary = entity(w, lock_target); locked.attributes.integrity = 8; locked.attributes["repair_lock_until_round"] = 6; install(w, locked)
	reset_orders(w, 6); w.data.castle_orders[0].choice = Work.choice(lock_target); guard(w, "Vulture", "Castle", 2); Work.develop(w, 6, [0, 1])
	check(entity(w, lock_target).attributes.integrity == 8, "work respects existing round repair lock")
	var lord: Dictionary = entity(w, w.players[0].lord_entity_id); lord.attributes.alive = false; install(w, lord)
	check(not Work.eligible(w, 0, engine), "banished Deimos cannot reconstruct")

func pair_rules() -> void:
	for suit in ["Penitent", "Butcher", "Vulture"]:
		var w: Dictionary = world()
		var first: String = guard(w, suit, "Lord", 0); guard(w, suit, "Lord", 1)
		Work.develop(w, 1, [0, 1])
		var pair: Dictionary = w.data.guard_work.pairs[0]
		check(Work.intact(w, pair), suit + " fresh pair bonded")
		var context: Dictionary = {"round": 1, "hook": Game.Timeline.COMBAT_RESOLUTION, "seed": "pair-test", "player_order": [0, 1]}
		if suit == "Penitent":
			check(Work.defend(w, 0, "Lord", context, Callable()).screen == 5 and Work.defend(w, 0, "Castle", context, Callable()).screen == 0, "Penitent protects only its zone")
		elif suit == "Butcher":
			check(Work.defend(w, 0, "Lord", context, Callable()).events.is_empty(), "Butcher with no enemy Marcher does nothing")
			var ids = Ids.new(); ids.restore(w.entities)
			ids.create("marcher", "work-enemy", 0, 1, Marching.profile("Vulture", "Lord", 1, 1, 2, true))
			ids.create("marcher", "work-enemy", 1, 1, Marching.profile("Wright", "Castle", 1, 1, 2, true))
			w.entities = ids.snapshot()
			var a: Dictionary = Work.defend(w.duplicate(true), 0, "Lord", context, Callable(self, "no_reaction"))
			var b: Dictionary = Work.defend(w.duplicate(true), 0, "Lord", context, Callable(self, "no_reaction"))
			check(a == b and a.action != "invalid" and a.world.entities.entities.filter(func(e): return e.kind == "marcher").size() == 1 and a.world.entities.entities.filter(func(e): return e.kind == "marcher")[0].attributes.lane == "Castle", "Butcher kills one same-lane enemy deterministically")
		else:
			var before: int = w.data.card_zones.hands[0].size()
			check(Work.draw_pairs(w, 1, "draw").is_empty(), "Vulture does not draw on formation round")
			Work.draw_pairs(w, 2, "draw")
			check(w.data.card_zones.hands[0].size() == before + 1 and Work.draw_pairs(w, 2, "draw").is_empty(), "Vulture draws once next round")
		var moved: Dictionary = entity(w, first); moved.attributes.slot = 2; install(w, moved)
		Work.reconcile(w)
		moved.attributes.slot = 0; install(w, moved)
		check(not Work.intact(w, pair), suit + " original bond remains broken after card returns")
		reset_orders(w, 2); guard(w, suit, "Lord", 2); Work.develop(w, 2, [0, 1])
		check(w.data.guard_work.pairs.size() == 1 and not pair.active, "single " + suit + " reinforcement cannot create replacement bond")

func no_reaction(w: Dictionary, _event: Dictionary, _seed: String, _order: Array) -> Dictionary:
	return {"action": "resolved", "world": w, "events": []}

func conversion() -> void:
	for action in ["Ward", "Siege", "Hunt"]:
		var w: Dictionary = world()
		var ids = Ids.new(); ids.restore(w.entities)
		var cards: Array = []
		for index in range(2):
			var made: Dictionary = ids.create("card", "conversion", index, 0, {"suit": "Penitent", "value": 2, "role": "hand"})
			cards.append(made.entity.id)
		w.entities = ids.snapshot()
		var revealed: Dictionary = Combat._reveal({"world": w, "round": 1, "seed": "conversion", "player_order": [0, 1], "combat_orders": [{"action": action, "lane": "Lord", "card_ids": cards}, {}]})
		check(revealed.events.filter(func(e): return e.event.type == "MARCHER_SPAWNED").size() == (2 if action == "Ward" else 1), action + " uses its correct Marcher conversion")
		check(Combat._card_strength(ids, cards, "Penitent", false) == 4, "commitment no longer adds suit pair strength")

func conductor() -> void:
	var game = Game.new()
	if not check(game.start("guard-work-replay", ["Orias", "Gremory"], [Slots.TYPES, Slots.TYPES]).action != "invalid", "new rules game starts"): return
	for round_number in range(1, 4):
		if not check(Bot.to_planning(game).action != "invalid", "planning round " + str(round_number)): return
		var tampered: Dictionary = game.snapshot()
		tampered.world.data.guard_work.draw_round += 1
		var before: Dictionary = game.snapshot()
		check(game.restore(tampered).action == "invalid" and game.snapshot() == before, "forged work clock rejected without mutating live game")
		var plans: Array = [Bot.plan(game._owner, 0), Bot.plan(game._owner, 1)]
		if not check(game.submit(plans).action != "invalid", "doctrine submits work and Guard plans"): return
		while not game._owner.next_hook().is_empty():
			var replay = Game.new()
			if not check(replay.restore_json(game.snapshot_json()).action != "invalid", "hook checkpoint restores"): return
			var a: Dictionary = game.step(); var b: Dictionary = replay.step()
			if not check(a.action != "invalid" and a == b and game.snapshot() == replay.snapshot(), "hook replay agrees including work and bonds"): return
		if round_number < 3: game.next_round()


func scheduled_consume_pairs() -> void:
	for suit in ["Butcher", "Penitent", "Wright", "Vulture"]:
		var w: Dictionary = Game.Economy.initialize(Game.Scenario.loadout_world(["Deimos", "Kroni"], [Slots.TYPES, Slots.TYPES]), "consume-pair").world
		reset_orders(w, 1)
		var victim: String = guard(w, suit, "Castle", 0)
		var survivor: String = guard(w, suit, "Castle", 1)
		Work.develop(w, 1, [0, 1])
		var before: Dictionary = w.duplicate(true)
		check(Work.valid(w) and w.data.guard_work.pairs[0].active, "Consume fixture has an intact " + suit + " pair")
		var result: Dictionary = Game.Content.new().resolve({"fire_hook": Game.Timeline.ROUND_START_SCHEDULED, "declaration": {"power_id": "Consume", "player_id": 1, "parameters": {}, "target": {"entity_id": victim}}}, {"world": w, "round": 2})
		if not check(result.action == "resolved", "scheduled Consume resolves against " + suit): continue
		check(w == before, "power transform preserves its input")
		check(Work.valid(result.world) and not result.world.data.guard_work.pairs[0].active, "scheduled removal breaks pair before authority validation")
		check(entity(result.world, victim).is_empty() and not entity(result.world, survivor).is_empty(), "Consume removes only the targeted Guard")
		reset_orders(result.world, 2)
		guard(result.world, suit, "Castle", 0)
		Work.develop(result.world, 2, [0, 1])
		check(not result.world.data.guard_work.pairs[0].active and result.world.data.guard_work.pairs.size() == 1, "replacement beside survivor does not reactivate consumed pair")
