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
var _flow_details_action: String = ""
var _card_sfx: AudioStreamPlayer
var _commit_sfx: AudioStreamPlayer
var _march_sfx: AudioStreamPlayer
var _march_release_sfx: AudioStreamPlayer
var _card_draw_sfx: AudioStreamPlayer
var _battle_sfx: AudioStreamPlayer
var _block_sfx: AudioStreamPlayer
var _resolution_hit_sfx: AudioStreamPlayer
var _resolution_hit_streams: Dictionary = {}
var _last_reveal_sfx_ms: int = -10000
var _block_playback: Playback
var _last_block_at: float = -1.0
var _last_battle_sfx_ms: int = -1000
var _last_card_sfx_ms: int = -1000
var _modal_choose_sfx: AudioStreamPlayer
var _modal_back_sfx: AudioStreamPlayer
var _last_modal_sfx_ms: int = -1000
var _gameplay_sfx: AudioStreamPlayer
var _gameplay_streams: Dictionary = {}
var _last_siege_impact_ms: int = -1000
var _audio_round_before: int = -1
var ruin_visual
var _ruin_installing: bool = false

func _build() -> void:
	super._build()
	_install_sound_cues()
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
	flow_support = _label(action_zone.action_box, "", 13)
	flow_support.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow_back = _button(contents, "BACK", _flow_back)
	game_button.hide()
	flow_ready = true
	_install_modal_clicks()
	_install_gameplay_cues()
	resolution_view.strike_landed.connect(_on_resolution_strike)
	resolution_view.attack_revealed.connect(_on_resolution_reveal)
	recipe_menu.closed.connect(_play_gameplay_cue.bind("ui_close"))
	var power_details = preload("res://Prototype/U13/U13PowerDetails.gd").new()
	add_child(power_details)
	power_details.install(self)
	ruin_visual = preload("res://Prototype/U13/U13RuinVisual.gd").new()
	add_child(ruin_visual)
	ruin_visual.impact.connect(func(_hit): _play_gameplay_cue("castle_hit"))
	ruin_visual.finished.connect(_refresh)

func _install_gameplay_cues() -> void:
	_gameplay_sfx = AudioStreamPlayer.new()
	add_child(_gameplay_sfx)
	_resolution_hit_sfx = AudioStreamPlayer.new()
	add_child(_resolution_hit_sfx)
	for cue in ["ui_denied", "combat_ward", "combat_hunt", "combat_siege", "grimoire_chosen", "card_place", "castle_commission", "lord_power_select", "ui_open", "ui_close", "ui_save", "ui_load", "card_return", "card_pair", "guard_stationed", "aftermath_tally", "reward", "victory_dominion", "victory_ritual", "defeat", "monster_lands", "card_draw", "castle_hit", "siege_impact", "soul_gain", "tear_gain", "round_transition", "commit_reveal", "profane"]:
		_gameplay_streams[cue] = AudioStreamWAV.load_from_file("res://Sounds/Cues/%s.wav" % cue)
	for cue in ["siege_resolution_hit", "siege_intercept", "hunt_impact", "hunt_banish", "hunt_withstood", "castle_collapse"]:
		_resolution_hit_streams[cue] = AudioStreamWAV.load_from_file("res://Sounds/Cues/%s.wav" % cue)

func _play_gameplay_cue(cue: String) -> void:
	var sound: AudioStream = _gameplay_streams.get(cue)
	if sound == null: return
	_gameplay_sfx.stream = sound
	var volume: float = -11.0
	if cue == "combat_ward": volume = -10.0
	elif cue in ["ui_open", "ui_close", "ui_save", "ui_load", "aftermath_tally"]: volume = -7.0
	elif cue in ["card_return", "card_pair"]: volume = -8.0
	elif cue == "siege_impact": volume = -9.0
	_gameplay_sfx.volume_db = volume
	_gameplay_sfx.play()

func _error(result: Dictionary) -> bool:
	var rejected: bool = super._error(result)
	if rejected: _play_gameplay_cue("ui_denied")
	return rejected

func _select_direct_action(action: String) -> void:
	var active: String = _intent if _intent in ["Hunt", "Siege", "Ward"] else _draft_combat.get("action", "")
	if _planning() and flow_step == 3 and action == active and action in ["Hunt", "Siege", "Ward"]:
		_flow_details_action = "" if _flow_details_action == action else action
		_sync_flow()
		return
	_flow_details_action = ""
	var previous: String = _intent
	super._select_direct_action(action)
	if action in ["Ward", "Hunt", "Siege"] and _planning() and flow_step == 3 and _intent == action and (previous != action or action == "Ward"):
		_play_gameplay_cue("combat_" + action.to_lower())

func _reserve_ward() -> void:
	var can_reserve: bool = _planning() and not powers_step and _draft_combat.get("action") == "Ward" and not _draft_combat.get("card_ids", []).is_empty()
	super._reserve_ward()
	if can_reserve and not ward_plan.is_empty(): _play_gameplay_cue("combat_ward")

func _select_grimoire_summon(monster: String) -> void:
	var accepted: bool = not monster.is_empty() and _planning() and not playing and _job == null and monster in _available_monsters(_draft_combat.get("card_ids", []))
	super._select_grimoire_summon(monster)
	if accepted: _play_gameplay_cue("grimoire_chosen")

func _commission(id: String) -> void:
	var previous: Dictionary = castle_plan.duplicate(true)
	super._commission(id)
	if _planning() and castle_plan != previous and castle_plan.get("action") == "Activate":
		_play_gameplay_cue("castle_commission")

func _arm_power(power: String) -> void:
	var previous: String = _intent
	super._arm_power(power)
	if _planning() and _intent == power and previous != power:
		_play_gameplay_cue("lord_power_select")

func _open_recipes() -> void:
	super._open_recipes()
	if recipe_menu != null and recipe_menu.visible:
		_play_gameplay_cue("ui_open")

func _on_resolution_reveal() -> void:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_reveal_sfx_ms < 1100: return
	_last_reveal_sfx_ms = now_ms
	_play_gameplay_cue("commit_reveal")

func _on_resolution_strike(step: Dictionary) -> void:
	var result: Dictionary = step.get("result", {})
	var cue: String = ""
	if step.get("kind", "") == "intercept":
		cue = "siege_intercept"
	elif step.get("lane", "") == "Castle":
		if result.get("destroyed", false): cue = "castle_collapse"
		elif result.get("pillage", false) and result.get("pillage_success", false): cue = "hunt_impact"
		elif int(result.get("damage", 0)) > 0: cue = "siege_resolution_hit"
		else: cue = "siege_intercept"
	elif result.get("banished", false):
		cue = "hunt_banish"
	else:
		cue = "hunt_impact" if int(result.get("guards_defeated", 0)) > 0 else "hunt_withstood"
	var stream: AudioStream = _resolution_hit_streams.get(cue)
	if stream == null: return
	_resolution_hit_sfx.stream = stream
	_resolution_hit_sfx.volume_db = -9.0 if cue in ["siege_resolution_hit", "hunt_banish", "castle_collapse"] else -11.0
	_resolution_hit_sfx.play()

func _artillery_impact(shot: Dictionary) -> void:
	super._artillery_impact(shot)
	if shot.get("target_after", {}).is_empty(): return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_siege_impact_ms < 180: return
	_last_siege_impact_ms = now_ms
	_play_gameplay_cue("siege_impact")

func _start_job(operation: String, powers: Array = [], order: Dictionary = {}) -> void:
	if operation == "next_round" and _job == null and session is PlaySession:
		_audio_round_before = session.round_number()
	super._start_job(operation, powers, order)

func _complete_job() -> void:
	# Reserve presentation before super binds decisions or considers tutorials.
	_ruin_installing = true
	var previous_session = session
	var event_cursor: int = session._owner._event_cursor()
	var operation: String = _job_operation
	var staged_release: bool = operation == "marching" and (
		(staging_modes.get("Lord", "Hold") == "March" and not staging_ids.get("Lord", []).is_empty())
		or (staging_modes.get("Castle", "Hold") == "March" and not staging_ids.get("Castle", []).is_empty())
	)
	super._complete_job()
	if session != previous_session and ruin_visual != null:
		var events: Array = session._owner._player_selected_events_since(0, event_cursor, ["CASTLE_DAMAGED"])
		ruin_visual.play_events(events, sides, session.board_view().world, _ruin_modal_controls())
	_ruin_installing = false
	if staged_release and playing and _march_release_sfx.stream != null:
		_march_release_sfx.play()
	if operation == "next_round" and _job == null and session is PlaySession and session.round_number() > _audio_round_before:
		_play_gameplay_cue("round_transition")
		if _card_draw_sfx.stream != null: _card_draw_sfx.play()
	if operation == "aftermath" and _job == null and session is PlaySession:
		if session.is_finished():
			var outcome: Dictionary = session.outcome()
			if int(outcome.get("winner", -1)) != 0:
				_play_gameplay_cue("defeat")
			elif outcome.get("win_by", "") == "Ritual":
				_play_gameplay_cue("victory_ritual")
			elif outcome.get("win_by", "") == "Dominion":
				_play_gameplay_cue("victory_dominion")
			else:
				_play_gameplay_cue("reward")
		else:
			_play_gameplay_cue("aftermath_tally")

func _install_modal_clicks() -> void:
	_modal_choose_sfx = AudioStreamPlayer.new()
	_modal_choose_sfx.stream = AudioStreamWAV.load_from_file("res://Sounds/Cues/modal_choose.wav")
	_modal_choose_sfx.volume_db = -9.0
	add_child(_modal_choose_sfx)
	_modal_back_sfx = AudioStreamPlayer.new()
	_modal_back_sfx.stream = AudioStreamWAV.load_from_file("res://Sounds/Cues/modal_back.wav")
	_modal_back_sfx.volume_db = -10.0
	add_child(_modal_back_sfx)
	get_tree().node_added.connect(_register_modal_control)
	_scan_modal_controls(self)

func _scan_modal_controls(parent: Node) -> void:
	_register_modal_control(parent)
	for child in parent.get_children():
		_scan_modal_controls(child)

func _register_modal_control(node: Node) -> void:
	if not (node is BaseButton or node is OptionButton): return
	var owner_node: Node = node.get_parent()
	var in_modal: bool = false
	while owner_node != null and owner_node != self:
		if owner_node == phase_prompt or owner_node == action_zone or owner_node == game_menu or owner_node == recipe_menu or owner_node == summon_menu or owner_node == setup_picker:
			# The earlier GameMenu patch already handles its own clicks if installed.
			if owner_node.has_method("_play_choose_sound"): return
			in_modal = true
			break
		owner_node = owner_node.get_parent()
	if not in_modal: return
	if node is OptionButton:
		var option_button: OptionButton = node as OptionButton
		var selected: Callable = _play_modal_choice.bind(option_button)
		if not option_button.item_selected.is_connected(selected): option_button.item_selected.connect(selected)
	elif node is BaseButton:
		var button: BaseButton = node as BaseButton
		var clicked: Callable = _play_modal_click.bind(button)
		if not button.pressed.is_connected(clicked): button.pressed.connect(clicked)

func _play_modal_choice(_index: int, control: BaseButton) -> void:
	_play_modal_click(control)

func _play_modal_click(control: BaseButton) -> void:
	if not is_instance_valid(control): return
	# The three combat choices and Ward reservation have their own material cues.
	if action_zone != null and control in action_zone.action_buttons.values(): return
	if control == reserve_ward_button: return
	if recipe_menu != null and control == recipe_menu.close_button: return
	if control.text.strip_edges().to_upper().begins_with("SAVE "): return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_modal_sfx_ms < 65: return
	_last_modal_sfx_ms = now_ms
	var label_text: String = control.text.strip_edges().to_upper()
	var is_back: bool = label_text.begins_with("BACK") or label_text.begins_with("RETURN") or label_text.begins_with("CANCEL") or label_text.begins_with("NO ")
	var player: AudioStreamPlayer = _modal_back_sfx if is_back else _modal_choose_sfx
	if player.stream != null: player.play()

func _install_sound_cues() -> void:
	_card_sfx = AudioStreamPlayer.new()
	_card_sfx.stream = AudioStreamWAV.load_from_file("res://Sounds/Cues/card_select.wav")
	_card_sfx.volume_db = -14.0
	add_child(_card_sfx)
	_commit_sfx = AudioStreamPlayer.new()
	_commit_sfx.stream = AudioStreamWAV.load_from_file("res://Sounds/Cues/commit_seal.wav")
	_commit_sfx.volume_db = -8.0
	add_child(_commit_sfx)
	_march_sfx = AudioStreamPlayer.new()
	_march_sfx.stream = AudioStreamWAV.load_from_file("res://Sounds/Cues/staging_march_select.wav")
	_march_sfx.volume_db = -9.0
	add_child(_march_sfx)
	_march_release_sfx = AudioStreamPlayer.new()
	_march_release_sfx.stream = AudioStreamWAV.load_from_file("res://Sounds/Cues/march_release.wav")
	_march_release_sfx.volume_db = -9.0
	add_child(_march_release_sfx)
	_card_draw_sfx = AudioStreamPlayer.new()
	_card_draw_sfx.stream = AudioStreamWAV.load_from_file("res://Sounds/Cues/card_draw.wav")
	_card_draw_sfx.volume_db = -8.0
	add_child(_card_draw_sfx)
	_battle_sfx = AudioStreamPlayer.new()
	_battle_sfx.stream = AudioStreamWAV.load_from_file("res://Sounds/Cues/melee_hit.wav")
	_battle_sfx.volume_db = -15.0
	add_child(_battle_sfx)
	_block_sfx = AudioStreamPlayer.new()
	_block_sfx.stream = AudioStreamWAV.load_from_file("res://Sounds/Cues/melee_block.wav")
	_block_sfx.volume_db = -12.0
	add_child(_block_sfx)
	hand_view.selection_changed.connect(_on_card_sound_selection)
	board_staging.march_requested.connect(_on_march_sound_requested)

func _on_card_sound_selection(card_ids: Array) -> void:
	if card_ids.is_empty() or _card_sfx.stream == null: return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_card_sfx_ms < 90: return
	_last_card_sfx_ms = now_ms
	_card_sfx.play()

func _on_march_sound_requested(lane: String) -> void:
	if staging_modes.get(lane, "") == "March" and not staging_ids.get(lane, []).is_empty() and _march_sfx.stream != null:
		_march_sfx.play()

func _process(delta: float) -> void:
	if ruin_visual != null and ruin_visual.active():
		# The visual owns its clock, including when a waiting tutorial paused
		# the tree. Gameplay and other presentation wait until it releases them.
		return
	var prior_feedback: int = _feedback_cursor
	super._process(delta)
	if playback != _block_playback:
		_block_playback = playback
		_last_block_at = -1.0
	if not playing or playback == null: return
	var now_ms: int = Time.get_ticks_msec()
	# Look through the recorded timeline, so fast playback cannot skip a block.
	var block_at: float = playback.latest_blocked_attack_at(clock, _last_block_at)
	if block_at > _last_block_at:
		_last_block_at = block_at
		if _block_sfx.stream != null and now_ms - _last_battle_sfx_ms >= 360:
			_last_battle_sfx_ms = now_ms
			_block_sfx.play()
			return
	if _feedback_cursor <= prior_feedback or _battle_sfx.stream == null: return
	if playback.sample(clock).get("clash", []).is_empty(): return
	if now_ms - _last_battle_sfx_ms < 360: return
	for index in range(prior_feedback, _feedback_cursor):
		var row: Dictionary = playback.feedback_rows[index]
		if float(row.get("hp", 0)) < 0.0 or float(row.get("armor", 0)) < 0.0:
			_last_battle_sfx_ms = now_ms
			_battle_sfx.play()
			break

func _resolution_pending() -> bool:
	return _ruin_installing or (ruin_visual != null and ruin_visual.active()) or super._resolution_pending()


func _ruin_modal_controls() -> Array:
	return [phase_prompt, game_menu, recipe_menu, summon_menu, reconfiguration_menu,
		history_panel, price_visual, get_node_or_null("DecisionPanelOverlayV5"),
		get_node_or_null("DecisionPanelActionOverlayV12")]


func _planning() -> bool:
	return (ruin_visual == null or not ruin_visual.active()) and super._planning()


func _reset_direct() -> void:
	if ruin_visual != null: ruin_visual.clear()
	if phase_prompt != null: phase_prompt.reset_scroll_memory()
	_flow_details_action = ""
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
	var combat_visible: bool = not mandatory and step == "Combat"
	var forecast: Dictionary = Forecast.evaluate({"world": _visible_world.merged({"viewer_id": 0})}, _order()) if combat_visible else {}
	var action: String = _intent if _intent in ["Hunt", "Siege", "Ward"] else _draft_combat.get("action", "")
	if _flow_details_action != action: _flow_details_action = ""
	flow_support.visible = combat_visible and not action.is_empty() and _flow_details_action == action
	flow_support.text = _flow_action_help(action) + "\n\n" + Forecast.text(forecast) if flow_support.visible else ""
	var selected: Button = action_zone.action_buttons.get(action)
	if combat_visible and selected != null:
		action_zone.action_box.move_child(flow_forecast, selected.get_index() + (0 if flow_forecast.get_index() < selected.get_index() else 1))
		action_zone.action_box.move_child(flow_support, flow_forecast.get_index() + (0 if flow_support.get_index() < flow_forecast.get_index() else 1))
		flow_forecast.text = Forecast.compact(forecast, action) if _draft_combat.get("action") == action else ""
		if flow_forecast.text.is_empty(): flow_forecast.text = "Select cards and a target for visible offense / defense."
		flow_forecast.tooltip_text = "Visible board only; hidden orders may change the result. Click the selected action for the full calculation."
		flow_forecast.show()
	flow_fracture.visible = not mandatory and step == "Combat" and _draft_combat.get("action") == "Hunt"
	flow_fracture.get_child(1).select(0 if fracture_choice == "infrastructure" else 1)
	flow_back.visible = not mandatory and flow_step > 0
	var previous: int = flow_step - 1
	while (previous == 1 and _human_alive()) or (previous == 4 and not _powers_available()): previous -= 1
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
	# bind_decision shows the modal again; targeting must win after that binding.
	_sync_power_targeting()

func _flow_title() -> String:
	if not session.pending_choice.is_empty():
		return "Stockpile" if session.pending_choice.action == "game_draw_choice" else "Slaver"
	return STEPS[flow_step]

func _flow_action_help(action: String) -> String:
	match action:
		"Hunt": return "Attack the enemy Lord. Select cards and a target, or drag cards onto the enemy Lord."
		"Siege": return "Pillage the enemy Castle zone when no enemy Castle can be targeted." if _pillage_available() else "Attack an enemy Castle. Select cards and a target, or drag cards onto the Castle."
		"Ward": return ("Drag cards to your Lord or Castles to defend that lane. You can use separate cards for Hunt or Siege. " if _visible_world.has("ward_experiment") else "Select cards and your Lord or Castle zone to defend. ") + "Ward recruits normal marchers at 2:1 but cannot summon a new monster."
	return ""

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
		"Guards": return "Place Guards in either zone."
		"Combat": return "Choose an action and cards. Click the selected action for details."
		"Lord Powers": return "Stage powers or skip."
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
	if summon_menu != null and summon_menu.visible: return
	if _error(session.choose(queued, _order())): return
	if flow_step == 3 and _offer_grimoire_summons(): return
	if flow_step == STEPS.size() - 1:
		if _commit_sfx.stream != null: _commit_sfx.play()
		resolve_round()
		return
	_goto_flow(flow_step + 1, true)

func _continue_after_grimoire() -> void:
	if flow_step == 3: _advance_flow()

func _goto_flow(index: int, skip_unavailable: bool = false) -> void:
	_sample_playtime()
	_flow_details_action = ""
	flow_step = clampi(index, 0, STEPS.size() - 1)
	if flow_step == 3: _summon_prompt_options = []
	if skip_unavailable:
		while (flow_step == 1 and _human_alive()) or (flow_step == 2 and not _guards_available()) or (flow_step == 4 and not _powers_available()):
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
		while (prior == 1 and _human_alive()) or (prior == 4 and not _powers_available()): prior -= 1
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
		5:
			rites_plan = {}
			game_menu.pending_selection = Callable()
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
		game_menu.present("DOMINION RITES", "Click a rite for details, or resolve without one.", false)
		game_menu.details("PROFANE CASTLE · +1 Tear", "Sacrifice a full, active Castle. Replaces this round's combat.", "CHOOSE CASTLE", _choose_profane)
		game_menu.details("FIVE SUPPLICANTS · +1 Tear", "Spend five Supplicants from the same lane for 1 Personal Tear.", "CHOOSE SUPPLICANTS", _choose_waiters)
		game_menu.details("INVOCATION · +1 Tear", "Once per game. Commit unused hand cards worth at least 11. Requires Veil 7+.", "CHOOSE CARDS", _choose_invocation)
		game_menu.details("PROFANE RUINS · 2 Souls → 1 Tear", "Requires at least two ruined Castles. Pay 2 Souls and choose one ruin to profane.", "CHOOSE RUIN", _choose_ruins)
		game_menu.button("CLEAR RITES", func(): rites_plan = {}; _refresh(); _open_game_menu())
		if not rites_plan.is_empty(): game_menu.label("Staged: " + _rites_summary(), 13)
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
	var previous_profane: Dictionary = _draft_combat.duplicate(true)
	super._stage_profane(id)
	if _draft_combat != previous_profane and _draft_combat.get("action") == "Profane":
		_play_gameplay_cue("profane")
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
	if session != prior_session: _play_gameplay_cue("ui_load")
	elif not path.is_empty(): _play_gameplay_cue("ui_denied")
	_playtime_loading = false
	_sample_playtime()

func _save_game() -> void:
	var prior_message: String = _busy_label.text
	super._save_game()
	if _busy_label.text.begins_with("Saved game: ") and _busy_label.text != prior_message:
		_play_gameplay_cue("ui_save")
	else:
		_play_gameplay_cue("ui_denied")

func _return_card(role: String, id: String) -> void:
	var reserved: bool = _hand_reserved(id)
	super._return_card(role, id)
	if reserved and not _hand_reserved(id): _play_gameplay_cue("card_return")

func _apply_cards(ids: Array, append: bool) -> bool:
	var placing: bool = flow_step == 2 and _intent == "Guard"
	var previous_count: int = _intent_cards().size() if not placing else 0
	var previous_guards: int = guard_plan.size()
	var accepted: bool = super._apply_cards(ids, append)
	if accepted and not placing and _intent_cards().size() > previous_count:
		_play_gameplay_cue("card_place")
	if accepted and placing and guard_plan.size() > previous_guards:
		var newest: Dictionary = guard_plan.back()
		var suit: String = _entity(newest.card_id).get("attributes", {}).get("suit", "")
		var same_suit: int = 0
		for move in guard_plan:
			if move.lane == newest.lane and _entity(move.card_id).get("attributes", {}).get("suit", "") == suit:
				same_suit += 1
		_play_gameplay_cue("card_pair" if not suit.is_empty() and same_suit == 2 else "guard_stationed")
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

func _powers_available() -> bool:
	return _human_alive() or _visible_world.get("breach_wish_access", [false, false])[0]
