extends "res://Scripts/Sim/U13BasicDoctrineTestRunner.gd"

const Focus = preload("res://Scripts/Sim/U13CommonDoctrine.gd")

func run() -> void:
	construction_focus()
	acceleration_and_repair()
	print("U13 construction doctrine failures: %d" % failures)
	quit(1 if failures else 0)

func select_castle(game, pid: int) -> Dictionary:
	var c = Bot.Context.new(Bot.BotPlanning.new(game._owner, pid).player_view(pid, 0))
	return Bot.choose(game._owner, pid, [], {}, Focus.castles(c, [], {}))

func construction_focus() -> void:
	var setup: Dictionary = Batch.setup(19)
	var game = Game.new()
	if not check(game.start(setup.seed, setup.lords, setup.castles, true).action != "invalid", "construction campaign fixture"): return
	var projects: Array = ["", ""]
	for round_number in range(1, 6):
		if not check(Bot.to_planning(game).action == "game_planning", "construction round " + str(round_number)): return
		var before: Dictionary = game.snapshot()
		var plans: Array = []
		for pid in [0, 1]:
			var order: Dictionary = select_castle(game, pid)
			var choice: Dictionary = order.get("castle_action", {})
			if round_number == 1:
				if not check(choice.get("action") == "Construct", "starts one useful project for seat " + str(pid)): return
				projects[pid] = choice.target_id
			elif round_number < 5:
				check(choice.get("action") != "Construct", "seat %d keeps its current project instead of redirecting or redundantly ordering construction" % pid)
			else:
				check(choice.get("action") == "Activate" and choice.target_id == projects[pid], "seat %d commissions its current project at useful integrity" % pid)
			check(select_castle(game, pid) == order and game.snapshot() == before, "construction choice is deterministic and read only")
			plans.append({"powers": [], "order": order})
		var replay = Game.new()
		if not check(replay.restore_json(game.snapshot_json()).action != "invalid", "construction checkpoint restores"): return
		if not check(game.submit(plans).action != "invalid" and replay.submit(plans).action != "invalid" and game.finish_round().action != "invalid" and replay.finish_round().action != "invalid" and game.snapshot() == replay.snapshot(), "construction round resolves and replays exactly"): return
		var after: Dictionary = game.snapshot().world
		for pid in [0, 1]:
			var castle: Dictionary = row(after, projects[pid])
			if round_number < 5:
				check(castle.attributes.integrity == round_number * 3 and after.data.construction_targets[pid] == projects[pid], "same project receives every automatic progress step")
			else:
				check(castle.attributes.construction_state == "active" and after.data.construction_targets[pid].is_empty(), "activation releases the construction crew")
		game.next_round()
	if not check(Bot.to_planning(game).action == "game_planning", "planning after commissioning"): return
	for pid in [0, 1]:
		var next: Dictionary = select_castle(game, pid).get("castle_action", {})
		check(next.get("action") == "Construct" and next.target_id != projects[pid], "starts another project after commissioning")

func development_fixture(integrity: int, damage: bool = false):
	var world: Dictionary = fixture("Gremory", 21)
	var project: String = Slots.castle_id(0, 3)
	patch(world, project, {"construction_state": "building", "status": "standing", "integrity": integrity})
	world.data.construction_targets[0] = project
	if damage: patch(world, Slots.castle_id(0, 0), {"integrity": 4})
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	return game if check(game._owner.start("conduit", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "directed construction fixture " + str(integrity)) else null

func acceleration_and_repair() -> void:
	for free_finish in [true, false]:
		var game = development_fixture(18 if free_finish else 17)
		if game == null: return
		var c = Bot.Context.new(Bot.BotPlanning.new(game._owner, 0).player_view(0, 0))
		var options: Array = Bot.ranked(Focus.castles(c, [], {}))
		if free_finish:
			check(not options.any(func(x): return x.payload.castle_action.action == "Construct") and select_castle(game, 0).is_empty(), "lets a free full-health completion happen without payment or early activation")
		else:
			var finishes: Array = options.filter(func(x): return x.payload.castle_action.action == "Construct" and not x.payload.castle_action.card_ids.is_empty())
			check(not finishes.is_empty(), "still considers a paid completion that free progress cannot reach")
			if not finishes.is_empty():
				var order: Dictionary = finishes[0].payload
				check(game._owner.preview_submission(0, [], order).action != "invalid", "completion payment passes authoritative admission")
				if check(game.submit([{"powers": [], "order": order}, {"powers": [], "order": {}}]).action != "invalid" and game.finish_round().action != "invalid", "paid completion resolves"):
					check(row(game.snapshot().world, Slots.castle_id(0, 3)).attributes.integrity == 21, "paid acceleration actually completes the castle")
	var game = development_fixture(3, true)
	if game == null: return
	var order: Dictionary = select_castle(game, 0)
	check(order.get("castle_action", {}).get("action") == "Repair" and order.castle_action.target_id == Slots.castle_id(0, 0), "urgent Repair is still selected while another castle builds")
	if check(game.submit([{"powers": [], "order": order}, {"powers": [], "order": {}}]).action != "invalid" and game.finish_round().action != "invalid", "repair and passive construction resolve together"):
		check(row(game.snapshot().world, Slots.castle_id(0, 3)).attributes.integrity == 6 and row(game.snapshot().world, Slots.castle_id(0, 0)).attributes.integrity > 4, "repair does not stop the active project's free progress")
