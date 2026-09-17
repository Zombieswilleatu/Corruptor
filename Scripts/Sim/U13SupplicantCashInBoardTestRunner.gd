extends "res://Scripts/Sim/U13UIFeedbackTestRunner.gd"

const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Monsters = preload("res://Scripts/Sim/U13MonsterRules.gd")

func prepare_cash_in() -> Array:
	var world: Dictionary = fixture()
	var ids = Work.Ids.new(); ids.restore(world.entities)
	var waiters: Array = []
	for i in range(7):
		var a: Dictionary = Monsters.profile("Lemek", "Castle", 0, 0, 1) if i == 0 else Marching.profile("Penitent", "Castle", 0, 0, 1, true)
		a.merge({"waiting": true, "waiting_since_round": 1, "x_fp": 2400, "y_fp": 50 + i * 80}, true)
		waiters.append(ids.create("marcher", "cash-in-ui", i, 0, a).entity.id)
	world.entities = ids.snapshot()
	var play = Board.PlaySession.new()
	play._owner = Game.Content.new().create_combat_match()
	check(play._owner.start("cash-in-ui", world, [0, 1]).action != "invalid", "cash-in fixture starts under production rules")
	play._to_planning()
	board._reset_direct(); board.session = play
	board.match_started = true; board.setup_open = false
	board._refresh()
	return waiters

func begin_picker() -> Array:
	board.pass_round(); await job_done()
	check(board.session.pending_choice.is_empty(), "Slaver completed before cash-in selection")
	board._draft_combat = {"action": "Siege", "card_ids": [board._visible_world.hand[0]], "lane": "Castle", "target_id": Slots.castle_id(1, 0)}
	board._goto_flow(5)
	board._choose_waiters()
	var boxes: Array = board.game_menu.column.get_children().filter(func(c): return c is CheckBox)
	check(boxes.size() == 7, "picker lists all seven eligible Supplicants")
	return boxes

func round_facts(kind: String) -> Array:
	return board.session._owner.snapshot().events.rows.filter(func(r): return r.event.type == kind).map(func(r): return r.event.data)

func run() -> void:
	board = Board.new(); root.add_child(board); board._runtime_ok = true
	await process_frame
	var waiters: Array = prepare_cash_in()
	var boxes: Array = await begin_picker()
	for i in range(4): boxes[i].button_pressed = true
	board._confirm_decision()
	check(board._job == null and board._planning() and board.rites_plan.is_empty(), "Resolve Round blocks an incomplete cash-in without submitting combat")
	check(board.game_menu.message.text.contains("five"), "invalid selection explains the required five Supplicants")
	boxes[4].button_pressed = true
	board._confirm_decision()
	await job_done()
	if board.playing: board.finish_playback(); await job_done()
	var tears: Array = round_facts("PERSONAL_TEAR_CREATED").filter(func(d): return d.player_id == 0 and d.source == "waiters")
	var sieges: Array = round_facts("SIEGE_STARTED").filter(func(d): return d.player_id == 0)
	check(tears.size() == 1 and tears[0].amount == 1 and tears[0].marcher_ids == waiters.slice(0, 5), "Resolve Round cashes in the checked five for one Personal Tear without a separate Stage click")
	check(sieges.size() == 1 and sieges[0].waiters_consumed.size() == 2 and not sieges[0].waiters_consumed.any(func(id): return id in waiters.slice(0, 5)), "Siege consumes only the two unreserved Supplicants")
	check(board.session._owner.snapshot().world.players[0].resources.personal_tears == 1, "cash-in reward reaches the player's actual resources")
	check(not board.game_menu.pending_selection.is_valid(), "picker callback clears after submission")
	prepare_cash_in()
	boxes = await begin_picker()
	for i in range(5): boxes[i].button_pressed = true
	board.pass_round()
	await job_done()
	if board.playing: board.finish_playback(); await job_done()
	tears = round_facts("PERSONAL_TEAR_CREATED").filter(func(d): return d.player_id == 0 and d.source == "waiters")
	sieges = round_facts("SIEGE_STARTED").filter(func(d): return d.player_id == 0)
	check(tears.is_empty() and sieges.size() == 1 and sieges[0].waiters_consumed.size() == 7, "explicit No Rites discards checkbox selections and allows normal Siege support")
	board.queue_free(); await process_frame
	print("U13 Supplicant cash-in UI failures: ", failures)
	quit(1 if failures else 0)
