extends "res://Scripts/Sim/U13UIFeedbackTestRunner.gd"

func run() -> void:
	var content = Game.Content.new()
	var w: Dictionary = fixture()
	var target: String = Slots.castle_id(0, 4)
	var opponent: String = Slots.castle_id(1, 0)
	var source: Dictionary = {"power_id": Gremory.RUIN, "player_id": 1, "target": {"entity_id": target}, "declaration_id": "ruin-threshold"}
	for health in [0, 6, 7, 8, 9, 16, 17]:
		var probe: Dictionary = w.duplicate(true)
		var ids = Work.Ids.new(); ids.restore(probe.entities)
		var castle: Dictionary = ids.get_entity(target)
		castle.attributes.merge({"integrity": health, "status": "standing" if health else "defunct", "construction_state": "active", "artillery_target": opponent}, true)
		ids.update(target, 0, castle.attributes); probe.entities = ids.snapshot()
		for phase in ["declaration", "firing"]:
			check(content.validate(source, probe, phase).legal == (health > 8), "Ruin threshold %d at %s" % [health, phase])
		if health > 8:
			var result: Dictionary = content.resolve({"declaration": source}, {"world": probe, "round": 2})
			check(result.action != "invalid", "Ruin resolves from %d" % health)
			if result.action == "invalid": continue
			ids.restore(result.world.entities); castle = ids.get_entity(target)
			check(castle.attributes.integrity == 8 and Work.Structures.operational(castle), "Ruin preserves an operational Castle at 8")
			check(castle.attributes.artillery_target == opponent and castle.attributes.get("repair_lock_until_round", 0) == 0, "Ruin preserves artillery targeting and ordinary repair")
			var damage: Dictionary = result.events.filter(func(row): return row.get("type") == "CASTLE_DAMAGED")[0]
			check(damage.data.damage == health - 8 and not damage.data.destroyed and result.world.data.neutral_tears == w.data.neutral_tears, "Ruin emits damage without destruction rewards")
			check(Ledger.describe(damage.type, damage.data).contains("Castle health 8"), "Aftermath states the remaining health")
		else:
			var before: Dictionary = probe.duplicate(true)
			check(content.resolve({"declaration": source}, {"world": probe, "round": 2}).action == "invalid" and probe == before, "Direct resolution cannot heal an ineligible Castle")
	# Exercise the actual modal's dropdown and board targeting together.
	board = Board.new(); root.add_child(board); board._runtime_ok = true
	board.open_setup(); await process_frame
	board.start_loadout(["Gremory", "Deimos"], [Slots.TYPES, Slots.TYPES], false)
	await process_frame
	board.pass_round(); await job_done()
	board._goto_flow(4); await process_frame
	var state: Dictionary = board.session._owner.snapshot()
	for row in state.world.entities.entities:
		if row.kind == "castle" and row.owner == 1:
			row.attributes.integrity = 8 if row.attributes.castle_slot == 0 else row.attributes.integrity
	state.presentation_world = state.world.duplicate(true)
	check(board.session._owner.restore(state).action != "invalid", "Threshold UI fixture restores")
	board.session._read_revision = -1; board._refresh(); board._goto_flow(4)
	await process_frame
	var options: Array = []
	for i in range(board.ruin_target.item_count): options.append(board.ruin_target.get_item_metadata(i))
	check(Slots.castle_id(1, 0) not in options and Slots.castle_id(1, 1) in options, "Target list excludes 8 and includes a full-health Castle")
	check(board.ruin_state.text.contains("above 8") and board.ruin_state.text.contains("Reduces it to 8"), "Modal explains the threshold and result")
	board._intent = Gremory.RUIN; board._power_cost = board._available_ids().slice(0, 2)
	check(not board._target_allowed({"kind": "castle", "owner": 1, "id": Slots.castle_id(1, 0)}, Gremory.RUIN), "Board refuses the 8-health target")
	check(board._target_allowed({"kind": "castle", "owner": 1, "id": Slots.castle_id(1, 1)}, Gremory.RUIN), "Board allows the healthy target")
	board.free()
	print("U13 Inevitable Ruin failures: ", failures)
	quit(1 if failures else 0)
