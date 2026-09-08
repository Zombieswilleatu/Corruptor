extends Control

const PhasePrompt = preload("res://Prototype/U13/U13PhasePrompt.gd")
const ActionZone = preload("res://Prototype/U13/U13ActionZone.gd")
const Session = preload("res://Scripts/Sim/U13BoardSession.gd")
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


var session = Session.new()
var playback = Playback.new()
var dense_mode: bool = false
var dense_button: Button
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
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(1440, 810)
	_build()
	if _runtime_ok:
		restart()
	else:
		status.text = "U13 requires Godot 4.7.2 stable."
		confirm.disabled = true
		next_button.disabled = true


func restart() -> void:
	if not _runtime_ok:
		return
	playing = false
	clock = 0
	queued = []
	payment = []
	powers_step = false
	staged_order = {}
	var result: Dictionary = session.reset()
	if _error(result):
		return
	action_choice.select(0)
	_refresh()
	reopen_decision()


func _build() -> void:
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
	_button(header.tools_box, "Restart", restart)
	_button(header.tools_box, "Exit", func(): get_tree().quit())
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
	var powers := VBoxContainer.new()
	powers_box = powers
	decisions.add_child(powers)
	var predator_section := VBoxContainer.new()
	predator_section.name = "PredatorOfRuinSection"
	predator_section.add_theme_constant_override("separation", 6)
	powers.add_child(predator_section)
	_label(predator_section, "PREDATOR OF RUIN", 17)
	_label(predator_section, "Summon 3 Vultures", 13)
	predator_state = _label(predator_section, "", 13)
	predator_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(predator_section, "Spawn lane", 12)
	power_lane = _option(predator_section, ["Castle", "Lord"])
	predator_button = _button(predator_section, "Queue Predator of Ruin", queue_predator)
	controls.append(predator_button)
	powers.add_child(HSeparator.new())
	var ruin_section := VBoxContainer.new()
	ruin_section.name = "InevitableRuinSection"
	ruin_section.add_theme_constant_override("separation", 6)
	powers.add_child(ruin_section)
	_label(ruin_section, "INEVITABLE RUIN", 17)
	ruin_state = _label(ruin_section, "", 13)
	ruin_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(ruin_section, "Enemy Castle target", 12)
	ruin_target = _option(ruin_section, [])
	ruin_button = _button(ruin_section, "Queue Ruin · reserve 2 selected", queue_ruin)
	controls.append(ruin_button)
	powers.add_child(HSeparator.new())
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
	hand_view.selection_changed.connect(func(_ids): _preview())
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


func _refresh(presented: Dictionary = {}) -> void:
	var view: Dictionary = session.view() if presented.is_empty() else presented
	var world: Dictionary = view.world
	header.bind_world(world, session.round_number())
	_render_side(sides[0], world, 1)
	_render_side(sides[1], world, 0)
	if not playing:
		lanes.show_world(world.entities, session.round_number())
	var cards: Array = []
	for id in world.hand:
		if id in payment or (powers_step and id in staged_order.get("card_ids", [])):
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
	target_choice.clear()
	for entity in world.entities:
		if entity.kind == "castle" and entity.owner == 1:
			target_choice.add_item("Enemy Castle · %s" % entity.attributes.status)
			target_choice.set_item_metadata(target_choice.item_count - 1, entity.id)
	ruin_target.clear()
	for entity in world.entities:
		if (
			entity.kind == "castle"
			and entity.owner == 1
			and entity.attributes.status == "standing"
			and entity.attributes.integrity > 0
			and entity.attributes.integrity < entity.attributes.max_integrity
		):
			ruin_target.add_item("Enemy Castle · %s" % entity.attributes.status)
			ruin_target.set_item_metadata(ruin_target.item_count - 1, entity.id)
	ruin_target.tooltip_text = "Inevitable Ruin targets a damaged enemy Castle."
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
	next_button.disabled = playing or not session.next_hook().is_empty()
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
	return _runtime_ok and not playing and session.next_hook() == Timeline.SUBMISSION_LOCK


func _order() -> Dictionary:
	if powers_step:
		return staged_order.duplicate(true)
	var action: String = action_choice.get_item_text(action_choice.selected)
	if action == "Pass":
		return {}
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
	return result


func _preview() -> void:
	if status == null or hand_view == null:
		return
	var names: Array[String] = []
	for source in queued:
		names.append(
			"Predator of Ruin" if source.power_id == Gremory.PREDATOR else "Inevitable Ruin"
		)
	plan_label.text = (
		"Powers: %s     Reserved for Ruin: %d cards"
		% ["None" if names.is_empty() else ", ".join(names), payment.size()]
	)
	if not _planning():
		confirm.disabled = true
		return
	var name: String = {0: "Powers Only", 1: "Siege", 2: "Ward"}[action_choice.selected]
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
		"Combat selected. Next opens Lord powers without advancing the round."
		if not confirm.disabled
		else _friendly_error(result)
	)

	if not confirm.disabled and action_choice.selected == 0:
		status.text = "No combat selected. Continue to Lord powers."
	if action_choice.selected == 1 and target_choice.item_count == 0:
		status.text = "No enemy Castle remains. Choose Ward or Skip Combat."
	action_zone.action_buttons["Siege"].disabled = target_choice.item_count == 0
	_update_power_controls()
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
	if not dense_mode or playing or not _runtime_ok:
		return
	if session.next_hook().is_empty():
		next_round()
	if not _planning():
		return
	queued = []
	payment = []
	powers_step = false
	staged_order = {}
	action_choice.select(0)
	hand_view.clear_selection()
	resolve_round()


func resolve_round() -> void:
	if not _planning():
		return
	if _error(session.choose(queued, _order())):
		return
	var result: Dictionary = session.run_to_marching()
	if _error(result):
		return
	if not playback.build(session.marching_events()):
		status.text = "Marching tape missing; playback stopped."
		return
	clock = 0.0
	playing = true
	_refresh(result.before_marching)
	lanes.show_frame(playback.sample(0), session.round_number())
	status.text = (
		"Marching — committed Marchers wait until next round; "
		+ "summoned Vultures move immediately."
	)

	if dense_mode:
		status.text = "Dense Marching · watch steering, queued contacts and shrinking health rings."


func _process(delta: float) -> void:
	if not playing:
		return
	clock = minf(playback.duration, clock + maxf(delta, 0.0))
	lanes.show_frame(playback.sample(clock), session.round_number())
	if clock >= playback.duration:
		finish_playback()


func finish_playback() -> void:
	if not playing:
		return
	playing = false
	for index in range(3):
		if session.next_hook().is_empty():
			break
		if _error(session.step()):
			return
	_refresh()
	status.text = (
		"Round resolved. Next round continues; Restart restores the opening hand. "
		+ "This slice has no normal draw or victory yet."
	)

	if dense_mode:
		status.text = "Dense round complete. Next dense round continues; Restart restores all 48 Marchers."


func next_round() -> void:
	if playing or not session.next_hook().is_empty():
		return
	if _error(session.next_round()):
		return
	queued = []
	payment = []
	powers_step = false
	staged_order = {}
	action_choice.select(0)
	_refresh()


func _select_action(action: String) -> void:
	if not _planning() or powers_step:
		return
	action_choice.select({"Siege": 1, "Ward": 2, "Powers Only": 0}[action])
	_preview()


func _confirm_decision() -> void:
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
	if dense_mode:
		return
	if playing or phase_prompt == null:
		return
	phase_prompt.board_view_collapsed = false
	phase_prompt.set_presenting(true)
	phase_prompt._refresh_mode()


func _update_decision_copy() -> void:
	if not _planning():
		return
	action_zone.action_box.visible = not powers_step
	powers_box.visible = powers_step
	if powers_step:
		(
			phase_prompt
			. bind_decision(
				"LORD_POWERS",
				"LORD POWERS",
				"Combat is staged. Choose optional powers using the remaining cards, then resolve both together.",
				"ROUND %d" % session.round_number()
			)
		)
	else:
		phase_prompt.bind_decision(
			"COMMITMENT",
			"COMBAT",
			"Choose combat and select cards. Next opens Lord powers; the round has not advanced.",
			"ROUND %d" % session.round_number()
		)
	confirm.text = "RESOLVE ROUND" if powers_step else "NEXT · LORD POWERS"
	pass_button.text = "NO POWERS" if powers_step else "SKIP COMBAT"
	pass_button.tooltip_text = (
		"Clear queued powers and resolve your staged combat."
		if powers_step
		else "Skip combat and continue to Lord powers."
	)


func _queued_power(power: String) -> bool:
	for source in queued:
		if source.power_id == power:
			return true
	return false


func _update_power_controls() -> void:
	for power in [Gremory.PREDATOR, Gremory.RUIN]:
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
	if powers_step and not confirm.disabled:
		status.text = (
			"Combat: %s · %d cards. Powers: %d queued. Resolve submits both together."
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
	decision_button.disabled = playing
	next_button.hide()
	if playing:
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
	if reason == "combat_order_invalid":
		return "Check your combat target and selected cards, or choose Powers Only or Pass Round."
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
