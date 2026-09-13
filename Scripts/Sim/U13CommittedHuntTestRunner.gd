extends "res://Scripts/Sim/U13BloodConduitTestRunner.gd"

const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")

func run() -> void:
	var world: Dictionary = fixture("Gremory", 7)
	for pid in [0, 1]:
		patch(world, world.players[pid].lord_entity_id, {"threat": 4})
		patch(world, Slots.castle_id(pid, 0), {"integrity": 1})
		world.data.sigils[pid].Lord = ""
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	if not check(game._owner.start("conduit", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "mutual Hunt fixture"):
		quit(1)
		return
	var plans: Array = []
	for pid in [0, 1]:
		plans.append({"powers": [], "order": {"action": "Hunt", "lane": "Lord", "target_id": world.players[1 - pid].lord_entity_id, "card_ids": game._owner.player_view(pid, 0).world.hand, "fracture_target": "subjects"}})
	if not check(game.submit(plans).action != "invalid", "both Hunts commit while Lords are alive"):
		quit(1)
		return
	while game._owner.next_hook() != Game.Timeline.COMBAT_RESOLUTION:
		if not check(game.step().action != "invalid", "advance committed Hunt"):
			quit(1)
			return
	var restored = Game.new()
	check(restored.restore_json(game.snapshot_json()).action != "invalid", "restore before opposing Hunts")
	check(game.finish_round().action != "invalid" and restored.finish_round().action != "invalid" and game.snapshot() == restored.snapshot(), "mutual Hunt and Fracture replay exactly")
	var after: Dictionary = game.snapshot().world
	check(after.entities.entities.filter(func(e): return e.kind == "lord").all(func(e): return not e.attributes.alive), "both committed Hunts can banish")
	var absent: Dictionary = world.duplicate(true)
	var attacker_id: String = world.players[1].lord_entity_id
	patch(absent, attacker_id, {"alive": false})
	var command: Dictionary = {"command_id": "hunt:1:lord:" + world.players[0].lord_entity_id, "kind": "banish_lord", "target_id": world.players[0].lord_entity_id, "attacker_id": attacker_id, "attack_kind": "Hunt"}
	check(Battle.apply(absent, command, 2, Game.Timeline.COMBAT_RESOLUTION).action != "invalid", "army Hunt attribution works with previously absent Lord")
	command.attacker_id = world.players[0].lord_entity_id
	check(Battle.apply(absent, command, 2, Game.Timeline.COMBAT_RESOLUTION).action == "invalid", "friendly banishment attribution remains invalid")
	for returning in [false, true]:
		absent_hunt(returning)
		for pillage in [false, true]:
			absent_siege(returning, pillage)
		for lane in ["Lord", "Castle"]:
			absent_ward(returning, lane)
	print("U13 committed army action failures: %d" % failures)
	quit(failures)

func absent_hunt(returning: bool) -> void:
	var world: Dictionary = fixture("Gremory", 7)
	patch(world, world.players[0].lord_entity_id, {"alive": false})
	patch(world, world.players[1].lord_entity_id, {"threat": 4})
	patch(world, Slots.castle_id(1, 0), {"integrity": 1})
	world.data.sigils[1].Lord = ""
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	if not check(game._owner.start("conduit", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "already absent Hunt fixture"):
		return
	var hand: Array = game._owner.player_view(0, 0).world.hand
	var order: Dictionary = {"action": "Hunt", "lane": "Lord", "target_id": world.players[1].lord_entity_id, "card_ids": hand}
	if returning:
		order["summon"] = {"card_ids": []}
	check(game._owner.legal_order_candidates(0, [], [order]) == [order], "bulk admits Hunt with absent Lord, returning=" + str(returning))
	check(game._owner.preview_submission(0, [], order).action != "invalid", "complete preview admits absent Lord Hunt")
	var before: Dictionary = game.snapshot()
	var invalid: Dictionary = order.duplicate(true)
	invalid["summon"] = {"card_ids": [hand[0]]}
	check(game._owner.preview_submission(0, [], invalid).action == "invalid" and game.snapshot() == before, "summon and Hunt cannot double-spend a card")
	if not check(game.submit([{"powers": [], "order": order}, {"powers": [], "order": {}}]).action != "invalid", "absent Lord Hunt submits"):
		return
	var restored = Game.new()
	check(restored.restore_json(game.snapshot_json()).action != "invalid", "restore sealed absent Lord Hunt")
	check(game.finish_round().action != "invalid" and restored.finish_round().action != "invalid" and game.snapshot() == restored.snapshot(), "absent Lord Hunt resolves and replays")
	check(not row(game.snapshot().world, world.players[1].lord_entity_id).attributes.alive, "army banishes enemy Lord")

func absent_siege(returning: bool, pillage: bool) -> void:
	const Bot = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
	var label: String = ("Pillage" if pillage else "Siege") + ", returning=" + str(returning)
	var world: Dictionary = fixture("Gremory", 7)
	patch(world, world.players[0].lord_entity_id, {"alive": false})
	world.data.sigils[1].Castle = ""
	var target: String = Slots.castle_id(1, 1)
	patch(world, target, {"integrity": 1})
	if pillage:
		for slot in range(5):
			patch(world, Slots.castle_id(1, slot), {"construction_state": "unbuilt", "integrity": 0, "status": "defunct"})
		patch(world, Slots.castle_id(1, 0), {"construction_state": "building", "integrity": 6, "status": "standing"})
		world.data.construction_targets[1] = Slots.castle_id(1, 0)
		target = "castle_zone:1"
	# Exercise attributed guard defeat with an absent attacking Lord as well.
	var guard: String = world.data.card_zones.hands[1][0]
	world.data.card_zones.hands[1].erase(guard)
	patch(world, guard, {"role": "guard", "lane": "Castle", "slot": 0, "suit": "Butcher", "value": 1})
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	if not check(game._owner.start("conduit", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "absent Lord fixture: " + label):
		return
	var hand: Array = game._owner.player_view(0, 0).world.hand
	var order: Dictionary = {"action": "Siege", "lane": "Castle", "target_id": target, "card_ids": hand}
	if returning:
		order["summon"] = {"card_ids": []}
	var before: Dictionary = game.snapshot()
	check(game._owner.legal_order_candidates(0, [], [order]) == [order], "authority batch admits " + label)
	var planning = game._owner.planning_session(0)
	check(planning.legal_order_candidates(0, [], [order]) == [order] and planning.preview_submission(0, [], order).action != "invalid", "planning session admits " + label)
	check(game._owner.preview_submission(0, [], order).action != "invalid" and game.snapshot() == before, "complete preview is atomic: " + label)
	var c = Bot.Context.new(Bot.BotPlanning.new(planning, 0).player_view(0, 0))
	var options: Array = Bot.Common.combat(c, [], {"summon": {"card_ids": []}} if returning else {}).map(func(x): return x.payload)
	check(planning.legal_order_candidates(0, [], options).any(func(x): return x.get("action") == "Siege" and x.get("target_id") == target), "doctrine retains legal " + label)
	var invalid: Dictionary = order.duplicate(true)
	invalid["summon"] = {"card_ids": [hand[0]]}
	check(game._owner.preview_submission(0, [], invalid).action == "invalid" and game.snapshot() == before, "return cannot double-spend army cards: " + label)
	invalid = order.duplicate(true)
	invalid.target_id = Slots.castle_id(0, 0)
	check(game._owner.preview_submission(0, [], invalid).action == "invalid", "friendly castle remains invalid: " + label)
	invalid.target_id = Slots.castle_id(1, 0) if pillage else "castle_zone:1"
	check(game._owner.preview_submission(0, [], invalid).action == "invalid", "castle-zone target restrictions remain: " + label)
	if not check(game.submit([{"powers": [], "order": order}, {"powers": [], "order": {}}]).action != "invalid", "absent Lord army submits: " + label):
		return
	var restored = Game.new()
	if not check(restored.restore_json(game.snapshot_json()).action != "invalid", "sealed army restores: " + label):
		return
	check(game.finish_round().action != "invalid" and restored.finish_round().action != "invalid" and game.snapshot() == restored.snapshot(), "army resolves and replays exactly: " + label)
	var after: Dictionary = game.snapshot().world
	check(row(after, guard).attributes.role != "guard", "army defeats Castle guard: " + label)
	if pillage:
		check(after.players[0].resources.souls == before.world.players[0].resources.souls + 1, "absent Lord Pillage earns one Soul")
		check(row(after, Slots.castle_id(1, 0)).attributes.integrity == row(before.world, Slots.castle_id(1, 0)).attributes.integrity + preload("res://Scripts/Sim/U13Construction.gd").PASSIVE, "Pillage leaves passive construction progress intact")
	else:
		check(row(after, target).attributes.integrity == 0, "absent Lord Siege ruins the enemy castle")
	check(row(after, world.players[0].lord_entity_id).attributes.alive == returning, "Lord presence follows only resummoning: " + label)

func absent_ward(returning: bool, lane: String) -> void:
	const Bot = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
	const GremoryOptions = preload("res://Scripts/Sim/U13GremoryCandidates.gd")
	var label: String = "Ward " + lane + ", returning=" + str(returning)
	var world: Dictionary = fixture("Gremory", 7)
	patch(world, world.players[0].lord_entity_id, {"alive": false})
	world.data.sigils[0].Castle = ""
	var target: String = Slots.castle_id(0, 1)
	patch(world, target, {"integrity": 1})
	for card in world.data.card_zones.hands[0]:
		patch(world, card, {"suit": "Penitent", "value": 3})
	var attack_card: String = world.data.card_zones.hands[1][0]
	patch(world, attack_card, {"suit": "Butcher", "value": 3})
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	if not check(game._owner.start("conduit", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "absent Lord fixture: " + label):
		return
	var hand: Array = game._owner.player_view(0, 0).world.hand
	var order: Dictionary = {"action": "Ward", "lane": lane, "card_ids": hand}
	if returning: order["summon"] = {"card_ids": []}
	var before: Dictionary = game.snapshot()
	var planning = game._owner.planning_session(0)
	check(game._owner.legal_order_candidates(0, [], [order]) == [order] and planning.legal_order_candidates(0, [], [order]) == [order], "authority and planning session admit " + label)
	check(game._owner.preview_submission(0, [], order).action != "invalid" and game.snapshot() == before, "complete preview is atomic: " + label)
	var empty: Dictionary = order.duplicate(true)
	empty.card_ids = []
	check(planning.preview_submission(0, [], empty).action != "invalid", "zero-card Ward remains legal: " + label)
	var invalid: Dictionary = order.duplicate(true)
	invalid["summon"] = {"card_ids": [hand[0]]}
	check(game._owner.preview_submission(0, [], invalid).action == "invalid" and game.snapshot() == before, "return cannot double-spend Ward cards: " + label)
	var power: Dictionary = GremoryOptions._source(0, game._owner.round_number(), GremoryOptions.Gremory.PREDATOR, {"lane": lane})
	check(game._owner.preview_submission(0, [power], order).action == "invalid", "absent Lord powers remain unavailable: " + label)
	var c = Bot.Context.new(Bot.BotPlanning.new(planning, 0).player_view(0, 0))
	var options: Array = Bot.Common.combat(c, [], {"summon": {"card_ids": []}} if returning else {}).map(func(x): return x.payload)
	check(planning.legal_order_candidates(0, [], options).any(func(x): return x.get("action") == "Ward" and x.get("lane") == lane), "doctrine retains legal " + label)
	var attack: Dictionary = {"action": "Siege", "lane": "Castle", "target_id": target, "card_ids": [attack_card]}
	if not check(game.submit([{"powers": [], "order": order}, {"powers": [], "order": attack}]).action != "invalid", "absent Lord Ward submits against Siege: " + label):
		return
	var restored = Game.new()
	if not check(restored.restore_json(game.snapshot_json()).action != "invalid", "sealed Ward restores: " + label):
		return
	check(game.finish_round().action != "invalid" and restored.finish_round().action != "invalid" and game.snapshot() == restored.snapshot(), "Ward resolves and replays exactly: " + label)
	var after: Dictionary = game.snapshot().world
	check(row(after, target).attributes.integrity == 1, "absent Lord Ward screens incoming Siege: " + label)
	check(row(after, world.players[0].lord_entity_id).attributes.alive == returning, "Ward does not require or restore Lord presence: " + label)
