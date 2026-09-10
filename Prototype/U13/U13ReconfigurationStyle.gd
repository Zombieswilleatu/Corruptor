extends RefCounted

static func apply(panel: Control) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("141310")
	background.border_color = Color("81704b")
	background.set_border_width_all(2)
	background.set_corner_radius_all(4)
	background.content_margin_left = 18
	background.content_margin_right = 18
	background.content_margin_top = 20
	background.content_margin_bottom = 20
	background.shadow_color = Color(0, 0, 0, 0.65)
	background.shadow_size = 8
	panel.add_theme_stylebox_override("panel", background)
	var theme := Theme.new()
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", Color("dfd4bb"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var button := StyleBoxFlat.new()
		button.bg_color = Color("211d16") if state != "hover" else Color("393022")
		button.border_color = Color("a28c58") if state in ["hover", "focus", "pressed"] else Color("63543a")
		button.set_border_width_all(1)
		button.set_corner_radius_all(3)
		button.content_margin_top = 11
		button.content_margin_bottom = 11
		button.content_margin_left = 8
		button.content_margin_right = 8
		theme.set_stylebox(state, "Button", button)
		theme.set_color("font_" + ("color" if state == "normal" else state + "_color"), "Button", Color("e6d2a3") if state != "disabled" else Color("766e5e"))
	panel.theme = theme
