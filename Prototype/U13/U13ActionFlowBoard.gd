extends "res://Prototype/U13/U13PlayableBoard.gd"

const STEPS: Array = ["Work Target", "Resummon", "Guards", "Combat", "Lord Powers", "Dominion Rites"]
var flow_step: int = 0
var flow_ready: bool = false
var flow_work: VBoxContainer
var flow_back: Button
var flow_fracture: VBoxContainer
const Forecast = preload("res://Scripts/Sim/U13ActionForecast.gd")
var flow_support: Label
var flow_forecast: Label

func _build() -> void:
	super._build()
	var contents: Control = action_zone.get_node("ActionScroll/ActionContents")
	game_menu.embed_in(contents)
	game_menu.closed.disconnect(reopen_decision)
	game_menu.closed.connect(_flow_menu_closed)
	flow_work = VBoxContainer.new()
	contents.add_child(flow_work)
	work_button.reparent(flow_work)
	_label(flow_work, "Choose a Castle on the board. New Guards provide work; unfinished construction also gains 3 each round.", 13).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow_fracture = VBoxContainer.new()
	contents.add_child(flow_fracture)
	_label(flow_fracture, "Hunt Fracture", 13)
	var fracture: OptionButton = _option(flow_fracture, ["Infrastructure", "Subjects"])
	fracture.item_selected.connect(func(index): fracture_choice = "infrastructure" if index == 0 else "subjects"; _refresh())
	flow_forecast = _label(action_zone.action_box, "", 16)
	flow_forecast.name = "SelectedActionForecast"
	flow_forecast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow_support = _label(contents, "", 13)
	flow_support.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow_back = _button(contents, "BACK", _flow_back)
	game_button.hide()
	flow_ready = true

func _reset_direct() -> void:
	flow_step = 0
	powers_step = false
	staged_order = {}
	super._reset_direct()

func _refresh(presented: Dictionary = {}) -> void:
	super._refresh(presented)
	_sync_flow()

func _update_direct_ui() -> void:
	super._update_direct_ui()
	_sync_flow()

func _sync_flow() -> void:
	if not flow_ready or not match_started or setup_open or not session is PlaySession: return
	game_button.hide()
	for child in powers_box.get_children():
		if child is Button and child.text.begins_with("Back to combat"): child.hide()
	flow_work.hide()
	flow_fracture.hide()
	flow_support.hide()
	flow_forecast.hide()
	flow_back.hide()
	if playing or _job != null or session.next_hook().is_empty(): return
	var mandatory: bool = not session.pending_choice.is_empty()
	if not mandatory and not _planning(): return
	var step: String = _flow_title()
	action_zone.show()
	action_zone.action_box.visible = not mandatory and step == "Combat"
	castle_box.hide()
	development_box.visible = not mandatory and step in ["Resummon", "Guards"]
	for child in development_box.get_children():
		if child is Button:
			child.visible = (child == guard_button or child.text.begins_with("Clear Guard")) if step == "Guards" else (child == summon_button or child.text.begins_with("Cancel resummon"))
	powers_box.visible = not mandatory and step == "Lord Powers"
	flow_work.visible = not mandatory and step == "Work Target"
	flow_support.visible = not mandatory and step == "Combat"
	var forecast: Dictionary = Forecast.evaluate({"world": _visible_world.merged({"viewer_id": 0})}, _order()) if flow_support.visible else {}
	flow_support.text = Forecast.text(forecast) if flow_support.visible else ""
	var action: String = _intent if _intent in ["Hunt", "Siege", "Ward"] else _draft_combat.get("action", "")
	var selected: Button = action_zone.action_buttons.get(action)
	if flow_support.visible and selected != null:
		action_zone.action_box.move_child(flow_forecast, selected.get_index() + (0 if flow_forecast.get_index() < selected.get_index() else 1))
		flow_forecast.text = Forecast.compact(forecast, action) if _draft_combat.get("action") == action else ""
		if flow_forecast.text.is_empty(): flow_forecast.text = "Select cards and a target for visible offense / defense."
		flow_forecast.tooltip_text = "Current visible board only. Hidden orders and later effects can change the result. Full calculation below."
		flow_forecast.show()
		action_zone.get_node("ActionScroll").call_deferred("ensure_control_visible", flow_forecast)
	flow_fracture.visible = not mandatory and step == "Combat" and _draft_combat.get("action") == "Hunt"
	flow_fracture.get_child(1).select(0 if fracture_choice == "infrastructure" else 1)
	flow_back.visible = not mandatory and flow_step > 0
	var previous: int = flow_step - 1
	while (previous == 1 and _human_alive()) or (previous == 4 and not _human_alive()): previous -= 1
	flow_back.text = "BACK · " + str(STEPS[maxi(0, previous)])
	if not mandatory and step != "Dominion Rites": game_menu.hide()
	phase_prompt.bind_decision("FLOW_" + step, step.to_upper(), _flow_copy(step), "ROUND %d" % session.round_number())
	confirm.visible = not mandatory
	confirm.disabled = not _planning()
	confirm.text = "RESOLVE ROUND" if step == "Dominion Rites" else "DONE · NEXT"
	pass_button.visible = not mandatory
	pass_button.disabled = not _planning()
	pass_button.text = "NO RITES · RESOLVE" if step == "Dominion Rites" else "SKIP " + step.to_upper()
	pass_button.tooltip_text = "Skip this step. Other staged choices are retained."
	if mandatory:
		if step == "Slaver":
			confirm.show()
			confirm.text = "SWAP CARDS"
			confirm.disabled = not slaver_swap.is_valid() or _job != null
			pass_button.show()
			pass_button.text = "PASS TRADE"
			pass_button.disabled = _job != null
			pass_button.tooltip_text = "Keep your hand and decline this trade."
		phase_prompt.set_presenting(true)
	phase_prompt.call_deferred("_sync_decision_bottom_actions_v12")

func _flow_title() -> String:
	if not session.pending_choice.is_empty():
		return "Stockpile" if session.pending_choice.action == "game_draw_choice" else "Slaver"
	return STEPS[flow_step]

func _playtime_surface() -> String:
	var shared: String = super._playtime_surface()
	if shared in ["history", "aftermath", "stockpile", "slaver", "board_review", "game_menu"]:
		return shared
	return ["work_target", "resummon", "guards", "combat_commitment", "lord_powers", "dominion_rites"][flow_step]

func _flow_copy(step: String) -> String:
	match step:
		"Stockpile": return "Choose the card to keep. Then visit the Slaver."
		"Slaver": return "Trade a card or pass. Then choose this round's work."
		"Work Target": return _work_preview()
		"Resummon": return "Choose your return payment, then Done. Skip to remain banished."
		"Guards": return "Place Guards in either zone, then Done. Each new Guard supplies work."
		"Combat": return "Choose Siege, Hunt, Ward or skip. Select cards, then Done."
		"Lord Powers": return "Stage your optional powers, then Done to review Dominion rites."
		"Dominion Rites": return "Choose optional rites, then resolve all staged orders."
	return ""

func _show_economy() -> void:
	super._show_economy()
	_sync_flow()

func _sync_decision() -> void:
	super._sync_decision()
	_sync_flow()

func reopen_decision() -> void:
	if flow_ready and match_started and session is PlaySession and session.is_finished() and not game_menu.visible:
		_refresh()
	super.reopen_decision()
	_sync_flow()

func _confirm_decision() -> void:
	if _slaver_pending():
		if slaver_swap.is_valid(): slaver_swap.call()
		return
	if _planning():
		_advance_flow()
	else:
		super._confirm_decision()

func _advance_flow() -> void:
	if not _planning(): return
	if _error(session.choose(queued, _order())): return
	if flow_step == STEPS.size() - 1:
		resolve_round()
		return
	_goto_flow(flow_step + 1, true)

func _goto_flow(index: int, skip_unavailable: bool = false) -> void:
	_sample_playtime()
	flow_step = clampi(index, 0, STEPS.size() - 1)
	if skip_unavailable:
		while (flow_step == 1 and _human_alive()) or (flow_step == 2 and not _guards_available()) or (flow_step == 4 and not _human_alive()):
			flow_step += 1
	powers_step = flow_step >= 4
	staged_order = _order().duplicate(true) if powers_step else {}
	choosing_work = false
	_intent = ""
	_target = {}
	hand_view.clear_selection()
	_refresh()
	if flow_step == 5:
		_open_game_menu()
	else:
		reopen_decision()
	_sample_playtime()

func _flow_back() -> void:
	if _planning() and flow_step > 0:
		var prior: int = flow_step - 1
		while (prior == 1 and _human_alive()) or (prior == 4 and not _human_alive()): prior -= 1
		_goto_flow(prior)

func _slaver_pending() -> bool:
	return session is PlaySession and not session.pending_choice.is_empty() and session.pending_choice.action != "game_draw_choice" and _job == null

func pass_round() -> void:
	if _slaver_pending():
		_economy({"market": "Pass"})
		return
	if not _planning(): return
	match flow_step:
		0: castle_plan = Work.choice("")
		1: summon_plan = {}
		2: guard_plan = []
		3: _draft_combat = {}; action_choice.select(0)
		4: queued = []; _power_cost = []; payment = []
		5: rites_plan = {}
	_advance_flow()

func enter_powers() -> void:
	if not _planning() or _error(session.choose(queued, _order())): return
	_goto_flow(4, true)

func back_to_combat() -> void:
	if _planning(): _goto_flow(3)

func _set_work_target(id: String) -> void:
	super._set_work_target(id)
	if _planning() and castle_plan.get("target_id") == id and flow_step == 0:
		_advance_flow()

func _open_game_menu() -> void:
	if _planning():
		flow_step = 5
		powers_step = true
		game_menu.present("DOMINION RITES", "Optional rites use the remaining cards, Souls, Castles or Supplicants.", false)
		game_menu.button("PROFANE CASTLE", _choose_profane)
		game_menu.label("Sacrifice a full Castle for a Tear. Replaces this round's combat.", 13)
		game_menu.button("SPEND FIVE SUPPLICANTS", _choose_waiters)
		game_menu.button("INVOCATION", _choose_invocation)
		game_menu.button("PROFANE RUINS", _choose_ruins)
		game_menu.button("CLEAR RITES", func(): rites_plan = {}; _refresh(); _open_game_menu())
		if not rites_plan.is_empty(): game_menu.label("Staged: " + ", ".join(rites_plan.keys()), 13)
		_sync_flow()
		phase_prompt.set_presenting(true)
		return
	super._open_game_menu()
	_sync_flow()
	if match_started and session.is_finished() and game_menu.visible:
		phase_prompt.bind_decision("FLOW_RESULT", "YOU WIN" if session.outcome().winner == 0 else "OPPONENT WINS", "", "ROUND %d" % session.round_number())
		action_zone.show()
		action_zone.action_box.hide()
		powers_box.hide()
		development_box.hide()
		flow_work.hide()
		confirm.hide()
		pass_button.hide()
		phase_prompt.set_presenting(true)

func _flow_menu_closed() -> void:
	if _planning() and flow_step == 5: _open_game_menu()
	else: reopen_decision()

func _stage_profane(id: String) -> void:
	super._stage_profane(id)
	if _planning() and _draft_combat.get("action") == "Profane": _open_game_menu()

func _drop(at_position: Vector2, data, target: Dictionary) -> void:
	if _planning() and not powers_step:
		flow_step = 2 if _drop_intent(target) == "Guard" else 3
	super._drop(at_position, data, target)

func _load_game(path: String) -> void:
	_sample_playtime()
	_playtime_loading = true
	_sample_playtime()
	var prior_session = session
	super._load_game(path)
	# A loaded cart resumes at Work; all staged choices stay available for review.
	if session != prior_session and _planning(): _goto_flow(0)
	_playtime_loading = false
	_sample_playtime()

func _apply_cards(ids: Array, append: bool) -> bool:
	var placing: bool = flow_step == 2 and _intent == "Guard"
	var accepted: bool = super._apply_cards(ids, append)
	if accepted and placing and not _guards_available():
		call_deferred("_finish_guards_if_full")
	return accepted

func _finish_guards_if_full() -> void:
	if _planning() and flow_step == 2: _advance_flow()

func _guards_available() -> bool:
	if _available_ids().is_empty(): return false
	for lane in ["Lord", "Castle"]:
		for slot in range(3):
			if _target_allowed({"kind": "zone", "owner": 0, "lane": lane, "slot": slot}, "Guard"): return true
	return false
