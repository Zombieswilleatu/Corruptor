extends "res://Scripts/Sim/U13UIFeedbackTestRunner.gd"

func run() -> void:
	board = Board.new()
	root.add_child(board)
	board._runtime_ok = true
	board.open_setup()
	await process_frame
	board.start_loadout(["Deimos", "Gremory"], [Slots.TYPES, Slots.TYPES], false)
	await process_frame
	board.pass_round()
	await job_done()
	var owner = board.session._owner
	var state: Dictionary = owner.snapshot()
	var veil = preload("res://Scripts/Sim/U13VeilBreaches.gd")
	state.world.data.neutral_tears = 5
	state.world.data.veil_breaches.arrivals = [{"lord_id": "Kanifous", "round": 1, "veil": 5, "threshold": 5, "protection": 1}]
	state.presentation_world = state.world.duplicate(true)
	check(owner.restore(state).action != "invalid", "UI fixture restores an active permanent Kanifous")
	board.session._read_revision = -1
	board._refresh()
	board._goto_flow(4)
	await process_frame
	check(board.wish_box.is_visible_in_tree() and board.wish_button.text == "QUEUE BREACH WISH", "Deimos sees the Breach Wish controls in the modal")
	check(board.wish_note.text.contains("HEAVIER PRICE") and board.wish_note.text.contains("double their normal draw weight"), "increased Price is explained before committing")
	board.wish_choice.select(4)
	board._update_direct_ui()
	board._queue_wish()
	check(board.queued.size() == 1 and board.queued[0].power_id == "BreachWishWealth", "modal queues the Breach declaration with its heavier Price")
	board._remove_wish()
	check(board.queued.is_empty(), "Breach Wish can be removed")
	state.world.players[1].resources.personal_tears = 1
	state.presentation_world = state.world.duplicate(true)
	check(owner.restore(state).action != "invalid", "opponent protection fixture restores")
	board.session._read_revision = -1
	board._refresh()
	check(not board.wish_box.visible, "opponent protection removes Breach Wish access")
	state.world.players[1].resources.personal_tears = 0
	for row in state.world.entities.entities:
		if row.kind == "lord" and row.owner == 0:
			row.attributes.alive = false
	state.presentation_world = state.world.duplicate(true)
	check(owner.restore(state).action != "invalid", "banished Lord fixture restores")
	board.session._read_revision = -1
	board._refresh()
	board._goto_flow(4, true)
	await process_frame
	check(board._flow_title() == "Lord Powers" and board.wish_box.is_visible_in_tree() and not board.wish_button.disabled, "banished Lords can reach and use the Breach Wish step")
	board.free()
	print("U13 Breach Wish UI failures: ", failures)
	quit(1 if failures else 0)
