extends "res://Scripts/Sim/U13BloodConduitTestRunner.gd"

const Play = preload("res://Scripts/Sim/U13PlayableSession.gd")
const KroniScenario = preload("res://Scripts/Sim/U13KroniScenario.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Ranged = preload("res://Scripts/Sim/U13RangedMarching.gd")

func run() -> void:
	cache_consistency()
	for banished in [false, true]: consume_presence(banished)
	ranged_cadence()
	print("U13 playable interaction failures: %d" % failures)
	quit(failures)

func cache_consistency() -> void:
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	if not check(game._owner.start("conduit", fixture("Gremory", 7), [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "UI cache fixture reaches planning"): return
	var play = Play.new()
	play._owner = game._owner
	var before: Dictionary = game.snapshot()
	var view: Dictionary = play.board_view()
	check(view == game._owner.player_view(0, 15), "cached UI projection equals authority")
	view.world.hand.clear()
	view.world.entities.clear()
	check(play.board_view() == game._owner.player_view(0, 15), "UI callers cannot mutate cached projection")
	var hand: Array = play.board_view().world.hand
	var orders: Array = [{}, {"guard_moves": [{"card_id": hand[0], "lane": "Castle", "slot": 0}]}, {"action": "Siege", "lane": "Castle", "target_id": Slots.castle_id(1, 0), "card_ids": [hand[0]]}, {"action": "Ward", "lane": "Lord", "card_ids": []}]
	var invalid: Dictionary = orders[2].duplicate(true)
	invalid["guard_moves"] = orders[1].guard_moves
	orders.append(invalid)
	for order in orders:
		var expected: Dictionary = game._owner.preview_submission(0, [], order)
		check(play.choose([], order) == expected and play.choose([], order) == expected, "cached cart admission matches full authority: " + str(order.get("action", "development")))
	check(game.snapshot() == before, "all UI previews leave the live match untouched")
	var planning = play._planning_cache
	play.choose([], {})
	check(play._planning_cache == planning, "card edits reuse one validated planning baseline")
	var original = preload("res://Scripts/Sim/U13BoardSession.gd").new()
	original._owner = game._owner
	check(play.power_status("PredatorOfRuin") == original.power_status("PredatorOfRuin"), "cached power clock equals original public clock")
	var worker = play._fork_for_job()
	check(worker._planning_cache == null and worker._read_owner == null, "worker never shares the UI planning cache")
	var revision: int = game._owner.revision()
	game._owner.submit(0, [], {})
	check(game._owner.revision() > revision and play.board_view().submitted, "submission invalidates the public view cache")
	check(play.choose([], orders[1]).action == "invalid", "cached legal guard is rejected after submission")
	revision = game._owner.revision()
	check(game._owner.restore(before).action != "invalid" and game._owner.revision() > revision and not play.board_view().submitted, "restore on the same owner invalidates cached state")
	check(play.choose([], orders[1]).action != "invalid", "restored planning accepts a fresh cart")
	game.submit([{"powers": [], "order": orders[1]}, {"powers": [], "order": {}}])
	play._owner = game._owner
	play.board_view()
	if not check(game.finish_round().action != "invalid", "cached fixture resolves normally"): return
	check(play.board_view() == game._owner.player_view(0, 15), "hook advancement invalidates cached views")
	game.next_round()
	planning_with_market_passes(game)
	check(play.board_view().round == 2 and play.board_view() == game._owner.player_view(0, 15), "next round refreshes cards and guard state")
	check(play.choose([], orders[1]).action == "invalid", "last round's guard payment cannot be reused")
	var absent: Dictionary = fixture("Gremory", 7)
	patch(absent, absent.players[0].lord_entity_id, {"alive": false})
	var replacement = Game.new()
	replacement._owner = Game.Content.new().create_combat_match(true)
	replacement._owner.start("conduit", absent, [0, 1])
	planning_with_market_passes(replacement)
	play._owner = replacement._owner
	check(play.board_view() == replacement._owner.player_view(0, 15), "replacing the owner invalidates UI caches")
	var quote: Dictionary = play.summon_preview([])
	check(quote == Return.quote(replacement.snapshot().world, 0, []) and play.summon_preview([]) == quote, "resummon quote agrees without copying replay history")

func consume_presence(banished: bool) -> void:
	var world: Dictionary = fixture("Kroni", 7)
	patch(world, Slots.castle_id(0, 0), {"integrity": 1})
	world.data.sigils[0].Lord = ""
	var guard: String = world.data.card_zones.hands[1][0]
	world.data.card_zones.hands[1].erase(guard)
	patch(world, guard, {"role": "guard", "lane": "Lord", "slot": 0})
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	if not check(game._owner.start("conduit", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "Consume fixture, banished=" + str(banished)): return
	var power: Dictionary = KroniScenario.source(0, 1, {"entity_id": guard}, 0, "Consume")
	var attack: Dictionary = {"action": "Hunt", "lane": "Lord", "target_id": world.players[0].lord_entity_id, "card_ids": game._owner.player_view(1, 0).world.hand} if banished else {}
	if not check(game.submit([{"powers": [power], "order": {}}, {"powers": [], "order": attack}]).action != "invalid" and game.finish_round().action != "invalid", "Consume queues before combat"): return
	check(row(game.snapshot().world, world.players[0].lord_entity_id).attributes.alive != banished, "Kroni presence reflects the actual Hunt")
	var restored = Game.new()
	if not check(restored.restore_json(game.snapshot_json()).action != "invalid", "pending Consume restores after combat"): return
	game.next_round(); restored.next_round()
	var cursor: int = game._owner._event_cursor()
	check(game.step().action != "invalid" and restored.step().action != "invalid" and game.snapshot() == restored.snapshot(), "Consume firing replays exactly")
	var events: Array = game._owner._player_events_since(0, cursor)
	if banished:
		check(events.any(func(e): return e.type == "FIZZLE_INVALID_TARGET" and e.data.get("result", {}).get("reason") == "kroni_source_banished"), "absent Kroni's Consume fizzles")
		check(not events.any(func(e): return e.type == "GUARD_DEVOURED") and row(game.snapshot().world, guard).attributes.role == "guard", "banished Consume leaves its guard untouched")
		check(game.snapshot().world.data.kroni_fed[0] != 2, "banished Consume grants no feeding credit")
	else:
		check(events.any(func(e): return e.type == "GUARD_DEVOURED" and e.data.cause == "Consume"), "living Kroni still consumes the selected guard")
	check(not game._owner.player_view(0, 0).pending.any(func(e): return e.declaration.power_id == "Consume"), "resolved or fizzled Consume leaves the queue")

func ranged_cadence() -> void:
	var world: Dictionary = fixture("Gremory", 7)
	var registry = Game.Content.Ids.new()
	registry.restore(world.entities)
	var a: Dictionary = Marching.profile("Vulture", "Castle", 0, 0, 1, true)
	a.x_fp = 600; a.y_fp = 300
	var vulture: String = registry.create("marcher", "cadence", 0, 0, a).entity.id
	var b: Dictionary = Marching.profile("Butcher", "Castle", 1, 0, 1, true)
	b.x_fp = 1200; b.y_fp = 300; b.hp = 100; b.max_hp = 100
	registry.create("marcher", "cadence", 1, 1, b)
	world.entities = registry.snapshot()
	var ids = Marching.Buffer.new()
	ids.restore(world.entities)
	var ticks: Array = []
	var context: Dictionary = {"round": 1, "hook": Game.Timeline.MARCHING}
	var react: Callable = func(w, _event, _seed, _order): return {"action": "resolved", "world": w, "events": []}
	for tick in range(65):
		var result: Dictionary = Ranged.volley(world, ids, context, {}, tick, {}, react)
		if not result.events.is_empty(): ticks.append(tick)
		if tick == 0:
			var unit: Dictionary = ids.get_entity(vulture)
			check(not Ranged.melee_ready(unit, 207) and Ranged.melee_ready(unit, 208) and not Ranged.ready(unit, 208), "ranged recovery leaves melee ready after eight ticks")
		if tick == 15:
			var fresh = Marching.Buffer.new()
			check(fresh.restore(bytes_to_var(var_to_bytes(ids.snapshot()))).action != "invalid", "separate ranged and melee clocks save exactly")
			ids = fresh
	check(ticks == [0, 32, 64], "Vulture ranged frequency is reduced by 75 percent")
	check(Marching.EXCHANGE_TICKS == 8 and not ids.get_entity(vulture).attributes.armor_bypass, "melee cadence and no armor piercing are preserved")
	var unit: Dictionary = ids.get_entity(vulture)
	unit.attributes.x_fp = 1000
	ids.update(unit.id, unit.owner, unit.attributes)
	for enemy in ids.marchers():
		if enemy.owner != 1: continue
		enemy.attributes.x_fp = 1170
		enemy.attributes.hp = 5
		enemy.attributes.max_hp = 5
		enemy.attributes.armor = 1
		ids.update(enemy.id, enemy.owner, enemy.attributes)
	world.entities = ids.snapshot()
	context.merge({"world": world, "seed": "melee-cadence", "player_order": [0, 1], "persistent_effects": []})
	var battle: Dictionary = Marching.resolve(context, react)
	if check(battle.action != "invalid", "ranged-to-melee transition runs the full Marching phase"):
		var contacts: Array = battle.events.filter(func(e): return e.event.type == "MARCHER_CONTACT")
		var clashes: Array = battle.events.filter(func(e): return e.event.type == "MARCHER_CLASH")
		check(not contacts.is_empty() and contacts[0].event.data.tick == 72, "melee starts after eight-tick recovery, before ranged reload ends")
		check(not clashes.is_empty() and clashes[0].event.data.end_tick == 80 and clashes[0].event.data.exchanges.size() == 2, "melee exchanges retain their original eight-tick cadence")
		var replay: Dictionary = Marching.resolve(bytes_to_var(var_to_bytes(context)), react)
		check(replay == battle, "separate attack clocks replay the whole phase exactly")
