extends Control

signal closed
var embedded: bool = false
var column: VBoxContainer
var message: Label
var close_button: Button
var _choose_sound: AudioStreamPlayer
var _back_sound: AudioStreamPlayer
var _last_click_ms: int = -1000
# An open picker can reserve its checked choices before the round is submitted.
var pending_selection: Callable
var _detail_rows: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 110
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(740, 760)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171511")
	style.border_color = Color("93713d")
	style.set_border_width_all(2)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	preload("res://Prototype/U13/U13MenuSkin.gd").apply(panel)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 625)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	message = Label.new()
	message.custom_minimum_size.y = 40
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(message)
	close_button = Button.new()
	close_button.text = "RETURN TO BOARD"
	close_button.custom_minimum_size.y = 42
	outer.add_child(close_button)
	# Keep the players under the close button: embed_in() reparents it,
	# while present() replaces the contents of the option column.
	_choose_sound = AudioStreamPlayer.new()
	_choose_sound.stream = AudioStreamWAV.load_from_file("res://Sounds/Cues/modal_choose.wav")
	_choose_sound.volume_db = -15.0
	close_button.add_child(_choose_sound)
	_back_sound = AudioStreamPlayer.new()
	_back_sound.stream = AudioStreamWAV.load_from_file("res://Sounds/Cues/modal_back.wav")
	_back_sound.volume_db = -16.0
	close_button.add_child(_back_sound)
	close_button.pressed.connect(_play_back_sound)
	close_button.pressed.connect(func(): hide(); closed.emit())
	hide()

func _play_choose_sound() -> void:
	if _choose_sound.stream == null: return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_click_ms < 65: return
	_last_click_ms = now_ms
	_choose_sound.play()

func _play_back_sound() -> void:
	if _back_sound.stream == null: return
	_back_sound.play()

func present(title: String, description: String, dismissible: bool = true) -> void:
	pending_selection = Callable()
	_detail_rows.clear()
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	set_message("")
	if not embedded: label(title, 24)
	if not description.is_empty(): label(description, 16)
	close_button.visible = dismissible
	if embedded: close_button.text = "BACK"
	show()

func set_message(value: String) -> void:
	message.text = value
	message.visible = not embedded or not value.strip_edges().is_empty()

func label(value: String, size_value: int = 16) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", size_value)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(result)
	return result

func button(value: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = value
	if embedded:
		result.clip_text = true
		result.tooltip_text = value
	result.custom_minimum_size.y = 42
	result.pressed.connect(_play_choose_sound)
	if callback.is_valid(): result.pressed.connect(callback)
	column.add_child(result)
	return result

func option(values: Array) -> OptionButton:
	var result := OptionButton.new()
	for value in values:
		result.add_item(str(value))
	result.custom_minimum_size.y = 40
	result.item_selected.connect(func(_index): _play_choose_sound())
	column.add_child(result)
	return result

# Opening an explanation never stages an order. Only its explicit action does.
# One expanded item per menu keeps the remaining choices in view.
func details(value: String, explanation: String, action_text: String = "", callback: Callable = Callable()) -> Button:
	var heading: Button = button("", Callable())
	heading.toggle_mode = true
	heading.clip_text = false
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.tooltip_text = "Click to show or hide details."
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	column.add_child(body)
	var copy: Label = label(explanation, 14)
	copy.reparent(body)
	if callback.is_valid():
		var proceed: Button = button(action_text, callback)
		proceed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		proceed.clip_text = false
		proceed.reparent(body)
	body.hide()
	_detail_rows.append({"heading": heading, "body": body, "title": value})
	heading.text = "▸ " + value
	heading.pressed.connect(_toggle_details.bind(heading))
	return heading

func _toggle_details(selected: Button) -> void:
	var expand: bool = selected.button_pressed
	for row in _detail_rows:
		var active: bool = row.heading == selected and expand
		row.heading.set_pressed_no_signal(active)
		row.heading.text = ("▾ " if active else "▸ ") + str(row.title)
		row.body.visible = active

func checks(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var box := CheckBox.new()
		box.text = str(value)
		box.custom_minimum_size.y = 36
		box.toggled.connect(func(_pressed): _play_choose_sound())
		column.add_child(box)
		result.append(box)
	return result

# Share the board's decision shell; retain the same choice callbacks and widgets.
func embed_in(host: Control) -> void:
	embedded = true
	var contents := VBoxContainer.new()
	add_child(contents)
	column.reparent(contents)
	message.reparent(contents)
	message.custom_minimum_size.y = 0
	set_message(message.text)
	close_button.reparent(contents)
	for child in get_children():
		if child != contents:
			remove_child(child)
			child.queue_free()
	reparent(host)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	z_index = 0
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	contents.minimum_size_changed.connect(func(): custom_minimum_size.y = contents.get_combined_minimum_size().y)
