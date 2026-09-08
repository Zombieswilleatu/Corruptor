extends Control

var dont_show: CheckBox
var continue_button: Button
var cancel_button: Button
var title: Label
var body: Label
var _preferences
var _tutorial_id: String = ""
var _accepted: Callable
var _cancelled: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.8)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("171511")
	skin.border_color = Color("93713d")
	skin.set_border_width_all(2)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		skin.set_content_margin(side, 24)
	panel.add_theme_stylebox_override("panel", skin)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	heading.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = "Close and keep the current choice"
	heading.add_child(close)
	close.pressed.connect(_finish.bind(false))
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 17)
	column.add_child(body)
	dont_show = CheckBox.new()
	dont_show.text = "Don't show this again"
	column.add_child(dont_show)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	cancel_button = Button.new()
	cancel_button.text = "KEEP CURRENT CHOICE"
	buttons.add_child(cancel_button)
	cancel_button.pressed.connect(_finish.bind(false))
	continue_button = Button.new()
	continue_button.text = "USE THIS CHOICE"
	buttons.add_child(continue_button)
	continue_button.pressed.connect(_finish.bind(true))
	hide()


func present(
	preferences,
	id: String,
	heading: String,
	text_value: String,
	accepted: Callable,
	cancelled: Callable = Callable()
) -> bool:
	if not preferences.should_show(id):
		return false
	_preferences = preferences
	_tutorial_id = id
	_accepted = accepted
	_cancelled = cancelled
	title.text = heading
	body.text = text_value
	dont_show.set_pressed_no_signal(false)
	show()
	cancel_button.grab_focus()
	return true


func _finish(accept_choice: bool) -> void:
	if not visible:
		return
	if dont_show.button_pressed:
		_preferences.dismiss(_tutorial_id)
	var callback: Callable = _accepted if accept_choice else _cancelled
	hide()
	_accepted = Callable()
	_cancelled = Callable()
	if callback.is_valid():
		callback.call()
