extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

const Sigils = preload("res://Scripts/Sim/U13Sigils.gd")

func run() -> void:
	var game = Game.new()
	if not check(game.start("sigil-cycle", ["Gremory", "Humbaba"], [Slots.TYPES, Slots.TYPES]).action != "invalid", "Sigil game starts"):
		quit(1)
		return
	for round_number in range(1, 4):
		if not check(planning_with_market_passes(game).action == "game_planning", "Sigil planning %d" % round_number):
			break
		var expected: String = ["", "flipped", ""][round_number - 1]
		check(game.player_view(0).world.sigils[0].Lord == expected and game.player_view(1).world.sigils[1].Castle == expected, "fresh ages once then expires")
		var plans: Array = [{"powers": [], "order": {}}, {"powers": [], "order": {}}]
		if round_number == 1:
			for pid in [0, 1]:
				plans[pid].order = {"action": "Ward", "lane": "Lord" if pid == 0 else "Castle", "card_ids": [game.player_view(pid).world.hand[0]]}
		if not check(game.submit(plans).action != "invalid", "lock Sigil orders"):
			break
		while game._owner.next_hook() != Game.Timeline.COMMITMENT_REVEAL:
			if not check(game.step().action != "invalid", "before Sigil reveal"):
				quit(1)
				return
		check(game.player_view(0).world.sigils[0].Lord == expected, "no early Sigil during planning or Development")
		var saved = Game.new()
		check(saved.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", "save before Sigil reveal")
		check(game.step().action != "invalid" and saved.step().action != "invalid" and game.snapshot() == saved.snapshot(), "reveal and Sigil events replay")
		check(game.player_view(0).world.sigils[0].Lord == ("fresh" if round_number == 1 else expected), "Ward creates fresh in selected zone")
		check(game.finish_round().action != "invalid" and saved.finish_round().action != "invalid" and game.snapshot() == saved.snapshot(), "Sigils replay through full round")
		if round_number < 3:
			check(game.next_round().action != "invalid", "next Sigil round")
	transform_cases()
	print("U13 Sigils failures: %d" % failures)
	quit(failures)

func transform_cases() -> void:
	var world: Dictionary = Economy.initialize(Game.Scenario.loadout_world(["Gremory", "Humbaba"], [Slots.TYPES, Slots.TYPES]), "sigil-cases").world
	var ids = Game.Content.Ids.new()
	ids.restore(world.entities)
	var actor: Dictionary = ids.get_entity(world.players[0].lord_entity_id)
	actor.attributes["threat"] = 2
	ids.update(actor.id, 0, actor.attributes)
	world.entities = ids.snapshot()
	world.data.sigils[0].Castle = "flipped"
	var context: Dictionary = {"world": world, "round": 1, "hook": Game.Timeline.ROUND_START_AUTOMATIC}
	var aged: Dictionary = Sigils.on_hook(context)
	check(aged.world.data.sigils[0].Castle == "" and world.data.sigils[0].Castle == "flipped", "aging transform is pure")
	context.world = aged.world
	check(Sigils.on_hook(context).action == "invalid", "cannot age twice in same round")
	context.hook = Game.Timeline.COMMITMENT_REVEAL
	context.combat_orders = [{"action": "Ward", "lane": "Lord"}, {"action": "Ward", "lane": "Lord"}]
	var created: Dictionary = Sigils.on_hook(context)
	check(ids.restore(created.world.entities).action != "invalid", "created entities restore")
	check(ids.get_entity(actor.id).attributes.threat == 1 and not ids.get_entity(world.players[1].lord_entity_id).attributes.has("threat"), "Lord Ward lowers Threat while Humbaba remains statless")
	context.world = created.world
	check(Sigils.on_hook(context).action == "invalid", "cannot create twice in same round")
	context.round = 2
	context.hook = Game.Timeline.ROUND_START_AUTOMATIC
	var next: Dictionary = Sigils.on_hook(context)
	context.world = next.world
	context.hook = Game.Timeline.COMMITMENT_REVEAL
	var refreshed: Dictionary = Sigils.on_hook(context)
	check(refreshed.world.data.sigils[0].Lord == "fresh" and refreshed.world.data.sigils[1].Lord == "fresh", "Ward refreshes decaying Sigil; no old Humbaba preservation")
