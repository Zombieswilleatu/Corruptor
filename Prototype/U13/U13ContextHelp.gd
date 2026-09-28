extends Control

signal closed
signal suppression_requested(id: String)
signal automatic_changed(value: bool)
signal reset_requested
var title: Label
var body: RichTextLabel
var dont_show: CheckBox
var close_button: Button
var automatic: CheckBox
var reset_button: Button
var topics: OptionButton
var search: LineEdit
var note: Label
var panel: PanelContainer
var topic_id: String = ""
var _book: Array = []
var _manual: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 250
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.025, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("191712")
	skin.border_color = Color("a68b52")
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(6)
	skin.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", skin)
	preload("res://Prototype/U13/U13MenuSkin.gd").apply(panel)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var eyebrow := Label.new()
	eyebrow.text = "CORRUPTOR · FIELD GUIDE"
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.modulate = Color("c1aa78")
	column.add_child(eyebrow)
	title = Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	search = LineEdit.new()
	search.placeholder_text = "Find a topic…"
	search.text_changed.connect(func(_text): _filter())
	column.add_child(search)
	topics = OptionButton.new()
	topics.item_selected.connect(_select_topic)
	column.add_child(topics)
	body = RichTextLabel.new()
	body.bbcode_enabled = false
	body.selection_enabled = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 18)
	column.add_child(body)
	dont_show = CheckBox.new()
	dont_show.text = "Don't show this again"
	column.add_child(dont_show)
	automatic = CheckBox.new()
	automatic.text = "Show automatic explanations"
	automatic.toggled.connect(func(value): automatic_changed.emit(value))
	column.add_child(automatic)
	reset_button = Button.new()
	reset_button.text = "RESET TUTORIAL HISTORY"
	reset_button.tooltip_text = "Allow explanations again, including topics learned in the prologue."
	reset_button.pressed.connect(func(): reset_requested.emit())
	column.add_child(reset_button)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.modulate = Color("c5bfae")
	column.add_child(note)
	close_button = Button.new()
	close_button.text = "CLOSE · RETURN TO GAME"
	close_button.custom_minimum_size.y = 42
	close_button.pressed.connect(dismiss)
	column.add_child(close_button)
	resized.connect(_fit)
	_fit()
	hide()

func _fit() -> void:
	if panel == null: return
	panel.custom_minimum_size = Vector2(minf(650.0, maxf(300.0, size.x - 32.0)), minf(610.0, maxf(380.0, size.y - 32.0)))

func present(lesson: Dictionary, automatic_enabled: bool, used: int) -> void:
	_manual = false
	_book = []
	topic_id = lesson.id
	title.text = lesson.title
	body.text = lesson.body
	body.scroll_to_line(0)
	search.hide()
	topics.hide()
	dont_show.show()
	dont_show.set_pressed_no_signal(false)
	automatic.set_pressed_no_signal(automatic_enabled)
	reset_button.hide()
	note.text = "Explanation %d this round · Nothing is submitted or changed by closing. All topics remain in HELP." % used
	show()
	_fit()
	close_button.grab_focus()

func open_book(lessons: Array, automatic_enabled: bool) -> void:
	_manual = true
	_book = lessons
	search.text = ""
	search.show()
	topics.show()
	dont_show.hide()
	reset_button.show()
	automatic.set_pressed_no_signal(automatic_enabled)
	note.text = "Browse freely. Reading Help does not use the automatic-popup allowance."
	_filter()
	show()
	_fit()
	search.grab_focus()

func _filter() -> void:
	topics.clear()
	var query: String = search.text.to_lower()
	for lesson in _book:
		if query.is_empty() or (str(lesson.title) + " " + str(lesson.body)).to_lower().contains(query):
			topics.add_item(lesson.title)
			topics.set_item_metadata(topics.item_count - 1, lesson)
	if topics.item_count > 0: _select_topic(0)
	else:
		title.text = "No matching topic"
		body.text = "Try a shorter search, such as Ward, Supplicants or Wright."

func _select_topic(index: int) -> void:
	var lesson: Dictionary = topics.get_item_metadata(index)
	topic_id = lesson.id
	title.text = lesson.title
	body.text = lesson.body
	body.scroll_to_line(0)

func dismiss() -> void:
	if not visible: return
	if not _manual and dont_show.button_pressed: suppression_requested.emit(topic_id)
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		dismiss()
