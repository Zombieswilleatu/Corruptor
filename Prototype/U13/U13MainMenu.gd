extends Control
const Backdrop = preload("res://Prototype/U13/U13MenuBackdrop.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Picker = preload("res://Prototype/U13/U13LoadoutPicker.gd")
var flow: Node
var error_label: Label
var new_panel: Control
var menu_column: Control
var dev_button: Button
var entering: bool = false
var load_dialog: FileDialog
var serif: SystemFont
var new_button: Button

func _ready() -> void:
	get_tree().auto_accept_quit = true
	flow = get_node("/root/CorruptorMenuFlow")
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "DejaVu Serif", "Times New Roman"])
	var theme_style := Theme.new()
	theme_style.default_font_size = 20
	theme = theme_style
	var backdrop := Backdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var column := VBoxContainer.new()
	menu_column = column
	column.anchor_left = 0.075
	column.anchor_top = 0.12
	column.anchor_right = 0.405
	column.anchor_bottom = 0.87
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	var logo := TextureRect.new()
	logo.texture = Backdrop.Art.texture("res://ConceptImages/Menus/TitleCard.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size.y = 240
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(logo)
	var space := Control.new()
	space.custom_minimum_size.y = 24
	column.add_child(space)
	new_button = _menu_button(column, "New Game", _open_new)
	_menu_button(column, "Load Game", _open_load)
	_menu_button(column, "Options", func(): get_node("/root/CorruptorAudio").open_options())
	_menu_button(column, "Quit", func(): get_tree().quit())
	error_label = _label(column, "", 18, Color("e1a184"))
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var dev := Button.new()
	dev_button = dev
	dev.text = "DEV MENU  ↗"
	dev.tooltip_text = "Setup, sound and music labs, animation previews, and other test systems."
	dev.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	dev.offset_left = -190
	dev.offset_right = -28
	dev.offset_top = 24
	dev.offset_bottom = 65
	dev.add_theme_font_size_override("font_size", 16)
	_skin_button(dev, false)
	add_child(dev)
	dev.pressed.connect(func():
		flow.click()
		flow.launch({"action": "dev"}))
	_build_new()
	_build_load()
	flow.ensure_theme()
	if not flow.last_error.is_empty(): show_error(flow.last_error)
	new_button.grab_focus()

func _skin_button(button: Button, large: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var skin := StyleBoxFlat.new()
		skin.bg_color = Color(0.07, 0.065, 0.065, 0.65 if large else 0.78)
		skin.border_color = Color("70624c") if state == "normal" else Color("c6a66d")
		skin.border_width_bottom = 1
		if state != "normal":
			skin.border_width_left = 3
			skin.bg_color = Color(0.16, 0.13, 0.10, 0.86)
		skin.content_margin_left = 22 if large else 12
		skin.content_margin_right = 14
		button.add_theme_stylebox_override(state, skin)
	button.add_theme_color_override("font_color", Color("c7bba7"))
	button.add_theme_color_override("font_hover_color", Color("f0d7a7"))
	button.add_theme_color_override("font_focus_color", Color("f0d7a7"))

func _menu_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 64
	button.add_theme_font_override("font", serif)
	button.add_theme_font_size_override("font_size", 28)
	_skin_button(button, true)
	parent.add_child(button)
	button.pressed.connect(func():
		flow.click(text == "Back")
		action.call())
	return button

func _label(parent: Node, text: String, font_size: int, color: Color = Color("c7bba7")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _option(parent: Node, entries: Array) -> OptionButton:
	var choice := OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.custom_minimum_size.y = 38
	for entry in entries: choice.add_item(str(entry).replace("SiegeEngine", "Siege Engine").replace("SummoningCircle", "Summoning Circle"))
	parent.add_child(choice)
	choice.item_selected.connect(func(_index): flow.click())
	return choice

func _build_new() -> void:
	new_panel = preload("res://Prototype/U13/U13MenuSelection.gd").new()
	add_child(new_panel)
	new_panel.closed.connect(_close_new)

func _open_new() -> void:
	if entering: return
	entering = true
	# Settle container geometry before recording the words to burn.
	await get_tree().process_frame
	await get_tree().process_frame
	dev_button.hide()
	for child in menu_column.get_children():
		if child is BaseButton: child.disabled = true
	var burn := preload("res://Prototype/U13/U13MenuBurn.gd").new()
	burn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child in menu_column.get_children():
		if child is BaseButton:
			var rect: Rect2 = child.get_global_rect()
			var face: Font = child.get_theme_font("font")
			rect.position.x += 22.0
			rect.size.x = face.get_string_size(child.text,HORIZONTAL_ALIGNMENT_LEFT,-1,child.get_theme_font_size("font_size")).x + 16.0
			burn.areas.append(rect)
	add_child(burn)
	var fire := create_tween()
	fire.tween_property(burn,"progress",1.0,0.85)
	var fade := create_tween()
	fade.tween_property(menu_column,"modulate",Color(1.6,0.7,0.25),0.22)
	fade.tween_property(menu_column,"modulate:a",0.0,0.55)
	await fire.finished
	burn.queue_free()
	menu_column.hide()
	entering = false
	new_panel.open()

func _close_new() -> void:
	new_panel.hide()
	menu_column.show()
	menu_column.modulate = Color.WHITE
	for child in menu_column.get_children():
		if child is BaseButton: child.disabled = false
	dev_button.show()
	new_button.grab_focus()

func _build_load() -> void:
	load_dialog = FileDialog.new()
	load_dialog.title = "Load a saved game"
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.filters = PackedStringArray(["u13-playable-*.json ; Corruptor saved games", "*.json ; Other JSON files"])
	load_dialog.file_selected.connect(func(path: String): flow.launch({"action": "load", "path": path}))
	add_child(load_dialog)
	preload("res://Prototype/U13/U13MenuSkin.gd").window(load_dialog)
	var older := Button.new()
	older.text = "OLDER SAVES IN DOWNLOADS"
	older.pressed.connect(func(): load_dialog.current_dir = _downloads())
	load_dialog.get_vbox().add_child(older)

func _downloads() -> String:
	var directory := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	return OS.get_user_data_dir() if directory.is_empty() else directory

func _open_load() -> void:
	var directory := _downloads().path_join("Corruptor/Saves")
	load_dialog.current_dir = directory if DirAccess.dir_exists_absolute(directory) else _downloads()
	load_dialog.popup_centered(Vector2i(1100, 700))

func show_error(message: String) -> void:
	_close_new()
	error_label.text = message

