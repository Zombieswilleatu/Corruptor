extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

const WardCombat = preload("res://Scripts/Sim/U13Combat.gd")

func run() -> void:
	for name in Monsters.NAMES:
		var w: Dictionary = fixture()
		var cards: Array = []
		for suit in Monsters.ROSTER[name].recipe:
			var available: Array = w.entities.entities.filter(func(r): return r.kind == "card" and r.attributes.suit == suit)
			for i in range(Monsters.ROSTER[name].recipe[suit]):
				cards.append(available[i].id)
		for lane in ["Lord", "Castle"]:
			var order: Dictionary = {"action": "Ward", "lane": lane, "card_ids": cards, "monster_choice": name}
			check(not WardCombat.order_shape(order), name + " Ward shape rejected")
			check(Monsters.validate_choice(w, 0, order).action == "invalid", name + " Ward recipe rejected")
			var raw: Dictionary = WardCombat._reveal({"world": w, "round": 1, "seed": "ward-recipe", "player_order": [0, 1], "combat_orders": [order, {}]})
			check(raw.action == "invalid", "reveal cannot bypass Ward recipe admission")
			order.erase("monster_choice")
			check(WardCombat.order_shape(order), "normal Ward shape retained")
			var existing: Dictionary = put(w, "Kopita", 0, 200)
			var before: Dictionary = w.duplicate(true)
			raw = WardCombat._reveal({"world": w, "round": 1, "seed": "ward-recipe", "player_order": [0, 1], "combat_orders": [order, {}]})
			check(raw.action == "resolved", "normal Ward still recruits")
			check(w == before, "native reveal leaves input unchanged")
			if raw.action == "resolved":
				var total: int = 0
				for suit in Marching.SUITS:
					var printed: int = 0
					for row in w.entities.entities:
						if row.kind == "card" and row.id in cards and row.attributes.suit == suit: printed += int(row.attributes.value)
					total += floori(printed / 2.0)
				check(facts(raw, "MARCHER_SPAWNED").size() == total, "Ward recruits at 2:1")
				check(facts(raw, "MONSTER_SUMMONED").is_empty(), "Ward creates no monsters")
				check(raw.world.entities.entities.any(func(r): return r.id == existing.id), "existing field monster preserved")
			# Each lane case starts fresh, including deterministic entity identities.
			w = fixture()
		for action in ["Hunt", "Siege"]:
			w = fixture()
			var order: Dictionary = {"action": action, "lane": "Lord" if action == "Hunt" else "Castle", "target_id": "fixture-target", "card_ids": cards, "monster_choice": name}
			check(WardCombat.order_shape(order), action + " recipe shape retained")
			check(Monsters.validate_choice(w, 0, order).action == "legal", action + " recipe retained")
			var raw: Dictionary = WardCombat._reveal({"world": w, "round": 1, "seed": "ward-recipe", "player_order": [0, 1], "combat_orders": [order, {}]})
			check(raw.action == "resolved", action + " summons")
			if raw.action == "resolved":
				var total: int = 0
				for suit in Marching.SUITS:
					var printed: int = 0
					for row in w.entities.entities:
						if row.kind == "card" and row.id in cards and row.attributes.suit == suit: printed += int(row.attributes.value)
					total += floori(printed / 3.0)
				var normal: Array = facts(raw, "MARCHER_SPAWNED").filter(func(r): return not r.attributes.has("monster_id"))
				check(normal.size() == total, action + " recruits at 3:1")
				check(facts(raw, "MONSTER_SUMMONED").size() == 1, action + " one recipe summon")
	board = Board.new()
	root.add_child(board)
	await process_frame
	var w: Dictionary = fixture()
	var ids: Array = []
	for row in w.entities.entities:
		if row.kind == "card" and row.attributes.suit == "Penitent" and ids.size() < 2: ids.append(row.id)
	board._visible_world = {"entities": w.entities.entities, "monsters": w.data.monsters}
	board._draft_combat = {"action": "Ward", "lane": "Lord", "card_ids": ids}
	board.monster_choice = "Lemek"
	board._sync_monsters()
	check(board.monster_choice.is_empty() and board.monster_picker.disabled, "Ward clears and disables recipe picker")
	check("Lemek" in board._available_monsters(ids, "Hunt"), "Hunt picker exposes recipe")
	check("Lemek" in board._available_monsters(ids, "Siege"), "Siege picker exposes recipe")
	board.queue_free()
	print("U13 Ward recipe failures: ", failures)
	quit(1 if failures else 0)
