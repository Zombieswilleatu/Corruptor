extends Control

const Session = preload("res://Scripts/Sim/U13BoardSession.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
const Lanes = preload("res://Prototype/U13/U13BoardLanes.gd")
const DomainRow = preload("res://Prototype/U13/U13DomainRow.gd")
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
var plan_label: Label
var action_choice: OptionButton
var lane_choice: OptionButton
var target_choice: OptionButton
var ruin_target: OptionButton
var power_lane: OptionButton
var confirm: Button
var next_button: Button
var controls: Array = []
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
	get_window().content_scale_size = Vector2i(1600, 1080)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(1440, 972)
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


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	add_child(margin)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)
	margin.add_child(main)
	var top := HBoxContainer.new()
	main.add_child(top)
	summary = _label(top, "", 23)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(top, "Restart board", restart)
	_button(top, "Exit", func(): get_tree().quit())
	_label(
		main,
		(
			"U13 • Gremory combat board — Siege, Ward and Lord powers. "
			+ "Development, Hunt, normal draws and victory are not yet connected."
		),
		16
	)
	var enemy = DomainRow.new()
	enemy.player_id = 1
	enemy.custom_minimum_size.y = 165
	main.add_child(enemy)
	sides.append(enemy)
	lanes = Lanes.new()
	lanes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(lanes)
	var own = DomainRow.new()
	own.player_id = 0
	own.custom_minimum_size.y = 165
	main.add_child(own)
	sides.append(own)
	var decisions := HBoxContainer.new()
	main.add_child(decisions)
	_label(decisions, "COMMIT", 18)
	action_choice = _option(decisions, ["Pass", "Siege", "Ward"])
	lane_choice = _option(decisions, ["Castle", "Lord"])
	target_choice = OptionButton.new()
	target_choice.custom_minimum_size.x = 190
	decisions.add_child(target_choice)
	controls.append(target_choice)
	for option in [action_choice, lane_choice, target_choice]:
		option.item_selected.connect(func(_index): _preview())
	confirm = _button(decisions, "Commit & resolve", resolve_round)
	next_button = _button(decisions, "Next round", next_round)
	_button(decisions, "Skip animation", finish_playback)
	var powers := HBoxContainer.new()
	main.add_child(powers)
	_label(powers, "GREMORY", 18)
	power_lane = _option(powers, ["Castle", "Lord"])
	controls.append(_button(powers, "Queue 3 Vultures", queue_predator))
	ruin_target = _option(powers, [])
	controls.append(_button(powers, "Queue Ruin · discard 2 selected", queue_ruin))
	controls.append(_button(powers, "Clear powers", clear_powers))
	plan_label = _label(main, "", 16)
	status = _label(main, "Select cards, choose an action, then commit.", 17)
	hand_view = Hand.new()
	main.add_child(hand_view)
	hand_view.selection_changed.connect(func(_ids): _preview())
	history = RichTextLabel.new()
	history.custom_minimum_size.y = 85
	history.scroll_following = true
	main.add_child(history)


func _refresh(presented: Dictionary = {}) -> void:
	var view: Dictionary = session.view() if presented.is_empty() else presented
	var world: Dictionary = view.world
	summary.text = (
		"CORRUPTOR  /  U13     ROUND %d     Souls %d : %d     Neutral Tears %d     Breach: %s"
		% [
			session.round_number(),
			world.souls[0],
			world.souls[1],
			world.neutral_tears,
			world.breach_lord
		]
	)
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
	for pid in [1, 0]:
		for entity in world.entities:
			if entity.kind == "castle" and entity.owner == pid:
				ruin_target.add_item("Enemy Castle" if pid == 1 else "Your Castle")
				ruin_target.set_item_metadata(ruin_target.item_count - 1, entity.id)
	history.text = ""
	for event in view.events.slice(maxi(0, view.events.size() - 15)):
		history.append_text(String(event.get("text", event.type)) + "\n")
	for control in controls:
		control.disabled = not _planning()
	next_button.disabled = playing or not session.next_hook().is_empty()
	_preview()


func _render_side(row: HBoxContainer, world: Dictionary, pid: int) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	_picture(row, Art.lord_texture("Gremory"), Vector2(110, 155))
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 240
	row.add_child(details)
	_label(details, "YOUR DOMAIN" if pid == 0 else "OPPONENT DOMAIN", 21)
	_label(details, "Gremory · Souls %d" % world.souls[pid], 18)
	_label(details, "Hand: %d" % (world.hand.size() if pid == 0 else world.opponent_hand_count), 17)
	for entity in world.entities:
		if entity.owner != pid:
			continue
		if entity.kind == "castle":
			_label(
				details,
				(
					"Castle · %s\nIntegrity %d / %d"
					% [
						entity.attributes.status,
						entity.attributes.integrity,
						entity.attributes.max_integrity
					]
				),
				18
			)
	var guard_box := HBoxContainer.new()
	row.add_child(guard_box)
	_label(guard_box, "CASTLE\nGUARDS", 16)
	for entity in world.entities:
		if (
			entity.owner == pid
			and entity.kind == "card"
			and entity.attributes.get("role") == "guard"
		):
			_picture(
				guard_box,
				Art.texture_for(entity.attributes.suit, int(entity.attributes.value)),
				Vector2(82, 120)
			)
	var note := Label.new()
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.text = (
		"Choose your cards and powers below."
		if pid == 0
		else "Random-legal exercise opponent\nCommitments stay hidden until reveal."
	)
	row.add_child(note)


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
	lane_choice.disabled = action_choice.selected != 2
	target_choice.disabled = action_choice.selected != 1
	var result: Dictionary = session.choose(queued, _order())
	confirm.disabled = result.action == "invalid"
	status.text = (
		"Ready. Selected cards pay for your combat action; queued Ruin cards are reserved separately."
		if not confirm.disabled
		else "Cannot commit: " + String(result.get("reason", "invalid plan"))
	)

	if not confirm.disabled and action_choice.selected == 0:
		status.text = "Pass selected. Your cards stay in hand; queued Lord powers still fire."


func queue_predator() -> void:
	if not _planning():
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
	if not _planning() or ruin_target.item_count == 0:
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
	_refresh()


func _error(result: Dictionary) -> bool:
	if result.action != "invalid":
		return false
	status.text = "Stopped: " + String(result.get("reason", "unknown error"))
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
