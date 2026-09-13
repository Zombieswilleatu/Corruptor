extends "res://Prototype/U13/U13KanifousBoard.gd"

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
	game_button = _button(header.history_box, "GAME / RITES", _open_game_menu)
	var files := HBoxContainer.new()
	header.history_box.add_child(files)
	save_button = _button(files, "SAVE", _save_game)
	load_button = _button(files, "LOAD", _open_load)
	load_dialog = FileDialog.new()
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_dialog.filters = PackedStringArray(["*.json ; U13 saved game"])
	load_dialog.file_selected.connect(_load_game)
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
	header.scope.text = "U13 · YOU vs DOCTRINE"
	header.scope.tooltip_text = "Full game · Dominion, Ritual or Final Collapse. Veil threshold penalties are disabled."
	header.veil_label.text = "VEIL %d · TEARS %d : %d · NEUTRAL %d" % [w.veil_total, w.personal_tears[0], w.personal_tears[1], w.neutral_tears]
	game_button.disabled = _job != null or playing or setup_open
	save_button.disabled = not _can_save()
	load_button.disabled = _job != null or playing
	if _planning() and not _human_alive():
		status.text = "Your Lord is banished. Your army can still Hunt; stage resummoning in Guards & Lord Return."
	if _planning() and _intent == "Pillage":
		status.text = "Pillage the empty enemy Castle zone. Click hand cards, then continue to powers."
	if not rites_plan.is_empty():
		plan_label.text += "\nTear rites staged · inspect or clear in GAME / RITES."
	if not session.pending_choice.is_empty() and _job == null:
		call_deferred("_show_economy")

func _target_allowed(target: Dictionary, intent: String) -> bool:
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
		phase_prompt.set_presenting(false)
		confirm.disabled = true
		next_button.disabled = true

func _confirm_decision() -> void:
	if session is PlaySession and (session.is_finished() or not session.pending_choice.is_empty()):
		_open_game_menu()
		return
	super._confirm_decision()

func _complete_job() -> void:
	super._complete_job()
	if session is PlaySession and session.is_finished() and not playing:
		_open_game_menu()

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
			game_menu.button("SWAP CARDS", func(): _economy({"market": "Swap", "take_id": w.market[take.selected], "give_id": w.hand[give.selected]}))
		game_menu.button("PASS TRADE", _economy.bind({"market": "Pass"}))
	game_menu.button("SAVE AND RETURN LATER", _save_game)
	game_menu.message.text = choice_error

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
		game_menu.present("YOU WIN" if outcome.winner == 0 else "OPPONENT WINS", "%s · round %d" % [outcome.win_by, outcome.round])
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
	game_menu.button("PILLAGE EMPTY ENEMY CASTLE ZONE", _stage_pillage)
	game_menu.button("PROFANE A FULL CASTLE · gain a Tear", _choose_profane)
	game_menu.button("SPEND FIVE WAITERS · gain a Tear", _choose_waiters)
	game_menu.button("INVOCATION · once per game · value 11 at Veil 7+", _choose_invocation)
	game_menu.button("PROFANE RUINS · pay 2 Souls with two ruins", _choose_ruins)
	game_menu.button("CLEAR TEAR RITES · return reserved cards / waiters", func(): rites_plan = {}; _refresh(); _open_game_menu())
	if not rites_plan.is_empty():
		game_menu.label("Staged: " + ", ".join(rites_plan.keys()))

func _stage_pillage() -> void:
	if _visible_world.entities.any(func(e): return e.owner == 1 and Structures.targetable(e)):
		game_menu.message.text = "An active targetable enemy Castle remains. Siege it first."
		return
	game_menu.hide()
	_intent = "Pillage"
	_target = {"id": Plunder.zone_id(1), "kind": "zone", "owner": 1, "lane": "Castle"}
	action_choice.select(1)
	powers_step = false
	_refresh()
	reopen_decision()

func _apply_cards(ids: Array, append: bool) -> bool:
	if _intent != "Pillage":
		return super._apply_cards(ids, append)
	var selected: Array = _draft_combat.get("card_ids", []).duplicate() if append else []
	for id in ids:
		if id not in selected:
			selected.append(id)
	var combat: Dictionary = {"action": "Siege", "lane": "Castle", "target_id": Plunder.zone_id(1), "card_ids": selected}
	var order: Dictionary = _with_development(combat)
	if not castle_plan.is_empty():
		order["castle_action"] = castle_plan.duplicate(true)
	if _error(session.choose(queued, order)):
		return false
	_draft_combat = combat
	_refresh()
	return true

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
		game_menu.message.text = _friendly_error(result)
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
	game_menu.present("SPEND WAITERS", "Choose exactly five waiting marchers in one lane. Each selected group creates one Personal Tear.")
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
		game_menu.message.text = _friendly_error(result)
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
		"rites_shape_invalid": "Choose exactly five different waiting marchers in one lane.",
		"rite_waiter_unavailable": "Choose five of your available waiting marchers in the same lane.",
		"profane_ruins_insufficient_souls": "Profaning a ruin costs 2 Souls.",
		"profane_ruins_target_unavailable": "You need at least two ruined Castles; select one of them.",
		"rite_castle_already_reserved": "That Castle is already part of your development order."
	}
	return messages.get(result.get("reason", ""), super._friendly_error(result))

func _error(result: Dictionary) -> bool:
	if result.action == "invalid" and session is PlaySession and not session.pending_choice.is_empty():
		choice_error = _friendly_error(result)
	return super._error(result)

func _save_game() -> void:
	if not _can_save():
		return
	if _planning():
		var checked: Dictionary = session.choose(queued, _order())
		if checked.action == "invalid":
			game_menu.message.text = "Finish or clear the incomplete order before saving."
			return
	var folder: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if folder.is_empty(): folder = OS.get_user_data_dir()
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = folder.path_join("u13-playable-%s-r%d-%d.json" % [stamp, session.round_number(), Time.get_ticks_usec()])
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_busy_label.text = "Could not write the saved game."
		game_menu.message.text = _busy_label.text
		return
	file.store_string(PlaySession.Game.encode_snapshot(session.checkpoint()))
	file.close()
	_busy_label.text = "Saved game: " + path
	game_menu.message.text = _busy_label.text
	print("U13 saved game: " + path)

func _open_load() -> void:
	if _job != null or playing:
		return
	load_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
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
	session = candidate
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
