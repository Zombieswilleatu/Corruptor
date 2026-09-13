extends SceneTree

const Board = preload("res://Prototype/U13/U13PlayableBoard.gd")
const Bot = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
var failures: int = 0
var board

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> bool:
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + message)
	return ok

func run() -> void:
	board = Board.new()
	root.add_child(board)
	# Tests exercise the widgets under the diagnostic engine too. The production
	# launcher and board retain their exact 4.7.2 stable acceptance requirement.
	board._runtime_ok = true
	board.open_setup()
	await process_frame
	check(board.setup_picker.full_game and not board.setup_picker.opening.visible, "playable setup uses the production opening")
	check(board.setup_load_button.visible, "saved games can be loaded from startup")
	check(not board.debug_button.visible, "exercise mutation controls are hidden")
	board.start_loadout(["Deimos", "Gremory"], [Slots.TYPES, Slots.TYPES], false)
	await process_frame
	if not check(board.session is Board.PlaySession and board.match_started, "setup starts a full playable session"):
		finish(); return
	await human_choices()
	check(board._planning(), "human choices unlock the board's planning controls")
	var enemy: Dictionary = board._visible_world.entities.filter(func(e): return e.kind == "lord" and e.owner == 1)[0]
	# The target picker uses public enemy presence, independent of own presence.
	var own: Dictionary = board._visible_world.entities.filter(func(e): return e.kind == "lord" and e.owner == 0)[0]
	own.attributes.alive = false
	check(board._target_allowed(board._entity_target(enemy.id), "Hunt"), "Hunt target stays selectable with own Lord absent")
	board._refresh()
	board._select_direct_action("Hunt")
	board._choose_target(board._entity_target(enemy.id))
	var card: String = board._visible_world.hand[0]
	check(board._apply_cards([card], false), "hand card stages a real Hunt")
	check(board._order().fracture_target == "infrastructure", "human Hunt carries a Fracture choice")
	board._open_game_menu()
	check(board.game_menu.visible, "full-game menu opens")
	board.fracture_choice = "subjects"
	check(board._order().fracture_target == "subjects", "Fracture selection updates the complete cart")
	board.game_menu.hide()
	board._refresh()
	var before: Dictionary = board.session._owner.snapshot()
	var saved: Dictionary = board.session.checkpoint()
	var file_path: String = "user://u13-playable-ui-test.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(Board.PlaySession.Game.encode_snapshot(saved))
	file.close()
	board._load_game(file_path)
	check(board.session._owner.snapshot() == before and board._order() == saved.order, "load restores the board cart without changing authority")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	board.enter_powers()
	board.resolve_round()
	await job_done()
	if check(board.playing, "human plan starts animated Marching"):
		board.finish_playback()
		await job_done()
		check(board.session.next_hook().is_empty(), "skip animation completes actual Aftermath")
		board.next_round()
		await job_done()
		await human_choices()
		check(board.session.round_number() == 2 and board._planning(), "next round draws and returns to interactive planning")
		check(board.rites_plan.is_empty() and board.queued.is_empty(), "new round clears the old cart")
	await special_actions()
	finish()

func special_actions() -> void:
	const Game = Board.PlaySession.Game
	const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
	const Marching = preload("res://Scripts/Sim/U13Marching.gd")
	var world: Dictionary = Game.Economy.initialize(Game.Scenario.loadout_world(["Gremory", "Deimos"], [Slots.TYPES, Slots.TYPES]), "playable-rites").world
	world.data.neutral_tears = 7
	world.players[0].resources.souls = 3
	world.players[0].resources.personal_tears = 1
	var ids = Ids.new()
	ids.restore(world.entities)
	for row in world.entities.entities:
		if row.kind != "castle": continue
		if row.owner == 1:
			row.attributes.construction_state = "unbuilt"
			row.attributes.integrity = 0
			row.attributes.status = "defunct"
			if row.attributes.castle_slot == 0:
				row.attributes.construction_state = "building"
				row.attributes.integrity = 6
				row.attributes.status = "standing"
				world.data.construction_targets[1] = row.id
		elif row.attributes.castle_slot in [3, 4]:
			row.attributes.status = "ruined"
			row.attributes.construction_state = "active"
			row.attributes.integrity = 0
		ids.update(row.id, row.owner, row.attributes)
	for index in range(10):
		var a: Dictionary = Marching.profile("Butcher", "Castle", 0, 0, 1, true)
		a.waiting = true
		a.waiting_since_round = 1
		a.x_fp = 2400
		a.y_fp = 40 + index * 50
		ids.create("marcher", "playable-rite-fixture", index, 0, a)
	world.entities = ids.snapshot()
	var play = Board.PlaySession.new()
	play._owner = Game.Content.new().create_combat_match()
	play.setup_lords = ["Gremory", "Deimos"]
	play.setup_castles = [Slots.TYPES, Slots.TYPES]
	play.hunt_enabled = true
	if not check(play._owner.start("playable-rites", world, [0, 1]).action != "invalid", "special-action fixture uses valid production rules"): return
	play._to_planning()
	board._reset_direct()
	board.session = play
	board.queued = []
	board.castle_plan = {}
	board.powers_step = false
	board._refresh()
	await human_choices()
	board._open_game_menu()
	board._stage_pillage()
	var card: String = board._visible_world.hand[0]
	check(board._apply_cards([card], false) and board._order().target_id == "castle_zone:1", "Pillage stages against protected construction with no active enemy castle")
	board._draft_combat = {}
	board._intent = ""
	board._target = {}
	board._refresh()
	var castle: Dictionary = board._visible_world.entities.filter(func(e): return Board.Plunder.eligible(e, 0))[0]
	board._stage_profane(castle.id)
	check(board._order().action == "Profane", "full own castle can be staged for Profane")
	board._draft_combat = {}
	board._refresh()
	board._choose_waiters()
	var waiters: Array = board._visible_world.entities.filter(func(e): return e.kind == "marcher" and e.owner == 0 and e.attributes.waiting)
	board._stage_rite("waiter_spends", [{"lane": "Castle", "marcher_ids": waiters.slice(0, 5).map(func(e): return e.id)}])
	check(board.rites_plan.has("waiter_spends"), "human can stage five waiting marchers")
	board._choose_waiters()
	check(board.game_menu.column.get_children().filter(func(child): return child is CheckBox).size() == 5, "already reserved waiters disappear from the next picker")
	var groups: Array = board.rites_plan.waiter_spends.duplicate(true)
	groups.append({"lane": "Castle", "marcher_ids": waiters.slice(5).map(func(e): return e.id)})
	board._stage_rite("waiter_spends", groups)
	check(board.rites_plan.waiter_spends.size() == 2, "multiple groups from one lane can share the same cart")
	board._stage_rite("invocation", {"card_ids": board._visible_world.hand.duplicate()})
	check(board.rites_plan.has("invocation"), "Invocation stages actual hand payment")
	board._choose_ruins()
	board._stage_rite("profane_ruins", {"castle_id": Slots.castle_id(0, 3)})
	check(board.rites_plan.has("profane_ruins") and board.session.preview().action != "invalid", "Profane Ruins shares one legal complete cart with other rites")
	board.game_menu.hide()
	board.resolve_round()
	await job_done()
	if board.playing:
		board.finish_playback()
		await job_done()
	check(board.session.is_finished() and board.game_menu.visible, "victory automatically opens the playable result screen")
	var terminal: Dictionary = board.session._owner.snapshot()
	board.next_round()
	check(board._job == null and terminal == board.session._owner.snapshot(), "finished UI cannot begin another round")

func human_choices() -> void:
	for attempt in range(12):
		if board.session.pending_choice.is_empty(): return
		board._show_economy()
		check(board.game_menu.visible and not board.game_menu.close_button.visible, "mandatory human choice is visible")
		var w: Dictionary = board.session.board_view().world
		var choice: Dictionary = {"market": "Pass"}
		if board.session.pending_choice.action == "game_draw_choice":
			choice = {"keep_id": w.game_economy.stockpile_pending.card_ids[0]}
		board._economy(choice)
		await job_done()

func job_done() -> void:
	var deadline: int = Time.get_ticks_msec() + 120000
	while board._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(board._job == null, "board worker finished")
	await process_frame

func finish() -> void:
	board.queue_free()
	await process_frame
	print("U13 playable board failures: %d" % failures)
	quit(failures)
