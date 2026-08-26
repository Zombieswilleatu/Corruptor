class_name UI2ConsoleOverlay
extends PanelContainer


signal closed


var title_label: Label = null
var body_label: RichTextLabel = null


func _ready() -> void:
	visible = false
	z_index = 100

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override(
		"separation",
		8
	)
	add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)

	title_label = Label.new()
	title_label.text = "CONSOLE"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override(
		"font_size",
		20
	)
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(
		hide_console
	)
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	outer.add_child(tabs)

	for tab_name: String in [
		"LORD",
		"CASTLES",
		"MARCHING",
		"MATCH LOG",
		"RULES",
	]:
		var tab := Button.new()
		tab.text = tab_name
		tab.disabled = true
		tabs.add_child(tab)

	body_label = RichTextLabel.new()
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.fit_content = false
	body_label.scroll_active = true
	body_label.text = (
		"[b]UI2 Console shell[/b]\n\n"
		+ "Static reference and historical information moves here. "
		+ "Nothing required for a legal, informed decision may depend "
		+ "on opening this overlay."
	)
	outer.add_child(body_label)


func show_console() -> void:
	visible = true


func hide_console() -> void:
	visible = false
	closed.emit()
