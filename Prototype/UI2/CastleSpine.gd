class_name UI2CastleSpine
extends PanelContainer


const ABBREVIATIONS: Dictionary = {
	"Keep": "KEP",
	"Bastion": "BST",
	"SummoningCircle": "CIR",
	"Stockpile": "STK",
	"SiegeEngine": "ENG",
}


var code_label: Label = null
var value_label: Label = null
var state_label: Label = null
var castle_name: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(
		120,
		150
	)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var box := VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		0
	)
	add_child(box)

	code_label = Label.new()
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_label.add_theme_font_size_override(
		"font_size",
		12
	)
	box.add_child(code_label)

	value_label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	value_label.add_theme_font_size_override(
		"font_size",
		19
	)
	box.add_child(value_label)

	state_label = Label.new()
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override(
		"font_size",
		9
	)
	box.add_child(state_label)


func bind_castle(
	player,
	p_castle_name: String
) -> void:
	castle_name = p_castle_name

	if player == null:
		return

	var short_name: String = String(
		ABBREVIATIONS.get(
			castle_name,
			castle_name.left(3).to_upper()
		)
	)

	code_label.text = short_name

	var standing: bool = player.castles.has(
		castle_name
	)
	var ruined: bool = player.ruined_castles.has(
		castle_name
	)
	var profaned: bool = player.profaned_castles.has(
		castle_name
	)

	var progress: int = int(
		player.castle_construction_progress.get(
			castle_name,
			0
		)
	)

	var integrity: int = int(
		player.castle_integrity.get(
			castle_name,
			0
		)
	)

	var value_text: String = "—"
	var state_text: String = ""
	var background := Color(
		0.075,
		0.075,
		0.082,
		1.0
	)
	var border := Color(
		0.20,
		0.21,
		0.24,
		1.0
	)

	if standing:
		value_text = str(
			integrity
		)

		if integrity >= 7:
			state_text = "OPERATIONAL"
		else:
			state_text = "DEFUNCT"
			background = Color(
				0.13,
				0.105,
				0.055,
				1.0
			)
			border = Color(
				0.55,
				0.42,
				0.18,
				1.0
			)

	elif profaned:
		value_text = "—"
		state_text = "PROFANED"
		background = Color(
			0.105,
			0.065,
			0.12,
			1.0
		)
		border = Color(
			0.48,
			0.30,
			0.53,
			1.0
		)

	elif ruined:
		value_text = "0"
		state_text = "RUINED"
		background = Color(
			0.18,
			0.055,
			0.055,
			1.0
		)
		border = Color(
			0.68,
			0.20,
			0.20,
			1.0
		)

	elif progress > 0:
		value_text = "%d/14" % progress
		state_text = "BUILDING"
		background = Color(
			0.12,
			0.105,
			0.055,
			1.0
		)
		border = Color(
			0.58,
			0.48,
			0.18,
			1.0
		)

	value_label.text = value_text
	state_label.text = state_text

	_apply_style(
		background,
		border
	)

	tooltip_text = "%s — %s" % [
		castle_name,
		_full_state_text(
			standing,
			ruined,
			profaned,
			progress,
			integrity
		),
	]


func _full_state_text(
	standing: bool,
	ruined: bool,
	profaned: bool,
	progress: int,
	integrity: int
) -> String:
	if standing:
		if integrity >= 7:
			return (
				"Operational, Integrity %d"
				% integrity
			)

		return (
			"Defunct, Integrity %d"
			% integrity
		)

	if profaned:
		return "Profaned"

	if ruined:
		return "Ruined"

	if progress > 0:
		return (
			"Construction %d/14"
			% progress
		)

	return "Not built"


func _apply_style(
	background: Color,
	border: Color
) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	add_theme_stylebox_override(
		"panel",
		style
	)
