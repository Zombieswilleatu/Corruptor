extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

const Structures = preload("res://Scripts/Sim/U13Structures.gd")

func fixture(hand_count: int = 0, integrity: int = 7, construction: String = "active", copies: int = 1, supply: int = -1):
	var choices: Array = Slots.TYPES.duplicate()
	if copies == 2:
		choices[4] = "Stockpile"
	var world: Dictionary = Economy.initialize(Game.Scenario.loadout_world(["Gremory", "Gremory"], [choices, choices]), "stockpile").world
	var ids = Game.Content.Ids.new()
	ids.restore(world.entities)
	for pid in [0, 1]:
		for slot in ([3, 4] if copies == 2 else [3]):
			var castle: Dictionary = ids.get_entity(Slots.castle_id(pid, slot))
			castle.attributes.integrity = integrity
			castle.attributes.construction_state = construction
			castle.attributes.status = "standing"
			ids.update(castle.id, pid, castle.attributes)
	world.entities = ids.snapshot()
	for pid in [0, 1]:
		while world.data.card_zones.hands[pid].size() < hand_count:
			var drawn: Dictionary = Cards.draw(world, pid, "stockpile-fixture", "fill:%d" % pid)
			if not drawn.get("drawn", false):
				break
		Cards.discard(world, pid, world.data.card_zones.hands[pid].slice(hand_count))
	if supply >= 0:
		var retained: Array = world.data.card_zones.deck.slice(0, supply)
		ids.restore(world.entities)
		for card in world.entities.entities:
			if card.kind == "card" and card.id not in retained:
				ids.retire(card.id)
		world.entities = ids.snapshot()
		world.data.card_zones.deck = retained
		world.data.card_zones.discard = []
		world.data.card_zones.market = []
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match()
	if not check(game._owner.start("stockpile", world, [0, 1]).action != "invalid", "Stockpile directed match starts"):
		return null
	return game

func run() -> void:
	for copies in [1, 2]:
		var game = fixture(0, 7, "active", copies)
		if game == null:
			continue
		check(planning_with_market_passes(game).action == "game_draw_choice", "draw pauses for private choice")
		var before: Dictionary = game.snapshot()
		var offer: Dictionary = game.player_view(0).world.game_economy.stockpile_pending
		check(offer.card_ids.size() == 2 and game.player_view(0).world.hand.size() == 7, "one Stockpile benefit regardless of copies")
		check(not game.player_view(1).world.game_economy.stockpile_pending.has("card_ids") and game.player_view(1).world.hand.is_empty(), "opponent cannot see offered identities and waits for own draw")
		check(game.step().action == "invalid" and game.snapshot() == before, "cannot advance past unanswered choice")
		check(game.choose_stockpile(1, offer.card_ids[0]).action == "invalid" and game.snapshot() == before, "wrong player choice is atomic")
		var ordinary: String = game.player_view(0).world.hand.filter(func(id): return id not in offer.card_ids)[0]
		check(game.choose_stockpile(0, ordinary).action == "invalid" and game.snapshot() == before, "cannot select an old hand card")
		var corrupt: Dictionary = before.duplicate(true)
		corrupt.world.data.game_economy.stockpile_pending.card_ids[1] = offer.card_ids[0]
		check(game.restore(corrupt).action == "invalid" and game.snapshot() == before, "malformed offer restore is atomic")
		var restored = Game.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(before))).action != "invalid", "pending choice survives JSON restore")
		check(game.choose_stockpile(0, offer.card_ids[1]).action != "invalid" and restored.choose_stockpile(0, offer.card_ids[1]).action != "invalid" and game.snapshot() == restored.snapshot(), "same chosen identity replays draw continuation")
		check(game.player_view(0).world.hand.size() == 6 and offer.card_ids[1] in game.player_view(0).world.hand and offer.card_ids[0] in game.snapshot().world.data.card_zones.discard, "keep selected new card and discard other")
		var public_selections: Array = game.player_view(1).events.filter(func(e): return e.type == "STOCKPILE_SELECTED")
		check(public_selections.size() == 1 and not public_selections[0].data.has("keep_id"), "selection event hides kept identity")
		var after: Dictionary = game.snapshot()
		check(game.choose_stockpile(0, offer.card_ids[1]).action == "invalid" and game.snapshot() == after, "choice cannot resolve twice")
		check(game.to_planning(true).action == "game_planning" and restored.to_planning(true).action == "game_planning" and game.snapshot() == restored.snapshot(), "Random-Legal chooses through same deterministic path")
		var pass_plan: Dictionary = {"powers": [], "order": {}}
		check(game.submit([pass_plan, pass_plan]).action != "invalid" and restored.submit([pass_plan, pass_plan]).action != "invalid", "planning unlocks after both choices")
		check(game.finish_round().action != "invalid" and restored.finish_round().action != "invalid" and game.snapshot() == restored.snapshot(), "Stockpile round and Lord hooks replay exactly")
	for example in [[4, 7, "active", 10], [5, 7, "active", 10], [0, 6, "active", 5], [0, 7, "building", 5]]:
		var game = fixture(example[0], example[1], example[2])
		if game == null:
			continue
		check(planning_with_market_passes(game).action == "game_planning" and game.player_view(0).world.hand.size() == example[3], "cap and inactive Stockpile %s" % str(example))
	for supply in [0, 6, 7]:
		var scarce = fixture(0, 7, "active", 1, supply)
		if scarce == null:
			continue
		var advance: Dictionary = planning_with_market_passes(scarce)
		if supply == 7:
			check(advance.action == "game_draw_choice", "last two cards still offer a choice")
			var offered: Array = scarce.player_view(0).world.game_economy.stockpile_pending.card_ids
			check(scarce.choose_stockpile(0, offered[0]).action != "invalid" and planning_with_market_passes(scarce).action == "game_planning", "scarce draw resumes")
			check(scarce.player_view(1).world.hand == [offered[1]], "discard recycles into second player's draw in seat order")
		else:
			check(advance.action == "game_planning" and scarce.player_view(0).world.hand.size() == supply, "zero or one available extra card needs no choice")
	print("U13 Stockpile failures: %d" % failures)
	quit(failures)
