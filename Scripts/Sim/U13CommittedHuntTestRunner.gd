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
	print("U13 committed Hunt failures: %d" % failures)
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
