extends "res://Prototype/U13/U13KanifousBoard.gd"

const VictoryRules = preload("res://Scripts/Sim/U13Victory.gd")
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
var ward_plan: Dictionary = {}
var reserve_ward_button: Button
var clear_ward_button: Button
var ward_note: Label
const MonsterRules = preload("res://Scripts/Sim/U13MonsterRules.gd")
const StagingTray = preload("res://Prototype/U13/U13GameStagingTray.gd")
const BoardStaging = preload("res://Prototype/U13/U13BoardStaging.gd")
var board_staging
var staging_modes: Dictionary = {"Lord": "Hold", "Castle": "Hold"}
var staging_round: int = 0
var staging_ids: Dictionary = {}
var _opening_playback = null
var _opening_clock: float = 0.0
var _opening_round: int = 0
var _opening_unit_ids: Array = []
var _opening_feedback_cursor: int = 0
var _opening_death_cursor: int = 0
var _warm_round_job = null
var _warm_round_source = null
var monster_choice: String = ""
var monster_picker: OptionButton
var monster_note: Label
var recipe_menu
var summon_menu
var _summon_prompt_options: Array = []
const HandRecipeHints = preload("res://Prototype/U13/U13HandRecipeHints.gd")
var hand_recipe_hints
var _recipe_hand_separation: int = -52
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
var _playtime_loading: bool = false
var _playtime_round: int = 0

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
	board_staging = BoardStaging.new()
	board_staging.name = "BoardStaging"
	lanes.add_child(board_staging)
	# Recover decorative spacing so bottom reserve controls fit the 1080 canvas.
	var board_stack: VBoxContainer = sides[0].get_parent()
	board_stack.add_theme_constant_override("separation", 3)
	board_stack.get_child(1).custom_minimum_size.y = 0
	lanes.get_parent().get_parent().add_theme_constant_override("separation", 4)
	board_staging.march_requested.connect(func(lane):
		if not _planning() or playing or _job != null: return
		staging_ids[lane] = _visible_world.game_staging.lanes[lane].units.filter(func(u): return u.owner == 0 and int(u.attributes.staged_round) < session.round_number()).map(func(u): return u.id)
		if staging_ids[lane].is_empty(): return
		staging_modes[lane] = "March"
		if powers_step: staged_order = _order()
		_refresh())
	recipe_menu = GameMenu.new()
	add_child(recipe_menu)
	summon_menu = GameMenu.new()
	add_child(summon_menu)
	summon_menu.z_index = 130
	summon_menu.closed.connect(func(): _summon_prompt_options = [])
	_button(header.tools_box, "GRIMOIRES", _open_recipes)
	# Keep the existing hand intact; planning hints share its bottom row.
	var hand_parent: Node = hand_view.get_parent()
	var hand_index: int = hand_view.get_index()
	var hand_row := HBoxContainer.new()
	hand_row.name = "HandAndRecipes"
	hand_row.add_theme_constant_override("separation", 10)
	hand_parent.add_child(hand_row)
	hand_parent.move_child(hand_row, hand_index)
	hand_view.reparent(hand_row)
	hand_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_recipe_hints = HandRecipeHints.new()
	hand_row.add_child(hand_recipe_hints)
	_recipe_hand_separation = hand_view.hand_box.get_theme_constant("separation")
	resized.connect(_fit_recipe_hand)
	for row in sides:
		row.get_node("PromptCastleGutter").item_rect_changed.connect(_queue_main_modal_fit)
	_queue_main_modal_fit()
	monster_picker = _option(action_zone.action_box, ["No monster summon"])
	monster_picker.name = "MonsterSummonChoice"
	monster_picker.item_selected.connect(func(index): monster_choice = str(monster_picker.get_item_metadata(index)); _refresh())
	reserve_ward_button = _button(action_zone.action_box, "RESERVE WARD", _reserve_ward)
	reserve_ward_button.tooltip_text = "Choose Ward, its lane and cards first. Reserve those cards, then choose Hunt or Siege with your remaining hand."
	clear_ward_button = _button(action_zone.action_box, "CLEAR RESERVED WARD", _clear_ward)
	ward_note = _label(action_zone.action_box, "", 13)
	ward_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	monster_note = _label(action_zone.action_box, "", 13)
	monster_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	work_button = _button(header.history_box, "WORK TARGET", _open_work_target)
	work_button.tooltip_text = "Click, then select a pulsing Castle. Each newly placed Guard gives 1 work; a fresh Wright pair adds 5 construction or 3 repair work. Unbuilt targets also gain 3 per round. No card payment."
	action_zone.action_buttons["Ward"].tooltip_text = "Defend a lane and recruit one Marcher per 2 printed suit value. Ward cannot summon grimoire monsters. Hunt and Siege recruit at 3:1 and can summon monsters."
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

func _queue_main_modal_fit() -> void:
	call_deferred("_fit_main_modal")

func _fit_main_modal() -> void:
	if phase_prompt == null or sides.size() != 2: return
	var inverse: Transform2D = get_global_transform().affine_inverse()
	var left: float = -INF
	var right: float = INF
	for row in sides:
		if row.lord_guard_box.get_child_count() == 0 or row.castle_row.get_child_count() == 0: return
		for card in row.lord_guard_box.get_children():
			var rect: Rect2 = inverse * card.get_global_rect()
			left = maxf(left, rect.end.x)
		for card in row.castle_row.get_children():
			var rect: Rect2 = inverse * card.get_global_rect()
			right = minf(right, rect.position.x)
	phase_prompt.fit_board_gutter(left, right)

func _development_stacks(stacks: Array) -> void:
	super._development_stacks(stacks)
	if ward_plan.is_empty() or not _planning() or setup_open: return
	var before: int = stacks.size()
	_add_stack(stacks, "reserved_ward", "WARD", ward_plan.card_ids, {"id": "", "kind": "zone", "owner": 0, "lane": ward_plan.lane})
	if stacks.size() > before: stacks.back().locked = powers_step

func _return_card(role: String, id: String) -> void:
	if role != "reserved_ward":
		super._return_card(role, id)
		return
	if not _planning() or powers_step: return
	ward_plan.card_ids.erase(id)
	if ward_plan.card_ids.is_empty(): ward_plan = {}
	_refresh()

func _reserve_ward() -> void:
	if not _planning() or powers_step or _draft_combat.get("action") != "Ward" or _draft_combat.get("card_ids", []).is_empty(): return
	ward_plan = _draft_combat.duplicate(true)
	_draft_combat = {}
	_intent = ""
	_target = {}
	monster_choice = ""
	_refresh()

func _clear_ward() -> void:
	if not _planning() or powers_step: return
	ward_plan = {}
	_refresh()

func _planning() -> bool:
	return super._planning() and session is PlaySession and session.pending_choice.is_empty() and not session.is_finished()

func _with_development(order: Dictionary) -> Dictionary:
	var result: Dictionary = super._with_development(order)
	result.erase("ward")
	if not ward_plan.is_empty():
		if result.has("action"):
			result["ward"] = ward_plan.duplicate(true)
		elif not result.has("action"):
			result.merge(ward_plan.duplicate(true))
	if _visible_world.has("game_staging"):
		result["staging"] = staging_modes.duplicate()
		result["staging_ids"] = staging_ids.duplicate(true)
	if not rites_plan.is_empty():
		result["rites"] = rites_plan.duplicate(true)
	if result.get("action") == "Hunt":
		result["fracture_target"] = fracture_choice
	result.erase("monster_choice")
	if result.get("action") in ["Hunt", "Siege"] and not monster_choice.is_empty() and monster_choice in _available_monsters(result.get("card_ids", []), result.get("action", "")):
		result["monster_choice"] = monster_choice
	return result

func _hand_reserved(id: String) -> bool:
	return id in ward_plan.get("card_ids", []) or id in rites_plan.get("invocation", {}).get("card_ids", []) or super._hand_reserved(id)

func _reset_direct() -> void:
	choosing_work = false
	if _job_operation != "next_round":
		staging_modes = {"Lord": "Hold", "Castle": "Hold"}
		staging_round = 0
		staging_ids = {}
	rites_plan = {}
	ward_plan = {}
	monster_choice = ""
	fracture_choice = "infrastructure"
	choice_error = ""
	if game_menu != null:
		game_menu.pending_selection = Callable()
		game_menu.hide()
	if recipe_menu != null: recipe_menu.hide()
	if summon_menu != null: summon_menu.hide()
	_summon_prompt_options = []
	_hide_hand_recipe_hints()
	super._reset_direct()

func _refresh(presented: Dictionary = {}) -> void:
	var view: Dictionary = session.board_view() if presented.is_empty() else presented
	if session is PlaySession and not playing:
		# Set before show_world observes disappearing bodies. Concealment
		# is not death, and a reappearing body must be observable again.
		lanes.quiet_removal_ids = view.world.get("concealed_ids", []).duplicate()
		if _opening_round != session.round_number():
			for event in session._opening_marching:
				if event.type == "MARCHING_STARTED":
					lanes.quiet_removal_ids.append_array(event.data.units.map(func(u): return u.id))
		elif _opening_playback != null:
			lanes.quiet_removal_ids.append_array(_opening_unit_ids)
	super._refresh(view)
	_queue_main_modal_fit()
	_hide_hand_recipe_hints()
	if not session is PlaySession:
		return
	var w: Dictionary = _visible_world
	var split: bool = w.get("ward_experiment") == "U13_SPLIT_WARD_V1"
	reserve_ward_button.visible = split
	reserve_ward_button.disabled = not _planning() or powers_step or _draft_combat.get("action") != "Ward" or _draft_combat.get("card_ids", []).is_empty()
	clear_ward_button.visible = split and not ward_plan.is_empty()
	clear_ward_button.disabled = not _planning() or powers_step
	ward_note.visible = split
	ward_note.text = "Ward %s reserved · %d cards. Hunt or Siege can use the remaining hand." % [ward_plan.lane, ward_plan.card_ids.size()] if not ward_plan.is_empty() else "Optional: reserve one paid Ward, then Hunt or Siege. No Sigils. A Ward that prevents a successful attack earns 1 Soul (once per round)."
	if not ward_plan.is_empty(): plan_label.text += "\nWard %s · %d cards reserved" % [ward_plan.lane, ward_plan.card_ids.size()]
	if staging_round != session.round_number():
		staging_ids = {}
		for lane in staging_modes:
			if staging_modes[lane] == "March": staging_modes[lane] = "Hold"
		staging_round = session.round_number()
	lanes.live_layout = w.has("game_staging")
	lanes.custom_minimum_size.x = 680.0 if lanes.live_layout else 435.0
	var display_controls: Control = lanes.get_node("UnitDisplayControls")
	display_controls.offset_top = 4 if lanes.live_layout else 123
	display_controls.offset_bottom = 32 if lanes.live_layout else 151
	board_staging.bind(w.get("game_staging", {}), session.round_number(), staging_modes, _planning() and not playing and _job == null and not setup_open)
	lanes.queue_redraw()
	_sync_monsters()
	lanes.monster_fields = w.get("monsters", {}).get("fields", []).filter(func(f): return f.expires_round >= session.round_number())
	header.bind_playable_veil(w, session.round_number())
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
	_sync_hand_recipe_hints()
	_sync_opening_march()

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
	var operation: String = _job_operation
	super._complete_job()
	if operation == "aftermath" and session is PlaySession and session.next_hook().is_empty() and not session.is_finished():
		# Work on a detached next round while the player reviews Aftermath.
		_discard_warm_round()
		_warm_round_job = BoardJob.new()
		_warm_round_source = session
		var result: Dictionary = _warm_round_job.start(session, "next_round")
		if result.action == "invalid":
			_warm_round_job = null
			_warm_round_source = null
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
	_sync_hand_recipe_hints()

func _sync_hand_recipe_hints() -> void:
	if hand_recipe_hints == null: return
	if not match_started or setup_open or playing or _job != null or not session is PlaySession:
		_hide_hand_recipe_hints()
		return
	if not _planning() and session.pending_choice.is_empty():
		_hide_hand_recipe_hints()
		return
	# Combat cards still belong to a potential summon. Other allocations do
	# not: moving a card into Guards/rites/powers must update the guidance.
	var reserved: Array = ward_plan.get("card_ids", []) + payment + castle_plan.get("card_ids", []) + summon_plan.get("card_ids", []) + _power_cost + rites_plan.get("invocation", {}).get("card_ids", [])
	for move in guard_plan: reserved.append(move.card_id)
	var combat_cards: Array = []
	if _draft_combat.get("action") == "Ward": reserved.append_array(_draft_combat.get("card_ids", []))
	if _draft_combat.get("action") in ["Hunt", "Siege"]:
		combat_cards = _draft_combat.get("card_ids", []).filter(func(id): return id not in reserved)
	hand_recipe_hints.show_for(_visible_world, reserved, combat_cards)
	_fit_recipe_hand()

func _fit_recipe_hand() -> void:
	if hand_recipe_hints == null or not hand_recipe_hints.visible: return
	var count: int = hand_view.card_buttons.size()
	if count < 2: return
	# The lanes retain their width. Fan a full hand more tightly while the
	# recipe strip is open instead of pushing the battlefield off screen.
	var card_width: float = hand_view.card_buttons[0].custom_minimum_size.x
	var space: float = size.x - lanes.get_combined_minimum_size().x - 24.0 - hand_recipe_hints.custom_minimum_size.x - 10.0 - 52.0
	var separation: int = mini(_recipe_hand_separation, floori((space - card_width * count) / (count - 1)))
	hand_view.hand_box.add_theme_constant_override("separation", separation)

func _hide_hand_recipe_hints() -> void:
	if hand_recipe_hints == null: return
	hand_recipe_hints.dismiss()
	hand_view.hand_box.add_theme_constant_override("separation", _recipe_hand_separation)

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
	var tempo: bool = _visible_world.get("tempo_experiment") == "U13_VEIL_ATTACK_ROUND25_V1"
	game_menu.present("GAME / TEAR RITES", ("Ritual: %d Souls with your Lord present. Dominion: Veil %d+, at least %d Personal Tears and more than your opponent. " % [VictoryRules.RITUAL_SOULS, VictoryRules.DOMINION_VEIL, VictoryRules.DOMINION_TEARS]) + ("Round 25 ends the game after normal victories; most Souls wins (seat 0 wins a tie). Veil 15/19/23 adds +1/+2/+3 committed attack strength. From round 20, a Hunt banishment or Siege destruction earns +1 Soul, once per player per round. Reserve one paid Ward alongside Hunt or Siege. Ward protects only its chosen lane; no Sigils." if tempo else "Final Collapse: Veil 26; most Souls wins (seat 0 wins a tie)."))
	if not _planning():
		game_menu.label("Round resolved. Return to the board and continue to the next round.")
		return
	game_menu.label("Hunt Fracture")
	var fracture = game_menu.option(["Infrastructure", "Subjects"])
	fracture.select(0 if fracture_choice == "infrastructure" else 1)
	fracture.item_selected.connect(func(index): fracture_choice = "infrastructure" if index == 0 else "subjects"; _refresh())
	game_menu.button("PROFANE A FULL CASTLE · gain a Tear", _choose_profane)
	game_menu.button("SPEND FIVE SUPPLICANTS", _choose_waiters)
	game_menu.label("Gain 1 Personal Tear per group of five in the same lane.", 13)
	game_menu.button("INVOCATION · once per game · value 11 at Veil 7+", _choose_invocation)
	game_menu.button("PROFANE RUINS · pay 2 Souls with two ruins", _choose_ruins)
	game_menu.button("CLEAR TEAR RITES · return reserved cards / Supplicants", func(): rites_plan = {}; _refresh(); _open_game_menu())
	if not rites_plan.is_empty():
		game_menu.label("Staged: " + _rites_summary())

func _pillage_available() -> bool:
	return not _visible_world.get("entities", []).is_empty() and not _visible_world.entities.any(func(e): return e.owner == 1 and Structures.targetable(e))

func _select_direct_action(action: String) -> void:
	if action == "Ward" and not ward_plan.is_empty() and _planning() and not powers_step:
		_draft_combat = ward_plan.duplicate(true)
		ward_plan = {}
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
	if not _direct_binding: _sync_hand_recipe_hints()

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
	if not ward_plan.is_empty():
		game_menu.set_message("Clear the reserved Ward before choosing Profane.")
		return
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
	game_menu.present("SPEND SUPPLICANTS", "Select five Supplicants in one lane, then Resolve Round to gain 1 Personal Tear. Stage the group first if you want to add other rites. Unreserved Supplicants are automatically spent on your Hunt or Siege.")
	var selections: Array = []
	for lane in ["Lord", "Castle"]:
		var rows: Array = _visible_world.entities.filter(func(e): return e.kind == "marcher" and e.owner == 0 and e.attributes.lane == lane and e.attributes.waiting)
		game_menu.label(lane + " lane")
		var used: Array = []
		for spend in rites_plan.get("waiter_spends", []): used.append_array(spend.marcher_ids)
		rows = rows.filter(func(e): return e.id not in used)
		var boxes: Array = game_menu.checks(rows.map(func(e): return "%s · %s" % [str(e.attributes.get("monster_id", e.attributes.get("suit", "Marcher"))), str(e.id).get_slice(":", str(e.id).get_slice_count(":") - 1)]))
		selections.append({"lane": lane, "rows": rows, "boxes": boxes})
		game_menu.button("STAGE FIVE FROM " + lane.to_upper(), func():
			var selected: Array = []
			for index in range(rows.size()):
				if boxes[index].button_pressed: selected.append(rows[index].id)
			var spends: Array = rites_plan.get("waiter_spends", []).duplicate(true)
			spends.append({"lane": lane, "marcher_ids": selected})
			_stage_rite("waiter_spends", spends))
	game_menu.pending_selection = func() -> bool:
		var spends: Array = rites_plan.get("waiter_spends", []).duplicate(true)
		var added: bool = false
		for selection in selections:
			var selected: Array = []
			for index in range(selection.rows.size()):
				if selection.boxes[index].button_pressed: selected.append(selection.rows[index].id)
			if not selected.is_empty():
				spends.append({"lane": selection.lane, "marcher_ids": selected})
				added = true
		return _stage_rite("waiter_spends", spends) if added else true

func resolve_round() -> void:
	if not _planning(): return
	if game_menu.pending_selection.is_valid() and not game_menu.pending_selection.call(): return
	super.resolve_round()

func _rites_summary() -> String:
	var parts: PackedStringArray = []
	for spend in rites_plan.get("waiter_spends", []):
		parts.append("5 %s Supplicants → 1 Personal Tear" % spend.lane)
	if rites_plan.has("invocation"): parts.append("Invocation → 1 Personal Tear")
	if rites_plan.has("profane_ruins"): parts.append("Profane Ruins → 1 Personal Tear")
	return "; ".join(parts)

func _choose_ruins() -> void:
	game_menu.present("PROFANE RUINS", "With at least two ruined Castles, pay 2 Souls to profane one ruin and gain a Personal Tear.")
	for row in _visible_world.entities:
		if row.kind == "castle" and row.owner == 0 and row.attributes.status == "ruined":
			game_menu.button(_castle_name(row), _stage_rite.bind("profane_ruins", {"castle_id": row.id}))

func _stage_rite(key: String, value) -> bool:
	if not _planning():
		return false
	var proposed: Dictionary = rites_plan.duplicate(true)
	proposed[key] = value
	var order: Dictionary = _order()
	order["rites"] = proposed
	var result: Dictionary = session.choose(queued, order)
	if result.action == "invalid":
		game_menu.set_message(_friendly_error(result))
		return false
	rites_plan = proposed
	_refresh()
	_open_game_menu()
	return true

func _can_save() -> bool:
	return match_started and not setup_open and _job == null and not playing and session is PlaySession and (session.next_hook() == Timeline.SUBMISSION_LOCK or not session.pending_choice.is_empty() or session.next_hook().is_empty())

func _friendly_error(result: Dictionary) -> String:
	if result.get("reason") == "ward_cards_required": return "Ward requires at least one card. Skip combat to keep your hand."
	var messages: Dictionary = {
		"common_bot_python_unavailable": "The opponent needs Python 3.10 or newer. Start the game with run_u13_playable.sh to check its setup.",
		"common_bot_pipe_closed": "The opponent could not start. Run run_u13_playable.sh to check the Python setup.",
		"common_bot_worker_missing": "The opponent's files are missing. Update the checkout before starting the game.",
		"common_bot_worker_failed": "The opponent could not finish its decision. Your turn is unchanged; check the run log before retrying.",
		"common_bot_timeout": "The opponent took too long to respond. Your turn is unchanged; try again.",
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
	ward_plan = order.get("ward", {}).duplicate(true)
	monster_choice = order.get("monster_choice", "")
	fracture_choice = order.get("fracture_target", "infrastructure")
	staging_ids = order.get("staging_ids", {}).duplicate(true)
	_opening_playback = null
	_opening_round = candidate.round_number()
	staging_modes = order.get("staging", {"Lord": "Hold", "Castle": "Hold"}).duplicate()
	# Restore the saved clicked cohort exactly; do not rebuild it from the old board.
	for lane in ["Lord", "Castle"]:
		staging_modes[lane] = "March" if staging_modes.get(lane) == "March" else "Hold"
	staging_round = candidate.round_number()
	_draft_combat = order.duplicate(true)
	for key in ["castle_action", "guard_moves", "summon", "rites", "staging", "staging_ids", "ward"]: _draft_combat.erase(key)
	powers_step = false
	staged_order = {}
	payment = []
	playing = false
	gem_dagger_view.clear()
	artillery_view.clear()
	_install_impacts([])
	lanes.reset_effects()
	_refresh()
	header.veil_wheel.follow_current()
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
		if count >= 2: work += Work.wright_pair_work(target)
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
			var benefit: String = {"Butcher": "When attacked, destroy up to 2 random enemy Marchers in this lane.", "Penitent": "3 protection before Guards while intact.", "Wright": "+5 construction or +3 repair work once on placement, plus 1 work per new Guard.", "Vulture": "Draw 1 each following round while intact."}[pair.suit]
			card.input_surface.tooltip_text += "\nBonded " + pair.suit + " pair. " + benefit + " Either card leaving breaks the bond; a replacement does not restore it."


# Presentation telemetry lives beside the save payload, never inside match state.
func _encode_playable_save() -> String:
	_sample_playtime()
	var envelope: Dictionary = JSON.parse_string(PlaySession.Game.encode_snapshot(session.checkpoint()))
	envelope["playtime"] = playtime.snapshot()
	return JSON.stringify(envelope)

func _playtime_mode() -> String:
	if _playtime_paused or _playtime_loading or not _playtime_focused or not match_started or setup_open:
		return "excluded"
	# A worker owns the session while running: do not read it from this thread.
	if _job != null or playing:
		return "resolution"
	if not session is PlaySession or session.is_finished():
		return "excluded"
	return "decision"

func _sample_playtime() -> void:
	var mode: String = _playtime_mode()
	# Cache the round before starting a worker. Never read its mutable session.
	if _job == null and match_started and session is PlaySession:
		_playtime_round = session.round_number()
	playtime.sample(Time.get_ticks_msec(), mode, _playtime_round, _playtime_surface() if mode == "decision" else "")

func _playtime_surface() -> String:
	# Called only while idle, focused, and actively in a match.
	if history_panel != null and history_panel.visible:
		return "history"
	if session.next_hook().is_empty():
		return "aftermath"
	if not session.pending_choice.is_empty():
		return "stockpile" if session.pending_choice.action == "game_draw_choice" else "slaver"
	if choosing_work:
		return "work_target"
	if _intent == "Guard":
		return "guards"
	if phase_prompt != null and phase_prompt.board_view_collapsed and _intent.is_empty():
		return "board_review"
	if game_menu != null and game_menu.visible and not game_menu.embedded:
		return "game_menu"
	return "lord_powers" if powers_step else "combat_commitment"

func _process(delta: float) -> void:
	_sample_playtime()
	super._process(delta)
	_advance_opening_march(delta)
	_sample_playtime()
	if playtime_label != null:
		playtime_label.text = "PLAYTIME " + Playtime.duration(playtime.decision_ms + playtime.resolution_ms) + (" *" if not playtime.history_complete else "")
		playtime_label.tooltip_text = playtime.summary() + "\nExcludes setup, pauses, unfocused time and time closed. Decision time includes reviewing the board/Aftermath. Resolution includes computation and playback. Saves include timing by round and decision screen." + ("\n* Earlier playtime is unknown; this is the recorded portion only." if not playtime.history_complete else "")
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
		_opening_round = 0
		_opening_playback = null
		_sync_opening_march()
		playtime = Playtime.new()
		header.veil_wheel.follow_current()
	_sample_playtime()

func _start_job(operation: String, powers: Array = [], order: Dictionary = {}) -> void:
	if summon_menu != null: summon_menu.hide()
	_hide_hand_recipe_hints()
	_sample_playtime()
	if _job == null and session is PlaySession:
		_playtime_round = session.round_number() + (1 if operation == "next_round" else 0)
	if _playtime_mode() != "excluded":
		playtime.sample(Time.get_ticks_msec(), "resolution", _playtime_round)
	if operation == "marching": _finish_opening_march()
	super._start_job(operation, powers, order)
	if _job != null and board_staging != null: board_staging.set_editable(false)
	_sample_playtime()

func open_setup() -> void:
	if summon_menu != null: summon_menu.hide()
	_hide_hand_recipe_hints()
	_sample_playtime()
	super.open_setup()
	_sample_playtime()

func close_setup() -> void:
	_sample_playtime()
	super.close_setup()
	_sample_playtime()

func _exit_tree() -> void:
	_discard_warm_round()
	if _playtime_paused:
		get_tree().paused = false
	super._exit_tree()


func restart() -> void:
	var can_restart: bool = not setup_open and _job == null and _runtime_ok
	_sample_playtime()
	super.restart()
	if can_restart:
		playtime = Playtime.new()
		header.veil_wheel.follow_current()
	_sample_playtime()

func _available_monsters(cards: Array, action: String = "") -> Array:
	if action.is_empty(): action = _draft_combat.get("action", "")
	if action not in ["Hunt", "Siege"]: return []
	var state: Dictionary = _visible_world.get("monsters", {})
	if state.is_empty(): return []
	return MonsterRules.available(_visible_world.get("entities", []) + _staged_monsters(), cards, 0, state.unlocked[0])

func _sync_monsters() -> void:
	if monster_picker == null: return
	var available: Array = _available_monsters(_draft_combat.get("card_ids", []))
	if monster_choice not in available: monster_choice = ""
	monster_picker.clear()
	monster_picker.add_item("No monster summon")
	monster_picker.set_item_metadata(0, "")
	for name in available:
		monster_picker.add_item("Summon " + name)
		monster_picker.set_item_metadata(monster_picker.item_count - 1, name)
		if name == monster_choice: monster_picker.select(monster_picker.item_count - 1)
	monster_picker.disabled = not _planning() or available.is_empty()
	monster_note.text = "Commit a grimoire during Hunt or Siege to summon. Ward recruits normal marchers only." if available.is_empty() else "Choose one monster alongside your normal marchers. Printed card values do not affect grimoires."
	if not monster_choice.is_empty(): monster_note.text = MonsterRules.recipe_text(monster_choice) + " → " + monster_choice
	monster_picker.tooltip_text = MonsterRules.ROSTER[monster_choice].ability if not monster_choice.is_empty() else "Choose one qualifying grimoire, or keep No monster summon."
	if available.is_empty():
		_summon_prompt_options = []
		if summon_menu != null: summon_menu.hide()

func _offer_grimoire_summons() -> bool:
	if summon_menu == null or not _planning() or powers_step or playing or _job != null or setup_open: return false
	if _draft_combat.get("action") not in ["Hunt", "Siege", "Ward"]: return false
	var available: Array = _available_monsters(_draft_combat.get("card_ids", []))
	if available.is_empty() or available == _summon_prompt_options: return false
	_summon_prompt_options = available.duplicate()
	summon_menu.present("GRIMOIRE SUMMONS", "Your committed cards unlock these summons. Choose one to continue to Lord Powers, or continue without a summon.")
	summon_menu.close_button.text = "BACK TO COMMITMENT"
	for monster in available:
		var button: Button = summon_menu.button("SUMMON %s · %s" % [monster.to_upper(), MonsterRules.recipe_text(monster)], _select_grimoire_summon.bind(monster))
		button.tooltip_text = MonsterRules.ROSTER[monster].ability
	summon_menu.button("NO MONSTER SUMMON", _select_grimoire_summon.bind(""))
	return true

func _select_grimoire_summon(monster: String) -> void:
	if not _planning() or playing or _job != null: return
	if not monster.is_empty() and monster not in _available_monsters(_draft_combat.get("card_ids", [])): return
	monster_choice = monster
	summon_menu.hide()
	_refresh()
	_continue_after_grimoire()

func _continue_after_grimoire() -> void:
	pass

func _open_recipes() -> void:
	if recipe_menu == null: return
	recipe_menu.present("MONSTER GRIMOIRES", "Commit the named subjects together in Hunt or Siege, then choose a summon in the Combat step. One grimoire per round, alongside normal marchers. Ward keeps its defenses and 2:1 normal recruits but cannot summon a new monster. Existing field and staged monsters remain usable. Saved cards and cards spent on Guards, work, powers or rites do not count. All ten grimoires are unlocked for this prototype.")
	var available: Array = _available_monsters(_draft_combat.get("card_ids", []))
	for name in MonsterRules.NAMES:
		var r: Dictionary = MonsterRules.ROSTER[name]
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("242019")
		style.set_content_margin_all(14)
		panel.add_theme_stylebox_override("panel", style)
		recipe_menu.column.add_child(panel)
		var text := Label.new()
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_size_override("font_size", 16)
		var eligibility: String = "\nReady with your committed cards." if name in available else ""
		if MonsterRules.limited(name) and MonsterRules.living(_visible_world.get("entities", []) + _staged_monsters(), 0, name): eligibility = "\nAlready alive: summon another after it leaves play."
		text.text = "%s · %s\n%s\nAttack %d · Armor %d · Speed %d · HP %d\n%s%s" % [name, r.tier, MonsterRules.recipe_text(name), r.attack, r.armor, r.speed, r.hp, r.ability, eligibility]
		panel.add_child(text)
	recipe_menu.label("Initial playtest values: Sinodek's stats, HP, chances and ability ranges are provisional. Varn is 3–5 bodies per summon. Sooge and Sinodek each allow one living copy per player, with no fixed cooldown.", 14)


func _staged_monsters() -> Array:
	var result: Array = []
	for tray in _visible_world.get("game_staging", {}).get("lanes", {}).values(): result.append_array(tray.units)
	return result

# This tape is presentation only. Planning uses its fully resolved world, so
# taking longer in a modal never grants extra simulation time or changes a roll.
func _sync_opening_march() -> void:
	if not session is PlaySession or setup_open: return
	if _opening_round != session.round_number():
		_opening_round = session.round_number()
		_opening_playback = null
		var events: Array = session.opening_marching_events()
		if not events.is_empty():
			var tape = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
			if tape.build(events):
				_opening_playback = tape
				_opening_unit_ids = tape.sample(0).units.map(func(u): return u.id)
				_opening_clock = 0.0
				_opening_feedback_cursor = 0
				_opening_death_cursor = 0
				if kroni_visual != null: kroni_visual.load_tape(events)
	if _opening_playback != null:
		lanes.show_frame(_opening_playback.sample(_opening_clock), session.round_number())

func _advance_opening_march(delta: float) -> void:
	if _opening_playback == null or playing or setup_open: return
	if guard_chomp != null and guard_chomp.active(): return
	if kroni_visual != null and kroni_visual.busy(): return
	var step: float = kroni_visual.limit_delta(_opening_clock, delta) if kroni_visual != null else delta
	_opening_clock = minf(_opening_playback.duration, _opening_clock + maxf(0.0, step))
	var deaths: Dictionary = _opening_playback.deaths_through(_opening_clock, _opening_death_cursor)
	_opening_death_cursor = deaths.cursor
	lanes.show_deaths(deaths.rows)
	lanes.show_frame(_opening_playback.sample(_opening_clock), session.round_number())
	var feedback: Dictionary = _opening_playback.feedback_through(_opening_clock, _opening_feedback_cursor)
	_opening_feedback_cursor = feedback.cursor
	lanes.show_feedback(feedback.rows)
	if kroni_visual != null: kroni_visual.show_time(_opening_clock)
	if _opening_clock >= _opening_playback.duration: _finish_opening_march()

func _finish_opening_march() -> void:
	if _opening_playback == null: return
	lanes.show_frame(_opening_playback.sample(_opening_playback.duration), session.round_number())
	_opening_playback = null
	_opening_unit_ids = []
	lanes.quiet_removal_ids = _visible_world.get("concealed_ids", []).duplicate()
	if kroni_visual != null: kroni_visual.clear()

func finish_playback(skip: bool = true) -> void:
	_finish_opening_march()
	super.finish_playback(skip)

func _new_board_job(operation: String):
	if operation == "next_round" and _warm_round_job != null and _warm_round_source == session:
		var prepared = _warm_round_job
		_warm_round_job = null
		_warm_round_source = null
		return prepared
	return super._new_board_job(operation)

func _discard_warm_round() -> void:
	if _warm_round_job != null:
		_warm_round_job.join_on_exit()
		_warm_round_job = null
		_warm_round_source = null
