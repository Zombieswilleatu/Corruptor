extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

const Resummon = preload("res://Scripts/Sim/U13Resummoning.gd")
const Trace = preload("res://Scripts/Sim/U13ParityTrace.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")


func run() -> void:
	production_opening()
	all_lords_free()
	resummon_still_paid()
	restore_guards()
	one_castle_action_remains_canonical()
	export_openings()
	print("U13 opening economy failures: %d" % failures)
	quit(failures)


func production_opening() -> void:
	var no_keep: Array = [
		"Bastion", "Stockpile", "SiegeEngine", "SummoningCircle", "Bastion"
	]
	var two_circles: Array = [
		"SummoningCircle", "Bastion", "SummoningCircle", "Keep", "Stockpile"
	]
	var game = Game.new()
	if not check(
		game.start(
			"production-opening",
			["Odradek", "Kanifous"],
			[no_keep, two_circles]
		).action
		!= "invalid",
		"production opening accepts optional Keep and duplicate-cap loadouts"
	):
		return
	var world: Dictionary = game.snapshot().world
	var opening: Dictionary = world.data.game_economy.opening
	var states_ok: bool = true
	for pid in [0, 1]:
		for slot in range(Slots.SLOT_COUNT):
			var castle: Dictionary = entity(world, Slots.castle_id(pid, slot))
			states_ok = states_ok and (
				castle.attributes.construction_state == ("active" if slot < 3 else "unbuilt")
				and castle.attributes.status == ("standing" if slot < 3 else "defunct")
				and int(castle.attributes.integrity) == opening_integrity(pid, slot)
			)
	check(states_ok, "first three physical slots stand and final two remain constructible")
	check(
		opening.active_castle_ids
		== [
			[Slots.castle_id(0, 0), Slots.castle_id(0, 1), Slots.castle_id(0, 2)],
			[Slots.castle_id(1, 0), Slots.castle_id(1, 1), Slots.castle_id(1, 2)]
		],
		"opening ledger binds the exact three starting Castle identities"
	)
	check(
		opening.summons.all(func(record): return record.cost == 0 and record.paid_value == 0 and record.card_ids.is_empty() and record.circle_id.is_empty()),
		"first Lords are free with or without a starting Circle"
	)
	check(
		entity(world, Slots.castle_id(1, 0)).attributes.integrity == 17
		and entity(world, Slots.castle_id(1, 2)).attributes.integrity == 17,
		"all starting Circles keep full Integrity"
	)
	check(world.data.card_zones.hands == [[], []] and world.data.card_zones.discard.is_empty()
		and world.data.card_zones.deck.size() == 57,
		"only the market is dealt at setup; first hand waits for normal draw")
	check(
		world.data.summon_counts == [1, 1]
		and world.data.neutral_tears == 0
		and Resummon.lord(world, 0).attributes.alive
		and Resummon.lord(world, 1).attributes.alive,
		"first summons create neither return count nor Neutral Tear"
	)


func all_lords_free() -> void:
	for lord in Game.LORDS:
		var game = Game.new()
		if not check(game.start("opening-free-" + lord, [lord, "Gremory"], [Slots.TYPES, Slots.TYPES]).action != "invalid", lord + " free opening starts"):
			continue
		var world: Dictionary = game.snapshot().world
		var record: Dictionary = world.data.game_economy.opening.summons[0]
		var actor: Dictionary = Resummon.lord(world, 0)
		check(record.lord_id == lord and record.cost == 0 and record.paid_value == 0
			and record.shortfall == 0 and record.card_ids.is_empty() and record.card_values.is_empty()
			and record.circle_id.is_empty() and record.circle_exerted == 0 and actor.attributes.alive
			and (not actor.attributes.has("threat") if lord == "Humbaba" else actor.attributes.threat == 0),
			lord + " has a clean free first-summon ledger")
		actor.attributes.alive = false
		var returned: Dictionary = Resummon.quote(world, 0, [])
		check(returned.cost == maxi(0, int(Resummon.COSTS[lord]) - 3)
			and returned.circle_id == Slots.castle_id(0, 2),
			lord + " later return keeps its printed cost and Circle discount")


func resummon_still_paid() -> void:
	var no_circle: Array = ["Bastion", "Stockpile", "SiegeEngine", "SummoningCircle", "Keep"]
	var initialized: Dictionary = Economy.initialize(
		Game.Scenario.loadout_world(["Odradek", "Humbaba"], [no_circle, no_circle]), "free-first-paid-return")
	if not check(initialized.action != "invalid", "return-cost fixture starts with free Lords"):
		return
	var world: Dictionary = initialized.world
	for pid in [0, 1]:
		Resummon.lord(world, pid).attributes.alive = false
		var quoted: Dictionary = Resummon.quote(world, pid, [])
		check(quoted.action == "invalid" and quoted.cost == int(Resummon.COSTS[world.players[pid].lord_id])
			and quoted.shortfall == quoted.cost and quoted.circle_id.is_empty(),
			"a protected Circle does not grant a free or discounted later return")


func restore_guards() -> void:
	var game = Game.new()
	var duplicate_circles: Array = [
		"SummoningCircle", "Bastion", "SummoningCircle", "Keep", "Stockpile"
	]
	if not check(
		game.start(
			"opening-restore",
			["Gremory", "Deimos"],
			[duplicate_circles, Slots.TYPES]
		).action
		!= "invalid",
		"opening restore fixture starts"
	):
		return
	var before: Dictionary = game.snapshot()
	for corruption in ["count", "payment", "circle", "old_policy"]:
		var forged: Dictionary = before.duplicate(true)
		if corruption == "count":
			forged.world.data.game_economy.opening.active_castle_count = 2
		elif corruption == "payment":
			forged.world.data.game_economy.opening.summons[0].paid_value += 1
		elif corruption == "old_policy":
			forged.policy_id = forged.policy_id.replace(Economy.VERSION, "U13_GAME_ECONOMY_V4")
		else:
			# Free first summons must not claim an offering from either Circle.
			forged.world.data.game_economy.opening.summons[0].circle_id = Slots.castle_id(0, 2)
		check(
			game.restore(forged).action == "invalid" and game.snapshot() == before,
			"opening %s corruption rejects atomically" % corruption
		)
	var restored = Game.new()
	check(
		restored.restore(JSON.parse_string(JSON.stringify(before))).action != "invalid"
		and restored.snapshot() == before,
		"free opening survives exact JSON restoration"
	)


func one_castle_action_remains_canonical() -> void:
	var game = Game.new()
	if not check(
		game.start(
			"opening-one-castle-action",
			["Gremory", "Deimos"],
			[Slots.TYPES, Slots.TYPES]
		).action
		!= "invalid"
		and planning_with_market_passes(game).action == "game_planning",
		"one-action fixture reaches locked planning"
	):
		return
	var before: Dictionary = game.snapshot()
	var duplicate: Dictionary = {
		"castle_action": choice("Construct", Slots.castle_id(0, 3)),
		"castle_actions": [choice("Construct", Slots.castle_id(0, 4))]
	}
	check(
		game._owner.preview_submission(0, [], duplicate).action == "invalid"
		and game.snapshot() == before,
		"accepted U13 one-Castle-action rule rejects an old sequential action list"
	)


func entity(world: Dictionary, id: String) -> Dictionary:
	return world.entities.entities.filter(func(row): return row.id == id)[0]


func choice(action: String, id: String) -> Dictionary:
	return {
		"action": action,
		"target_id": id,
		"card_ids": [],
		"use_repair_token": false
	}


func opening_integrity(_pid: int, slot: int) -> int:
	return 17 if slot < Economy.STARTING_CASTLES else 0


# Optional bounded export: every Lord in both seats, normal draw, Stockpile and
# Slaver, ending before submission. Every snapshot and event view is compared.
func export_openings() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		return
	if not check(args.size() == 3, "opening export receives path/revision/source identity"):
		return
	var modes: Array = [
		["Keep", "Stockpile", "SummoningCircle", "SiegeEngine", "Bastion"],
		["Keep", "Bastion", "SiegeEngine", "SummoningCircle", "Stockpile"]]
	var suite: Dictionary = {"schema": "U13_FREE_OPENING_SUITE_V1", "traces": []}
	for index in range(Game.LORDS.size()):
		var setup: Dictionary = {"seed": "u13-free-opening:%d" % index,
			"lords": [Game.LORDS[index], Game.LORDS[(index + 1) % Game.LORDS.size()]], "castles": modes}
		var session: Dictionary = Trace.begin(setup, args[1], args[2])
		if not check(session.action != "invalid", "opening export starts " + str(index)):
			continue
		for attempt in range(20):
			var game = session.game
			var state: Dictionary = game.snapshot()
			var hook: String = game._owner.next_hook()
			if hook == Game.Timeline.SUBMISSION_LOCK:
				break
			var pending: Dictionary = state.world.data.game_economy.stockpile_pending
			var operation: Dictionary
			if not pending.is_empty():
				operation = {"kind": "stockpile", "player_id": pending.player_id, "keep_id": pending.card_ids[0]}
			elif hook == Game.Timeline.PRESENT_PUBLIC_STATE and state.world.data.game_market.seat != 2:
				operation = {"kind": "market", "player_id": state.world.data.game_market.seat, "choice": {"market": "Pass"}}
			else:
				operation = {"kind": "step", "hook": hook}
			if not check(Trace.record(session, operation).action != "invalid", "opening operation " + str(index) + ":" + str(attempt)):
				break
		check(session.game._owner.next_hook() == Game.Timeline.SUBMISSION_LOCK
			and session.game.player_view(0).world.hand.size() == 6
			and session.game.player_view(1).world.hand.size() == 5,
			"opening reaches planning with one normal hand per seat " + str(index))
		check(Trace.replay(session.trace, args[1], args[2]).action == "trace_replayed", "opening replay " + str(index))
		suite.traces.append(session.trace)
	var encoded: Dictionary = Codec.encode(suite)
	if not check(encoded.action == "encoded", "opening suite encodes"):
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if not check(file != null, "opening export opens"):
		return
	file.store_string(encoded.text + "\n")
	file.close()
