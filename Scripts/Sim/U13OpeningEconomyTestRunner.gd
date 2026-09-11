extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

const Resummon = preload("res://Scripts/Sim/U13Resummoning.gd")


func run() -> void:
	production_opening()
	all_lord_costs()
	forced_shortfall()
	restore_guards()
	one_castle_action_remains_canonical()
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
		opening.summons[0].cost == Resummon.COSTS.Odradek
		and opening.summons[0].circle_id.is_empty()
		and opening.summons[1].cost
		== Resummon.COSTS.Kanifous - Economy.BLOOD_OFFERING_DISCOUNT
		and opening.summons[1].circle_id == Slots.castle_id(1, 0),
		"only the first operational Circle makes one opening Blood Offering"
	)
	check(
		entity(world, Slots.castle_id(1, 0)).attributes.integrity == 18
		and entity(world, Slots.castle_id(1, 2)).attributes.integrity == 21,
		"duplicate starting Circles do not stack opening Blood Offering"
	)
	var paid_ids: Array = []
	var payments_ok: bool = true
	for pid in [0, 1]:
		var record: Dictionary = opening.summons[pid]
		paid_ids.append_array(record.card_ids)
		payments_ok = payments_ok and record.card_values == sorted_values(record.card_values)
		if not record.card_values.is_empty():
			var last_paid: int = int(record.card_values[-1])
			for card_id in world.data.card_zones.hands[pid]:
				payments_ok = payments_ok and int(entity(world, card_id).attributes.value) >= last_paid
		payments_ok = payments_ok and (
			record.paid_value >= record.cost
			or world.data.card_zones.hands[pid].is_empty()
		)
	check(
		payments_ok
		and paid_ids.all(func(id): return id in world.data.card_zones.discard),
		"opening summons consume lowest-value physical Hand cards"
	)
	check(
		world.data.summon_counts == [1, 1]
		and world.data.neutral_tears == 0
		and Resummon.lord(world, 0).attributes.alive
		and Resummon.lord(world, 1).attributes.alive,
		"first summons create neither return count nor Neutral Tear"
	)


func all_lord_costs() -> void:
	for lord in Game.LORDS:
		var game = Game.new()
		if not check(
			game.start(
				"opening-cost-" + lord,
				[lord, "Gremory"],
				[Slots.TYPES, Slots.TYPES]
			).action
			!= "invalid",
			lord + " paid opening starts"
		):
			continue
		var world: Dictionary = game.snapshot().world
		var record: Dictionary = world.data.game_economy.opening.summons[0]
		var actor: Dictionary = Resummon.lord(world, 0)
		check(
			record.lord_id == lord
			and record.cost
			== maxi(0, int(Resummon.COSTS[lord]) - Economy.BLOOD_OFFERING_DISCOUNT)
			and not record.card_ids.is_empty()
			and actor.attributes.alive
			and (
				not actor.attributes.has("threat")
				if lord == "Humbaba"
				else actor.attributes.threat == 0
			),
			lord + " uses current U13 cost and clean first-summon state"
		)


func forced_shortfall() -> void:
	var no_circle: Array = [
		"Bastion", "Stockpile", "SiegeEngine", "SummoningCircle", "Keep"
	]
	var initialized: Dictionary = Economy.initialize(
		Game.Scenario.loadout_world(["Odradek", "Odradek"], [no_circle, no_circle]),
		"opening-shortfall"
	)
	if not check(initialized.action != "invalid", "sparse opening fixture starts"):
		return
	var world: Dictionary = initialized.world
	Cards.discard(world, 0, world.data.card_zones.hands[0].duplicate())
	var drawn: Dictionary = Cards.draw(world, 0, "opening-shortfall", "sparse-hand")
	if not check(drawn.get("drawn") == true, "sparse opening fixture retains one payable card"):
		return
	var sparse_card_id: String = drawn.card_id
	var sparse_card_value: int = int(entity(world, sparse_card_id).attributes.value)
	var payment: Dictionary = Economy._pay_opening_summons(world)
	if not check(payment.action != "invalid", "forced sparse opening payment resolves"):
		return
	var record: Dictionary = payment.records[0]
	var actor: Dictionary = Resummon.lord(world, 0)
	check(
		world.data.card_zones.hands[0].is_empty()
		and record.card_ids == [sparse_card_id]
		and record.paid_value == sparse_card_value
		and record.paid_value + record.shortfall == record.cost
		and actor.attributes.alive
		and actor.attributes.threat == 0,
		"forced opening pays the whole Hand without creating starting Fracture"
	)


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
	for corruption in ["count", "payment", "circle"]:
		var forged: Dictionary = before.duplicate(true)
		if corruption == "count":
			forged.world.data.game_economy.opening.active_castle_count = 2
		elif corruption == "payment":
			forged.world.data.game_economy.opening.summons[0].paid_value += 1
		else:
			# A later active Circle cannot replace the deterministic first copy.
			forged.world.data.game_economy.opening.summons[0].circle_id = Slots.castle_id(0, 2)
		check(
			game.restore(forged).action == "invalid" and game.snapshot() == before,
			"opening %s corruption rejects atomically" % corruption
		)
	var restored = Game.new()
	check(
		restored.restore(JSON.parse_string(JSON.stringify(before))).action != "invalid"
		and restored.snapshot() == before,
		"paid opening survives exact JSON restoration"
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


func opening_integrity(pid: int, slot: int) -> int:
	if slot >= Economy.STARTING_CASTLES:
		return 0
	return (
		18
		if pid == 1 and slot == 0
		else 21
	)


func sorted_values(raw: Array) -> Array:
	var result: Array = raw.duplicate()
	result.sort()
	return result
