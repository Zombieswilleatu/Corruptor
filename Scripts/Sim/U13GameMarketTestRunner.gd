extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

const Market = preload("res://Scripts/Sim/U13GameMarket.gd")

func run() -> void:
	var game = Game.new()
	if not check(game.start("market-test", ["Gremory", "Gremory"], [Slots.TYPES, Slots.TYPES]).action != "invalid", "market opening"):
		quit(1)
		return
	# This directed exchange uses seat 0 first; separate cases below cover both.
	while game.player_view(0).world.game_market.first_player != 0:
		var next_seed: String = game._owner.rng_seed() + "x"
		game = Game.new()
		game.start(next_seed, ["Gremory", "Gremory"], [Slots.TYPES, Slots.TYPES])
	var initial: Dictionary = game.player_view(0).world
	check(initial.market.size() == 3 and initial.deck_count == 47, "market dealt before opening hands")
	check(initial.market.all(func(id): return initial.entities.any(func(e): return e.id == id and e.owner == -1)), "offers and card faces are public")
	check(game.to_planning().action == "game_market_choice" and game.player_view(0).world.market == initial.market, "opening market stays through round one draw")
	var before: Dictionary = game.snapshot()
	check(game.step().action == "invalid" and game.snapshot() == before, "market must finish before planning")
	var take: String = initial.market[0]
	var give: String = game.player_view(0).world.hand[0]
	var hand_size_before_swap: int = game.player_view(0).world.hand.size()
	check(game.choose_market(1, {"market": "Swap", "take_id": take, "give_id": game.player_view(1).world.hand[0]}).action == "invalid" and game.snapshot() == before, "second player cannot act early")
	check(game.choose_market(0, {"market": "Swap", "take_id": give, "give_id": take}).action == "invalid" and game.snapshot() == before, "reversed or foreign card zones rejected atomically")
	var corrupt: Dictionary = before.duplicate(true)
	corrupt.world.data.card_zones.market.append(take)
	check(game.restore(corrupt).action == "invalid" and game.snapshot() == before, "duplicate market identity rejected on restore")
	var replay = Game.new()
	check(replay.restore(JSON.parse_string(JSON.stringify(before))).action != "invalid", "save at first market choice")
	var swap: Dictionary = {"market": "Swap", "take_id": take, "give_id": give}
	check(game.choose_market(0, swap).action != "invalid" and replay.choose_market(0, swap).action != "invalid" and game.snapshot() == replay.snapshot(), "first swap replays exactly")
	check(take in game.player_view(0).world.hand and give in game.player_view(1).world.market and game.player_view(0).world.hand.size() == hand_size_before_swap, "swap preserves hand size and returns payment to public row")
	before = game.snapshot()
	check(game.choose_market(0, {"market": "Pass"}).action == "invalid" and game.snapshot() == before, "one choice per player")
	check(game.choose_market(1, {"market": "Swap", "take_id": take, "give_id": game.player_view(1).world.hand[0]}).action == "invalid" and game.snapshot() == before, "stale taken offer rejected")
	var second = Game.new()
	check(second.restore(JSON.parse_string(JSON.stringify(before))).action != "invalid", "save between market seats")
	var swap_back: Dictionary = {"market": "Swap", "take_id": give, "give_id": game.player_view(1).world.hand[0]}
	check(game.choose_market(1, swap_back).action != "invalid" and second.choose_market(1, swap_back).action != "invalid" and game.snapshot() == second.snapshot(), "second player can take newly offered card")
	check(game.to_planning().action == "game_planning", "both choices unlock planning")
	var pass_plan: Dictionary = {"powers": [], "order": {}}
	check(game.submit([pass_plan, pass_plan]).action != "invalid" and game.finish_round().action != "invalid", "market round completes normally")
	var old: Array = game.player_view(0).world.market
	check(game.next_round().action != "invalid", "next market round")
	var saved = Game.new()
	check(saved.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", "save before rollover")
	check(game.to_planning().action == "game_market_choice" and saved.to_planning().action == "game_market_choice" and saved.snapshot() == game.snapshot(), "refresh replay matches before decisions")
	check(game.player_view(0).world.market.all(func(id): return id not in old) and game.snapshot().world.data.card_zones.deck.slice(0, 3) == [old[2], old[1], old[0]], "fresh row then old offers below draw pile")
	check(game.to_planning(true).action == "game_planning" and saved.to_planning(true).action == "game_planning" and game.snapshot() == saved.snapshot(), "Random-Legal market choices replay")
	var seen: Array = []
	for index in range(12):
		var sample = Game.new()
		sample.start("slaver-priority:%d" % index, ["Gremory", "Gremory"], [Slots.TYPES, Slots.TYPES])
		var first: int = sample.player_view(0).world.game_market.first_player
		if first not in seen:
			seen.append(first)
		check(sample.to_planning().player_id == first, "seeded first visitor reaches Slaver")
		check(sample.choose_market(first, {"market": "Pass"}).action != "invalid" and sample.to_planning().player_id == 1 - first, "other visitor follows first")
		check(sample.choose_market(1 - first, {"market": "Pass"}).action != "invalid" and sample.to_planning().action == "game_planning", "both priority orders complete")
	check(seen.size() == 2, "both seeded first visitors covered")
	scarcity()
	print("U13 game market failures: %d" % failures)
	quit(failures)

func scarcity() -> void:
	var world: Dictionary = Economy.initialize(Game.Scenario.loadout_world(["Gremory", "Gremory"], [Slots.TYPES, Slots.TYPES]), "market-scarce").world
	var original: Array = world.data.card_zones.market.duplicate()
	var ids = Game.Content.Ids.new()
	ids.restore(world.entities)
	for row in world.entities.entities:
		if row.kind == "card" and row.id not in original:
			ids.retire(row.id)
	world.entities = ids.snapshot()
	world.data.card_zones.hands = [[], []]
	world.data.card_zones.deck = []
	world.data.card_zones.discard = []
	world.data.game_market.round = 1
	var reused: Dictionary = Market.begin(world, "market-scarce", 2)
	check(reused.action != "invalid" and Cards.valid(reused.world) and reused.world.data.card_zones.market.size() == 3 and reused.world.data.card_zones.market.all(func(id): return id in original), "fully exhausted refresh reuses old offers without duplication")
	var context: Dictionary = {"world": reused.world, "seed": "market-scarce", "round": 2, "hook": Game.Timeline.PRESENT_PUBLIC_STATE, "player_id": reused.world.data.game_market.first_player, "choice": {"market": "Pass"}}
	check(Market.choose(context).action != "invalid", "empty hand can pass market")
