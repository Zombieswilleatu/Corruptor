extends SceneTree

const Board = preload("res://Prototype/U13/U13ActionFlowBoard.gd")
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
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	split_ward_controls()
	playtime_controls()
	staging_controls()
	work_and_guard_controls()
	check(board.action_zone.action_buttons["Siege"].text == "Siege", "active enemy castles keep the Siege action")
	var enemy: Dictionary = board._visible_world.entities.filter(func(e): return e.kind == "lord" and e.owner == 1)[0]
	# The target picker uses public enemy presence, independent of own presence.
	var own: Dictionary = board._visible_world.entities.filter(func(e): return e.kind == "lord" and e.owner == 0)[0]
	own.attributes.alive = false
	check(board._target_allowed(board._entity_target(enemy.id), "Hunt"), "Hunt target stays selectable with own Lord absent")
	check(board._target_allowed(board._entity_target(Slots.castle_id(1, 1)), "Siege"), "Siege target stays selectable with own Lord absent")
	check(not board._target_allowed(board._entity_target(Slots.castle_id(0, 1)), "Siege") and not board._target_allowed(board._entity_target(Slots.castle_id(1, 4)), "Siege"), "absent Lord cannot select friendly or unbuilt castles for Siege")
	check(board._target_allowed(board._entity_target(own.id), "Ward") and board._target_allowed(board._entity_target(Slots.castle_id(0, 1)), "Ward") and not board._target_allowed(board._entity_target(enemy.id), "Ward"), "absent Lord can Ward either own lane only")
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
	check(not board.playtime.history_complete, "legacy save loads with partial timing")
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
	await absent_siege()
	await special_actions()
	finish()

func split_ward_controls() -> void:
	check(board._visible_world.get("tempo_experiment") == "U13_VEIL_ATTACK_ROUND25_V1", "new playable enables the promoted round-20 rules")
	var cards: Array = board._available_ids()
	var own: Dictionary = board._visible_world.entities.filter(func(e): return e.kind == "lord" and e.owner == 0)[0]
	var enemy: Dictionary = board._visible_world.entities.filter(func(e): return e.kind == "lord" and e.owner == 1)[0]
	board._select_direct_action("Ward")
	board._choose_target(board._entity_target(own.id))
	check(board._apply_cards(cards.slice(0, 1), false), "stage a paid Ward")
	board._reserve_ward()
	check(board.ward_plan.card_ids == cards.slice(0, 1) and cards[0] not in board._available_ids(), "reserved Ward cards leave the available hand")
	check(board._order().action == "Ward", "reserved Ward can resolve without an attack")
	board._select_direct_action("Hunt")
	board._choose_target(board._entity_target(enemy.id))
	check(board._apply_cards(cards.slice(1, 2), false), "stage Hunt using a separate card")
	var combined: Dictionary = board._order()
	check(combined.action == "Hunt" and combined.ward.card_ids == cards.slice(0, 1), "one complete cart contains Hunt and Ward")
	check(board.session.choose([], combined).action != "invalid", "authority accepts the UI split cart")
	var saved: Dictionary = board.session.checkpoint()
	var loaded = Board.PlaySession.new()
	check(loaded.restore_checkpoint(saved).action != "invalid" and loaded._order == combined, "split cart saves and restores exactly")
	var bad: Dictionary = combined.duplicate(true)
	bad.ward.card_ids = bad.card_ids.duplicate()
	check(board.session._preview_cart([], bad).action == "invalid", "shared attack and Ward payment is rejected")
	bad = combined.duplicate(true)
	bad.ward.monster_choice = "Lemek"
	check(board.session._preview_cart([], bad).action == "invalid", "Ward cannot summon a recipe monster")
	board._clear_ward()
	check(not board._order().has("ward") and cards[0] in board._available_ids(), "clearing Ward returns its card")
	board._reset_direct()
	board._refresh()
	check(board.ward_plan.is_empty(), "reset clears the reserved Ward")

func work_and_guard_controls() -> void:
	board._refresh()
	var available: String = Slots.castle_id(0, 4)
	var target: Dictionary = board._entity_target(available)
	board._open_work_target()
	check(board.choosing_work and not board.game_menu.visible and board._work_target_allowed(target), "Work button arms eligible Castles directly without a menu")
	var control: Control = board.sides[1].target_controls[available].get_parent().get_parent()
	check(control.has_meta("u13_target_flash"), "eligible Work target pulses")
	board._choose_target(board._entity_target(Slots.castle_id(1, 4)))
	check(board.choosing_work and board.castle_plan.is_empty(), "enemy Castle cannot receive work")
	board._choose_target(target)
	check(not board.choosing_work and board.castle_plan.target_id == available and board._order().castle_action.card_ids.is_empty(), "clicking Castle stages Work without card payment")
	board._open_work_target()
	board._choose_target(target)
	check(board.castle_plan.target_id.is_empty(), "clicking selected Work target clears it")
	board.castle_plan = {}
	for lane in ["Lord", "Castle"]:
		var card: String = board._available_ids()[0]
		var data: Dictionary = {"ui2_type": "commitment_hand_card", "source": "Hand", "card": card}
		var zone: Dictionary = {"kind": "zone", "owner": 0, "lane": lane, "id": ""}
		check(board._can_drop(Vector2.ZERO, data, zone), "whole " + lane + " Guard zone accepts a hand card")
		board._drop(Vector2.ZERO, data, zone)
		check(board.guard_plan.any(func(m): return m.card_id == card and m.lane == lane) and board._draft_combat.is_empty(), "Guard-zone drop places Guard without staging Ward in " + lane)
		board._refresh()
	var lord: Dictionary = board._visible_world.entities.filter(func(e): return e.kind == "lord" and e.owner == 0)[0]
	for destination in [board._entity_target(lord.id), board._entity_target(Slots.castle_id(0, 1))]:
		var card: String = board._available_ids()[0]
		var data: Dictionary = {"ui2_type": "commitment_hand_card", "source": "Hand", "card": card}
		board._drop(Vector2.ZERO, data, destination)
		check(board._draft_combat.get("action") == "Ward" and board._draft_combat.lane == destination.lane, "direct " + destination.kind + " drop stages Ward")
		board._draft_combat = {}
		board._refresh()
	board._reset_direct()
	board._refresh()

func absent_siege() -> void:
	const Game = Board.PlaySession.Game
	var world: Dictionary = Game.Economy.initialize(Game.Scenario.loadout_world(["Gremory", "Deimos"], [Slots.TYPES, Slots.TYPES]), "playable-absent-siege").world
	var ids = Game.Content.Ids.new()
	ids.restore(world.entities)
	var actor: Dictionary = ids.get_entity(world.players[0].lord_entity_id)
	actor.attributes.alive = false
	ids.update(actor.id, 0, actor.attributes)
	world.entities = ids.snapshot()
	var play = Board.PlaySession.new()
	play._owner = Game.Content.new().create_combat_match()
	if not check(play._owner.start("playable-absent-siege", world, [0, 1]).action != "invalid", "playable absent Lord fixture is valid"): return
	play._to_planning()
	board._reset_direct()
	board.session = play
	board.queued = []
	board.castle_plan = {}
	board.powers_step = false
	board._refresh()
	await human_choices()
	board._select_direct_action("Siege")
	board._choose_target(board._entity_target(Slots.castle_id(1, 1)))
	var staged: bool = board._apply_cards([board._visible_world.hand[0]], false)
	check(staged and board._order().get("action") == "Siege" and board.session.preview().action != "invalid", "playable board stages a legal Siege with the Lord actually absent")
	for lane in ["Lord", "Castle"]:
		board._select_direct_action("Ward")
		board._choose_target({"id": "", "kind": "zone", "owner": 0, "lane": lane})
		check(board._apply_cards([board._visible_world.hand[0]], false) and board._order().get("action") == "Ward" and board.session.preview().action != "invalid", "playable board stages absent Lord Ward in " + lane)

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
	check(not board.game_menu.column.get_children().any(func(child): return child is Button and "PILLAGE" in child.text), "Pillage needs no separate rites-menu selection")
	board.game_menu.hide()
	board.back_to_combat()
	check(board.action_zone.action_buttons["Siege"].text == "Pillage" and not board.action_zone.action_buttons["Siege"].disabled, "Siege automatically becomes an enabled Pillage action")
	board._select_direct_action("Siege")
	var card: String = board._visible_world.hand[0]
	check(board._apply_cards([card], false) and board._order().target_id == "castle_zone:1", "Pillage stages against protected construction with no active enemy castle")
	board._all_in()
	check(board._order().card_ids.size() == board._visible_world.hand.size(), "automatic Pillage supports normal ALL IN")
	board._draft_combat = {}
	board._intent = ""
	board._target = {}
	board._drop(Vector2.ZERO, {"ui2_type": "commitment_hand_card", "source": "Hand", "card": card}, {"id": "", "kind": "zone", "owner": 1, "lane": "Castle"})
	check(board._order().get("target_id") == "castle_zone:1", "dragging to the empty enemy Castle zone stages Pillage")
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
	check(board.session.is_finished() and board.phase_prompt.visible and board.phase_prompt.ledger.visible, "victory preserves final round ledger")
	check(board.phase_prompt.ledger.text.contains("Personal Tears") and board.phase_prompt.ledger.text.contains("OPPONENT"), "ledger shows both players and economy")
	board._confirm_decision()
	check(board.game_menu.visible, "ledger confirmation opens match result")
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


func playtime_controls() -> void:
	board._playtime_focus(true)
	board.playtime.decision_ms = 12000
	board.playtime.resolution_ms = 3000
	var authority: Dictionary = board.session.checkpoint()
	var encoded: String = board._encode_playable_save()
	var envelope: Dictionary = JSON.parse_string(encoded)
	check(envelope.playtime.total_ms >= 15000 and envelope.playtime.history_complete, "save envelope exposes readable playtime metadata")
	check(bytes_to_var(Marshalls.base64_to_raw(envelope.payload)) == authority and board.session.checkpoint() == authority, "timing does not alter authoritative payload or staged decisions")
	var file_path: String = "user://u13-playtime-test.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(encoded)
	file.close()
	board._load_game(file_path)
	check(board.playtime.decision_ms == int(envelope.playtime.decision_ms) and board.playtime.resolution_ms == int(envelope.playtime.resolution_ms) and board.playtime.history_complete and board.session.checkpoint() == authority, "timed save restores counters and authority")
	board._playtime_focus(true)
	check(board._playtime_mode() == "decision", "planning counts as decision time")
	board._playtime_focus(false)
	check(board._playtime_mode() == "excluded", "unfocused window excluded")
	board._playtime_focus(true)
	board._pause_playtime()
	check(paused and board.pause_dialog.visible and board._playtime_mode() == "excluded", "explicit pause blocks game and timing")
	board._resume_playtime()
	check(not paused and not board.pause_dialog.visible, "resume restores processing")
	board.open_setup()
	check(board._playtime_mode() == "excluded", "setup excluded without clearing existing time")
	board.close_setup()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))


func staging_controls() -> void:
	var panel = board.board_staging
	check(board._visible_world.has("game_staging") and panel.visible and board.lanes.live_layout, "new game shows staging directly on the main battlefield")
	check(panel.get_parent() == board.lanes and panel.trays.size() == 4 and panel.pickers.size() == 2, "four permanent reserve trays and two lane controls")
	check(board.lanes.custom_minimum_size.x == 680, "battlefield widened from 435 to 680")
	print("INLINE LAYOUT ", {"board_size": board.size, "window_size": root.size, "viewport": root.get_visible_rect(), "lanes": board.lanes.get_global_rect(), "header": board.header.get_global_rect()})
	check(board.lanes.get_global_rect().end.x <= root.get_visible_rect().end.x + 1, "expanded battlefield fits the board viewport")
	check(panel.get_global_rect().end.y <= root.get_visible_rect().end.y + 1, "all staging controls fit vertically")
	for lane in ["Lord", "Castle"]:
		var arena: Rect2 = board.lanes.travel_rect(lane)
		var enemy: Rect2 = panel.scrolls[lane + "1"].get_rect()
		var own: Rect2 = panel.scrolls[lane + "0"].get_rect()
		check(enemy.end.y < arena.position.y and own.position.y > arena.end.y, lane + " trays sit outside opposite arena gates")
		check(board.lanes.beam_bounds(lane) == arena, lane + " beam bounds exclude protected staging")
		check(panel.pickers[lane].get_rect().end.y <= panel.size.y, lane + " release control stays on screen")
	check(panel.pickers.values().all(func(p): return p is Button and not p is OptionButton and p.text == "MARCH"), "each lane has only a MARCH button")
	panel.pickers.Castle.pressed.emit()
	check(board._order().staging == {"Lord": "Hold", "Castle": "March"}, "MARCH enters only its lane into the sealed cart")
	check(panel.pickers.Castle.disabled and "ROUND 2" in panel.pickers.Castle.text and not panel.pickers.Lord.disabled, "queued button displays next round and prevents repeat clicks")
	check(board.session.choose([], board._order()).action != "invalid", "staging-only Pass admitted through playable session")
	var state: Dictionary = board._visible_world.game_staging.duplicate(true)
	for lane in ["Lord", "Castle"]:
		for pid in [0, 1]:
			for i in range(20):
				var a: Dictionary = Board.MonsterRules.profile("Varn", lane, pid, 1, 2)
				a["staged_round"] = 1
				state.lanes[lane].units.append({"id": lane + str(pid) + str(i), "kind": "marcher", "owner": pid, "attributes": a})
	panel.bind(state, 2, board.staging_modes, false)
	check(panel.trays.values().all(func(t): return t.reserves.size() == 20 and t.custom_minimum_size.y > 90), "overflow trays scroll without shrinking the battle lanes")
	check(panel.pickers.values().all(func(p): return p.disabled), "release editing is disabled during resolution while reserves stay visible")
	board._refresh()
