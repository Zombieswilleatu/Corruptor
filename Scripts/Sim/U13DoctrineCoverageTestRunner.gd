extends "res://Scripts/Sim/U13BasicDoctrineTestRunner.gd"

const Marching = preload("res://Scripts/Sim/U13Marching.gd")

func run() -> void:
	for power in ["Inversion", "WishPower", "WishResurrection"]:
		var low = opportunity(power, 1)
		var high = opportunity(power, 5)
		if low == null or high == null: continue
		var low_c = Bot.Context.new(Bot.BotPlanning.new(low._owner, 0).player_view(0, 0))
		var high_c = Bot.Context.new(Bot.BotPlanning.new(high._owner, 0).player_view(0, 0))
		var selected: Array = Bot.choose_power(Bot.BotPlanning.new(low._owner.planning_session(0), 0), 0, low_c, {})
		var repeated: Array = Bot.choose_power(Bot.BotPlanning.new(high._owner.planning_session(0), 0), 0, high_c, {})
		if not check(selected.size() == 1 and selected[0].power_id == power, power + " wins selection in a favorable public position"):
			continue
		check(low_c.view == high_c.view and selected == repeated, power + " selection is independent of concealed enemy guard faces")
		var facade = Bot.BotPlanning.new(low._owner, 0)
		var plan: Dictionary = facade.canonical_plan({"powers": selected, "order": {}})
		var before: Dictionary = low.snapshot()
		check(low._owner.preview_submission(0, plan.powers, {}).action != "invalid" and low.snapshot() == before, power + " complete cart is legal and preview is read only")
		var replay = Game.new()
		if not check(replay.restore_json(low.snapshot_json()).action != "invalid", power + " opportunity saves exactly"): continue
		var opponent: Dictionary = {}
		if power == "WishResurrection":
			opponent = {"action": "Hunt", "lane": "Lord", "target_id": before.world.players[0].lord_entity_id, "card_ids": low._owner.player_view(1, 0).world.hand}
		var plans: Array = [plan, {"powers": [], "order": opponent}]
		if not check(low.submit(plans).action != "invalid" and replay.submit(plans).action != "invalid" and low.finish_round().action != "invalid" and replay.finish_round().action != "invalid" and low.snapshot() == replay.snapshot(), power + " accepted round replays exactly"): continue
		if power == "Inversion":
			var pending_save = Game.new()
			check(pending_save.restore_json(low.snapshot_json()).action != "invalid", power + " delayed order restores between rounds")
			low.next_round(); pending_save.next_round()
			check(low.step().action != "invalid" and pending_save.step().action != "invalid" and low.snapshot() == pending_save.snapshot(), power + " next-round transfer replays exactly")
		var events: Array = low._owner.player_view(0).events
		check(events.any(func(e): return e.type == "POWER_RESOLVED" and e.data.get("power_id") == power), power + " actually reaches resolution")
		if power == "Inversion":
			check(events.filter(func(e): return e.type == "GUARD_RECONFIGURED" and e.data.get("power") == power).size() == 3, "Inversion moves the entire three-guard source into the empty receiving zone")
		elif power == "WishResurrection":
			check(events.any(func(e): return e.type == "KANIFOUS_WISH_RESOLVED" and e.data.power == power and e.data.count == 3), "Resurrection actually restores the three guards lost to the opposing Hunt")
	print("U13 doctrine coverage failures: %d" % failures)
	quit(1 if failures else 0)

func place_guards(world: Dictionary, pid: int, lane: String, count: int, hidden_value: int = 3) -> void:
	for slot in range(count):
		var id: String = world.data.card_zones.hands[pid][0]
		world.data.card_zones.hands[pid].erase(id)
		patch(world, id, {"role": "guard", "lane": lane, "slot": slot, "value": hidden_value})

func opportunity(power: String, hidden_value: int):
	var odradek: bool = power == "Inversion"
	var world: Dictionary = fixture("Odradek" if odradek else "Kanifous", 21)
	if odradek:
		world.players[0].resources.reconfiguration = 3
		place_guards(world, 1, "Castle", 3, hidden_value)
	elif power == "WishResurrection":
		place_guards(world, 0, "Lord", 3)
		var ids = Game.Content.Ids.new()
		ids.restore(world.entities)
		for index in range(3):
			var a: Dictionary = Marching.profile("Penitent", "Lord", 1, 0, 1, true)
			a.x_fp = 300 + index * 500; a.y_fp = 300
			ids.create("marcher", "coverage-enemy", index, 1, a)
		world.entities = ids.snapshot()
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	var started: Dictionary = game._owner.start("conduit", world, [0, 1])
	var planning: Dictionary = planning_with_market_passes(game) if started.action != "invalid" else started
	return game if check(planning.action == "game_planning", power + " legal opportunity fixture") else null
