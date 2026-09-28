extends Node
# Layout only: original buttons remain board-owned with their original callbacks.
var header: HBoxContainer
var utility_buttons: Array[Button] = []
var status: HBoxContainer
var hidden_tools: VBoxContainer

func install(target: HBoxContainer) -> void:
	header = target
	add_to_group("corruptor_compact_header")
	hidden_tools = VBoxContainer.new()
	hidden_tools.name = "OptionsActions"
	header.add_child(hidden_tools)
	hidden_tools.hide()
	for caption in ["New loadout", "Restart", "Exit", "SAVE", "LOAD", "PAUSE"]:
		var button := _find_button(header, caption)
		if button != null:
			button.reparent(hidden_tools)
			utility_buttons.append(button)
	# The empty Save/Load/Pause row must no longer request any height.
	for child in header.history_box.get_children():
		if child is Container and child.get_child_count() == 0: child.hide()
	var row := HBoxContainer.new()
	row.name = "OptionsAndHelp"
	header.tools_box.add_child(row)
	var audio := get_node_or_null("/root/CorruptorAudio")
	if audio != null:
		var options := Button.new()
		options.text = "OPTIONS"
		options.name = "SoundOptionsButton"
		options.tooltip_text = "Sound and game options · F10"
		options.pressed.connect(audio.open_options)
		row.add_child(options)
		_compact_button(options)
	var help := _find_button(header.history_box, "HELP")
	if help != null:
		help.reparent(row)
		_compact_button(help)
	status = HBoxContainer.new()
	status.name = "MatchStatus"
	status.add_theme_constant_override("separation", 12)
	var center: VBoxContainer = header.veil_wheel.get_parent()
	center.add_child(status)
	# Preserve the full 104px Veil control and reserve a single status line.
	header.custom_minimum_size.y = 146
	for child in header.history_box.get_children():
		if child is Label:
			child.reparent(status)
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			child.add_theme_font_size_override("font_size", 12)
			child.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for column in [header.tools_box, header.history_box]:
		column.alignment = BoxContainer.ALIGNMENT_CENTER

func _compact_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(78, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)

func _find_button(parent: Node, caption: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == caption: return child
		var found := _find_button(child, caption)
		if found != null: return found
	return null
