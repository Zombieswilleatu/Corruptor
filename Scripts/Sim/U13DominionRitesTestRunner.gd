extends "res://Scripts/Sim/U13BloodConduitTestRunner.gd"

const Rites = preload("res://Scripts/Sim/U13DominionRites.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Development = preload("res://Scripts/Sim/U13GameDevelopment.gd")


func base() -> Dictionary:
	var world: Dictionary = fixture()
	world.data.neutral_tears = 7
	world.players[0].resources.souls = 4
	for slot in [0, 1]:
		patch(world, Slots.castle_id(0, slot), {"status": "ruined", "integrity": 0})
	while world.data.card_zones.hands[0].size() < 4:
		Cards.draw(world, 0, "rites", "fixture")
	for id in world.data.card_zones.hands[0]:
		patch(world, id, {"value": 5})
	return world


func waiters(world: Dictionary, count: int, lane: String = "Lord", pid: int = 0) -> Array:
	var registry = Game.Content.Ids.new()
	registry.restore(world.entities)
	var result: Array = []
	for index in range(count):
		var attributes: Dictionary = Marching.profile("Penitent", lane, pid, 0, 1)
		attributes.waiting = true
		attributes.waiting_since_round = 1
		attributes.x_fp = Marching.LANE_FP if pid == 0 else 0
		var made: Dictionary = registry.create("marcher", "rites:%d:%s" % [pid, lane], index, pid, attributes)
		result.append(made.entity.id)
	world.entities = registry.snapshot()
	return result


func choice(ids: Array, lane: String = "Lord") -> Dictionary:
	return {"rites": {"waiter_spends": [{"lane": lane, "marcher_ids": ids}]}}


func perform(world: Dictionary, order: Dictionary) -> Dictionary:
	var reserved: Dictionary = Rites.reserve({"world": world, "player_id": 0, "order": order, "round": 1})
	if reserved.action == "invalid":
		return reserved
	reserved = Rites.reserve({"world": reserved.world, "player_id": 1, "order": {}, "round": 1})
	return Rites.resolve({"world": reserved.world, "hook": Game.Timeline.DEVELOPMENT, "round": 1, "player_order": [0, 1]})


func run() -> void:
	var world: Dictionary = base()
	var ids: Array = waiters(world, 10)
	check(Game.Content.new().valid_world(world), "directed rite fixture is a valid production world")
	var before: Dictionary = world.duplicate(true)
	var order: Dictionary = choice(ids.slice(0, 5))
	var result: Dictionary = perform(world, order)
	check(result.action != "invalid" and result.world.players[0].resources.personal_tears == 1 and result.world.players[0].resources.souls == 4 and result.world.data.neutral_tears == 7, "five waiters buy one personal Tear without Souls or neutral Tears")
	check(world == before and result.world.entities.entities.filter(func(e): return e.kind == "marcher").size() == 5, "only selected bodies retire; transform preserves its input")
	check(result.events.size() == 1 and result.events[0].event.type == "PERSONAL_TEAR_CREATED", "spending is not a combat death or kill reward")
	check(Game.Content.new().valid_world(result.world), "waiter retirement keeps all-Lord state valid")
	check(Rites.resolve({"world": result.world, "hook": Game.Timeline.DEVELOPMENT, "round": 1, "player_order": [0, 1]}).action == "invalid", "same Development cannot pay twice")
	order.rites.waiter_spends.append({"lane": "Lord", "marcher_ids": ids.slice(5)})
	result = perform(world, order)
	check(result.world.players[0].resources.personal_tears == 2, "ten distinct waiters allow two exchanges without an invented round cap")
	order.rites.waiter_spends[1].marcher_ids[0] = ids[0]
	check(Rites.validate(world, 0, order).action == "invalid", "one waiter cannot fund two Tears")
	for bad in [ids.slice(0, 4), ids.slice(0, 6), [ids[0], ids[0], ids[1], ids[2], ids[3]]]:
		check(Rites.validate(world, 0, choice(bad)).action == "invalid", "wrong count or repeated physical ID rejected")
	check(Rites.validate(world, 1, choice(ids.slice(0, 5))).action == "invalid", "enemy waiters cannot be spent")
	patch(world, ids[0], {"waiting": false, "waiting_since_round": 0})
	check(Rites.validate(world, 0, choice(ids.slice(0, 5))).action == "invalid", "moving Marcher cannot pay")
	patch(world, ids[0], {"waiting": true, "lane": "Castle"})
	check(Rites.validate(world, 0, choice(ids.slice(0, 5))).action == "invalid", "mixed lanes cannot pay")
	world = base()
	var payment: Array = world.data.card_zones.hands[0].slice(0, 3)
	order = {"rites": {"invocation": {"card_ids": payment}, "profane_ruins": {"castle_id": Slots.castle_id(0, 0)}}}
	result = perform(world, order)
	check(result.action != "invalid" and result.world.players[0].resources.personal_tears == 2 and result.world.players[0].resources.souls == 2, "Invocation and Profane the Ruins compose with their real costs")
	check(result.world.data.dominion_rites.invocation_rounds[0] == 1 and row(result.world, Slots.castle_id(0, 0)).attributes.status == "profaned" and row(result.world, Slots.castle_id(0, 1)).attributes.status == "ruined", "Invocation use persists; Profane affects one physical ruin")
	check(payment.all(func(id): return id in result.world.data.card_zones.discard) and Game.Content.new().valid_world(result.world), "Invocation payment is discarded and profaned structure remains valid")
	check(Rites.validate(result.world, 0, {"rites": {"invocation": {"card_ids": []}}}).reason == "invocation_already_used", "Invocation is once per match")
	var low: Dictionary = world.duplicate(true)
	low.data.neutral_tears = 6
	check(Rites.validate(low, 0, order).action == "invalid", "Veil six does not unlock Invocation")
	low = world.duplicate(true)
	low.players[0].resources.souls = 1
	check(Rites.validate(low, 0, order).action == "invalid", "Profane cannot borrow future Souls")
	low = world.duplicate(true)
	patch(low, Slots.castle_id(0, 1), {"status": "defunct"})
	check(Rites.validate(low, 0, order).action == "invalid", "one ruin plus a Defunct Castle does not satisfy two ruins")
	check(Rites.validate(world, 0, {"rites": {"invocation": {"card_ids": payment.slice(0, 2)}}}).action == "invalid", "ten card value does not pay eleven")
	var conflicting: Dictionary = order.duplicate(true)
	conflicting["guard_moves"] = [{"card_id": payment[0], "lane": "Lord", "slot": 0}]
	check(Rites.validate(world, 0, conflicting).action == "invalid", "Invocation cannot reuse a deployed guard card")
	for key in ["summon", "castle_action"]:
		conflicting = order.duplicate(true)
		conflicting[key] = {"card_ids": [payment[0]]}
		check(Rites.validate(world, 0, conflicting).action == "invalid", key + " cannot reuse Invocation payment")
	conflicting = order.duplicate(true)
	conflicting["castle_action"] = {"target_id": Slots.castle_id(0, 0)}
	check(Rites.validate(world, 0, conflicting).action == "invalid", "cannot reconstruct and profane the same ruin")
	for malformed in [null, [], {"unknown": true}, {"waiter_spends": {}}, {"invocation": []}, {"profane_ruins": {}}]:
		check(Rites.validate(world, 0, {"rites": malformed}).action == "invalid", "malformed rite rejects without mutation")
	replay_and_support()
	print("U13 Dominion rites failures: %d" % failures)
	quit(failures)


func replay_and_support() -> void:
	var world: Dictionary = base()
	var bodies: Array = waiters(world, 6, "Castle")
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match()
	if not check(game._owner.start("rites-game", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "rites fixture reaches real planning"):
		return
	var view: Dictionary = game.player_view(0)
	var hand: Array = view.world.hand
	var order: Dictionary = choice(bodies.slice(0, 5), "Castle")
	var payment: Array = []
	var value: int = 0
	for id in hand:
		payment.append(id)
		value += int(row(game.snapshot().world, id).attributes.value)
		if value >= Rites.INVOCATION_COST:
			break
	order.rites["invocation"] = {"card_ids": payment}
	order.rites["profane_ruins"] = {"castle_id": Slots.castle_id(0, 0)}
	var spare: Array = hand.filter(func(id): return id not in payment)
	order.merge({"action": "Siege", "lane": "Castle", "target_id": Slots.castle_id(1, 0), "card_ids": [spare[0]]})
	var saved: Dictionary = game.snapshot()
	var candidates: Array = Development.rite_orders(view, [], {}, "waiters")
	check(not game._owner.legal_order_candidates(0, [], candidates).is_empty(), "Random-Legal can propose and validate waiter spending")
	check(not game._owner.legal_order_candidates(0, [], Development.rite_orders(view, [], {}, "invocation")).is_empty(), "Random-Legal can propose Invocation")
	check(not game._owner.legal_order_candidates(0, [], Development.rite_orders(view, [], {}, "profane_ruins")).is_empty(), "Random-Legal can propose Profane the Ruins")
	check(game._owner.preview_submission(0, [], order).action != "invalid" and game.snapshot() == saved, "combined rite preview leaves the owner untouched")
	var illegal: Dictionary = order.duplicate(true)
	illegal.card_ids = [payment[0]]
	check(game._owner.legal_order_candidates(0, [], [order, illegal]) == [order], "bulk legality agrees with preview on shared combat payment")
	check(game.submit([{"powers": [], "order": order}, {"powers": [], "order": {"rites": {"bad": true}}}]).action == "invalid" and game.snapshot() == saved, "invalid second submission cannot charge first player")
	if not check(game.submit([{"powers": [], "order": order}, {"powers": [], "order": {}}]).action != "invalid", "all three rites seal alongside Siege"):
		return
	var support_checked: bool = false
	while not game._owner.next_hook().is_empty():
		var hook: String = game._owner.next_hook()
		var restored = Game.new()
		if not check(restored.restore(JSON.parse_string(JSON.stringify(game.snapshot()))).action != "invalid", "rite JSON restore before " + hook):
			return
		var advanced: Dictionary = game.step()
		var replayed: Dictionary = restored.step()
		if not check(advanced.action != "invalid" and replayed.action != "invalid" and game.snapshot() == restored.snapshot(), "rite deterministic step " + hook):
			print(advanced)
			return
		if hook == Game.Timeline.SUBMISSION_LOCK:
			var locked: Dictionary = game.snapshot()
			var forged: Dictionary = locked.duplicate(true)
			forged.world.data.dominion_rites.orders[0].choice.waiter_spends[0].marcher_ids[0] = bodies[5]
			check(game.restore(forged).action == "invalid" and game.snapshot() == locked, "forged waiter reservation rejects atomically")
			forged = locked.duplicate(true)
			forged.world.players[0].resources.souls += Rites.RUINS_SOUL_COST
			check(game.restore(forged).action == "invalid" and game.snapshot() == locked, "cannot restore Profane without paying Souls")
			forged = locked.duplicate(true)
			forged.world.data.card_zones.discard.erase(payment[0])
			forged.world.data.card_zones.hands[0].append(payment[0])
			check(game.restore(forged).action == "invalid" and game.snapshot() == locked, "cannot restore Invocation payment into Hand")
			check(not game.player_view(1).world.dominion_rites.has("orders"), "opponent projection does not expose sealed rite choices")
		if hook == Game.Timeline.DEVELOPMENT:
			check(game.snapshot().world.players[0].resources.personal_tears == 3, "all three personal Tears arrive during Development")
			var forged: Dictionary = game.snapshot().duplicate(true)
			forged.world.data.dominion_rites.invocation_rounds[0] = 0
			check(game.restore(forged).action == "invalid", "cannot erase current Invocation usage from a save")
		if hook == Game.Timeline.COMBAT_RESOLUTION:
			# Remaining waiter is consumed by real combat; selected five were
			# already retired. Inspect the authoritative event stream below.
			var snapshot_text: String = JSON.stringify(game.snapshot())
			support_checked = snapshot_text.contains('"waiters_consumed":["' + bodies[5] + '"]')
	check(support_checked, "real Siege consumes only the sixth waiter for support")
	check(game.next_round().action != "invalid" and planning_with_market_passes(game).action == "game_planning", "next round starts with persistent rite effects")
	check(game.player_view(0).world.dominion_rites.invocation_rounds[0] == 1, "Invocation remains used after round cleanup")
