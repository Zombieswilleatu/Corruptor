extends "res://Prototype/U13/U13TutorialBoard.gd"

const HotSession = preload("res://Scripts/Sim/U13HotseatSession.gd")
const HotPicker = preload("res://Prototype/U13/U13HotseatPicker.gd")
const RecordedJob = preload("res://Prototype/U13/U13HotseatResultJob.gd")
const HotFeedback = preload("res://Prototype/U13/U13MarcherFeedback.gd")
var _privacy_layer: CanvasLayer
var _privacy: ColorRect
var _ready_heading: Label
var _ready_note: Label
var _ready_button: Button
var _seat_label: Label
var _covered: bool = false
var _handoff_seat: int = 0
var _handoff_action: String = "turn"
var _together_view: bool = false
var _playing_replay: bool = false
var _replay_aftermath: bool = false
var _live_session

func _hotseat() -> bool: return session is HotSession
func _new_loadout_picker():
	var picker = HotPicker.new()
	picker.full_game = true
	return picker
func _new_loadout_session():
	if setup_picker is HotPicker and setup_picker.hotseat_enabled():
		var candidate = HotSession.new()
		candidate.watch_mode = setup_picker.watch_mode()
		return candidate
	return super._new_loadout_session()

func _build() -> void:
	super._build()
	_seat_label = _label(header.history_box, "", 14)
	_seat_label.hide()
	_privacy_layer = CanvasLayer.new()
	_privacy_layer.name = "HotseatPrivacy"
	_privacy_layer.layer = 200
	add_child(_privacy_layer)
	_privacy = ColorRect.new()
	_privacy.color = Color("100f13")
	_privacy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_privacy.mouse_filter = Control.MOUSE_FILTER_STOP
	_privacy_layer.add_child(_privacy)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_privacy.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(700, 240)
	column.add_theme_constant_override("separation", 28)
	var handoff_panel := PanelContainer.new()
	var handoff_padding := StyleBoxEmpty.new()
	handoff_padding.set_content_margin_all(36)
	handoff_panel.add_theme_stylebox_override("panel", handoff_padding)
	center.add_child(handoff_panel)
	handoff_panel.add_child(column)
	preload("res://Prototype/U13/U13MenuSkin.gd").apply(handoff_panel)
	_ready_heading = _label(column, "", 34)
	_ready_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ready_note = _label(column, "", 20)
	_ready_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ready_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ready_button = _button(column, "READY", _accept_handoff)
	_ready_button.custom_minimum_size.y = 64
	_ready_button.add_theme_font_size_override("font_size", 24)
	_privacy.hide()

func _cover(seat_value: int, action: String = "turn") -> void:
	if not _hotseat(): return
	_sample_playtime()
	_covered = true
	_sample_playtime()
	_handoff_seat = seat_value
	_handoff_action = action
	_finish_opening_march()
	get_viewport().gui_release_focus()
	get_viewport().gui_cancel_drag()
	for modal in [game_menu, recipe_menu, summon_menu, history_panel, phase_prompt, context_help]:
		if modal != null: modal.hide()
	_hide_hand_recipe_hints()
	var lord: String = session._owner.canonical.player_view(seat_value, 0).world.lord_ids[seat_value]
	_ready_heading.text = "READY PLAYER %d — %s" % [seat_value + 1, lord.to_upper()]
	_ready_note.text = "Pass the controls. Press READY when only this player is looking."
	if session.has_replay(seat_value): _ready_note.text += "\nYour previous round's resolution plays before your turn."
	if action == "together":
		_ready_heading.text = "BOTH PLAYERS READY?"
		_ready_note.text = "Watch this round's resolution together. Private hands stay hidden."
	_ready_button.text = "WATCH TOGETHER" if action == "together" else "READY"
	_privacy.show()
	# No automatic focus: the commit's Enter/Space cannot dismiss the curtain.

func _accept_handoff() -> void:
	if not _covered: return
	_sample_playtime()
	var action: String = _handoff_action
	if action == "turn":
		_clear_seat_ui()
		session.switch_to(_handoff_seat)
		_ledger_before = {}
		_ledger_round = -1
	_covered = false
	_privacy.hide()
	if action == "together":
		var committed_powers: Array = queued.duplicate(true)
		var committed_order: Dictionary = _order()
		_together_view = true
		_clear_seat_ui()
		_refresh()
		_start_job("marching", committed_powers, committed_order)
		return
	if action == "next_round":
		_together_view = false
		_start_job("next_round")
		return
	if session.has_replay(session.active_seat):
		_begin_saved_replay()
		return
	_refresh()
	reopen_decision()

func _clear_seat_ui() -> void:
	_reset_direct()
	queued = []
	payment = []
	castle_plan = {}
	staged_order = {}
	powers_step = false
	hand_view.clear_selection()
	resolution_view.clear()
	_resolution_final_view = {}
	gem_dagger_view.clear()
	_gem_final_view = {}
	artillery_view.clear()
	_install_impacts([])
	lanes.reset_effects()
	for row in sides: row._castle_art_states.clear()
	_opening_playback = null
	_opening_round = session.round_number()
	_tutorial_events = []
	_tutorial_threat = {}
	_tutorial_threat_change = {}
	_tutorial_context_cache = {}
	_tutorial_event_cursor = session._owner._event_cursor()

func start_loadout(lords: Array, castles: Array, quick: bool) -> void:
	var previous = session
	super.start_loadout(lords, castles, quick)
	if session == previous: return
	_playing_replay = false
	_replay_aftermath = false
	_live_session = null
	_together_view = false
	if _hotseat(): _cover(session.required_seat())
	else:
		_covered = false
		_privacy.hide()

func resolve_round() -> void:
	if not _hotseat():
		super.resolve_round()
		return
	if not _planning(): return
	if game_menu.pending_selection.is_valid() and not game_menu.pending_selection.call(): return
	if session.active_seat == session.first_planner:
		var result: Dictionary = session.seal_first(queued, _order())
		if _error(result): return
		_cover(session.required_seat())
	elif session.watch_mode == "together":
		var result: Dictionary = session.choose(queued, _order())
		if _error(result): return
		_cover(session.active_seat, "together")
	else:
		super.resolve_round()

func _planning() -> bool:
	if _covered or _playing_replay or _replay_aftermath or _together_view: return false
	if _hotseat() and (session.required_seat() != session.active_seat or not session.sealed[session.active_seat].is_empty()): return false
	return super._planning()
func _show_economy() -> void:
	if _covered or _playing_replay or _replay_aftermath: return
	if _hotseat() and session.required_seat() != session.active_seat: return
	super._show_economy()
func _tutorial_busy() -> bool:
	return _covered or _playing_replay or _replay_aftermath or _together_view or super._tutorial_busy()
func _tutorial_consider() -> void:
	if not _hotseat(): super._tutorial_consider()
func _process(delta: float) -> void:
	if _covered: return
	super._process(delta)
func _can_save() -> bool:
	return not _covered and not _playing_replay and not _replay_aftermath and super._can_save()
func _playtime_mode() -> String:
	if _covered: return "excluded"
	return super._playtime_mode()

func _refresh(presented: Dictionary = {}) -> void:
	if not _hotseat():
		super._refresh(presented)
		if _seat_label != null: _seat_label.hide()
		return
	var view: Dictionary = session.board_view() if presented.is_empty() else presented.duplicate(true)
	var private_hand_count: int = view.world.hand.size()
	if _together_view or _playing_replay or _replay_aftermath:
		# A public showing never exposes either player's private hand.
		var hand: Array = view.world.hand.duplicate()
		view.world.hand = []
		view.world.entities = view.world.entities.filter(func(e): return e.id not in hand)
	super._refresh(view)
	for relative_seat in [0, 1]:
		var physical: int = HotSession.Perspective.pid(relative_seat, session.active_seat)
		header.scores[relative_seat].text = header.scores[relative_seat].text.replace("YOU ·", "PLAYER %d ·" % (physical + 1)).replace("OPPONENT ·", "PLAYER %d ·" % (physical + 1))
	if view.world.hand.is_empty() and private_hand_count > 0:
		header.scores[0].text = header.scores[0].text.replace("Hand  0", "Hand  %d" % private_hand_count)
	if _seat_label != null:
		_seat_label.show()
		_seat_label.text = "HOTSEAT · PLAYER %d · %s" % [session.active_seat + 1, session.setup_lords[0].to_upper()]
		if _playing_replay or _replay_aftermath: _seat_label.text += " · REPLAY ROUND %d" % session.round_number()

func _complete_job() -> void:
	var operation: String = _job_operation
	super._complete_job()
	if not _hotseat() or _playing_replay or _replay_aftermath: return
	if operation in ["economy_choice", "next_round"] and session.required_seat() != session.active_seat:
		_cover(session.required_seat())
	elif operation == "aftermath":
		reopen_decision()

func _sync_decision() -> void:
	super._sync_decision()
	if not _hotseat() or playing or _job != null: return
	if session.is_finished(): phase_prompt.title_label.text = _winner_heading()
	if _replay_aftermath:
		confirm.text = "MATCH RESULT" if _live_session.is_finished() else "BEGIN MY TURN"
		confirm.disabled = false
	elif session.next_hook().is_empty() and session.is_finished() and session.has_replay(1 - session.active_seat):
		confirm.text = "PASS FOR FINAL REPLAY"
		confirm.disabled = false
	elif session.next_hook().is_empty() and not session.is_finished():
		confirm.text = "READY PLAYER %d · NEXT ROUND" % (session.active_seat + 1) if _together_view else "BEGIN MY NEXT TURN"

func next_round() -> void:
	if not _hotseat():
		super.next_round()
		return
	if _covered or _job != null or playing: return
	if _replay_aftermath:
		session = _live_session
		_live_session = null
		_replay_aftermath = false
		_clear_seat_ui()
		_refresh()
		if session.is_finished(): _open_game_menu()
		else: reopen_decision()
		return
	if session.is_finished():
		if session.has_replay(1 - session.active_seat): _cover(1 - session.active_seat)
		else: _open_game_menu()
		return
	if _together_view:
		_cover(session.active_seat, "next_round")
		return
	super.next_round()

func _begin_saved_replay() -> void:
	var frozen = session.replay_session(session.active_seat)
	if frozen == null:
		_busy_label.text = "Could not load the saved round replay."
		_cover(session.active_seat, "resume")
		return
	var tape: Dictionary = HotSession.Perspective.orient(session.replay.seats[session.active_seat], session.active_seat)
	var movie = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	if not movie.build(tape.marching_events):
		_busy_label.text = "The saved round replay is incomplete."
		_cover(session.active_seat, "resume")
		return
	_live_session = session
	_playing_replay = true
	_clear_seat_ui()
	_ledger_before = tape.before
	_ledger_round = frozen.round_number()
	var feedback: Array = HotFeedback.outside_marching(tape.events.filter(func(e): return e.type in HotFeedback.TYPES and e.data.get("hook", "") != Timeline.MARCHING), tape.presented.world.entities)
	var job = RecordedJob.new()
	job.result = {"action": "board_job_complete", "operation": "marching", "session": frozen, "playback": movie, "presented": tape.presented, "resolution": tape.resolution, "artillery_events": tape.artillery_events, "feedback": feedback, "gem_dagger_events": tape.events.filter(func(e): return e.type in ["GUARD_DEFEATED", "GEM_DAGGER"] and e.data.get("hook", "") != Timeline.MARCHING), "worker_ms": 0.0}
	_job = job
	_job_operation = "marching"
	_complete_job()

func _start_job(operation: String, powers: Array = [], order: Dictionary = {}) -> void:
	if _playing_replay and operation == "aftermath":
		_playing_replay = false
		_replay_aftermath = true
		_live_session.replay.seen[_live_session.active_seat] = true
		_refresh()
		reopen_decision()
		return
	super._start_job(operation, powers, order)

func _load_game(path: String) -> void:
	var previous = session
	super._load_game(path)
	if session == previous: return
	_covered = false
	_privacy.hide()
	_together_view = false
	if not _hotseat(): return
	_playing_replay = false
	_replay_aftermath = false
	_live_session = null
	_together_view = session.watch_mode == "together" and session.next_hook().is_empty()
	setup_picker.play_mode.select(1)
	setup_picker.replay_mode.select(1 if session.watch_mode == "together" else 0)
	setup_picker._hotseat_mode_changed()
	_cover(session.active_seat, "resume")

func _session_from_save(raw: Dictionary):
	return HotSession.new() if raw.get("version") == HotSession.HOTSEAT_VERSION else super._session_from_save(raw)

func restart() -> void:
	if _playing_replay or _replay_aftermath or _covered: return
	super.restart()
	if _hotseat() and _job == null:
		_together_view = false
		_cover(session.required_seat())


func _confirm_decision() -> void:
	if _covered: return
	if _hotseat() and session.next_hook().is_empty():
		next_round()
		return
	super._confirm_decision()

func reopen_decision() -> void:
	if _covered: return
	super.reopen_decision()
	if _hotseat(): _sync_decision()


func _winner_heading() -> String:
	var outcome: Dictionary = session.game().outcome()
	var winner: int = int(outcome.get("winner", -1))
	if winner not in [0, 1]: return "MATCH COMPLETE"
	var lords: Array = session._owner.canonical.player_view(0, 0).world.lord_ids
	return "PLAYER %d WINS — %s" % [winner + 1, str(lords[winner]).to_upper()]

func _open_game_menu() -> void:
	super._open_game_menu()
	if _hotseat() and session.is_finished() and game_menu.visible:
		for child in game_menu.column.get_children():
			if child is Label:
				child.text = _winner_heading()
				break

func open_setup() -> void:
	super.open_setup()
	if _hotseat() and setup_open:
		var world: Dictionary = session._owner.canonical.player_view(0, 0).world
		setup_picker.present(world.lord_ids, world.castle_loadouts, false, match_started)

func _sync_flow() -> void:
	super._sync_flow()
	if _hotseat() and _planning() and _flow_title() == "Dominion Rites":
		var label: String = "COMMIT & PASS" if session.active_seat == session.first_planner else "COMMIT & WATCH"
		confirm.text = label
		pass_button.text = "NO RITES · " + label
