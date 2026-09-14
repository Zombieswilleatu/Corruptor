extends "res://Scripts/Sim/U13BasicDoctrineTestRunner.gd"

func run() -> void:
	mark_in_full_game(2)
	mark_in_full_game(3)
	public_values()
	hidden_guard_boundary()
	print("U13 hunt ward doctrine failures: %d" % failures)
	quit(failures)

func mark_in_full_game(threat: int) -> void:
	var world: Dictionary = fixture("Orias")
	patch(world, Slots.castle_id(1, 0), {"integrity": 0, "status": "ruined"})
	patch(world, world.players[1].lord_entity_id, {"threat": threat})
	world.data.sigils[1].Lord = ""
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	if not check(game._owner.start("conduit", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "full-game Mark fixture threat " + str(threat)): return
	var order: Dictionary = {"action": "Hunt", "lane": "Lord", "target_id": world.players[1].lord_entity_id, "card_ids": game._owner.player_view(0, 0).world.hand, "fracture_target": "subjects"}
	if not check(game.submit([{"powers": [], "order": order}, {"powers": [], "order": {}}]).action != "invalid", "full-game Mark Hunt seals"): return
	var replay = Game.new()
	check(replay.restore_json(game.snapshot_json()).action != "invalid", "full-game Mark sealed restore")
	var resolved: Dictionary = game.finish_round()
	if not check(resolved.action != "invalid", "full-game Mark resolves: " + str(resolved)): return
	check(replay.finish_round().action != "invalid" and replay.snapshot() == game.snapshot(), "full-game Mark replay exact")
	var state: Dictionary = game.snapshot().world
	var victim: Dictionary = row(state, world.players[1].lord_entity_id)
	check(not victim.attributes.alive and victim.attributes.threat == 0, "banishment resets live entity Threat")
	check((state.data.orias_marks[1] != null) == (threat >= 3), "full-game Mark uses pre-reset Threat threshold")
	var facts: Array = game._owner._player_selected_events_since(0, 0, ["LORD_BANISHED", "ORIAS_MARKED"])
	var banished: Array = facts.filter(func(e): return e.type == "LORD_BANISHED")
	check(banished.size() == 1 and banished[0].data.lord.attributes.threat == threat, "banishment fact preserves pre-reset Threat")
	var marks: Array = facts.filter(func(e): return e.type == "ORIAS_MARKED")
	check(marks.size() == (1 if threat >= 3 else 0), "exactly one Mark reward above threshold")
	check(state.players[0].resources.souls == world.players[0].resources.souls + (4 if threat >= 3 else 2), "normal plus Mark Souls paid exactly")
	check(replay.restore_json(game.snapshot_json()).action != "invalid" and replay.snapshot() == game.snapshot(), "full-game Mark final save restores")

func public_values() -> void:
	var game = Game.new()
	game.start("hunt-ward-values", ["Orias", "Gremory"], [Slots.TYPES, Slots.TYPES], true)
	Bot.to_planning(game)
	var original: Dictionary = Bot.BotPlanning.new(game._owner, 0).player_view(0, 0)
	var c = Bot.Context.new(original.duplicate(true))
	c.w.opponent_hand_count = 0
	var own: Dictionary = c.select("lord", 0)[0]
	var target: Dictionary = c.select("lord", 1)[0]
	var hunt: Dictionary = {"action": "Hunt", "lane": "Lord", "target_id": target.id, "card_ids": []}
	var keep: Dictionary = c.castles(1).filter(func(e): return e.attributes.castle_type == "Keep")[0]
	keep.attributes.integrity = 21
	var small: float = Bot.Common.HuntWard.hunt(c, hunt, 2)
	var useful: float = Bot.Common.HuntWard.hunt(c, hunt, 10)
	check(useful > small + 5, "Hunt values real Keep damage without a banishment")
	# Pursuit cannot appear beyond a Guard who stopped the attack at equality.
	c.w.entities.append({"id": "known-guard", "kind": "card", "owner": 1, "attributes": {"role": "guard", "lane": "Lord", "slot": 0, "value": 5}})
	check(Bot.Common.HuntWard.hunt(c, hunt, 4) == 0, "Pursuit is screened before Guard equality")
	check(Bot.Common.HuntWard.hunt(c, hunt, 5) > 0, "crossing Guard threshold earns Orias setup value")
	var ward: Dictionary = {"action": "Ward", "lane": "Lord", "card_ids": []}
	c.w.sigils[0].Lord = ""
	own.attributes.threat = 0
	var quiet: float = Bot.Common.combat_score(c, ward)
	own.attributes.threat = 3
	check(Bot.Common.combat_score(c, ward) > quiet, "Lord Ward values an actual defense recovery breakpoint")
	c.w.sigils[0].Lord = "fresh"
	check(Bot.Common.combat_score(c, ward) < quiet + 5, "fresh Sigil is not valued as another new Sigil")
	own.attributes.threat = 1
	var conduit: Dictionary = Bot.Common.HuntWard.circle(c, 0)
	# The opening may still have its Circle under construction; activate only
	# this scoring view, never the authoritative game.
	if conduit.is_empty():
		conduit = c.select("castle", 0).filter(func(e): return e.attributes.castle_type == "SummoningCircle")[0]
		conduit.attributes.construction_state = "active"
		conduit.attributes.status = "standing"
	conduit.attributes.integrity = 12
	var healthy_cost: float = Bot.Common.HuntWard.snare_cost(c)
	conduit.attributes.integrity = 9
	check(Bot.Common.HuntWard.snare_cost(c) > healthy_cost, "Snare prices operational Circle loss above integrity cost")
	check(not Bot.Powers.orias(c).any(func(x): return x.payload.power_id == "Snare"), "Snare does not spend Threat against an empty hand")
	own.attributes.threat = 4
	c.w.opponent_hand_count = 8
	check(not Bot.Powers.orias(c).any(func(x): return x.payload.power_id == "Snare"), "Snare does not trap Orias at minimum defense against a full hand")
	c.w.opponent_hand_count = 0
	c.w.entities.append({"id": "ward-waiter-lord", "kind": "marcher", "owner": 1, "attributes": {"lane": "Lord", "waiting": true}})
	var one_lane: float = Bot.Common.HuntWard.ward(c, ward, 4)
	c.w.entities.append({"id": "ward-waiter-castle", "kind": "marcher", "owner": 1, "attributes": {"lane": "Castle", "waiting": true}})
	check(Bot.Common.HuntWard.ward(c, ward, 4) == one_lane, "Ward does not add mutually exclusive attack lanes together")
	check(Bot.BotPlanning.new(game._owner, 0).player_view(0, 0) == original, "all scoring leaves public authority unchanged")
