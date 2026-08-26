# UI2_KRONI_HUNGER_RESTORED_V4
# UI2_KRONI_HUNGER_LAZY_V2
# UI2_KRONI_HUNGER_SIMPLE_LABEL_V1
# UI2_ZERO_CARD_WARD_KRONI_HUNGER_V3
# UI2_LORD_BACK_RULES_TOGGLE_SCROLL_V1
# UI2_LORD_BACK_POWER_SCRIM_V1
# UI2_LORD_BACK_POWER_TEXT_V1
# UI2_CARD_INTERACTION_STAGING_V2
# UI2_LORD_CARD_ART_V1
# UI2_LORD_CARD_PORTRAIT_V1
# UI2_LORD_CARD_STAT_SLOTS_V1
class_name UI2LordCard
extends PanelContainer


const LordArtCatalogData = preload(
	"res://Prototype/UI2/LordArtCatalog.gd"
)

const GameSetupData = preload(
	"res://Scripts/Sim/GameSetup.gd"
)

const LordPowerTextData = preload(
	"res://Prototype/UI2/LordPowerText.gd"
)


const STAT_TOP: float = 0.105
const STAT_BOTTOM: float = 0.215
const SUMMON_LEFT: float = 0.175
const SUMMON_RIGHT: float = 0.345
const DEFENSE_LEFT: float = 0.415
const DEFENSE_RIGHT: float = 0.585
const FRACTURE_LEFT: float = 0.655
const FRACTURE_RIGHT: float = 0.825


var art_rect: TextureRect = null
var fallback_label: Label = null
var stat_overlay: Control = null
var summon_value_label: Label = null
var defense_value_label: Label = null
var fracture_value_label: Label = null

var hold_timer: Timer = null
var preview_hold_timer: Timer = null
var preview_popup: PopupPanel = null
var preview_input_surface: Control = null
var preview_art: TextureRect = null
var preview_overlay: Control = null
var preview_summon_label: Label = null
var preview_defense_label: Label = null
var preview_fracture_label: Label = null

var back_power_panel: PanelContainer = null
var back_power_text: RichTextLabel = null
var preview_power_panel: PanelContainer = null
var preview_power_text: RichTextLabel = null
var back_rules_button: Button = null
var preview_rules_button: Button = null
var kroni_hunger_track: Label = null
var preview_kroni_hunger_track: Label = null
var _rules_visible: bool = true

var _left_down: bool = false
var _hold_triggered: bool = false
var _preview_left_down: bool = false
var _preview_hold_triggered: bool = false

var _lord_name: String = ""
var _showing_back: bool = false
var _front_texture: Texture2D = null
var _back_texture: Texture2D = null
var _prominent: bool = false
var _alive: bool = true
var _defense: int = 0
var _summon_value: int = 0
var _fracture_value: int = 0
var _kroni_hunger: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true

	art_rect = TextureRect.new()
	art_rect.name = "LordArt"
	art_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art_rect)

	fallback_label = Label.new()
	fallback_label.name = "Fallback"
	fallback_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fallback_label.add_theme_font_size_override(
		"font_size",
		16
	)
	add_child(fallback_label)

	# PanelContainer stretches direct Control children. A plain overlay Control
	# gives the stat labels their own coordinate space, so their anchors actually
	# land in the printed Summon / Defense / Fracture shapes.
	stat_overlay = Control.new()
	stat_overlay.name = "StatOverlay"
	stat_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	stat_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stat_overlay)

	summon_value_label = _make_stat_label(
		"SummonValue",
		SUMMON_LEFT,
		SUMMON_RIGHT
	)
	defense_value_label = _make_stat_label(
		"DefenseValue",
		DEFENSE_LEFT,
		DEFENSE_RIGHT
	)
	fracture_value_label = _make_stat_label(
		"FractureValue",
		FRACTURE_LEFT,
		FRACTURE_RIGHT
	)

	hold_timer = Timer.new()
	hold_timer.one_shot = true
	hold_timer.wait_time = 0.28
	hold_timer.timeout.connect(
		_on_hold_timeout
	)
	add_child(hold_timer)

	preview_hold_timer = Timer.new()
	preview_hold_timer.one_shot = true
	preview_hold_timer.wait_time = 0.28
	preview_hold_timer.timeout.connect(
		_on_preview_hold_timeout
	)
	add_child(preview_hold_timer)

	_build_preview_popup()
	_build_back_power_text()

	gui_input.connect(
		_on_gui_input
	)

	_apply_size()


func bind_player(
	player,
	prominent: bool = false
) -> void:
	if player == null:
		return

	_prominent = prominent
	_lord_name = String(player.lord)
	_alive = bool(player.alive)
	_defense = int(player.derived_lord_def)

	var lord_content: Dictionary = GameSetupData.LORD_CONTENT.get(
		_lord_name,
		{}
	)

	_summon_value = _printed_int(
		lord_content,
		["summon_cost", "summon", "cost", "s"],
		0
	)
	_fracture_value = _printed_int(
		lord_content,
		["fracture", "return_threat", "r"],
		0
	)

	_front_texture = LordArtCatalogData.texture_for(
		_lord_name,
		false
	)
	_back_texture = LordArtCatalogData.texture_for(
		_lord_name,
		true
	)

	if String(get_meta("bound_lord", "")) != _lord_name:
		_showing_back = false
		set_meta(
			"bound_lord",
			_lord_name
		)

	_apply_size()
	_kroni_hunger = (
		int(player.kroni_hunger)
		if _lord_name == "Kroni"
		else 0
	)
	if _lord_name == "Kroni":
		_build_kroni_hunger_track()

	_refresh_art()


func _apply_size() -> void:
	# UI2_LORD_CARD_INTERACTION_V1
# UI2_LORD_CARD_PINNED_PREVIEW_V1
	# Both Lords use the full readable card footprint. Player ownership is already
	# obvious from the board zone; shrinking the enemy card only hurts legibility.
	custom_minimum_size = Vector2(188, 282)

	var value_font_size: int = 17
	for label in [
		summon_value_label,
		defense_value_label,
		fracture_value_label,
	]:
		if label != null:
			label.add_theme_font_size_override(
				"font_size",
				value_font_size
			)


func _make_stat_label(
	node_name: String,
	left_anchor: float,
	right_anchor: float
) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.anchor_left = left_anchor
	label.anchor_right = right_anchor
	label.anchor_top = STAT_TOP
	label.anchor_bottom = STAT_BOTTOM
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = 0.0
	label.offset_bottom = 0.0

	label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.84, 0.68, 1.0)
	)
	label.add_theme_color_override(
		"font_outline_color",
		Color(0.015, 0.012, 0.010, 1.0)
	)
	label.add_theme_constant_override(
		"outline_size",
		3
	)

	if stat_overlay != null:
		stat_overlay.add_child(label)
	else:
		add_child(label)
	return label


func _build_preview_popup() -> void:
	preview_popup = PopupPanel.new()
	preview_popup.name = "LordCardPreview"
	add_child(preview_popup)

	preview_input_surface = Control.new()
	preview_input_surface.name = "PreviewInputSurface"
	preview_input_surface.custom_minimum_size = Vector2(420, 630)
	preview_input_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_input_surface.gui_input.connect(
		_on_preview_gui_input
	)
	preview_popup.add_child(preview_input_surface)

	preview_art = TextureRect.new()
	preview_art.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_input_surface.add_child(preview_art)

	preview_overlay = Control.new()
	preview_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	preview_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_input_surface.add_child(preview_overlay)

	preview_summon_label = _make_preview_stat_label(
		"PreviewSummon",
		SUMMON_LEFT,
		SUMMON_RIGHT
	)
	preview_defense_label = _make_preview_stat_label(
		"PreviewDefense",
		DEFENSE_LEFT,
		DEFENSE_RIGHT
	)
	preview_fracture_label = _make_preview_stat_label(
		"PreviewFracture",
		FRACTURE_LEFT,
		FRACTURE_RIGHT
	)


func _make_preview_stat_label(
	node_name: String,
	left_anchor: float,
	right_anchor: float
) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = left_anchor
	label.anchor_right = right_anchor
	label.anchor_top = STAT_TOP
	label.anchor_bottom = STAT_BOTTOM
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = 0.0
	label.offset_bottom = 0.0
	label.add_theme_font_size_override(
		"font_size",
		34
	)
	label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.84, 0.68, 1.0)
	)
	label.add_theme_color_override(
		"font_outline_color",
		Color(0.015, 0.012, 0.010, 1.0)
	)
	label.add_theme_constant_override(
		"outline_size",
		5
	)
	preview_overlay.add_child(label)
	return label


func _refresh_preview() -> void:
	if preview_art == null:
		return

	var chosen: Texture2D = (
		_back_texture
		if _showing_back
		else _front_texture
	)
	preview_art.texture = chosen

	var show_front_stats: bool = (
		not _showing_back
		and chosen != null
	)

	if preview_summon_label != null:
		preview_summon_label.visible = show_front_stats
		preview_summon_label.text = str(_summon_value)

	if preview_defense_label != null:
		preview_defense_label.visible = show_front_stats
		preview_defense_label.text = (
			str(_defense)
			if _alive
			else "—"
		)

	if preview_fracture_label != null:
		preview_fracture_label.visible = show_front_stats
		preview_fracture_label.text = str(_fracture_value)

	_refresh_back_power_text()
	_refresh_kroni_hunger_track()


func _show_preview() -> void:
	if preview_popup == null:
		return
	_refresh_preview()
	preview_popup.popup_centered(
		Vector2i(420, 630)
	)


func _hide_preview() -> void:
	if preview_popup != null:
		preview_popup.hide()


func _on_hold_timeout() -> void:
	if not _left_down:
		return
	_hold_triggered = true
	_show_preview()


func _build_kroni_hunger_track() -> void:
	if _lord_name != "Kroni":
		return

	if stat_overlay != null and kroni_hunger_track == null:
		kroni_hunger_track = _make_kroni_hunger_track(
			"KroniHungerTrack",
			false
		)
		stat_overlay.add_child(
			kroni_hunger_track
		)

	if preview_overlay != null and preview_kroni_hunger_track == null:
		preview_kroni_hunger_track = _make_kroni_hunger_track(
			"PreviewKroniHungerTrack",
			true
		)
		preview_overlay.add_child(
			preview_kroni_hunger_track
		)

	_refresh_kroni_hunger_track()


func _make_kroni_hunger_track(
	node_name: String,
	enlarged: bool
) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true

	label.anchor_left = 0.07 if enlarged else 0.055
	label.anchor_right = 0.93 if enlarged else 0.945
	label.anchor_top = 0.835 if enlarged else 0.825
	label.anchor_bottom = 0.900 if enlarged else 0.905
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = 0.0
	label.offset_bottom = 0.0

	label.add_theme_font_size_override(
		"font_size",
		17 if enlarged else 8
	)
	label.add_theme_color_override(
		"font_color",
		Color(
			0.97,
			0.88,
			0.67,
			1.0
		)
	)
	label.add_theme_color_override(
		"font_outline_color",
		Color(
			0.0,
			0.0,
			0.0,
			0.98
		)
	)
	label.add_theme_constant_override(
		"outline_size",
		3 if enlarged else 2
	)

	return label


func _kroni_hunger_text() -> String:
	var tier: int = mini(
		maxi(
			_kroni_hunger,
			0
		),
		3
	)

	var labels: Array[String] = [
		"0",
		"1",
		"2",
		"3+",
	]

	for index: int in range(
		labels.size()
	):
		if index == tier:
			labels[index] = (
				"[%s]"
				% labels[index]
			)

	return (
		"HUNGER   %s"
		% "   ".join(labels)
	)


func _refresh_kroni_hunger_track() -> void:
	var visible_now: bool = (
		_lord_name == "Kroni"
		and not _showing_back
		and _front_texture != null
	)

	var hunger_text: String = (
		_kroni_hunger_text()
		if visible_now
		else ""
	)

	if kroni_hunger_track != null:
		kroni_hunger_track.visible = visible_now
		kroni_hunger_track.text = hunger_text

	if preview_kroni_hunger_track != null:
		preview_kroni_hunger_track.visible = visible_now
		preview_kroni_hunger_track.text = hunger_text


func _build_back_power_text() -> void:
	var power_font: Font = LordPowerTextData.font()

	if stat_overlay != null:
		back_power_panel = _make_power_panel(
			"BackPowerPanel",
			false
		)
		stat_overlay.add_child(
			back_power_panel
		)

		back_power_text = _make_power_text(
			"BackPowerText",
			power_font,
			false
		)
		back_power_panel.add_child(
			back_power_text
		)

		back_rules_button = _make_rules_button(
			"BackRulesButton",
			false
		)
		stat_overlay.add_child(
			back_rules_button
		)

	if preview_overlay != null:
		preview_power_panel = _make_power_panel(
			"PreviewPowerPanel",
			true
		)
		preview_overlay.add_child(
			preview_power_panel
		)

		preview_power_text = _make_power_text(
			"PreviewPowerText",
			power_font,
			true
		)
		preview_power_panel.add_child(
			preview_power_text
		)

		preview_rules_button = _make_rules_button(
			"PreviewRulesButton",
			true
		)
		preview_overlay.add_child(
			preview_rules_button
		)

	_refresh_back_power_text()

func _make_power_panel(
	node_name: String,
	enlarged: bool
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enlarged
		else Control.MOUSE_FILTER_IGNORE
	)
	panel.clip_contents = true

	panel.anchor_left = (
		0.085
		if enlarged
		else 0.075
	)
	panel.anchor_right = (
		0.915
		if enlarged
		else 0.925
	)
	panel.anchor_top = (
		0.105
		if enlarged
		else 0.095
	)
	panel.anchor_bottom = (
		0.885
		if enlarged
		else 0.895
	)

	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0

	# No visible bounding box. The card-back art should remain the thing
	# you're looking at; this is only the faintest readability wash.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		0.008,
		0.006,
		0.006,
		0.10 if enlarged else 0.14
	)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	var margin: float = (
		10.0
		if enlarged
		else 3.0
	)

	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin

	panel.add_theme_stylebox_override(
		"panel",
		style
	)

	return panel

func _make_power_text(
	node_name: String,
	power_font: Font,
	enlarged: bool
) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.name = node_name
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = enlarged
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enlarged
		else Control.MOUSE_FILTER_IGNORE
	)

	var body_size: int = (
		18
		if enlarged
		else 7
	)
	var bold_size: int = (
		19
		if enlarged
		else 8
	)

	if power_font != null:
		for theme_name in [
			"normal_font",
			"bold_font",
			"italics_font",
			"bold_italics_font",
			"mono_font",
		]:
			label.add_theme_font_override(
				theme_name,
				power_font
			)

	label.add_theme_font_size_override(
		"normal_font_size",
		body_size
	)
	label.add_theme_font_size_override(
		"bold_font_size",
		bold_size
	)
	label.add_theme_font_size_override(
		"italics_font_size",
		body_size
	)
	label.add_theme_font_size_override(
		"bold_italics_font_size",
		bold_size
	)
	label.add_theme_font_size_override(
		"mono_font_size",
		body_size
	)

	label.add_theme_color_override(
		"default_color",
		Color(
			0.97,
			0.91,
			0.79,
			1.0
		)
	)
	label.add_theme_color_override(
		"font_outline_color",
		Color(
			0.0,
			0.0,
			0.0,
			0.98
		)
	)
	label.add_theme_constant_override(
		"outline_size",
		3 if enlarged else 2
	)
	label.add_theme_constant_override(
		"line_separation",
		2 if enlarged else 0
	)

	return label

func _make_rules_button(
	node_name: String,
	enlarged: bool
) -> Button:
	var button := Button.new()
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.text = "HIDE RULES"

	button.anchor_left = (
		0.68
		if enlarged
		else 0.58
	)
	button.anchor_right = (
		0.92
		if enlarged
		else 0.93
	)
	button.anchor_top = (
		0.905
		if enlarged
		else 0.905
	)
	button.anchor_bottom = (
		0.955
		if enlarged
		else 0.965
	)

	button.offset_left = 0.0
	button.offset_right = 0.0
	button.offset_top = 0.0
	button.offset_bottom = 0.0

	button.add_theme_font_size_override(
		"font_size",
		11 if enlarged else 6
	)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(
		0.02,
		0.015,
		0.012,
		0.66
	)
	normal.border_color = Color(
		0.66,
		0.54,
		0.36,
		0.72
	)
	normal.set_border_width_all(
		1
	)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4

	var hover := normal.duplicate()
	hover.bg_color = Color(
		0.10,
		0.075,
		0.045,
		0.82
	)

	button.add_theme_stylebox_override(
		"normal",
		normal
	)
	button.add_theme_stylebox_override(
		"hover",
		hover
	)
	button.add_theme_stylebox_override(
		"pressed",
		hover
	)
	button.add_theme_color_override(
		"font_color",
		Color(
			0.96,
			0.89,
			0.75,
			1.0
		)
	)

	button.pressed.connect(
		_on_rules_button_pressed
	)

	return button


func _on_rules_button_pressed() -> void:
	_rules_visible = not _rules_visible
	_refresh_back_power_text()


func _refresh_back_power_text() -> void:
	var on_back: bool = (
		_showing_back
		and _back_texture != null
	)
	var show_rules: bool = (
		on_back
		and _rules_visible
	)

	var bbcode: String = (
		LordPowerTextData.bbcode_for(
			_lord_name
		)
		if show_rules
		else ""
	)

	if back_power_panel != null:
		back_power_panel.visible = show_rules

	if back_power_text != null:
		back_power_text.text = bbcode

	if preview_power_panel != null:
		preview_power_panel.visible = show_rules

	if preview_power_text != null:
		preview_power_text.text = bbcode

	for button in [
		back_rules_button,
		preview_rules_button,
	]:
		if button == null:
			continue

		button.visible = on_back
		button.text = (
			"HIDE RULES"
			if _rules_visible
			else "SHOW RULES"
		)

func _printed_int(
	data: Dictionary,
	keys: Array,
	fallback: int
) -> int:
	for raw_key in keys:
		var key: String = String(raw_key)
		if data.has(key):
			return int(data.get(key, fallback))
	return fallback


func _refresh_art() -> void:
	if art_rect == null:
		return

	var chosen: Texture2D = (
		_back_texture
		if _showing_back
		else _front_texture
	)
	art_rect.texture = chosen

	if fallback_label != null:
		fallback_label.visible = chosen == null
		fallback_label.text = (
			"%s\n%s ART MISSING"
			% [
				_lord_name.to_upper(),
				"BACK" if _showing_back else "FRONT",
			]
		)

	var show_front_stats: bool = (
		not _showing_back
		and chosen != null
	)

	if summon_value_label != null:
		summon_value_label.visible = show_front_stats
		summon_value_label.text = str(_summon_value)

	if defense_value_label != null:
		defense_value_label.visible = show_front_stats
		defense_value_label.text = (
			str(_defense)
			if _alive
			else "—"
		)

	if fracture_value_label != null:
		fracture_value_label.visible = show_front_stats
		fracture_value_label.text = str(_fracture_value)

	if preview_popup != null and preview_popup.visible:
		_refresh_preview()

	_refresh_back_power_text()
	_refresh_kroni_hunger_track()

	tooltip_text = (
		"%s · %s · Summon %d · DEF %s · Fracture %d · click to inspect · enlarged click flips"
		% [
			_lord_name,
			"BACK" if _showing_back else "FRONT",
			_summon_value,
			str(_defense) if _alive else "—",
			_fracture_value,
		]
	)


func _on_preview_gui_input(event: InputEvent) -> void:
	if not (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		return

	if event.pressed:
		_preview_left_down = true
		_preview_hold_triggered = false
		if preview_hold_timer != null:
			preview_hold_timer.start()
		if preview_input_surface != null:
			preview_input_surface.accept_event()
		return

	# A release without a preview-side press can happen when the popup appears
	# while the original board-card hold is still physically down. Ignore it.
	if not _preview_left_down:
		return

	_preview_left_down = false
	if preview_hold_timer != null:
		preview_hold_timer.stop()

	if _preview_hold_triggered:
		_preview_hold_triggered = false
	else:
		# Quick click flips in place and deliberately leaves the preview open.
		_showing_back = not _showing_back
		_refresh_art()
		_refresh_preview()

	if preview_input_surface != null:
		preview_input_surface.accept_event()


func _on_preview_hold_timeout() -> void:
	if not _preview_left_down:
		return

	_preview_hold_triggered = true
	_preview_left_down = false
	_hide_preview()


func _on_gui_input(event: InputEvent) -> void:
	if not (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		return

	if event.pressed:
		_left_down = true
		_hold_triggered = false
		if hold_timer != null:
			hold_timer.start()
		accept_event()
		return

	_left_down = false
	if hold_timer != null:
		hold_timer.stop()

	if _hold_triggered:
		# Hold already opened this same pinned inspection view.
		_hold_triggered = false
	else:
		# Board click means inspect. Front/back flip controls now live in the
		# enlarged card where the art and stats are actually legible.
		_show_preview()

	accept_event()
