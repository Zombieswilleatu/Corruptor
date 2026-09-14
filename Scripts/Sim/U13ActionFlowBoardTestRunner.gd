extends SceneTree
const Board = preload("res://Prototype/U13/U13ActionFlowBoard.gd")
const Game = Board.PlaySession.Game
const Slots = Game.Slots
var board
var failures: int = 0

func check(ok: bool, label: String) -> bool:
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
	return ok

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	board = Board.new()
	root.add_child(board)
	board._runtime_ok = true
	board.open_setup()
	await process_frame
	board.start_loadout(["Deimos", "Gremory"], [Slots.TYPES, Slots.TYPES], false)
	await process_frame
	await choices()
	check(board._flow_title() == "Work Target" and board.work_button.get_parent() == board.flow_work, "Work Target is the next action inside the shared modal")
	check(not board.game_button.visible and board.game_menu.get_parent() == board.action_zone.get_node("ActionScroll/ActionContents"), "economy and rites share the existing action modal")
	board._open_work_target()
	board._choose_target(board._entity_target(Slots.castle_id(0, 4)))
	check(board.flow_step == 2 and board.development_box.visible and not board.summon_button.visible, "Work choice advances to Guards, skipping a living Lord's resummon")
	var guard: String = board._available_ids()[0]
	board._drop(Vector2.ZERO, {"ui2_type": "commitment_hand_card", "source": "Hand", "card": guard}, {"kind": "zone", "owner": 0, "lane": "Castle", "id": ""})
	board._confirm_decision()
	check(board.flow_step == 3 and board.action_zone.action_box.visible and board.guard_plan.size() == 1, "Done Guards advances to Combat with placements retained")
	board._select_direct_action("Ward")
	board._choose_target(board._entity_target(board.session._owner.snapshot().world.players[0].lord_entity_id))
	check(board._apply_cards([board._available_ids()[0]], false), "combat cards stage normally")
	var staged: Dictionary = board._order().duplicate(true)
	board._confirm_decision()
	check(board.flow_step == 4 and board.powers_box.visible and not board.action_zone.action_box.visible, "Done Combat advances to Lord Powers")
	board.pass_round()
	check(board.flow_step == 5 and board.game_menu.visible and board.phase_prompt.visible and board.session.next_hook() == Game.Timeline.SUBMISSION_LOCK, "No Powers opens Dominion Rites without resolving early")
	check(board._order() == staged, "work, Guards and combat survive the full sequence")
	board._flow_back()
	board._flow_back()
	check(board.flow_step == 3 and board._order() == staged, "Back reviews earlier choices without discarding the cart")
	board._confirm_decision(); board._confirm_decision()
	board.pass_round()
	await job_done()
	check(board.playing, "final rites confirmation starts actual resolution")
	board.finish_playback()
	await job_done()
	check(board.session.next_hook().is_empty() and board.phase_prompt.stage_key == "AFTERMATH", "Aftermath remains outside planning sequence")
	await stockpile_and_resummon()
	board.queue_free()
	await process_frame
	print("U13 action flow board failures: %d" % failures)
	quit(failures)

func stockpile_and_resummon() -> void:
	var world: Dictionary = Game.Economy.initialize(Game.Scenario.loadout_world(["Deimos", "Gremory"], [Slots.TYPES, Slots.TYPES]), "flow-stockpile").world
	var ids = Game.Content.Ids.new()
	ids.restore(world.entities)
	var stock: Dictionary = ids.get_entity(Slots.castle_id(0, 3))
	stock.attributes.construction_state = "active"
	stock.attributes.status = "standing"
	stock.attributes.integrity = stock.attributes.max_integrity
	ids.update(stock.id, 0, stock.attributes)
	var lord: Dictionary = ids.get_entity(world.players[0].lord_entity_id)
	lord.attributes.alive = false
	ids.update(lord.id, 0, lord.attributes)
	world.entities = ids.snapshot()
	var play = Board.PlaySession.new()
	play._owner = Game.Content.new().create_combat_match()
	if not check(play._owner.start("flow-stockpile", world, [0, 1]).action != "invalid", "Stockpile and absent Lord fixture valid"): return
	play._to_planning()
	board._reset_direct(); board.session = play; board.powers_step = false; board._refresh()
	await process_frame
	check(board._flow_title() == "Stockpile" and board.game_menu.visible and board.phase_prompt.visible, "Stockpile starts in the common modal")
	await process_frame
	check(board.game_menu.size.x > 100 and board.game_menu.custom_minimum_size.y > 50 and board.action_zone.size.y > 50, "embedded choice controls have usable scrollable layout")
	var keep: String = play.board_view().world.game_economy.stockpile_pending.card_ids[0]
	board._economy({"keep_id": keep}); await job_done()
	check(board._flow_title() == "Slaver" and board.phase_prompt.visible, "Stockpile completion advances to Slaver")
	await choices()
	board.pass_round()
	check(board.flow_step == 1 and board.summon_button.visible and not board.guard_button.visible, "Work completion offers resummon for an absent Lord")
	board.pass_round()
	check(board.flow_step == 2, "Skip resummon continues to Guard placement")
	board.pass_round(); board.pass_round()
	check(board.flow_step == 5, "banished Lord skips unavailable Lord powers")

func choices() -> void:
	for attempt in range(5):
		if board.session.pending_choice.is_empty(): return
		board._show_economy()
		check(board.game_menu.visible and board.phase_prompt.visible, "mandatory choice is in the shared modal")
		var w: Dictionary = board.session.board_view().world
		var choice: Dictionary = {"market": "Pass"}
		if board.session.pending_choice.action == "game_draw_choice": choice = {"keep_id": w.game_economy.stockpile_pending.card_ids[0]}
		board._economy(choice)
		await job_done()

func job_done() -> void:
	var deadline: int = Time.get_ticks_msec() + 90000
	while board._job != null and Time.get_ticks_msec() < deadline: await process_frame
	check(board._job == null, "worker completes")
	await process_frame
