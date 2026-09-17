extends "res://Prototype/U13/U13KanifousBoard.gd"

const Work = preload("res://Scripts/Sim/U13GuardWork.gd")
var slaver_swap: Callable
var work_button: Button
var choosing_work: bool = false
const PlaySession = preload("res://Scripts/Sim/U13PlayableSession.gd")
const GameMenu = preload("res://Prototype/U13/U13GameMenu.gd")
const Plunder = preload("res://Scripts/Sim/U13Plunder.gd")
var game_menu
var game_button: Button
var save_button: Button
var load_button: Button
var load_dialog: FileDialog
var rites_plan: Dictionary = {}
var fracture_choice: String = "infrastructure"
var choice_error: String = ""
var setup_load_button: Button
const Playtime = preload("res://Prototype/U13/U13Playtime.gd")
var playtime = Playtime.new()
var playtime_label: Label
var pause_button: Button
var pause_dialog: AcceptDialog
var _playtime_paused: bool = false
var _playtime_focused: bool = true

func _new_loadout_session():
	return PlaySession.new()

func _new_loadout_picker():
	var picker = LoadoutPicker.new()
	picker.full_game = true
	return picker

func _build() -> void:
	super._build()
	debug_button.hide()
	game_menu = GameMenu.new()
	add_child(game_menu)
	game_menu.closed.connect(reopen_decision)
	work_button = _button(header.history_box, "WORK TARGET", _open_work_target)
	work_button.tooltip_text = "Click, then select a pulsing Castle. Each newly placed Guard gives 1 work; a fresh Wright pair adds 5. Unbuilt targets also gain 3 per round. No card payment."
	action_zone.action_buttons["Ward"].tooltip_text = "Defend a lane and recruit one Marcher per 2 printed suit value. Hunt and Siege recruit at 3:1."
	game_button = _button(header.history_box, "GAME / RITES", _open_game_menu)
	var files := HBoxContainer.new()
	header.history_box.add_child(files)
	save_button = _button(files, "SAVE", _save_game)
	load_button = _button(files, "LOAD", _open_load)
	pause_button = _button(files, "PAUSE", _pause_playtime)
	playtime_label = _label(header.history_box, "PLAYTIME 00:00:00", 12)
	pause_dialog = AcceptDialog.new()
	pause_dialog.title = "Game paused"
	pause_dialog.dialog_text = "Playtime is paused. Resume when you are ready."
	pause_dialog.ok_button_text = "RESUME"
	pause_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_dialog.exclusive = true
	pause_dialog.confirmed.connect(_resume_playtime)
	pause_dialog.canceled.connect(_resume_playtime)
	add_child(pause_dialog)
	get_window().focus_entered.connect(_playtime_focus.bind(true))
	get_window().focus_exited.connect(_playtime_focus.bind(false))
	load_dialog = FileDialog.new()
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_dialog.filters = PackedStringArray(["u13-playable-*.json ; Corruptor saved games", "*.json ; Other JSON files"])
	load_dialog.file_selected.connect(_load_game)
	var older_saves: Button = Button.new()
	older_saves.text = "OLDER SAVES IN DOWNLOADS"
	older_saves.pressed.connect(func(): load_dialog.current_dir = _downloads_folder())
	load_dialog.get_vbox().add_child(older_saves)
	add_child(load_dialog)
	setup_load_button = _button(setup_picker.start_button.get_parent(), "LOAD SAVED GAME", _open_load)

func _planning() -> bool:
	return super._planning() and session is PlaySession and session.pending_choice.is_empty() and not session.is_finished()

func _with_development(order: Dictionary) -> Dictionary:
	var result: Dictionary = super._with_development(order)
	if not rites_plan.is_empty():
		result["rites"] = rites_plan.duplicate(true)
	if result.get("action") == "Hunt":
		result["fracture_target"] = fracture_choice
	return result

func _hand_reserved(id: String) -> bool:
	return id in rites_plan.get("invocation", {}).get("card_ids", []) or super._hand_reserved(id)

func _reset_direct() -> void:
	choosing_work = false
	rites_plan = {}
	fracture_choice = "infrastructure"
	choice_error = ""
	if game_menu != null:
		game_menu.hide()
	super._reset_direct()

func _refresh(presented: Dictionary = {}) -> void:
	super._refresh(presented)
	if not session is PlaySession:
		return
	var w: Dictionary = _visible_world
	header.scope.text = "Dominion %s · 5+ Personal Tears and the lead\nFinal Collapse: 26 · Neutral Tears: %d" % ["OPEN" if int(w.veil_total) >= 12 else "at Veil 12", w.neutral_tears]
	header.veil_track.show()
	header.veil_track.value = w.veil_total
	header.scope.tooltip_text = "Full game · Dominion, Ritual or Final Collapse. Neutral Tears: +1 each round 13-20, +2 from round 21. Final Collapse at 26 total Tears. Veil threshold penalties are disabled."
	header.veil_label.text = "VEIL  %d / 26" % w.veil_total
	header.veil_label.tooltip_text = "Total Veil = both players’ Personal Tears + shared Neutral Tears."
	work_button.disabled = not _planning() or playing or _job != null
	work_button.text = "CANCEL WORK" if choosing_work else "WORK TARGET"
	castle_box.hide()
	for row in sides:
		row.show_commission_buttons(_planning() and not playing and _job == null, castle_plan.get("target_id", "") if castle_plan.get("action") == "Activate" else "")
	_show_work_target()
	if _planning():
		plan_label.text += "\n" + _work_preview()
		_show_pair_badges()
	game_button.disabled = _job != null or playing or setup_open
	save_button.disabled = not _can_save()
	load_button.disabled = _job != null or playing
	if _planning() and not _human_alive():
		status.text = "Your Lord is banished. Your army can still Hunt, Siege, Pillage or Ward; stage resummoning in Guards & Lord Return."
	if not rites_plan.is_empty():
		plan_label.text += "\nTear rites staged · inspect or clear in GAME / RITES."
	if not session.pending_choice.is_empty() and _job == null:
		call_deferred("_show_economy")

func _target_allowed(target: Dictionary, intent: String) -> bool:
	if intent == "Ward":
		return _planning() and target.get("owner") == 0 and target.get("kind") in ["lord", "castle", "zone"] and target.get("lane") in ["Lord", "Castle"]
	if intent == "Siege":
		if target.get("kind") == "zone":
			return _planning() and target.get("owner") == 1 and target.get("lane") == "Castle" and _pillage_available()
		return _planning() and target.get("owner") == 1 and target.get("kind") == "castle" and Structures.targetable(_entity(str(target.get("id", ""))))
	if intent == "Hunt":
		var entity: Dictionary = _entity(str(target.get("id", "")))
		return _planning() and target.get("owner") == 1 and target.get("kind") == "lord" and not entity.is_empty() and entity.attributes.alive
	return super._target_allowed(target, intent)

func _entity_target(id: String) -> Dictionary:
	if id == Plunder.zone_id(1):
		return {"id": "", "kind": "zone", "owner": 1, "lane": "Castle"}
	return super._entity_target(id)

func _sync_decision() -> void:
	super._sync_decision()
	if not session is PlaySession:
		return
	if not session.pending_choice.is_empty():
		phase_prompt.set_presenting(false)
		confirm.disabled = true
	elif session.is_finished():
		phase_prompt.set_presenting(true)
		phase_prompt.title_label.text = "VICTORY" if session.outcome().winner == 0 else "DEFEAT"
		confirm.text = "MATCH RESULT"
		confirm.disabled = false
		next_button.disabled = true

func _confirm_decision() -> void:
	if session is PlaySession and (session.is_finished() or not session.pending_choice.is_empty()):
		_open_game_menu()
		return
	super._confirm_decision()

func _complete_job() -> void:
	super._complete_job()
	# Keep the final round ledger visible until MATCH RESULT is selected.

func next_round() -> void:
	if session is PlaySession and session.is_finished():
		_open_game_menu()
		return
	super.next_round()

func _card_name(id: String) -> String:
	var row: Dictionary = _entity(id)
	return "%s %d" % [row.attributes.suit, row.attributes.value] if not row.is_empty() else "Card"

func _show_economy() -> void:
	if not match_started or setup_open or _job != null or not session is PlaySession or session.pending_choice.is_empty():
		return
	slaver_swap = Callable()
	phase_prompt.set_presenting(false)
	var w: Dictionary = session.board_view().world
	if session.pending_choice.action == "game_draw_choice":
		game_menu.present("STOCKPILE DRAW", "Choose the card to keep. The other card is discarded.", false)
		for id in w.game_economy.stockpile_pending.card_ids:
			game_menu.button(_card_name(id), _economy.bind({"keep_id": id}))
	else:
		game_menu.present("THE SLAVER", "Swap one hand card for an offered card, or pass. Each player chooses once.", false)
		if not w.market.is_empty() and not w.hand.is_empty():
			game_menu.label("Take from the Slaver")
			var take = game_menu.option(w.market.map(_card_name))
			game_menu.label("Give from your hand")
			var give = game_menu.option(w.hand.map(_card_name))
			slaver_swap = func(): _economy({"market": "Swap", "take_id": w.market[take.selected], "give_id": w.hand[give.selected]})
			if not game_menu.embedded: game_menu.button("SWAP CARDS", slaver_swap)
		if not game_menu.embedded: game_menu.button("PASS TRADE", _economy.bind({"market": "Pass"}))
	game_menu.button("SAVE AND RETURN LATER", _save_game)
	game_menu.set_message(choice_error)

func _economy(choice: Dictionary) -> void:
	if _job != null:
		return
	choice_error = ""
	game_menu.hide()
	_start_job("economy_choice", [], choice)

func _open_game_menu() -> void:
	if not match_started or setup_open or _job != null or playing or not session is PlaySession:
		return
	if not session.pending_choice.is_empty():
		_show_economy()
		return
	phase_prompt.set_presenting(false)
	if session.is_finished():
		var outcome: Dictionary = session.outcome()
		game_menu.present("YOU WIN" if outcome.winner == 0 else "OPPONENT WINS", AftermathLedger.result_summary(session.board_view().world, outcome) + "\nRound %d" % outcome.round)
		_sample_playtime()
		game_menu.label("Playtime: " + playtime.summary())
		game_menu.button("NEW GAME", func(): game_menu.hide(); open_setup())
		game_menu.button("SAVE FINISHED GAME", _save_game)
		return
	game_menu.present("GAME / TEAR RITES", "Ritual: 12 Souls with your Lord present. Dominion: Veil 12+, at least 5 Personal Tears and more than your opponent. Final Collapse: Veil 26; most Souls wins (seat 0 wins a tie).")
	if not _planning():
		game_menu.label("Round resolved. Return to the board and continue to the next round.")
		return
	game_menu.label("Hunt Fracture")
	var fracture = game_menu.option(["Infrastructure", "Subjects"])
	fracture.select(0 if fracture_choice == "infrastructure" else 1)
	fracture.item_selected.connect(func(index): fracture_choice = "infrastructure" if index == 0 else "subjects"; _refresh())
	game_menu.button("PROFANE A FULL CASTLE · gain a Tear", _choose_profane)
	game_menu.button("SPEND FIVE SUPPLICANTS · gain a Tear", _choose_waiters)
	game_menu.button("INVOCATION · once per game · value 11 at Veil 7+", _choose_invocation)
	game_menu.button("PROFANE RUINS · pay 2 Souls with two ruins", _choose_ruins)
	game_menu.button("CLEAR TEAR RITES · return reserved cards / Supplicants", func(): rites_plan = {}; _refresh(); _open_game_menu())
	if not rites_plan.is_empty():
		game_menu.label("Staged: " + ", ".join(rites_plan.keys()))

func _pillage_available() -> bool:
	return not _visible_world.get("entities", []).is_empty() and not _visible_world.entities.any(func(e): return e.owner == 1 and Structures.targetable(e))

func _select_direct_action(action: String) -> void:
	choosing_work = false
	if action != "Siege" or not _pillage_available():
		super._select_direct_action(action)
		return
	if not _planning() or powers_step:
		return
	_interaction_error = ""
	_intent = "Siege"
	_target = {"id": Plunder.zone_id(1), "kind": "zone", "owner": 1, "lane": "Castle"}
	action_choice.select(1)
	_preview()
	_schedule_refresh()

func _update_direct_ui() -> void:
	super._update_direct_ui()
	if action_zone == null or not match_started:
		return
	var pillage: bool = _pillage_available()
	action_zone.action_buttons["Siege"].text = "Pillage" if pillage else "Siege"
	action_zone.action_buttons["Siege"].disabled = not _planning()
	if _planning() and pillage and _intent == "Siege":
		status.text = _guide() if _interaction_error.is_empty() else _interaction_error

func _guide() -> String:
	if _intent == "Siege" and _pillage_available():
		return "PILLAGE · no targetable enemy Castles. Click hand cards or use ALL IN, then continue to powers."
	return super._guide()

func _hand_selection_changed(ids: Array) -> void:
	if not _direct_binding and _planning() and not powers_step and _intent in ["Hunt", "Siege"] and _target.is_empty():
		if _intent == "Siege" and _pillage_available():
			_target = {"id": "", "kind": "zone", "owner": 1, "lane": "Castle"}
		for entity in _visible_world.get("entities", []):
			var candidate: Dictionary = _entity_target(entity.id)
			if _target_allowed(candidate, _intent):
				_target = candidate
				break
	super._hand_selection_changed(ids)

func _apply_cards(ids: Array, append: bool) -> bool:
	if _intent == "Siege" and _target.get("kind") == "zone" and _pillage_available():
		_target["id"] = Plunder.zone_id(1)
	return super._apply_cards(ids, append)

func _choose_profane() -> void:
	game_menu.present("PROFANE CASTLE", "Sacrifice one of your full, active Castles for a Personal Tear. This uses your combat action.")
	for row in _visible_world.entities:
		if Plunder.eligible(row, 0):
			game_menu.button(_castle_name(row), _stage_profane.bind(row.id))

func _stage_profane(id: String) -> void:
	var combat: Dictionary = {"action": "Profane", "lane": "Castle", "target_id": id, "card_ids": []}
	var order: Dictionary = _with_development(combat)
	if not castle_plan.is_empty():
		order["castle_action"] = castle_plan.duplicate(true)
	var result: Dictionary = session.choose(queued, order)
	if result.action == "invalid":
		game_menu.set_message(_friendly_error(result))
		return
	_draft_combat = combat
	_intent = ""
	_target = {}
	game_menu.hide()
	_refresh()
	reopen_decision()

func _choose_invocation() -> void:
	game_menu.present("INVOCATION", "Once per game: choose uncommitted hand cards with total printed value at least 11. Requires Veil 7 or higher.")
	var ids: Array = _visible_world.hand.filter(func(id): return not _hand_reserved(id))
	var boxes: Array = game_menu.checks(ids.map(_card_name))
	game_menu.button("STAGE INVOCATION", func():
		var selected: Array = []
		for index in range(ids.size()):
			if boxes[index].button_pressed: selected.append(ids[index])
		_stage_rite("invocation", {"card_ids": selected}))

func _choose_waiters() -> void:
	game_menu.present("SPEND SUPPLICANTS", "Choose exactly five Supplicants in one lane. Each selected group creates one Personal Tear.")
	for lane in ["Lord", "Castle"]:
		var rows: Array = _visible_world.entities.filter(func(e): return e.kind == "marcher" and e.owner == 0 and e.attributes.lane == lane and e.attributes.waiting)
		game_menu.label(lane + " lane")
		var used: Array = []
		for spend in rites_plan.get("waiter_spends", []): used.append_array(spend.marcher_ids)
		rows = rows.filter(func(e): return e.id not in used)
		var boxes: Array = game_menu.checks(rows.map(func(e): return "%s · %s" % [str(e.attributes.get("suit", "Marcher")), str(e.id).get_slice(":", str(e.id).get_slice_count(":") - 1)]))
		game_menu.button("STAGE FIVE FROM " + lane.to_upper(), func():
			var selected: Array = []
			for index in range(rows.size()):
				if boxes[index].button_pressed: selected.append(rows[index].id)
			var spends: Array = rites_plan.get("waiter_spends", []).duplicate(true)
			spends.append({"lane": lane, "marcher_ids": selected})
			_stage_rite("waiter_spends", spends))

func _choose_ruins() -> void:
	game_menu.present("PROFANE RUINS", "With at least two ruined Castles, pay 2 Souls to profane one ruin and gain a Personal Tear.")
	for row in _visible_world.entities:
		if row.kind == "castle" and row.owner == 0 and row.attributes.status == "ruined":
			game_menu.button(_castle_name(row), _stage_rite.bind("profane_ruins", {"castle_id": row.id}))

func _stage_rite(key: String, value) -> void:
	if not _planning():
		return
	var proposed: Dictionary = rites_plan.duplicate(true)
	proposed[key] = value
	var order: Dictionary = _order()
	order["rites"] = proposed
	var result: Dictionary = session.choose(queued, order)
	if result.action == "invalid":
		game_menu.set_message(_friendly_error(result))
		return
	rites_plan = proposed
	_refresh()
	_open_game_menu()

func _can_save() -> bool:
	return match_started and not setup_open and _job == null and not playing and session is PlaySession and (session.next_hook() == Timeline.SUBMISSION_LOCK or not session.pending_choice.is_empty() or session.next_hook().is_empty())

func _friendly_error(result: Dictionary) -> String:
	var messages: Dictionary = {
		"invocation_insufficient_payment": "Invocation requires total printed value of at least 11.",
		"invocation_veil_below_gate": "Invocation becomes available at Veil 7.",
		"invocation_already_used": "You have already used your once-per-game Invocation.",
		"rite_card_already_reserved": "That card is already committed to another part of your plan.",
		"rites_shape_invalid": "Choose exactly five different Supplicants in one lane.",
		"rite_waiter_unavailable": "Choose five of your available Supplicants in the same lane.",
		"profane_ruins_insufficient_souls": "Profaning a ruin costs 2 Souls.",
		"profane_ruins_target_unavailable": "You need at least two ruined Castles; select one of them.",
		"rite_castle_already_reserved": "That Castle is already part of your development order."
	}
	return messages.get(result.get("reason", ""), super._friendly_error(result))

func _error(result: Dictionary) -> bool:
	if result.action == "invalid" and session is PlaySession and not session.pending_choice.is_empty():
		choice_error = _friendly_error(result)
	return super._error(result)

static func _downloads_folder() -> String:
	var folder: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	return OS.get_user_data_dir() if folder.is_empty() else folder

static func _save_folder() -> String:
	return _downloads_folder().path_join("Corruptor/Saves")

func _save_game() -> void:
	if not _can_save():
		return
	if _planning():
		var checked: Dictionary = session.choose(queued, _order())
		if checked.action == "invalid":
			game_menu.set_message("Finish or clear the incomplete order before saving.")
			return
	var folder: String = _save_folder()
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_busy_label.text = "Could not create the saved-games folder: " + folder
		game_menu.set_message(_busy_label.text)
		return
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = folder.path_join("u13-playable-%s-r%d-%d.json" % [stamp, session.round_number(), Time.get_ticks_usec()])
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_busy_label.text = "Could not write the saved game."
		game_menu.set_message(_busy_label.text)
		return
	file.store_string(_encode_playable_save())
	file.close()
	_busy_label.text = "Saved game: " + path
	game_menu.set_message(_busy_label.text)
	print("U13 saved game: " + path)

func _open_load() -> void:
	if _job != null or playing:
		return
	var folder: String = _save_folder()
	load_dialog.current_dir = folder if DirAccess.make_dir_recursive_absolute(folder) == OK else _downloads_folder()
	load_dialog.popup_centered(Vector2i(1100, 700))

func _load_game(path: String) -> void:
	if _job != null or playing:
		return
	var envelope = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(envelope) != TYPE_DICTIONARY or envelope.get("codec") != "U13_GAME_JSON_SAVE_V1" or typeof(envelope.get("payload")) != TYPE_STRING:
		_busy_label.text = "This is not a U13 playable saved game."
		return
	var raw = bytes_to_var(Marshalls.base64_to_raw(envelope.payload))
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var candidate = PlaySession.new()
	var result: Dictionary = candidate.restore_checkpoint(raw)
	if result.action == "invalid":
		_busy_label.text = "Could not load game: " + str(result.get("reason", "invalid save"))
		return
	_reset_direct()
	_ledger_before = {}
	_ledger_round = candidate.round_number() # Loaded mid-round: show totals, never invent a baseline.
	session = candidate
	playtime = Playtime.new()
	playtime.restore(envelope.get("playtime"))
	setup_open = false
	setup_picker.hide()
	match_started = true
	queued = candidate._powers.duplicate(true)
	var order: Dictionary = candidate._order
	castle_plan = order.get("castle_action", {}).duplicate(true)
	guard_plan = order.get("guard_moves", []).duplicate(true)
	summon_plan = order.get("summon", {}).duplicate(true)
	rites_plan = order.get("rites", {}).duplicate(true)
	fracture_choice = order.get("fracture_target", "infrastructure")
	_draft_combat = order.duplicate(true)
	for key in ["castle_action", "guard_moves", "summon", "rites"]: _draft_combat.erase(key)
	powers_step = false
	staged_order = {}
	payment = []
	playing = false
	gem_dagger_view.clear()
	artillery_view.clear()
	_install_impacts([])
	lanes.reset_effects()
	_refresh()
	if session.is_finished(): _open_game_menu()
	else: reopen_decision()


func _work_preview() -> String:
	if not _visible_world.has("guard_work"): return ""
	var target_id: String = castle_plan.get("target_id", "") if castle_plan.get("action") == "Work" else _visible_world.guard_work.target
	if target_id.is_empty(): return "Work target: none · choose WORK TARGET"
	var target: Dictionary = _entity(target_id)
	if target.is_empty(): return "Work target unavailable"
	var work: int = guard_plan.size()
	var counts: Dictionary = {}
	for move in guard_plan:
		if _entity(move.card_id).get("attributes", {}).get("suit") == "Wright": counts[move.lane] = int(counts.get(move.lane, 0)) + 1
	for count in counts.values():
		if count >= 2: work += 5
	var a: Dictionary = target.attributes
	var passive: int = 3 if a.construction_state != "active" or a.status == "ruined" else 0
	var locked: bool = passive == 0 and int(a.get("repair_lock_until_round", 0)) >= session.round_number()
	return "Work: %s · %d/%d · Guards/pairs +%d · passive +%d → %d%s" % [a.castle_type, a.integrity, a.max_integrity, work, passive, mini(a.max_integrity, a.integrity + (0 if locked else work + passive)), " · repair locked" if locked else ""]

func _show_work_target() -> void:
	var id: String = _visible_world.get("guard_work", {}).get("target", "")
	if castle_plan.get("action") == "Work": id = castle_plan.get("target_id", "")
	for side in sides:
		for card in side.castle_row.get_children():
			card.set_work_target(not id.is_empty() and card.get_meta("castle_id", "") == id)

func _commission(id: String) -> void:
	if not _planning() or playing or _job != null: return
	var prior: Dictionary = castle_plan
	castle_plan = {} if castle_plan.get("action") == "Activate" and castle_plan.get("target_id") == id else {"action": "Activate", "target_id": id, "card_ids": [], "use_repair_token": false}
	if _error(session.choose(queued, _order())):
		castle_plan = prior
		return
	if powers_step: staged_order = _order()
	_refresh()

func _open_work_target() -> void:
	if not _planning(): return
	choosing_work = not choosing_work
	phase_prompt.set_presenting(false)
	_refresh()
	if choosing_work:
		_busy_label.text = "WORK · click a pulsing Castle. Click the selected target to clear it; WORK TARGET cancels."
		_pulse_targets()

func _work_target_allowed(target: Dictionary) -> bool:
	if not _planning() or target.get("kind") != "castle" or target.get("owner") != 0: return false
	var order: Dictionary = _order().duplicate(true)
	order["castle_action"] = Work.choice(str(target.id))
	var checked: Dictionary = session._owner.preview_submission(0, queued, order)
	return checked.action != "invalid"

func _choose_target(target: Dictionary) -> void:
	if not choosing_work:
		super._choose_target(target)
		return
	if not _work_target_allowed(target): return
	var current: String = castle_plan.get("target_id", _visible_world.guard_work.target)
	_set_work_target("" if current == target.id else str(target.id))

func _pulse_targets() -> void:
	if not choosing_work:
		super._pulse_targets()
		return
	for id in sides[1].target_controls:
		if _work_target_allowed(_entity_target(id)):
			_flash_selected(_entity_target(id))

func _set_work_target(id: String) -> void:
	var prior: Dictionary = castle_plan
	castle_plan = Work.choice(id)
	if _error(session.choose(queued, _order())):
		castle_plan = prior
		return
	choosing_work = false
	_refresh()
	reopen_decision()

func _drop_intent(target: Dictionary) -> String:
	if target.get("owner") == 0:
		return "Guard" if target.get("kind") == "zone" else "Ward"
	return super._drop_intent(target)

func _guard_drop_target(target: Dictionary) -> Dictionary:
	if target.get("owner") != 0 or target.get("kind") != "zone" or target.has("slot"): return target
	for slot in range(3):
		var cell: Dictionary = target.duplicate(true)
		cell["slot"] = slot
		if _target_allowed(cell, "Guard"): return cell
	return target

func _can_drop(at_position: Vector2, data, target: Dictionary) -> bool:
	return super._can_drop(at_position, data, _guard_drop_target(target))

func _drop(at_position: Vector2, data, target: Dictionary) -> void:
	choosing_work = false
	super._drop(at_position, data, _guard_drop_target(target))

func _show_pair_badges() -> void:
	var pairs: Array = _visible_world.guard_work.pairs.duplicate(true)
	var fresh: Dictionary = {}
	for move in guard_plan:
		var suit: String = _entity(move.card_id).get("attributes", {}).get("suit", "")
		var key: String = move.lane + ":" + suit
		if not fresh.has(key): fresh[key] = {"lane": move.lane, "suit": suit, "slots": []}
		fresh[key].slots.append(move.slot)
	for pair in fresh.values():
		pair.slots.sort()
		if pair.slots.size() >= 2:
			pair.slots = pair.slots.slice(0, 2)
			pairs.append(pair)
	for pair in pairs:
		var side = sides[1 if int(pair.get("player_id", 0)) == 0 else 0]
		var box = side.lord_guard_box if pair.lane == "Lord" else side.castle_guard_box
		for slot in pair.slots:
			if slot >= box.get_child_count(): continue
			var card = box.get_child(slot)
			var badge := Label.new()
			badge.text = "◆ " + pair.suit
			badge.add_theme_font_size_override("font_size", 10)
			badge.modulate = Color("e6cc75")
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(badge)
			var benefit: String = {"Butcher": "When attacked, destroy one random enemy Marcher in this lane.", "Penitent": "5 protection before Guards while intact.", "Wright": "+5 work once on placement.", "Vulture": "Draw 1 each following round while intact."}[pair.suit]
			card.input_surface.tooltip_text += "\nBonded " + pair.suit + " pair. " + benefit + " Either card leaving breaks the bond; a replacement does not restore it."


# Presentation telemetry lives beside the save payload, never inside match state.
func _encode_playable_save() -> String:
	_sample_playtime()
	var envelope: Dictionary = JSON.parse_string(PlaySession.Game.encode_snapshot(session.checkpoint()))
	envelope["playtime"] = playtime.snapshot()
	return JSON.stringify(envelope)

func _playtime_mode() -> String:
	if _playtime_paused or not _playtime_focused or not match_started or setup_open:
		return "excluded"
	# A worker owns the session while running: do not read it from this thread.
	if _job != null or playing:
		return "resolution"
	if not session is PlaySession or session.is_finished():
		return "excluded"
	return "decision"

func _sample_playtime() -> void:
	playtime.sample(Time.get_ticks_msec(), _playtime_mode())

func _process(delta: float) -> void:
	_sample_playtime()
	super._process(delta)
	_sample_playtime()
	if playtime_label != null:
		playtime_label.text = "PLAYTIME " + Playtime.duration(playtime.decision_ms + playtime.resolution_ms) + (" *" if not playtime.history_complete else "")
		playtime_label.tooltip_text = playtime.summary() + "\nExcludes setup, pauses, unfocused time and time closed. Decision time includes reviewing the board/Aftermath. Resolution includes computation and playback." + ("\n* Earlier playtime is unknown; this is the recorded portion only." if not playtime.history_complete else "")
		pause_button.disabled = not match_started or setup_open or _job != null or playing or session.is_finished()

func _playtime_focus(focused: bool) -> void:
	_sample_playtime()
	_playtime_focused = focused
	_sample_playtime()

func _pause_playtime() -> void:
	if not match_started or setup_open or _job != null or playing or session.is_finished(): return
	_sample_playtime()
	_playtime_paused = true
	_sample_playtime()
	get_tree().paused = true
	pause_dialog.popup_centered(Vector2i(440, 160))

func _resume_playtime() -> void:
	pause_dialog.hide()
	_playtime_paused = false
	get_tree().paused = false
	_sample_playtime()

func start_loadout(lords: Array, castles: Array, quick: bool) -> void:
	var previous = session
	_sample_playtime()
	super.start_loadout(lords, castles, quick)
	if session != previous:
		playtime = Playtime.new()
	_sample_playtime()

func _start_job(operation: String, powers: Array = [], order: Dictionary = {}) -> void:
	_sample_playtime()
	if _playtime_mode() != "excluded":
		playtime.sample(Time.get_ticks_msec(), "resolution")
	super._start_job(operation, powers, order)
	_sample_playtime()

func open_setup() -> void:
	_sample_playtime()
	super.open_setup()
	_sample_playtime()

func close_setup() -> void:
	_sample_playtime()
	super.close_setup()
	_sample_playtime()

func _exit_tree() -> void:
	if _playtime_paused:
		get_tree().paused = false
	super._exit_tree()


func restart() -> void:
	var can_restart: bool = not setup_open and _job == null and _runtime_ok
	_sample_playtime()
	super.restart()
	if can_restart:
		playtime = Playtime.new()
	_sample_playtime()
