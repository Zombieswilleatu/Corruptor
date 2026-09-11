extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

const Development = preload("res://Scripts/Sim/U13GameDevelopment.gd")

func run() -> void:
	for lord in Game.LORDS:
		var game = Game.new()
		if not check(game.start("development-plan-" + lord, [lord, "Gremory"], [Slots.TYPES, Slots.TYPES]).action != "invalid" and game.to_planning().action != "invalid", lord + " planning"):
			continue
		var before: Dictionary = game.snapshot()
		var plan: Dictionary = game.plan(0)
		if not check(plan.action != "invalid", lord + " complete random plan"):
			print(plan)
			continue
		var reserved: Array = Development.reserved_cards(plan.powers, plan.order)
		var unique: Dictionary = {}
		for id in reserved:
			unique[id] = true
		check(unique.size() == reserved.size() and game.snapshot() == before, lord + " no duplicate spending or planning mutation")
		if not check(game.submit([plan, {"powers": [], "order": {}}]).action != "invalid", lord + " legal joint lock"):
			continue
		check(game.step().action != "invalid" and game.step().action != "invalid", lord + " reaches Development result")
		var replay = Game.new()
		check(replay.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", lord + " Development result saves and restores")
		print("PLAN %s: power=%d castle=%s summon=%s guards=%d combat=%s" % [lord, plan.powers.size(), plan.order.get("castle_action", {}).get("action", "Pass"), plan.order.has("summon"), plan.order.get("guard_moves", []).size(), plan.order.get("action", "Pass")])
	print("U13 game plan coverage failures: %d" % failures)
	quit(failures)
