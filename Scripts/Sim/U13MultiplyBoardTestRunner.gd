extends "res://Scripts/Sim/U13BoardTargetingTestRunner.gd"

func run() -> void:
	await fresh("Odradek")
	var state: Dictionary = board.session._owner.snapshot()
	state.world.players[0].resources.reconfiguration = 3
	var zones: Dictionary = state.world.data.card_zones
	var id: String = zones.hands[1].pop_back()
	for row in state.world.entities.entities:
		if row.id == id:
			row.attributes.merge({"role": "guard", "lane": "Castle", "slot": 0}, true)
	install(state)
	check(board.inversion_button.text.contains("MULTIPLY") and board.inversion_button.text.contains("3"), "Multiply menu shows cost three")
	check(board.shift_button.text.contains("4") and board.shift_button.disabled, "Shift needs four points")
	board._begin_guard_power("Multiply")
	check(board.guard_targeting.visible and not board.phase_prompt.visible, "Multiply exposes guard targets")
	board.sides[1].castle_guard_box.get_child(0).input_surface.pressed.emit()
	check(board.guard_destination.is_empty(), "Multiply ignores own guards and empty slots")
	board.sides[0].castle_guard_box.get_child(0).input_surface.pressed.emit()
	check(board.guard_source.get("id") == id and not board.guard_targeting.confirm_button.disabled, "Multiply selects one enemy guard")
	board.guard_targeting.confirm_button.pressed.emit()
	check(board.queued.size() == 1, "Multiply queues authoritative declaration")
	if not board.queued.is_empty():
		var source: Dictionary = board.queued[0]
		check(source.power_id == "Multiply" and source.target == {"entity_id": id, "lane": "Castle"}, "Multiply uses single guard target")
		check(source.cost.reconfiguration == 3 and source.fire_hook == "development" and source.fire_round == board.session.round_number(), "Multiply has current-round timing")
	board.free()
	print("U13 Multiply board failures: %d" % failures)
	quit(1 if failures else 0)
