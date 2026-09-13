extends "res://Scripts/Sim/U13BasicDoctrineTestRunner.gd"

func run() -> void:
	var game = Game.new()
	game.start("wish-doctrine-v3", ["Kanifous", "Odradek"], [Slots.TYPES, Slots.TYPES], true)
	Bot.to_planning(game)
	var c = Bot.Context.new(Bot.BotPlanning.new(game._owner, 0).player_view(0, 0))
	c.w.entities = c.w.entities.filter(func(e): return e.kind != "marcher" and e.attributes.get("role") != "guard")
	for x in [500, 700, 900]:
		c.w.entities.append({"id": "enemy:" + str(x), "kind": "marcher", "owner": 1, "attributes": {"lane": "Castle", "x_fp": x, "y_fp": 300, "waiting": false}})
	check(not Bot.Powers.kanifous(c).any(func(x): return x.payload.power_id == "WishDeath"), "Death does not count victims outside its actual radius")
	var enemies: Array = c.select("marcher", 1)
	enemies[1].attributes.x_fp = 550
	check(Bot.Powers.kanifous(c).any(func(x): return x.payload.power_id == "WishDeath"), "Death values a cluster inside its actual radius")
	check(not Bot.Powers.kanifous(c).any(func(x): return x.payload.power_id == "WishResurrection"), "Resurrection never invents guards in a bare zone")
	c.w.hand = c.w.hand.slice(0, 1)
	c.w.souls[0] = 12
	check(Bot.Powers.kanifous(c).any(func(x): return x.payload.power_id == "WishWealth"), "Wealth replenishes depleted cards even with plentiful souls")
	var full: Array = c.w.hand.duplicate()
	while c.w.hand.size() < Economy.HAND_LIMIT: c.w.hand.append(full[0])
	check(not Bot.Powers.kanifous(c).any(func(x): return x.payload.power_id == "WishWealth"), "Wealth has no value with no hand space")
	c.w.hand = full
	var castle: Dictionary = c.castles(0)[0]
	castle.attributes.integrity = castle.attributes.max_integrity - 10
	check(Bot.Powers.kanifous(c).any(func(x): return x.payload.power_id == "WishLongevity"), "Longevity still values a damaged active castle")
	var debts: Array = []
	var before: Array = Bot.Powers.kanifous(c)
	for i in range(4): debts.append({"owner": 0})
	c.w.wish_prices = debts
	var after: Array = Bot.Powers.kanifous(c)
	check(after.filter(func(x): return x.payload.power_id == "WishLongevity")[0].score < before.filter(func(x): return x.payload.power_id == "WishLongevity")[0].score, "Outstanding public debts reduce wish utility")
	check(not after.any(func(x): return x.payload.power_id == "WishWealth"), "Several unpaid Prices stop repeated marginal Wealth wishes")
	c = Bot.Context.new(Bot.BotPlanning.new(game._owner, 1).player_view(1, 0))
	c.w.entities = c.w.entities.filter(func(e): return e.kind != "marcher" and e.attributes.get("role") != "guard")
	for owner_id in [0, 1]:
		c.w.entities.append({"id": "cluster:" + str(owner_id), "kind": "marcher", "owner": owner_id, "attributes": {"lane": "Lord", "x_fp": 1200, "y_fp": 300, "waiting": false}})
	for resource in [1, 2]:
		c.w.reconfiguration[1] = resource
		check(Bot.Powers.odradek(c).is_empty(), "Bank toward a useful Shift at resource " + str(resource))
	c.w.reconfiguration[1] = 3
	check(Bot.Powers.odradek(c).any(func(x): return x.payload.power_id == "AllegianceShift" and x.score == 5.0), "Shift becomes useful at three points without friendly-fire penalty")
	c.w.entities = c.w.entities.filter(func(e): return e.kind != "marcher")
	check(Bot.Powers.odradek(c).is_empty(), "No resource quota forces a spell on an empty board")
	for slot in range(3):
		for owner_id in [0, 1]:
			c.w.entities.append({"id": "guard:%d:%d" % [owner_id, slot], "kind": "card", "owner": owner_id, "attributes": {"role": "guard", "lane": "Lord", "slot": slot, "concealed": owner_id == 0, "value": 3}})
	c.w.reconfiguration[1] = 4
	check(not Bot.Powers.odradek(c).any(func(x): return x.payload.power_id == "Inversion"), "Inversion accounts for full receiving guard slots")
	c.w.entities = c.w.entities.filter(func(e): return e.kind != "card" or e.owner != 1)
	check(Bot.Powers.odradek(c).any(func(x): return x.payload.power_id == "Inversion"), "Inversion values enemy guards when receiving slots are open")
	check(game._owner.preview_submission(0, Bot.plan(game._owner, 0).powers, Bot.plan(game._owner, 0).order).action != "invalid", "Wish changes produce an admitted complete cart")
	print("U13 wish doctrine failures: %d" % failures)
	quit(failures)
