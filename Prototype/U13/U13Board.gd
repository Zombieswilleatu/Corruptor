extends Control

const PhasePrompt = preload("res://Prototype/U13/U13PhasePrompt.gd")
const ActionZone = preload("res://Prototype/U13/U13ActionZone.gd")
const Session = preload("res://Scripts/Sim/U13BoardSession.gd")
const LoadoutSession = preload("res://Scripts/Sim/U13LoadoutBoardSession.gd")
const LoadoutPicker = preload("res://Prototype/U13/U13LoadoutPicker.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const Humbaba = preload("res://Scripts/Sim/U13Humbaba.gd")
const Kalligan = preload("res://Scripts/Sim/U13Kalligan.gd")
const ScorchView = preload("res://Prototype/U13/U13ScorchPresentation.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const BoardJob = preload("res://Prototype/U13/U13BoardJob.gd")
const DenseSession = preload("res://Scripts/Sim/U13DenseBoardSession.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const Lanes = preload("res://Prototype/U13/U13BoardLanes.gd")
const DomainRow = preload("res://Prototype/U13/U13PlayerBoard.gd")
const Header = preload("res://Prototype/U13/U13BoardHeader.gd")
const Hand = preload("res://Prototype/U13/U13BoardHand.gd")
const Art = preload("res://Prototype/U13/U13BoardTextures.gd")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")


class CardFace:
	extends RefCounted
	var id: String
	var suit: String
	var value: int

	func _init(entity: Dictionary) -> void:
		id = entity.id
		suit = entity.attributes.suit
		value = int(entity.attributes.value)

	func card_id() -> String:
		return id


var setup_enabled: bool = true
var setup_open: bool = false
var match_started: bool = false
var setup_picker
var setup_hand_selection: Array = []
var setup_button: Button
var castle_plan: Dictionary = {}
var castle_box: VBoxContainer
var castle_action_choice: OptionButton
var castle_target: OptionButton
var castle_token: CheckBox
var castle_note: Label
var castle_stage: Button
var gremory_box: VBoxContainer
var deimos_box: VBoxContainer
var kalligan_box: VBoxContainer
var kalligan_buttons: Dictionary = {}
var kalligan_states: Dictionary = {}
var inferno_target: OptionButton
var _scorch_rows: Array = []
var humbaba_box: VBoxContainer
var humbaba_buttons: Dictionary = {}
var humbaba_states: Dictionary = {}
var humbaba_lanes: Dictionary = {}
var engine_choice: OptionButton
var rout_lane: OptionButton
var war_button: Button
var rout_button: Button
var war_state: Label
var rout_state: Label
var session = Session.new()
const ArtilleryView = preload("res://Prototype/U13/U13ArtilleryView.gd")
const GemDaggerView = preload("res://Prototype/U13/U13GemDaggerView.gd")
var gem_dagger_view
var _gem_final_view: Dictionary = {}
var artillery_view
var _artillery_final_castles: Dictionary = {}
var playback = Playback.new()
var dense_mode: bool = false
var dense_button: Button
var _job = null
var _job_operation: String = ""
var _restart_pending: bool = false
var _quit_pending: bool = false
var _continue_dense: bool = false
var _busy_label: Label
var _busy_clock: float = 0.0
var _impact_rows: Array = []
var _impact_cursor: int = 0
var _impact_clock: float = 0.0
var _impact_duration: float = 0.0
var _feedback_cursor: int = 0
var _previous_frame_us: int = 0
var playing: bool = false
var clock: float = 0.0
var queued: Array = []
var payment: Array = []
var hand_view
var lanes
var sides: Array = []
var status: Label
var summary: Label
var header
var history_panel: PanelContainer
var plan_label: Label
var action_choice: OptionButton
var lane_choice: OptionButton
var target_choice: OptionButton
var ruin_target: OptionButton
var power_lane: OptionButton
var confirm: Button
var next_button: Button
var controls: Array = []
var phase_prompt
var action_zone
var pass_button: Button
var decision_button: Button
var history: RichTextLabel
var _runtime_ok: bool = false
var powers_step: bool = false
var staged_order: Dictionary = {}
var powers_box: VBoxContainer
var predator_button: Button
var ruin_button: Button
var predator_state: Label
var ruin_state: Label


func _ready() -> void:
	dense_mode = dense_mode or OS.get_cmdline_user_args().has("--dense")
	if dense_mode:
		session = DenseSession.new()
	var version: Dictionary = Engine.get_version_info()
	_runtime_ok = (
		int(version.major) == 4
		and int(version.minor) == 7
		and int(version.patch) == 2
		and String(version.status) == "stable"
	)
	get_tree().auto_accept_quit = false
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(1440, 810)
	_build()
	if _runtime_ok:
		if setup_enabled and not dense_mode:
			open_setup()
		else:
			restart()
	else:
		status.text = "U13 requires Godot 4.7.2 stable."
		confirm.disabled = true
		next_button.disabled = true


func restart() -> void:
	if setup_open:
		return
	if _job != null:
		_restart_pending = true
		_continue_dense = false
		return
	if not _runtime_ok:
		return
	playing = false
	artillery_view.clear()
	gem_dagger_view.clear()
	_gem_final_view = {}
	_artillery_final_castles = {}
	castle_plan = {}
	clock = 0
	queued = []
	payment = []
	powers_step = false
	staged_order = {}
	var result: Dictionary = session.reset()
	if _error(result):
		return
	_install_impacts([])
	lanes.reset_effects()
	match_started = true
	for row in sides:
		row._castle_art_states.clear()
	action_choice.select(0)
	_refresh()
	reopen_decision()


func _build() -> void:
	gem_dagger_view = GemDaggerView.new()
	add_child(gem_dagger_view)
	gem_dagger_view.impact.connect(_gem_dagger_impact)
	artillery_view = ArtilleryView.new()
	add_child(artillery_view)
	artillery_view.impact.connect(_artillery_impact)
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 8)
	add_child(margin)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)
	margin.add_child(main)
	header = Header.new()
	main.add_child(header)
	summary = header.round_label
	decision_button = _button(header.tools_box, "DECISION", reopen_decision)
	if dense_mode:
		dense_button = _button(header.tools_box, "Run dense round", run_dense_round)
		decision_button.hide()
	if setup_enabled and not dense_mode:
		setup_button = _button(header.tools_box, "New loadout", open_setup)
	_button(header.tools_box, "Restart", restart)
	_button(header.tools_box, "Exit", request_exit)
	_button(
		header.history_box, "HISTORY", func(): history_panel.visible = not history_panel.visible
	)
	var body := HBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body)
	var center := VBoxContainer.new()
	center.name = "Center"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 5)
	body.add_child(center)
	var stack := VBoxContainer.new()
	stack.name = "BoardStack"
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 6)
	center.add_child(stack)
	var enemy = DomainRow.new()
	enemy.name = "EnemyPlayerBoard"
	stack.add_child(enemy)
	enemy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy.target_selected.connect(_board_target_selected)
	sides.append(enemy)
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	stack.add_child(gap)
	var own = DomainRow.new()
	own.name = "HumanPlayerBoard"
	own.castle_guards_above_castles = true
	stack.add_child(own)
	own.size_flags_vertical = Control.SIZE_EXPAND_FILL
	own.target_selected.connect(_board_target_selected)
	sides.append(own)
	lanes = Lanes.new()
	lanes.name = "MarchingBattlefield"
	lanes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(lanes)
	action_zone = ActionZone.new()
	add_child(action_zone)
	action_zone.configure_u13()
	phase_prompt = PhasePrompt.new()
	add_child(phase_prompt)
	phase_prompt.attach_action_zone(action_zone)
	var decisions: VBoxContainer = action_zone.get_node("ActionScroll/ActionContents")
	# Backing selection retained for existing board/test callers; UI uses buttons.
	action_choice = _option(decisions, ["Pass", "Siege", "Ward"])
	action_choice.hide()
	lane_choice = action_zone.secondary_select
	lane_choice.add_item("Castle")
	lane_choice.add_item("Lord")
	target_choice = action_zone.primary_select
	controls.append(lane_choice)
	controls.append(target_choice)
	for button in action_zone.action_buttons.values():
		controls.append(button)
	action_zone.action_selected.connect(_select_action)
	action_zone.target_changed.connect(func(_target): _preview())
	confirm = action_zone.confirm_button
	pass_button = action_zone.pass_button
	action_zone.confirm_requested.connect(_confirm_decision)
	action_zone.pass_requested.connect(pass_round)
	_build_castle_controls(decisions)
	var powers := VBoxContainer.new()
	powers_box = powers
	decisions.add_child(powers)
	gremory_box = VBoxContainer.new()
	powers.add_child(gremory_box)
	var predator_section := VBoxContainer.new()
	predator_section.name = "PredatorOfRuinSection"
	predator_section.add_theme_constant_override("separation", 6)
	gremory_box.add_child(predator_section)
	_label(predator_section, "PREDATOR OF RUIN", 17)
	_label(predator_section, "Summon 3 Vultures", 13)
	predator_state = _label(predator_section, "", 13)
	predator_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(predator_section, "Spawn lane", 12)
	power_lane = _option(predator_section, ["Castle", "Lord"])
	predator_button = _button(predator_section, "Queue Predator of Ruin", queue_predator)
	controls.append(predator_button)
	gremory_box.add_child(HSeparator.new())
	var ruin_section := VBoxContainer.new()
	ruin_section.name = "InevitableRuinSection"
	ruin_section.add_theme_constant_override("separation", 6)
	gremory_box.add_child(ruin_section)
	_label(ruin_section, "INEVITABLE RUIN", 17)
	ruin_state = _label(ruin_section, "", 13)
	ruin_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(ruin_section, "Enemy Castle target", 12)
	ruin_target = _option(ruin_section, [])
	ruin_button = _button(ruin_section, "Queue Ruin · reserve 2 selected", queue_ruin)
	controls.append(ruin_button)
	powers.add_child(HSeparator.new())
	_build_deimos_controls(powers)
	_build_humbaba_controls(powers)
	_build_kalligan_controls(powers)
	_button(powers, "Back to combat · clear powers", back_to_combat)
	controls.append(_button(powers, "Clear powers · return cards", clear_powers))
	plan_label = _label(powers, "", 15)
	plan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status = action_zone.status_label
	status.reparent(phase_prompt)
	status.position = Vector2(36, 401)
	status.size = Vector2(328, 49)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 12)
	status.clip_contents = true
	if dense_mode:
		status.reparent(main)
		status.custom_minimum_size.y = 30
		status.add_theme_font_size_override("font_size", 14)
	var navigation := HBoxContainer.new()
	header.history_box.add_child(navigation)
	next_button = _button(navigation, "Next round", next_round)
	next_button.hide()
	_button(navigation, "Skip animation", finish_playback)
	hand_view = Hand.new()
	center.add_child(hand_view)
	hand_view.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	hand_view.selection_changed.connect(_hand_selection_changed)
	history_panel = PanelContainer.new()
	history_panel.name = "HistoryOverlay"
	history_panel.z_index = 80
	history_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	history_panel.position = Vector2(850, 200)
	history_panel.size = Vector2(620, 480)
	add_child(history_panel)
	var history_column := VBoxContainer.new()
	history_panel.add_child(history_column)
	_button(history_column, "CLOSE HISTORY", func(): history_panel.hide())
	history = RichTextLabel.new()
	history.custom_minimum_size = Vector2(600, 400)
	history.scroll_following = true
	history_column.add_child(history)
	history_panel.hide()
	_busy_label = _label(main, "", 16)
	_busy_label.custom_minimum_size.y = 26
	if setup_enabled and not dense_mode:
		setup_picker = LoadoutPicker.new()
		add_child(setup_picker)
		setup_picker.hide()
		setup_picker.start_requested.connect(start_loadout)
		setup_picker.cancelled.connect(close_setup)


func _refresh(presented: Dictionary = {}) -> void:
	var view: Dictionary = session.board_view() if presented.is_empty() else presented
	var world: Dictionary = view.world
	lanes.bind_auras(view.get("persistent", []), session.round_number())
	lanes.bind_webs(view.get("persistent", []))
	_scorch_rows = ScorchView.records(
		view.get("persistent", []), view.get("pending", []), session.round_number()
	)
	lanes.bind_scorch(_scorch_rows)
	header.bind_world(world, session.round_number())
	_render_side(sides[0], world, 1)
	_render_side(sides[1], world, 0)
	sides[0].bind_cooldowns(view, 1)
	sides[1].bind_cooldowns(view, 0)
	sides[0].bind_scorch(_scorch_rows, 1)
	sides[1].bind_scorch(_scorch_rows, 0)
	if not playing:
		lanes.show_world(world.entities, session.round_number())
	var cards: Array = []
	for id in world.hand:
		if _hand_reserved(id):
			continue
		for entity in world.entities:
			if entity.id == id:
				cards.append(CardFace.new(entity))
	hand_view.bind_player({"hand": cards}, _planning())
	# Stable physical IDs stay in metadata, never replace printed card faces.
	for button in hand_view.card_buttons:
		button.tooltip_text = (
			"%s %d — click to select"
			% [button.get_meta("card_suit"), button.get_meta("card_value")]
		)
	_refresh_castle_targets(world)
	history.text = ""
	for event in view.events.slice(maxi(0, view.events.size() - 15)):
		var text_value: String = String(event.get("text", ""))
		history.append_text(
			(
				(text_value if not text_value.is_empty() else String(event.type).replace("_", " "))
				+ "\n"
			)
		)
	for control in controls:
		control.disabled = not _planning()
	ruin_target.disabled = ruin_target.item_count == 0 or not _planning()
	next_button.disabled = playing or gem_dagger_view.active() or not session.next_hook().is_empty()
	_preview()
	_sync_decision()


func _render_side(row, world: Dictionary, pid: int) -> void:
	row.bind_world(world, pid, _planning())


func _board_target_selected(action: String, lane: String, target_id: String) -> void:
	if not _planning() or powers_step:
		return
	_select_action(action)
	lane_choice.select(0 if lane == "Castle" else 1)
	if action == "Siege":
		for index in range(target_choice.item_count):
			if target_choice.get_item_metadata(index) == target_id:
				target_choice.select(index)
	_preview()
	reopen_decision()


func _planning() -> bool:
	return (
		_runtime_ok
		and not setup_open
		and match_started
		and _job == null
		and not playing
		and (gem_dagger_view == null or not gem_dagger_view.active())
		and session.next_hook() == Timeline.SUBMISSION_LOCK
	)


func _order() -> Dictionary:
	if powers_step:
		return staged_order.duplicate(true)
	var action: String = action_choice.get_item_text(action_choice.selected)
	if action == "Pass":
		return {} if castle_plan.is_empty() else {"castle_action": castle_plan.duplicate(true)}
	var result: Dictionary = {
		"action": action,
		"lane": "Castle" if action == "Siege" else lane_choice.get_item_text(lane_choice.selected),
		"card_ids": hand_view.selected_card_ids()
	}
	if action == "Siege":
		result["target_id"] = (
			""
			if target_choice.item_count == 0
			else target_choice.get_item_metadata(target_choice.selected)
		)
	if not castle_plan.is_empty():
		result["castle_action"] = castle_plan.duplicate(true)
	return result


func _preview() -> void:
	if status == null or hand_view == null:
		return
	var names: Array[String] = []
	for source in queued:
		names.append(_power_name(source.power_id))
	plan_label.text = (
		"Powers: %s     Reserved for Ruin: %d cards"
		% ["None" if names.is_empty() else ", ".join(names), payment.size()]
	)
	if not castle_plan.is_empty():
		for entity in session.board_view().world.entities:
			if entity.id == castle_plan.target_id:
				plan_label.text += (
					"\nCastle: %s · %s · %d cards"
					% [
						"Commission" if castle_plan.action == "Activate" else castle_plan.action,
						_castle_name(entity),
						castle_plan.card_ids.size()
					]
				)
	if not _planning():
		confirm.disabled = true
		return
	var name: String = {0: "Powers Only", 1: "Siege", 2: "Ward", 3: "Hunt"}[action_choice.selected]
	for key in action_zone.action_buttons:
		action_zone.action_buttons[key].set_pressed_no_signal(key == name)
	lane_choice.visible = not powers_step and action_choice.selected == 2
	target_choice.visible = not powers_step and action_choice.selected == 1
	action_zone.primary_label.visible = target_choice.visible
	action_zone.primary_label.text = "Enemy Castle"
	action_zone.secondary_label.visible = lane_choice.visible
	action_zone.secondary_label.text = "Defend lane"
	lane_choice.disabled = action_choice.selected != 2
	target_choice.disabled = action_choice.selected != 1
	var result: Dictionary = session.choose(queued, _order())
	confirm.disabled = result.action == "invalid"
	status.text = (
		"Orders selected. Next opens Lord powers without advancing the round."
		if not confirm.disabled
		else _friendly_error(result)
	)

	if not confirm.disabled and action_choice.selected == 0:
		status.text = "No combat selected. Continue to Lord powers."
	if action_choice.selected == 1 and target_choice.item_count == 0:
		status.text = "No enemy Castle remains. Choose Ward or Skip Combat."
	action_zone.action_buttons["Siege"].disabled = target_choice.item_count == 0
	_update_power_controls()
	_update_castle_controls()
	_update_decision_copy()


func queue_predator() -> void:
	if not _planning() or not powers_step or _queued_power(Gremory.PREDATOR):
		return
	var source: Dictionary = session.declaration(
		Gremory.PREDATOR, queued.size(), {"lane": power_lane.get_item_text(power_lane.selected)}
	)
	var candidate: Array = queued.duplicate(true)
	candidate.append(source)
	if _error(session.choose(candidate, _order())):
		return
	queued = candidate
	_preview()


func queue_ruin() -> void:
	if not _planning() or not powers_step or _queued_power(Gremory.RUIN):
		return
	if ruin_target.item_count == 0:
		status.text = "Ruin needs a damaged, standing enemy Castle. Defunct Castles are already ruined."
		return
	var selected: Array = hand_view.selected_card_ids()
	if selected.size() != 2:
		status.text = "Select exactly two cards to discard for Inevitable Ruin."
		return
	var source: Dictionary = session.declaration(
		Gremory.RUIN,
		queued.size(),
		{"entity_id": ruin_target.get_item_metadata(ruin_target.selected)},
		{"discard_ids": selected}
	)
	var candidate: Array = queued.duplicate(true)
	candidate.append(source)
	# Reserving payment removes these cards from the combat selection.
	if _error(session.choose(candidate, _order())):
		return
	queued = candidate
	payment.append_array(selected)
	_refresh()


func clear_powers() -> void:
	if not _planning():
		return
	queued = []
	payment = []
	_refresh()


func run_dense_round() -> void:
	if not dense_mode or playing or _job != null or not _runtime_ok:
		return
	if session.next_hook().is_empty():
		_continue_dense = true
		next_round()
		return
	if not _planning():
		return
	queued = []
	payment = []
	powers_step = false
	staged_order = {}
	castle_plan = {}
	action_choice.select(0)
	hand_view.clear_selection()
	resolve_round()


func resolve_round() -> void:
	if not _planning():
		return
	_start_job("marching", queued, _order())


func _start_job(operation: String, powers: Array = [], order: Dictionary = {}) -> void:
	if _job != null:
		return
	var started: int = Time.get_ticks_usec()
	var job = BoardJob.new()
	var result: Dictionary = job.start(session, operation, powers, order)
	if _error(result):
		_continue_dense = false
		return
	_job = job
	_job_operation = operation
	_busy_clock = 0.0
	phase_prompt.set_presenting(false)
	confirm.disabled = true
	pass_button.disabled = true
	next_button.disabled = true
	decision_button.disabled = true
	if dense_button != null:
		dense_button.disabled = true
	# Leave the rendered board intact. The worker owns no Nodes or textures.
	_busy_label.text = "Preparing round…"
	print(
		(
			"U13 BOARD prepare_submit_ms=%.3f operation=%s"
			% [float(Time.get_ticks_usec() - started) / 1000.0, operation]
		)
	)


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _previous_frame_us > 0 and now - _previous_frame_us > 100000:
		print(
			(
				"U13 BOARD frame_gap_ms=%.3f state=%s"
				% [
					float(now - _previous_frame_us) / 1000.0,
					_job_operation if _job != null else ("playback" if playing else "idle")
				]
			)
		)
	_previous_frame_us = now
	if _job != null:
		_busy_clock += maxf(delta, 0.0)
		_busy_label.text = (
			(
				"Closing"
				if _quit_pending
				else ("Restarting" if _restart_pending else "Preparing round")
			)
			+ ".".repeat(1 + int(_busy_clock * 3.0) % 3)
		)
		if _job.ready():
			_complete_job()
		return
	if not playing:
		if gem_dagger_view.advance(delta):
			_busy_label.text = "Gem Dagger…"
			return
		_finish_gem_presentation()
		_advance_impacts(delta)
		return
	if artillery_view.advance(delta):
		_busy_label.text = "Siege Engine fire…"
		return
	_restore_artillery_castles()
	if gem_dagger_view.advance(delta):
		_busy_label.text = "Gem Dagger…"
		return
	_finish_gem_presentation()
	if _advance_impacts(delta):
		_busy_label.text = "Scorch pulse…"
		return
	_busy_label.text = ""
	clock = minf(playback.duration, clock + maxf(delta, 0.0))
	lanes.show_frame(playback.sample(clock), session.round_number())
	var changes: Dictionary = playback.feedback_through(clock, _feedback_cursor)
	_feedback_cursor = int(changes.cursor)
	lanes.show_feedback(changes.rows)
	if clock >= playback.duration:
		finish_playback(false)


func _complete_job() -> void:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = _job.take()
	_job = null
	_job_operation = ""
	_busy_label.text = ""
	if _quit_pending:
		get_tree().quit()
		return
	if _restart_pending:
		_restart_pending = false
		restart()
		return
	if result.action == "invalid":
		_continue_dense = false
		_refresh()
		_error(result)
		return
	# Publish only a complete successful transaction; failures leave session intact.
	session = result.session
	gem_dagger_view.play_events(result.get("gem_dagger_events", []), sides)
	_gem_final_view = result.presented.duplicate(true) if gem_dagger_view.active() else {}
	_install_impacts(result.get("feedback", []))
	if result.operation == "marching":
		_feedback_cursor = 0
		playback = result.playback
		clock = 0.0
		playing = true
		artillery_view.play_shots(result.get("artillery_events", []), sides)
		var initial: Dictionary = artillery_view.initial_castles()
		var shown: Dictionary = gem_dagger_view.mask_view(result.presented)
		_artillery_final_castles = {}
		for entity in shown.world.entities:
			if initial.has(entity.id):
				_artillery_final_castles[entity.id] = entity.attributes.duplicate(true)
				entity.attributes = initial[entity.id]
		_refresh(shown)
		lanes.show_frame(playback.sample(0), session.round_number())
	elif result.operation == "aftermath":
		_refresh(gem_dagger_view.mask_view(result.presented))
		status.text = "Round resolved. Next round continues; Restart restores the opening."
	else:
		queued = []
		payment = []
		powers_step = false
		staged_order = {}
		castle_plan = {}
		action_choice.select(0)
		_refresh(gem_dagger_view.mask_view(result.presented))
	print(
		(
			"U13 BOARD worker_ms=%.3f install_ms=%.3f operation=%s"
			% [result.worker_ms, float(Time.get_ticks_usec() - started) / 1000.0, result.operation]
		)
	)
	if _continue_dense:
		_continue_dense = false
		run_dense_round()


func _artillery_impact(shot: Dictionary) -> void:
	if shot.get("target_after", {}).is_empty():
		return
	for side in sides:
		side.update_castle_presentation(shot.target_id, shot.target_after)


func _restore_artillery_castles() -> void:
	if _artillery_final_castles.is_empty():
		return
	# Later combat/powers may also change the same Castle. Apply that completed
	# phase state after the shot tape, without recreating board rows or Hand.
	for id in _artillery_final_castles:
		for side in sides:
			side.update_castle_presentation(id, _artillery_final_castles[id])
	_artillery_final_castles = {}


func finish_playback(skipped: bool = true) -> void:
	if _job != null:
		return
	if not playing:
		gem_dagger_view.clear()
		_finish_gem_presentation()
		return
	_restore_artillery_castles()
	gem_dagger_view.clear()
	_finish_gem_presentation()
	artillery_view.clear()
	_artillery_final_castles = {}
	_install_impacts([])
	if skipped:
		lanes.clear_feedback()
	# Skip goes to the actual final picture, never leaves a half-played field.
	clock = playback.duration
	lanes.show_frame(playback.sample(clock), session.round_number())
	playing = false
	_start_job("aftermath")


func next_round() -> void:
	if playing or gem_dagger_view.active() or _job != null or not session.next_hook().is_empty():
		return
	_start_job("next_round")


func request_exit() -> void:
	if _job != null:
		_quit_pending = true
		return
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_exit()


func _exit_tree() -> void:
	if _job != null:
		_job.join_on_exit()
		_job = null


func _select_action(action: String) -> void:
	if not _planning() or powers_step:
		return
	action_choice.select({"Siege": 1, "Ward": 2, "Powers Only": 0}[action])
	_preview()


func _confirm_decision() -> void:
	if _job != null:
		return
	if session.next_hook().is_empty():
		next_round()
	elif not powers_step:
		enter_powers()
	else:
		resolve_round()


func enter_powers() -> void:
	if not _planning() or powers_step:
		return
	var order: Dictionary = _order()
	if _error(session.choose([], order)):
		return
	staged_order = order.duplicate(true)
	powers_step = true
	hand_view.clear_selection()
	_refresh()
	reopen_decision()


func back_to_combat() -> void:
	if not _planning() or not powers_step:
		return
	var selected: Array = staged_order.get("card_ids", []).duplicate()
	powers_step = false
	staged_order = {}
	queued = []
	payment = []
	_refresh()
	for id in selected:
		hand_view.select_card_id(id)
	_preview()


func pass_round() -> void:
	if not _planning():
		return
	queued = []
	payment = []
	if not powers_step:
		action_choice.select(0)
		hand_view.clear_selection()
		enter_powers()
	else:
		# Skip powers only; the combat order from the first prompt is preserved.
		resolve_round()


func reopen_decision() -> void:
	if dense_mode or setup_open or _job != null:
		return
	if playing or gem_dagger_view.active() or phase_prompt == null:
		return
	phase_prompt.board_view_collapsed = false
	phase_prompt.set_presenting(true)
	phase_prompt._refresh_mode()


func _update_decision_copy() -> void:
	if not _planning():
		return
	action_zone.action_box.visible = not powers_step
	castle_box.visible = not powers_step and session is LoadoutSession
	powers_box.visible = powers_step
	gremory_box.visible = _human_lord() == "Gremory"
	deimos_box.visible = _human_lord() == "Deimos"
	humbaba_box.visible = _human_lord() == "Humbaba"
	kalligan_box.visible = _human_lord() == "Kalligan"
	if powers_step:
		(
			phase_prompt
			. bind_decision(
				"LORD_POWERS",
				"LORD POWERS",
				"Your orders are staged. Choose optional powers with remaining cards, then resolve together.",
				"ROUND %d" % session.round_number()
			)
		)
	else:
		(
			phase_prompt
			. bind_decision(
				"COMMITMENT",
				"COMBAT",
				(
					"Stage an optional Castle action, then select combat cards. Next opens Lord powers without advancing."
					if session is LoadoutSession
					else "Choose combat and select cards. Next opens Lord powers; the round has not advanced."
				),
				"ROUND %d" % session.round_number()
			)
		)
	confirm.text = "RESOLVE ROUND" if powers_step else "NEXT · LORD POWERS"
	pass_button.text = "NO POWERS" if powers_step else "SKIP COMBAT"
	pass_button.tooltip_text = (
		"Clear queued powers and resolve your staged orders."
		if powers_step
		else "Skip combat, keep your Castle action, and continue to Lord powers."
	)


func _queued_power(power: String) -> bool:
	for source in queued:
		if source.power_id == power:
			return true
	return false


func _update_power_controls() -> void:
	for power in [Gremory.PREDATOR, Gremory.RUIN] if _human_lord() == "Gremory" else []:
		var state: Dictionary = session.power_status(power)
		var label: Label = predator_state if power == Gremory.PREDATOR else ruin_state
		var button: Button = predator_button if power == Gremory.PREDATOR else ruin_button
		var queued_now: bool = _queued_power(power)
		label.text = "Queued · not spent yet" if queued_now else "Ready · cooldown 0"
		if not queued_now and state.remaining > 0:
			label.text = "Cooldown %d · ready round %d" % [state.remaining, state.ready_round]
		if state.fire_round > 0:
			label.text += "\nArmed · fires at start of round %d" % state.fire_round
		if power == Gremory.RUIN:
			label.text += (
				"\nDiscard 2 · damaged enemy Castle\nFires next round (%d), making it defunct."
				% (session.round_number() + 1)
			)
			if ruin_target.item_count == 0:
				label.text += "\nNo eligible enemy Castle."
			if not queued_now and hand_view.card_buttons.size() < 2:
				label.text += (
					"\nNot enough uncommitted cards: %d/2." % hand_view.card_buttons.size()
				)
		else:
			label.text += "\nFree · cooldown after use: 1 round"
		button.disabled = (
			not _planning()
			or not powers_step
			or queued_now
			or state.remaining > 0
			or (
				power == Gremory.RUIN
				and (ruin_target.item_count == 0 or hand_view.card_buttons.size() < 2)
			)
		)
	_update_deimos_controls()
	_update_humbaba_controls()
	_update_kalligan_controls()
	if powers_step and not confirm.disabled:
		status.text = (
			"Combat: %s · %d cards. Powers: %d queued. Resolve submits all orders together."
			% [
				staged_order.get("action", "Skipped"),
				staged_order.get("card_ids", []).size(),
				queued.size()
			]
		)


func _pending_notice() -> String:
	var state: Dictionary = session.power_status(Gremory.RUIN)
	if state.fire_round > 0:
		return "Inevitable Ruin is armed for the start of round %d." % state.fire_round
	return "View Board to inspect the result."


func _sync_decision() -> void:
	if dense_mode:
		phase_prompt.set_presenting(false)
		next_button.hide()
		dense_button.disabled = playing or not _runtime_ok
		dense_button.text = (
			"Next dense round" if session.next_hook().is_empty() else "Run dense round"
		)
		status.text = "Dense field: 48 Marchers at start · 24 per side · Castle lane. Click Run dense round."
		return
	decision_button.disabled = playing or gem_dagger_view.active()
	next_button.hide()
	if playing or gem_dagger_view.active():
		phase_prompt.set_presenting(false)
		return
	if session.next_hook().is_empty():
		phase_prompt.bind_decision(
			"AFTERMATH",
			"AFTERMATH",
			"The round has resolved. " + _pending_notice() + " Begin the next round to continue.",
			"ROUND %d" % session.round_number()
		)
		action_zone.hide()
		confirm.show()
		confirm.disabled = false
		confirm.text = "NEXT ROUND"
		pass_button.hide()
	else:
		action_zone.show()
		confirm.text = "CONFIRM"
		pass_button.show()
		pass_button.disabled = not _planning()
		_update_decision_copy()
	phase_prompt.call_deferred("_sync_decision_bottom_actions_v12")


func _friendly_error(result: Dictionary) -> String:
	var reason: String = result.get("reason", "")
	if reason == "castle_not_enemy":
		return "Inevitable Ruin must target an enemy Castle."
	if reason == "castle_not_damaged":
		return "Ruin requires a damaged enemy Castle before this round resolves."
	if reason == "power_not_ready" or reason.contains("cooldown"):
		return "That power is still cooling down. Choose another power or pass."
	if reason in ["combat_order_invalid", "combat_order_shape_invalid"]:
		return "Hunt and Siege require at least one committed card and a valid enemy target. Ward can use zero cards; Skip Combat passes."
	if reason == "castle_not_ready_to_activate":
		return "Commission needs a protected Castle with at least 7 Integrity."
	if reason == "castle_not_under_construction":
		return "Choose an unfinished Castle. Commissioned Castles use Repair."
	if reason.contains("repair_lock"):
		return "Repair is locked this round after damage took this Castle below 7."
	if reason.contains("castle_payment") or reason.contains("repair_payment"):
		return "Select available hand cards for this Castle action."
	if reason == "activation_does_not_accept_payment":
		return "Commission uses no cards or Repair token."
	if reason.contains("discard") or reason.contains("cost") or reason.contains("payment"):
		return "Ruin needs two available cards, separate from cards committed to combat."
	return "That choice is unavailable: " + reason.replace("_", " ")


func _error(result: Dictionary) -> bool:
	if result.action != "invalid":
		return false
	status.text = _friendly_error(result)
	reopen_decision()
	return true


func _label(parent: Node, text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _option(parent: Node, entries: Array) -> OptionButton:
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	option.clip_text = true
	for entry in entries:
		option.add_item(entry)
	parent.add_child(option)
	controls.append(option)
	return option


func _picture(parent: Node, texture: Texture2D, dimensions: Vector2) -> void:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.custom_minimum_size = dimensions
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(picture)


func open_setup() -> void:
	if (
		not _runtime_ok
		or _job != null
		or playing
		or gem_dagger_view.active()
		or setup_picker == null
	):
		return
	setup_hand_selection = hand_view.selected_card_ids()
	setup_open = true
	phase_prompt.set_presenting(false)
	history_panel.hide()
	var draft = session if session is LoadoutSession else LoadoutSession.new()
	setup_picker.present(draft.setup_lords, draft.setup_castles, draft.quick_start, match_started)


func close_setup() -> void:
	if not match_started:
		return
	setup_open = false
	setup_picker.hide()
	_refresh()
	for id in setup_hand_selection:
		hand_view.select_card_id(id)
	_preview()
	reopen_decision()


func start_loadout(lords: Array, castles: Array, quick: bool) -> void:
	if not setup_open or _job != null:
		return
	var candidate = _new_loadout_session()
	var result: Dictionary = candidate.configure(lords, castles, quick)
	if result.action == "invalid":
		setup_picker.message.text = _friendly_error(result)
		return
	session = candidate
	gem_dagger_view.clear()
	_gem_final_view = {}
	_install_impacts([])
	lanes.reset_effects()
	match_started = true
	setup_open = false
	setup_picker.hide()
	queued = []
	payment = []
	castle_plan = {}
	staged_order = {}
	powers_step = false
	playing = false
	clock = 0.0
	for row in sides:
		row._castle_art_states.clear()
	action_choice.select(0)
	_refresh()
	reopen_decision()


func _human_lord() -> String:
	return session.setup_lords[0] if session is LoadoutSession else "Gremory"


func _power_name(power: String) -> String:
	return (
		{
			Gremory.PREDATOR: "Predator of Ruin",
			Gremory.RUIN: "Inevitable Ruin",
			Deimos.WAR_MACHINE: "War Machine",
			Deimos.ROUT: "Rout",
			Humbaba.MUSTER: "Muster the Faithful",
			Humbaba.BREATH: "Breath of Life",
			Kalligan.INFERNO: "Inferno",
			Kalligan.PYROCLASM: "Pyroclasm"
		}
		. get(power, power)
	)


func _build_castle_controls(parent: Node) -> void:
	castle_box = VBoxContainer.new()
	castle_box.add_theme_constant_override("separation", 6)
	parent.add_child(castle_box)
	_label(castle_box, "CASTLE ACTION · OPTIONAL", 17)
	castle_action_choice = _option(castle_box, ["Construct", "Commission", "Repair"])
	castle_action_choice.item_selected.connect(func(_index): _update_castle_controls())
	castle_target = _option(castle_box, [])
	castle_target.item_selected.connect(func(_index): _update_castle_controls())
	castle_token = CheckBox.new()
	castle_token.text = "Use one Repair token (+3)"
	castle_box.add_child(castle_token)
	controls.append(castle_token)
	castle_note = _label(castle_box, "", 12)
	castle_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	castle_stage = _button(castle_box, "Stage Castle action", stage_castle_action)
	controls.append(castle_stage)
	controls.append(_button(castle_box, "Clear Castle action · return cards", clear_castle_action))
	castle_box.add_child(HSeparator.new())
	castle_box.hide()


func _build_deimos_controls(parent: Node) -> void:
	deimos_box = VBoxContainer.new()
	deimos_box.add_theme_constant_override("separation", 6)
	parent.add_child(deimos_box)
	_label(deimos_box, "WAR MACHINE", 17)
	_label(deimos_box, "One operational Siege Engine fires once more at its retained target.", 13).autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	war_state = _label(deimos_box, "", 13)
	war_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(deimos_box, "Your Siege Engine", 12)
	engine_choice = _option(deimos_box, [])
	war_button = _button(deimos_box, "Queue War Machine", queue_war_machine)
	controls.append(war_button)
	deimos_box.add_child(HSeparator.new())
	_label(deimos_box, "ROUT", 17)
	_label(deimos_box, "Enemy Marchers in this lane retreat this round, then recover at half speed next round.", 13).autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	rout_state = _label(deimos_box, "", 13)
	rout_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(deimos_box, "Enemy lane", 12)
	rout_lane = _option(deimos_box, ["Castle", "Lord"])
	rout_button = _button(deimos_box, "Queue Rout", queue_rout)
	controls.append(rout_button)
	deimos_box.hide()


func _refresh_castle_targets(world: Dictionary) -> void:
	var enemies: Array = []
	var damaged: Array = []
	var own: Array = []
	var engines: Array = []
	for entity in world.entities:
		if entity.kind != "castle":
			continue
		if entity.owner == 0:
			own.append(entity)
			if (
				entity.attributes.get("combat_profile") == "siege_engine"
				and Structures.operational(entity)
			):
				engines.append(entity)
		elif Structures.targetable(entity):
			enemies.append(entity)
			if (
				entity.attributes.status == "standing"
				and entity.attributes.integrity > 0
				and entity.attributes.integrity < entity.attributes.max_integrity
			):
				damaged.append(entity)
	_fill_castles(target_choice, enemies)
	_fill_castles(ruin_target, damaged)
	_fill_castles(castle_target, own)
	_fill_castles(engine_choice, engines)
	ruin_target.tooltip_text = "Inevitable Ruin targets a damaged enemy Castle that has been commissioned."


func _fill_castles(option: OptionButton, entities: Array) -> void:
	var previous: String = (
		"" if option.selected < 0 else String(option.get_item_metadata(option.selected))
	)
	option.clear()
	entities.sort_custom(
		func(a, b):
			return int(a.attributes.get("castle_slot", 0)) < int(b.attributes.get("castle_slot", 0))
	)
	for entity in entities:
		option.add_item(_castle_name(entity))
		var index: int = option.item_count - 1
		option.set_item_metadata(index, entity.id)
		option.set_item_tooltip(index, _castle_name(entity))
		if entity.id == previous:
			option.select(index)


func _castle_name(entity: Dictionary) -> String:
	var a: Dictionary = entity.attributes
	var type: String = (
		String(a.get("castle_type", "Test Castle"))
		. replace("SiegeEngine", "Siege Engine")
		. replace("SummoningCircle", "Summoning Circle")
	)
	var prefix: String = "Slot %d · " % (int(a.castle_slot) + 1) if a.has("castle_slot") else ""
	return "%s%s · %d/%d" % [prefix, type, a.integrity, a.max_integrity]


func stage_castle_action() -> void:
	if (
		not _planning()
		or powers_step
		or not session is LoadoutSession
		or castle_target.selected < 0
	):
		return
	if not castle_plan.is_empty():
		status.text = "Clear the staged Castle action before replacing it."
		return
	var action: String = ["Construct", "Activate", "Repair"][castle_action_choice.selected]
	var choice: Dictionary = {
		"action": action,
		"target_id": castle_target.get_item_metadata(castle_target.selected),
		"card_ids": [] if action == "Activate" else hand_view.selected_card_ids(),
		"use_repair_token": action == "Repair" and castle_token.button_pressed
	}
	# Ask the same owner validator as submission. No second UI rules engine.
	if _error(session.choose([], {"castle_action": choice})):
		return
	castle_plan = choice
	hand_view.clear_selection()
	_refresh()


func clear_castle_action() -> void:
	if not _planning() or powers_step:
		return
	var selected: Array = hand_view.selected_card_ids()
	castle_plan = {}
	_refresh()
	for id in selected:
		hand_view.select_card_id(id)
	_preview()


func _update_castle_controls() -> void:
	if castle_note == null or not _planning() or not session is LoadoutSession:
		return
	var action: String = ["Construct", "Activate", "Repair"][castle_action_choice.selected]
	castle_action_choice.disabled = not castle_plan.is_empty()
	castle_target.disabled = not castle_plan.is_empty()
	castle_token.visible = action == "Repair"
	castle_token.disabled = not castle_plan.is_empty()
	castle_stage.disabled = (
		powers_step or castle_target.item_count == 0 or not castle_plan.is_empty()
	)
	castle_stage.text = (
		"Stage %s" % ["Construct", "Commission", "Repair"][castle_action_choice.selected]
	)
	var explanation: String = {
		"Construct":
		"Select optional payment cards, then Stage. Progress includes +3 passive even with payment. Protected until you Commission.",
		"Activate":
		"Commission at 7+ uses no cards. This copy becomes vulnerable at its current Integrity. This cannot be undone.",
		"Repair":
		"Select payment cards, then Stage. Wrights give printed value; others give value minus 1 (minimum 1). Optional token adds 3."
	}[action]
	var world: Dictionary = session.board_view().world
	for entity in world.entities:
		if (
			castle_target.selected >= 0
			and entity.id == castle_target.get_item_metadata(castle_target.selected)
		):
			var a: Dictionary = entity.attributes
			explanation += (
				"\n%s · %s" % [String(a.get("construction_state", "active")).capitalize(), a.status]
			)
			if int(a.get("repair_lock_until_round", 0)) >= session.round_number():
				explanation += " · Repair locked this round"
	if not castle_plan.is_empty():
		explanation = (
			"STAGED: %s · %d cards. Clear to change.\nNow choose combat using the remaining hand."
			% [
				"Commission" if castle_plan.action == "Activate" else castle_plan.action,
				castle_plan.card_ids.size()
			]
		)
	var automatic: String = ""
	if not String(world.get("construction_target", "")).is_empty():
		for entity in world.entities:
			if entity.id == world.construction_target:
				automatic = "\nUnfinished construction: " + _castle_name(entity)
	castle_note.text = (
		explanation + "\nRepair tokens: %d" % int(world.get("repair_tokens", 0)) + automatic
	)


func queue_war_machine() -> void:
	if engine_choice.selected < 0:
		return
	_queue_deimos(
		Deimos.WAR_MACHINE, {"entity_id": engine_choice.get_item_metadata(engine_choice.selected)}
	)


func queue_rout() -> void:
	_queue_deimos(Deimos.ROUT, {"lane": rout_lane.get_item_text(rout_lane.selected)})


func _queue_deimos(power: String, target: Dictionary) -> void:
	if not _planning() or not powers_step or _human_lord() != "Deimos" or _queued_power(power):
		return
	var candidate: Array = queued.duplicate(true)
	candidate.append(session.declaration(power, queued.size(), target))
	if _error(session.choose(candidate, _order())):
		return
	queued = candidate
	_preview()


func _update_deimos_controls() -> void:
	if _human_lord() != "Deimos":
		return
	for power in [Deimos.WAR_MACHINE, Deimos.ROUT]:
		var state: Dictionary = session.power_status(power)
		var label: Label = war_state if power == Deimos.WAR_MACHINE else rout_state
		var button: Button = war_button if power == Deimos.WAR_MACHINE else rout_button
		var queued_now: bool = _queued_power(power)
		label.text = "Queued · not spent yet" if queued_now else "Ready · cooldown 0"
		if state.awaiting_expiration:
			label.text = "Active / recovering · then 2 cooldown rounds"
		elif state.remaining > 0:
			label.text = "Cooldown %d · ready round %d" % [state.remaining, state.ready_round]
		label.text += (
			"\nFree · one extra shot, from one Engine"
			if power == Deimos.WAR_MACHINE
			else "\nFree · cooldown starts when recovery ends"
		)
		if power == Deimos.WAR_MACHINE and engine_choice.item_count == 0:
			label.text += "\nNo operational Siege Engine."
		button.disabled = (
			not _planning()
			or not powers_step
			or _human_lord() != "Deimos"
			or queued_now
			or state.awaiting_expiration
			or state.remaining > 0
			or (power == Deimos.WAR_MACHINE and engine_choice.item_count == 0)
		)


func _hand_reserved(id: String) -> bool:
	return (
		id in payment
		or id in castle_plan.get("card_ids", [])
		or (powers_step and id in staged_order.get("card_ids", []))
	)


func _hand_selection_changed(_ids: Array) -> void:
	_preview()


func _new_loadout_session():
	return LoadoutSession.new()


func _build_humbaba_controls(parent: Node) -> void:
	humbaba_box = VBoxContainer.new()
	humbaba_box.add_theme_constant_override("separation", 6)
	parent.add_child(humbaba_box)
	for power in [Humbaba.MUSTER, Humbaba.BREATH]:
		_label(humbaba_box, _power_name(power).to_upper(), 17)
		var description: String = (
			"Summon 3 Penitents into one lane. They march this round."
			if power == Humbaba.MUSTER
			else "Friendly Marchers in one lane: +25% movement for this round and next; +1 regeneration at next round's start."
		)
		_label(humbaba_box, description, 13).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		humbaba_states[power] = _label(humbaba_box, "", 13)
		humbaba_states[power].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		humbaba_lanes[power] = _option(humbaba_box, ["Castle", "Lord"])
		var callback: Callable = queue_muster if power == Humbaba.MUSTER else queue_breath
		humbaba_buttons[power] = _button(
			humbaba_box, "CHOOSE " + _power_name(power).to_upper(), callback
		)
		controls.append(humbaba_buttons[power])
		humbaba_box.add_child(HSeparator.new())
	humbaba_box.hide()


func queue_muster() -> void:
	_queue_humbaba(Humbaba.MUSTER)


func queue_breath() -> void:
	_queue_humbaba(Humbaba.BREATH)


func _queue_humbaba(power: String) -> void:
	if not _planning() or not powers_step or _human_lord() != "Humbaba" or _queued_power(power):
		return
	var option: OptionButton = humbaba_lanes[power]
	var candidate: Array = queued.duplicate(true)
	candidate.append(
		session.declaration(power, queued.size(), {"lane": option.get_item_text(option.selected)})
	)
	if _error(session.choose(candidate, _order())):
		return
	queued = candidate
	_preview()


func _update_humbaba_controls() -> void:
	if _human_lord() != "Humbaba":
		return
	for power in [Humbaba.MUSTER, Humbaba.BREATH]:
		var state: Dictionary = session.power_status(power)
		var label: Label = humbaba_states[power]
		var queued_now: bool = _queued_power(power)
		label.text = "Queued · not spent yet" if queued_now else "Ready · cooldown 0"
		if state.awaiting_expiration:
			label.text = "Breath active · then 2 cooldown rounds"
		elif state.remaining > 0:
			label.text = "Cooldown %d · ready round %d" % [state.remaining, state.ready_round]
		label.text += (
			"\nFree · 1 round cooldown after use"
			if power == Humbaba.MUSTER
			else "\nFree · 2 active rounds, then 2 cooldown rounds"
		)
		humbaba_buttons[power].disabled = (
			not _planning()
			or not powers_step
			or queued_now
			or state.awaiting_expiration
			or state.remaining > 0
		)


func _build_kalligan_controls(parent: Node) -> void:
	kalligan_box = VBoxContainer.new()
	kalligan_box.add_theme_constant_override("separation", 6)
	parent.add_child(kalligan_box)
	for power in [Kalligan.INFERNO, Kalligan.PYROCLASM]:
		_label(kalligan_box, _power_name(power).to_upper(), 17)
		var description: String = (
			"Prepare fire for next round. Choose enemy Guards or either lane. Lane fire hits both sides. Moving preserves its 1 → 2 → 1 lifetime."
			if power == Kalligan.INFERNO
			else "Pulse your current Scorch once more this round. Uses its current location and intensity; normal fire still occurs."
		)
		_label(kalligan_box, description, 13).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kalligan_states[power] = _label(kalligan_box, "", 13)
		kalligan_states[power].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if power == Kalligan.INFERNO:
			inferno_target = _option(
				kalligan_box,
				[
					"Enemy Lord Guards",
					"Enemy Castle Guards",
					"Lord lane · both sides",
					"Castle lane · both sides"
				]
			)
		kalligan_buttons[power] = _button(
			kalligan_box,
			"CHOOSE INFERNO" if power == Kalligan.INFERNO else "QUEUE PYROCLASM",
			queue_inferno if power == Kalligan.INFERNO else queue_pyroclasm
		)
		controls.append(kalligan_buttons[power])
		kalligan_box.add_child(HSeparator.new())
	kalligan_box.hide()


func _kalligan_can_choose(power: String) -> bool:
	if (
		not _planning()
		or not powers_step
		or _human_lord() != "Kalligan"
		or _queued_power(power)
		or not session is LoadoutSession
	):
		return false
	# One representative legal region is sufficient for Inferno's readiness.
	# Final selection still submits its actual target through shared legality.
	var target: Dictionary = {"kind": "lane", "lane": "Lord"} if power == Kalligan.INFERNO else {}
	return session.preview_power(power, target, queued, _order()).action != "invalid"


func queue_inferno() -> void:
	if not _kalligan_can_choose(Kalligan.INFERNO):
		return
	var index: int = inferno_target.selected
	var target: Dictionary = (
		{"kind": "guard", "lane": "Lord" if index == 0 else "Castle", "player_id": 1}
		if index < 2
		else {"kind": "lane", "lane": "Lord" if index == 2 else "Castle"}
	)
	_queue_kalligan(Kalligan.INFERNO, target)


func queue_pyroclasm() -> void:
	if _kalligan_can_choose(Kalligan.PYROCLASM):
		_queue_kalligan(Kalligan.PYROCLASM, {})


func _queue_kalligan(power: String, target: Dictionary) -> bool:
	var candidate: Array = queued.duplicate(true)
	candidate.append(session.declaration(power, queued.size(), target))
	if _error(session.choose(candidate, _order())):
		return false
	queued = candidate
	_preview()
	return true


func _update_kalligan_controls() -> void:
	if _human_lord() != "Kalligan":
		return
	var active: Dictionary = ScorchView.active_for(_scorch_rows, 0)
	for power in [Kalligan.INFERNO, Kalligan.PYROCLASM]:
		var clock_state: Dictionary = session.power_status(power)
		var text: String = "Ready · cooldown 0"
		if not active.is_empty():
			text = (
				"Intensity %d · %d active rounds left\n%s"
				% [active.intensity, active.remaining, ScorchView.target_name(active.target)]
			)
		if power == Kalligan.INFERNO:
			if not active.is_empty():
				text += (
					"\nRelocation ready · fires next round"
					if active.remaining > 1
					else "\nFinal active round · relocation unavailable"
				)
			elif clock_state.awaiting_expiration:
				text = "Inferno prepared"
			elif clock_state.remaining > 0:
				text = (
					"Cooldown %d · ready round %d"
					% [clock_state.remaining, clock_state.ready_round]
				)
			text += "\nFree · 1 cooldown round after Scorch expires"
			if clock_state.fire_round > 0:
				text += "\nArmed · applies round %d" % clock_state.fire_round
		else:
			if active.is_empty():
				text = "Requires active Scorch"
			elif clock_state.remaining > 0:
				text += "\nUsed this round · ready round %d" % clock_state.ready_round
			text += "\nFree · once per round · no extra cooldown"
		if _queued_power(power):
			var queued_note: String = "Queued · not spent yet"
			if power == Kalligan.INFERNO:
				for source in queued:
					if source.power_id == power:
						queued_note += (
							"\nRound %d → %s"
							% [source.fire_round, ScorchView.target_name(source.target)]
						)
			text = queued_note + "\n" + text
		kalligan_states[power].text = text
		kalligan_buttons[power].disabled = not _kalligan_can_choose(power)


func _install_impacts(rows: Array) -> void:
	_impact_rows = rows
	_impact_cursor = 0
	_impact_clock = 0.0
	_impact_duration = 0.0 if rows.is_empty() else float(rows.back().at) + 1.1


func _advance_impacts(delta: float) -> bool:
	if _impact_clock >= _impact_duration:
		return false
	_impact_clock += maxf(0.0, delta)
	var ready_rows: Array = []
	while (
		_impact_cursor < _impact_rows.size()
		and float(_impact_rows[_impact_cursor].at) <= _impact_clock
	):
		var impact: Dictionary = _impact_rows[_impact_cursor]
		if impact.has("pulse"):
			lanes.flash_scorch(impact.pulse)
			for side in sides:
				side.flash_scorch(impact.pulse)
		else:
			ready_rows.append(impact)
		_impact_cursor += 1
	lanes.show_feedback(ready_rows)
	return _impact_clock < _impact_duration


func _gem_dagger_impact(_shot: Dictionary) -> void:
	if not _gem_final_view.is_empty():
		_refresh(gem_dagger_view.mask_view(_gem_final_view))


func _finish_gem_presentation() -> void:
	if _gem_final_view.is_empty() or gem_dagger_view.active():
		return
	var shown: Dictionary = _gem_final_view
	_gem_final_view = {}
	_refresh(shown)
	_busy_label.text = ""
