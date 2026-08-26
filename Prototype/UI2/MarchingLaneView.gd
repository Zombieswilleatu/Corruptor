# UI2_SUBJECT_CARD_ART_SURFACES_V2
class_name UI2MarchingLaneView
extends PanelContainer

const SubjectCardArtCatalogData = preload(
	"res://Prototype/UI2/SubjectCardArtCatalog.gd"
)
const SubjectCardHoldPreviewData = preload(
	"res://Prototype/UI2/SubjectCardHoldPreview.gd"
)


signal march_guard_dropped(source_zone, card_id, lane_name)


const SubjectSuitStyleData = preload(
	"res://Prototype/UI2/SubjectSuitStyle.gd"
)


const LANES: Array[String] = [
	"Lord",
	"Castle",
]
const STEP_COUNT: int = 3


var title_label: Label = null
var subtitle_label: Label = null
var lanes_box: HBoxContainer = null
var march_drop_enabled: bool = false
var forced_march_lane: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(300, 0)
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.035, 0.042, 0.98)
	panel_style.border_color = Color(0.19, 0.20, 0.23, 1.0)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.corner_radius_bottom_right = 5
	panel_style.content_margin_left = 7
	panel_style.content_margin_right = 7
	panel_style.content_margin_top = 7
	panel_style.content_margin_bottom = 7
	add_theme_stylebox_override("panel", panel_style)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 7)
	add_child(outer)

	title_label = Label.new()
	title_label.text = "MARCHING BATTLEFIELD"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 17)
	outer.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "ENEMY ↓   ·   YOU ↑"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 11)
	outer.add_child(subtitle_label)

	lanes_box = HBoxContainer.new()
	lanes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lanes_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lanes_box.add_theme_constant_override("separation", 7)
	outer.add_child(lanes_box)




func set_march_drop_enabled(
	enabled: bool,
	forced_lane: String = ""
) -> void:
	march_drop_enabled = enabled
	forced_march_lane = forced_lane


func bind_players(
	human,
	bot
) -> void:
	if lanes_box == null:
		return

	for child in lanes_box.get_children():
		lanes_box.remove_child(child)
		child.queue_free()

	subtitle_label.text = (
		"%s ↓   ·   ↑ %s"
		% [
			String(bot.lord).to_upper() if bot != null else "ENEMY",
			String(human.lord).to_upper() if human != null else "YOU",
		]
	)

	for lane_name: String in LANES:
		lanes_box.add_child(
			_build_lane(
				lane_name,
				human,
				bot
			)
		)


func _build_lane(
	lane_name: String,
	human,
	bot
) -> Control:
	var lane_panel := PanelContainer.new()
	lane_panel.custom_minimum_size = Vector2(132, 0)
	lane_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var lane_style := StyleBoxFlat.new()
	lane_style.bg_color = Color(0.055, 0.055, 0.063, 1.0)
	var lane_accepts_drop: bool = (
		march_drop_enabled
		and (
			forced_march_lane.is_empty()
			or forced_march_lane == lane_name
		)
	)
	lane_style.border_color = (
		Color(0.38, 0.62, 0.96, 1.0)
		if lane_accepts_drop
		else Color(0.20, 0.21, 0.24, 1.0)
	)
	lane_style.set_border_width_all(
		2 if lane_accepts_drop else 1
	)
	lane_style.corner_radius_top_left = 4
	lane_style.corner_radius_top_right = 4
	lane_style.corner_radius_bottom_left = 4
	lane_style.corner_radius_bottom_right = 4
	lane_style.content_margin_left = 5
	lane_style.content_margin_right = 5
	lane_style.content_margin_top = 5
	lane_style.content_margin_bottom = 5
	lane_panel.add_theme_stylebox_override("panel", lane_style)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	lane_panel.add_child(column)

	var lane_title := Label.new()
	lane_title.text = "%s LANE" % lane_name.to_upper()
	lane_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lane_title.add_theme_font_size_override("font_size", 13)
	column.add_child(lane_title)

	column.add_child(
		_gate_label(
			String(bot.lord).to_upper() if bot != null else "ENEMY",
			"↓ ENEMY GATE"
		)
	)

	column.add_child(
		_side_header(
			bot,
			human
		)
	)

	var track := VBoxContainer.new()
	track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track.add_theme_constant_override("separation", 4)
	column.add_child(track)

	var bot_marcher = _marcher_in_lane(bot, lane_name)
	var human_marcher = _marcher_in_lane(human, lane_name)

	for visual_index: int in range(STEP_COUNT):
		track.add_child(
			_build_step(
				visual_index,
				bot_marcher,
				human_marcher
			)
		)

	if bot_marcher != null and human_marcher != null:
		var contested_label := Label.new()
		contested_label.text = "CONTESTED LANE"
		contested_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		contested_label.add_theme_font_size_override("font_size", 10)
		column.add_child(contested_label)

	column.add_child(
		_gate_label(
			String(human.lord).to_upper() if human != null else "YOU",
			"YOUR GATE ↑"
		)
	)

	if march_drop_enabled:
		lane_panel.tooltip_text = (
			"Drop a Lord or Castle Guard here to launch it into the %s lane."
			% lane_name
			if lane_accepts_drop
			else "Reactive March is restricted to the %s lane."
			% forced_march_lane
		)
		if lane_accepts_drop:
			lane_panel.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP

	_configure_lane_drop_recursive(
		lane_panel,
		lane_name
	)

	return lane_panel


func _configure_lane_drop_recursive(
	node: Node,
	lane_name: String
) -> void:
	if node is Control:
		var control := node as Control
		control.set_drag_forwarding(
			Callable(),
			_can_drop_march_data.bind(
				lane_name
			),
			_drop_march_data.bind(
				lane_name
			)
		)

	for child in node.get_children():
		_configure_lane_drop_recursive(
			child,
			lane_name
		)


func _can_drop_march_data(
	_at_position: Vector2,
	data,
	lane_name: String
) -> bool:
	if (
		not march_drop_enabled
		or typeof(data) != TYPE_DICTIONARY
		or String(data.get("ui2_type", "")) != "march_guard"
		or String(data.get("source_zone", "")) not in ["Lord", "Castle"]
		or String(data.get("card", "")).is_empty()
	):
		return false

	if (
		not forced_march_lane.is_empty()
		and forced_march_lane != lane_name
	):
		return false

	return lane_name in LANES


func _drop_march_data(
	at_position: Vector2,
	data,
	lane_name: String
) -> void:
	if not _can_drop_march_data(
		at_position,
		data,
		lane_name
	):
		return

	march_guard_dropped.emit(
		String(data.get("source_zone", "")),
		String(data.get("card", "")),
		lane_name
	)


func _side_header(
	bot,
	human
) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(
		"separation",
		5
	)

	var enemy_label := Label.new()
	enemy_label.text = (
		String(bot.lord).to_upper()
		if bot != null
		else "ENEMY"
	)
	enemy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.add_theme_font_size_override(
		"font_size",
		10
	)
	enemy_label.add_theme_color_override(
		"font_color",
		Color(0.82, 0.36, 0.38, 1.0)
	)
	row.add_child(enemy_label)

	var step_label := Label.new()
	step_label.text = "STEP"
	step_label.custom_minimum_size.x = 28
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_label.add_theme_font_size_override(
		"font_size",
		9
	)
	row.add_child(step_label)

	var human_label := Label.new()
	human_label.text = (
		String(human.lord).to_upper()
		if human != null
		else "YOU"
	)
	human_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	human_label.add_theme_font_size_override(
		"font_size",
		10
	)
	human_label.add_theme_color_override(
		"font_color",
		Color(0.34, 0.58, 0.88, 1.0)
	)
	row.add_child(human_label)

	return row


func _build_step(
	visual_index: int,
	bot_marcher,
	human_marcher
) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 70
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.075, 0.075, 0.084, 0.80)
	row_style.border_color = Color(0.15, 0.16, 0.18, 1.0)
	row_style.set_border_width_all(1)
	row.add_theme_stylebox_override("panel", row_style)

	var row_box := HBoxContainer.new()
	row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row_box.add_theme_constant_override("separation", 5)
	row.add_child(row_box)

	var bot_here: bool = (
		bot_marcher != null
		and int(bot_marcher.get("pos", 0)) == visual_index
	)

	var human_visual_pos: int = -1
	if human_marcher != null:
		human_visual_pos = (
			STEP_COUNT
			- 1
			- int(human_marcher.get("pos", 0))
		)

	var human_here: bool = (
		human_marcher != null
		and human_visual_pos == visual_index
	)

	row_box.add_child(
		_marcher_slot(
			bot_marcher if bot_here else null,
			true
		)
	)

	var step_label := Label.new()
	step_label.text = str(STEP_COUNT - visual_index)
	step_label.custom_minimum_size.x = 18
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_label.add_theme_font_size_override("font_size", 11)
	row_box.add_child(step_label)

	row_box.add_child(
		_marcher_slot(
			human_marcher if human_here else null,
			false
		)
	)

	return row


func _gate_label(
	owner_name: String,
	direction_text: String
) -> Label:
	var label := Label.new()
	label.text = "%s\n%s" % [
		owner_name,
		direction_text,
	]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	return label


func _marcher_slot(
	marcher,
	enemy_side: bool
) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(44, 54)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	if marcher == null:
		style.bg_color = Color(0.04, 0.04, 0.045, 0.45)
		style.border_color = Color(0.18, 0.19, 0.21, 1.0)
		slot.add_theme_stylebox_override("panel", style)
		return slot

	var card = marcher.get("card", null)
	var suit_name: String = (
		String(card.suit)
		if card != null
		else "?"
	)
	var printed_value: int = (
		int(card.value)
		if card != null
		else int(marcher.get("value", 0))
	)
	var accent: Color = SubjectSuitStyleData.accent(suit_name)

	style.bg_color = (
		Color(0.12, 0.06, 0.065, 1.0)
		if enemy_side
		else Color(0.055, 0.075, 0.11, 1.0)
	)
	style.border_color = accent
	style.set_border_width_all(3)
	slot.add_theme_stylebox_override("panel", style)

	var card_art: Texture2D = (
		SubjectCardArtCatalogData.texture_for(
			suit_name,
			printed_value,
			false
		)
	)

	if card_art != null:
		var art := TextureRect.new()
		art.anchor_right = 1.0
		art.anchor_bottom = 1.0
		art.offset_left = 3.0
		art.offset_top = 3.0
		art.offset_right = -3.0
		art.offset_bottom = -3.0
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.texture = card_art
		slot.add_child(art)

		var preview = SubjectCardHoldPreviewData.new()
		slot.add_child(preview)
		preview.configure(slot, card_art)
	else:
		var label := Label.new()
		label.text = "%s\\n%d" % [
			suit_name.left(1).to_upper(),
			int(marcher.get("value", 0)),
		]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", accent)
		slot.add_child(label)

	slot.tooltip_text = (
		"%s marcher · force %d · progress %d"
		% [
			suit_name,
			int(marcher.get("value", 0)),
			int(marcher.get("pos", 0)),
		]
	)

	return slot

func _marcher_in_lane(
	player,
	lane_name: String
):
	if player == null:
		return null

	for marcher in player.marchers:
		if String(marcher.get("lane", "")) == lane_name:
			return marcher

	return null
