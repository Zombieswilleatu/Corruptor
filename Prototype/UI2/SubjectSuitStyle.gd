class_name UI2SubjectSuitStyle
extends RefCounted


static func accent(
	suit_name: String
) -> Color:
	match suit_name:
		"Butcher":
			return Color(0.86, 0.24, 0.22, 1.0)
		"Penitent":
			return Color(0.24, 0.46, 0.88, 1.0)
		"Wright":
			return Color(0.90, 0.72, 0.20, 1.0)
		"Vulture":
			return Color(0.58, 0.32, 0.82, 1.0)
		_:
			return Color(0.68, 0.68, 0.72, 1.0)


static func card_style(
	suit_name: String,
	background: Color,
	border_width: int = 3
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = accent(
		suit_name
	)
	style.set_border_width_all(
		border_width
	)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style
