extends Control

const PhasePrompt = preload("res://Prototype/U13/U13PhasePrompt.gd")
const ActionZone = preload("res://Prototype/U13/U13ActionZone.gd")
const Session = preload("res://Scripts/Sim/U13BoardSession.gd")
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


func _ready() -> void:
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
	decisions.add_child(powers)
	_label(powers, "GREMORY'S POWERS", 16)
	power_lane = _option(powers, ["Castle", "Lord"])
	controls.append(_button(powers, "PREDATOR OF RUIN\nSummon 3 Vultures", queue_predator))
	ruin_target = _option(powers, [])
	controls.append(_button(powers, "INEVITABLE RUIN\nReserve 2 selected cards", queue_ruin))
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
		if id in payment:
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
		if entity.kind == "castle" and entity.owner == 1:
			ruin_target.add_item("Enemy Castle · %s" % entity.attributes.status)
			ruin_target.set_item_metadata(ruin_target.item_count - 1, entity.id)
	ruin_target.tooltip_text = "Inevitable Ruin targets a damaged enemy Castle."
	history.text = ""
	for event in view.events.slice(maxi(0, view.events.size() - 15)):
		history.append_text(String(event.get("text", event.type)) + "\n")
	for control in controls:
		control.disabled = not _planning()
	ruin_target.disabled = ruin_target.item_count == 0 or not _planning()
	next_button.disabled = playing or not session.next_hook().is_empty()
	_preview()
	_sync_decision()


func _render_side(row, world: Dictionary, pid: int) -> void:
	row.bind_world(world, pid, _planning())


func _board_target_selected(action: String, lane: String, target_id: String) -> void:
	if not _planning():
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
	lane_choice.visible = action_choice.selected == 2
	target_choice.visible = action_choice.selected == 1
	action_zone.primary_label.visible = target_choice.visible
	action_zone.primary_label.text = "Enemy Castle"
	action_zone.secondary_label.visible = lane_choice.visible
	action_zone.secondary_label.text = "Defend lane"
	lane_choice.disabled = action_choice.selected != 2
	target_choice.disabled = action_choice.selected != 1
	var result: Dictionary = session.choose(queued, _order())
	confirm.disabled = result.action == "invalid"
	status.text = (
		"Ready. Selected cards pay for your combat action; queued Ruin cards are reserved separately."
		if not confirm.disabled
		else _friendly_error(result)
	)

	if not confirm.disabled and action_choice.selected == 0:
		status.text = "Combat is skipped. Confirm keeps queued powers; Pass Round cancels them."
	if action_choice.selected == 1 and target_choice.item_count == 0:
		status.text = "No enemy Castle remains. Choose Ward or Powers Only, or Pass Round."
	action_zone.action_buttons["Siege"].disabled = target_choice.item_count == 0
	_update_decision_copy()


func queue_predator() -> void:
	if not _planning():
		return
	var source: Dictionary = session.declaration(
		Gremory.PREDATOR, queued.size(), {"lane": power_lane.get_item_text(power_lane.selected)}
	)
	var candidate: Array = queued.duplicate(true)
	candidate.append(source)
	if _error(session.choose(candidate, {})):
		return
	queued = candidate
	_preview()


func queue_ruin() -> void:
	if not _planning():
		return
	if ruin_target.item_count == 0:
		status.text = "No enemy Castle remains for Inevitable Ruin."
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
	if _error(session.choose(candidate, {})):
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


func next_round() -> void:
	if playing or not session.next_hook().is_empty():
		return
	if _error(session.next_round()):
		return
	queued = []
	payment = []
	action_choice.select(0)
	_refresh()


func _select_action(action: String) -> void:
	if not _planning():
		return
	action_choice.select({"Siege": 1, "Ward": 2, "Powers Only": 0}[action])
	_preview()


func _confirm_decision() -> void:
	if session.next_hook().is_empty():
		next_round()
	else:
		resolve_round()


func pass_round() -> void:
	if not _planning():
		return
	queued = []
	payment = []
	action_choice.select(0)
	hand_view.clear_selection()
	resolve_round()


func reopen_decision() -> void:
	if playing or phase_prompt == null:
		return
	phase_prompt.board_view_collapsed = false
	phase_prompt.set_presenting(true)
	phase_prompt._refresh_mode()


func _update_decision_copy() -> void:
	if not _planning():
		return
	var copy: String = {
		0:
		"Queue Lord powers below, then confirm. Pass Round skips combat and cancels all queued powers.",
		1:
		"Select cards from your hand to attack the enemy Castle. Queued Lord powers resolve alongside combat.",
		2:
		"Choose a lane and select cards from your hand to defend it. You may also queue Lord powers."
	}[action_choice.selected]
	phase_prompt.bind_decision(
		"COMMITMENT", "YOUR ORDERS", copy, "ROUND %d" % session.round_number()
	)


func _sync_decision() -> void:
	decision_button.disabled = playing
	next_button.hide()
	if playing:
		phase_prompt.set_presenting(false)
		return
	if session.next_hook().is_empty():
		(
			phase_prompt
			. bind_decision(
				"AFTERMATH",
				"AFTERMATH",
				"The round has resolved. View Board to inspect it, or begin the next round. This slice has no normal draws or victory yet.",
				"ROUND %d" % session.round_number()
			)
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
	if reason.contains("cooldown"):
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
