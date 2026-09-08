# UI2_CASTLE_CARD_ART_V1
class_name UI2CastleSpine
extends PanelContainer


const CastleArtCatalogData = preload(
	"res://Prototype/UI2/CastleArtCatalog.gd"
)

const CastlePowerTextData = preload(
	"res://Prototype/UI2/CastlePowerText.gd"
)

# UI2_CASTLE_CONSTRUCTION_REVEAL_AND_DEFILE_NAME_V1
const CastleConstructionShader = preload(
	"res://Prototype/UI2/Shaders/CastleConstructionProgress.gdshader"
)


# CASTLE_INTEGRITY_150_PERCENT_V1
const MAX_INTEGRITY: int = 21
const OPERATIONAL_FLOOR: int = 7

const INTEGRITY_LEFT: float = 0.755
const INTEGRITY_RIGHT: float = 0.965
const INTEGRITY_TOP: float = 0.045
const INTEGRITY_BOTTOM: float = 0.185


var art_rect: TextureRect = null
var overlay_root: Control = null
var integrity_label: Label = null
var power_scrim: ColorRect = null
var power_name_label: Label = null
var compact_copy_label: Label = null
var state_label: Label = null
var fallback_label: Label = null

var hold_timer: Timer = null
# UI2_CASTLE_PREVIEW_INTERACTION_GUTTER_V2
var preview_hold_timer: Timer = null
var preview_popup: PopupPanel = null
var preview_surface: Control = null
var preview_art: TextureRect = null
var preview_integrity_label: Label = null
var preview_rules_scrim: ColorRect = null
var preview_rules_text: RichTextLabel = null
var preview_hold_catcher: Control = null
var preview_hold_button: Button = null
var preview_build_progress_label: Label = null
var preview_text_toggle_button: Button = null

var construction_material: ShaderMaterial = null
var preview_construction_material: ShaderMaterial = null

var castle_name: String = ""

var _integrity_text: String = "—"
var _state_text: String = "UNBUILT"
var _state_detail: String = "Not built."
var _art_modulate: Color = Color.WHITE
var _construction_visual_active: bool = false
var _construction_ratio: float = 1.0
var _left_down: bool = false
var _hold_triggered: bool = false
var _preview_left_down: bool = false
var _preview_hold_triggered: bool = false
var _preview_text_hidden: bool = false
# UI2_CASTLE_PREVIEW_POLLED_HOLD_V3
var _preview_poll_armed: bool = false
var _preview_poll_elapsed: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(
		120,
		180
	)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true

	art_rect = TextureRect.new()
	art_rect.name = "CastleArt"
	art_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art_rect)

	construction_material = _make_construction_material()

	fallback_label = Label.new()
	fallback_label.name = "CastleFallback"
	fallback_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fallback_label.add_theme_font_size_override(
		"font_size",
		13
	)
	add_child(fallback_label)

	# PanelContainer stretches direct Control children. Give all positioned
	# overlays their own full-card coordinate space so the printed Integrity
	# slot and rules scrim stay where the art expects them.
	overlay_root = Control.new()
	overlay_root.name = "CastleOverlay"
	overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_root)

	integrity_label = _make_integrity_label(
		"IntegrityValue",
		false
	)
	overlay_root.add_child(integrity_label)

	power_scrim = ColorRect.new()
	power_scrim.name = "PowerScrim"
	power_scrim.anchor_left = 0.045
	power_scrim.anchor_right = 0.955
	power_scrim.anchor_top = 0.625
	power_scrim.anchor_bottom = 0.985
	power_scrim.offset_left = 0.0
	power_scrim.offset_right = 0.0
	power_scrim.offset_top = 0.0
	power_scrim.offset_bottom = 0.0
	power_scrim.color = Color(0.012, 0.010, 0.009, 0.79)
	power_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(power_scrim)

	power_name_label = Label.new()
	power_name_label.name = "PowerName"
	power_name_label.anchor_left = 0.075
	power_name_label.anchor_right = 0.925
	power_name_label.anchor_top = 0.640
	power_name_label.anchor_bottom = 0.715
	power_name_label.offset_left = 0.0
	power_name_label.offset_right = 0.0
	power_name_label.offset_top = 0.0
	power_name_label.offset_bottom = 0.0
	power_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	power_name_label.clip_text = true
	power_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_name_label.add_theme_font_size_override("font_size", 8)
	power_name_label.add_theme_color_override(
		"font_color",
		Color(0.94, 0.84, 0.63, 1.0)
	)
	overlay_root.add_child(power_name_label)

	compact_copy_label = Label.new()
	compact_copy_label.name = "CompactPowerCopy"
	compact_copy_label.anchor_left = 0.075
	compact_copy_label.anchor_right = 0.925
	compact_copy_label.anchor_top = 0.710
	compact_copy_label.anchor_bottom = 0.915
	compact_copy_label.offset_left = 0.0
	compact_copy_label.offset_right = 0.0
	compact_copy_label.offset_top = 0.0
	compact_copy_label.offset_bottom = 0.0
	compact_copy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compact_copy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	compact_copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	compact_copy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compact_copy_label.add_theme_font_size_override("font_size", 6)
	compact_copy_label.add_theme_color_override(
		"font_color",
		Color(0.88, 0.87, 0.82, 1.0)
	)
	overlay_root.add_child(compact_copy_label)

	state_label = Label.new()
	state_label.name = "CastleState"
	state_label.anchor_left = 0.075
	state_label.anchor_right = 0.925
	state_label.anchor_top = 0.915
	state_label.anchor_bottom = 0.985
	state_label.offset_left = 0.0
	state_label.offset_right = 0.0
	state_label.offset_top = 0.0
	state_label.offset_bottom = 0.0
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.clip_text = true
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_label.add_theme_font_size_override("font_size", 7)
	state_label.add_theme_color_override(
		"font_color",
		Color(0.76, 0.79, 0.84, 1.0)
	)
	overlay_root.add_child(state_label)

	hold_timer = Timer.new()
	hold_timer.one_shot = true
	hold_timer.wait_time = 0.28
	hold_timer.timeout.connect(_on_hold_timeout)
	add_child(hold_timer)

	preview_hold_timer = Timer.new()
	preview_hold_timer.one_shot = true
	preview_hold_timer.wait_time = 0.28
	preview_hold_timer.timeout.connect(_on_preview_hold_timeout)
	add_child(preview_hold_timer)

	_build_preview_popup()
	gui_input.connect(_on_gui_input)


func bind_castle(
	player,
	p_castle_name: String
) -> void:
	castle_name = p_castle_name

	if player == null:
		return

	var texture: Texture2D = CastleArtCatalogData.texture_for(castle_name)

	if art_rect != null:
		art_rect.texture = texture

	if fallback_label != null:
		fallback_label.visible = texture == null
		fallback_label.text = castle_name if texture == null else ""

	var standing: bool = player.castles.has(castle_name)
	var ruined: bool = player.ruined_castles.has(castle_name)
	var profaned: bool = player.profaned_castles.has(castle_name)
	var progress: int = int(
		player.castle_construction_progress.get(castle_name, 0)
	)
	var integrity: int = int(
		player.castle_integrity.get(
			castle_name,
			MAX_INTEGRITY if standing else 0
		)
	)

	var border := Color(0.25, 0.22, 0.16, 0.95)
	_art_modulate = Color.WHITE

	if standing:
		_integrity_text = str(integrity)

		if integrity >= OPERATIONAL_FLOOR:
			_state_text = "OPERATIONAL"
			_state_detail = "Operational — printed Castle power active."
			border = Color(0.50, 0.43, 0.24, 0.95)
		else:
			_state_text = (
				"DEFUNCT · WALL ACTIVE"
				if castle_name == "Bastion"
				else "DEFUNCT"
			)
			_state_detail = (
				"Defunct — Bastion still screens Sieges while it stands."
				if castle_name == "Bastion"
				else "Defunct — printed Castle power is inactive until repaired to 7+ Integrity."
			)
			_art_modulate = Color(0.78, 0.70, 0.52, 1.0)
			border = Color(0.64, 0.47, 0.18, 1.0)

	elif profaned:
		_integrity_text = "—"
		_state_text = "PROFANED"
		_state_detail = "Profaned Ruin."
		_art_modulate = Color(0.52, 0.38, 0.62, 1.0)
		border = Color(0.55, 0.30, 0.62, 1.0)

	elif ruined:
		_integrity_text = "0"
		_state_text = "RUINED"
		_state_detail = "Ruined — permanently lost and cannot be rebuilt."
		_art_modulate = Color(0.48, 0.26, 0.26, 1.0)
		border = Color(0.72, 0.18, 0.18, 1.0)

	elif progress > 0:
		_integrity_text = "%d/%d" % [progress, MAX_INTEGRITY]
		_state_text = "BUILDING"
		_state_detail = "Construction %d/%d." % [progress, MAX_INTEGRITY]
		# UI2_CASTLE_BUILD_PROGRESS_HOLDBUTTON_V2
		_art_modulate = Color.WHITE
		border = Color(0.62, 0.48, 0.16, 1.0)

	else:
		_integrity_text = "—"
		_state_text = "UNBUILT"
		_state_detail = "Not built."
		_art_modulate = Color(0.40, 0.40, 0.42, 1.0)
		border = Color(0.22, 0.23, 0.27, 1.0)

	_construction_visual_active = (
		progress > 0
		and not standing
		and not ruined
		and not profaned
	)
	_construction_ratio = clampf(
		float(progress) / float(MAX_INTEGRITY),
		0.0,
		1.0
	)
	_apply_construction_visual()

	if art_rect != null:
		art_rect.modulate = _art_modulate
	if integrity_label != null:
		integrity_label.text = _integrity_text
	if power_name_label != null:
		power_name_label.text = CastlePowerTextData.power_name(castle_name)
	if compact_copy_label != null:
		compact_copy_label.text = CastlePowerTextData.compact_text(castle_name)
	if state_label != null:
		state_label.text = _state_text

	_apply_style(border)

	tooltip_text = (
		"%s — %s\n%s — %s\nHold to inspect the Castle card."
		% [
			castle_name,
			_state_detail,
			CastlePowerTextData.power_name(castle_name),
			CastlePowerTextData.full_text(castle_name),
		]
	)

	_refresh_preview()


func _make_construction_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CastleConstructionShader
	material.set_shader_parameter(
		"build_ratio",
		1.0
	)
	return material


func _apply_construction_visual() -> void:
	if construction_material != null:
		construction_material.set_shader_parameter(
			"build_ratio",
			_construction_ratio
		)

	if preview_construction_material != null:
		preview_construction_material.set_shader_parameter(
			"build_ratio",
			_construction_ratio
		)

	if art_rect != null:
		art_rect.material = (
			construction_material
			if _construction_visual_active
			else null
		)

	if preview_art != null:
		preview_art.material = (
			preview_construction_material
			if _construction_visual_active
			else null
		)


func _make_integrity_label(
	node_name: String,
	enlarged: bool
) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = INTEGRITY_LEFT
	label.anchor_right = INTEGRITY_RIGHT
	label.anchor_top = INTEGRITY_TOP
	label.anchor_bottom = INTEGRITY_BOTTOM
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = 0.0
	label.offset_bottom = 0.0
	label.add_theme_font_size_override("font_size", 30 if enlarged else 12)
	label.add_theme_color_override(
		"font_color",
		Color(0.96, 0.88, 0.68, 1.0)
	)
	label.add_theme_color_override(
		"font_outline_color",
		Color(0.01, 0.008, 0.006, 1.0)
	)
	label.add_theme_constant_override("outline_size", 5 if enlarged else 3)
	return label


func _build_preview_popup() -> void:
	preview_popup = PopupPanel.new()
	preview_popup.name = "CastleCardPreview"
	add_child(preview_popup)

	preview_surface = Control.new()
	preview_surface.name = "PreviewSurface"
	preview_surface.custom_minimum_size = Vector2(420, 630)
	preview_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_surface.gui_input.connect(_on_preview_gui_input)
	preview_popup.add_child(preview_surface)

	preview_art = TextureRect.new()
	preview_art.name = "PreviewArt"
	preview_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_surface.add_child(preview_art)

	preview_construction_material = _make_construction_material()

	preview_integrity_label = _make_integrity_label("PreviewIntegrity", true)
	preview_surface.add_child(preview_integrity_label)

	preview_rules_scrim = ColorRect.new()
	preview_rules_scrim.name = "PreviewRulesScrim"
	preview_rules_scrim.anchor_left = 0.055
	preview_rules_scrim.anchor_right = 0.945
	preview_rules_scrim.anchor_top = 0.465
	preview_rules_scrim.anchor_bottom = 0.970
	preview_rules_scrim.offset_left = 0.0
	preview_rules_scrim.offset_right = 0.0
	preview_rules_scrim.offset_top = 0.0
	preview_rules_scrim.offset_bottom = 0.0
	preview_rules_scrim.color = Color(0.010, 0.009, 0.008, 0.90)
	preview_rules_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_surface.add_child(preview_rules_scrim)

	preview_rules_text = RichTextLabel.new()
	preview_rules_text.name = "PreviewRulesText"
	preview_rules_text.bbcode_enabled = true
	preview_rules_text.fit_content = false
	preview_rules_text.scroll_active = false
	preview_rules_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_rules_text.anchor_left = 0.085
	preview_rules_text.anchor_right = 0.915
	preview_rules_text.anchor_top = 0.505
	preview_rules_text.anchor_bottom = 0.885
	preview_rules_text.offset_left = 0.0
	preview_rules_text.offset_right = 0.0
	preview_rules_text.offset_top = 0.0
	preview_rules_text.offset_bottom = 0.0
	preview_rules_text.add_theme_font_size_override("normal_font_size", 17)
	preview_rules_text.add_theme_font_size_override("bold_font_size", 20)
	preview_rules_text.add_theme_color_override(
		"default_color",
		Color(0.90, 0.88, 0.80, 1.0)
	)
	preview_surface.add_child(preview_rules_text)

	# UI2_CASTLE_PREVIEW_DETERMINISTIC_INPUT_V1
	# Dedicated enlarged-card gesture layer.
	preview_hold_catcher = Control.new()
	preview_hold_catcher.name = "PreviewHoldCatcher"
	preview_hold_catcher.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	# UI2_CASTLE_BUILD_FRACTION_LORD_INPUT_V1
	# Retained as an inert compatibility node; PreviewSurface now owns
	# enlarged-card input exactly as the Lord preview does.
	preview_hold_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_hold_catcher.focus_mode = Control.FOCUS_NONE
	preview_hold_catcher.z_index = 20
	preview_hold_catcher.gui_input.connect(
		_on_preview_catcher_gui_input
	)
	preview_surface.add_child(preview_hold_catcher)

	# UI2_CASTLE_BUILD_PROGRESS_HOLDBUTTON_V2
	preview_hold_button = Button.new()
	preview_hold_button.name = "PreviewHoldButton"
	preview_hold_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_hold_button.flat = true
	preview_hold_button.focus_mode = Control.FOCUS_NONE
	preview_hold_button.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_hold_button.z_index = 30
	preview_hold_button.button_down.connect(_on_preview_hold_button_down)
	preview_hold_button.button_up.connect(_on_preview_hold_button_up)
	preview_surface.add_child(preview_hold_button)

	preview_build_progress_label = Label.new()
	preview_build_progress_label.name = "PreviewBuildProgress"
	preview_build_progress_label.anchor_left = 0.075
	preview_build_progress_label.anchor_right = 0.360
	preview_build_progress_label.anchor_top = 0.895
	preview_build_progress_label.anchor_bottom = 0.950
	preview_build_progress_label.offset_left = 0.0
	preview_build_progress_label.offset_right = 0.0
	preview_build_progress_label.offset_top = 0.0
	preview_build_progress_label.offset_bottom = 0.0
	preview_build_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	preview_build_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_build_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_build_progress_label.z_index = 35
	preview_build_progress_label.add_theme_font_size_override("font_size", 12)
	preview_build_progress_label.add_theme_color_override("font_color", Color(0.94, 0.78, 0.42, 1.0))
	preview_build_progress_label.add_theme_color_override("font_outline_color", Color(0.01, 0.008, 0.006, 1.0))
	preview_build_progress_label.add_theme_constant_override("outline_size", 4)
	preview_surface.add_child(preview_build_progress_label)

	# UI2_CASTLE_TEXT_LAYOUT_TOGGLE_V1
	preview_text_toggle_button = Button.new()
	preview_text_toggle_button.name = "PreviewTextToggle"
	preview_text_toggle_button.text = "HIDE TEXT"
	preview_text_toggle_button.tooltip_text = (
		"Hide the rules overlay to inspect the Castle artwork."
	)
	preview_text_toggle_button.anchor_left = 0.700
	preview_text_toggle_button.anchor_right = 0.930
	preview_text_toggle_button.anchor_top = 0.895
	preview_text_toggle_button.anchor_bottom = 0.950
	preview_text_toggle_button.offset_left = 0.0
	preview_text_toggle_button.offset_right = 0.0
	preview_text_toggle_button.offset_top = 0.0
	preview_text_toggle_button.offset_bottom = 0.0
	preview_text_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_text_toggle_button.focus_mode = Control.FOCUS_NONE
	preview_text_toggle_button.z_index = 40
	preview_text_toggle_button.add_theme_font_size_override(
		"font_size",
		12
	)
	preview_text_toggle_button.pressed.connect(
		_on_preview_text_toggle_pressed
	)
	preview_surface.add_child(preview_text_toggle_button)
	preview_text_toggle_button.move_to_front()


func _refresh_preview() -> void:
	if preview_art == null:
		return

	preview_art.texture = CastleArtCatalogData.texture_for(castle_name)
	preview_art.modulate = _art_modulate
	_apply_construction_visual()

	if preview_integrity_label != null:
		preview_integrity_label.text = _integrity_text

	if preview_build_progress_label != null:
		preview_build_progress_label.visible = _construction_visual_active
		preview_build_progress_label.text = (
			"%d%% BUILT"
			% int(round(_construction_ratio * 100.0))
		)

	if preview_rules_text != null:
		preview_rules_text.text = (
			"[center][b]%s[/b][/center]\n%s\n\n[center][b]%s[/b] · %s[/center]"
			% [
				CastlePowerTextData.power_name(castle_name),
				CastlePowerTextData.full_text(castle_name),
				_state_text,
				_state_detail,
			]
		)

	_apply_preview_text_visibility()


func _apply_preview_text_visibility() -> void:
	var show_text: bool = not _preview_text_hidden

	if preview_rules_scrim != null:
		preview_rules_scrim.visible = show_text

	if preview_rules_text != null:
		preview_rules_text.visible = show_text

	if preview_text_toggle_button != null:
		preview_text_toggle_button.visible = true
		preview_text_toggle_button.disabled = false
		preview_text_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
		preview_text_toggle_button.z_index = 40
		preview_text_toggle_button.move_to_front()
		preview_text_toggle_button.text = (
			"SHOW TEXT"
			if _preview_text_hidden
			else "HIDE TEXT"
		)
		preview_text_toggle_button.tooltip_text = (
			"Restore the Castle rules overlay."
			if _preview_text_hidden
			else "Hide the rules overlay to inspect the Castle artwork."
		)

func _on_preview_text_toggle_pressed() -> void:
	_reset_preview_hold_state()

	_preview_text_hidden = not _preview_text_hidden
	_apply_preview_text_visibility()

func _show_preview() -> void:
	if preview_popup == null:
		return
	_reset_preview_hold_state()
	# Construction is itself information. Let the player see the built fraction
	# first; SHOW TEXT still restores the complete rules panel immediately.
	_preview_text_hidden = _construction_visual_active
	_refresh_preview()
	preview_popup.popup_centered(Vector2i(420, 630))


func _on_hold_timeout() -> void:
	if not _left_down:
		return
	_hold_triggered = true
	_show_preview()


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
		return

	_left_down = false
	if hold_timer != null:
		hold_timer.stop()
	if _hold_triggered:
		_hold_triggered = false


func _on_preview_gui_input(_event: InputEvent) -> void:
	return

func _on_preview_catcher_gui_input(
	_event: InputEvent
) -> void:
	return

func _on_preview_hold_button_down() -> void:
	_preview_left_down = true
	_preview_hold_triggered = false
	if preview_hold_timer != null:
		preview_hold_timer.stop()
		preview_hold_timer.start()


func _on_preview_hold_button_up() -> void:
	_preview_left_down = false
	if preview_hold_timer != null:
		preview_hold_timer.stop()


func _reset_preview_hold_state() -> void:
	_preview_left_down = false
	_preview_hold_triggered = false

	if preview_hold_timer != null:
		preview_hold_timer.stop()


func _on_preview_hold_timeout() -> void:
	if not _preview_left_down:
		return
	_preview_hold_triggered = true
	_preview_left_down = false
	if preview_hold_timer != null:
		preview_hold_timer.stop()
	if preview_popup != null:
		preview_popup.hide()

func _process(delta: float) -> void:
	if (
		preview_popup == null
		or not preview_popup.visible
	):
		_preview_poll_armed = false
		_preview_poll_elapsed = 0.0
		return

	# The preview opens while the mouse is still down from the original
	# board-card hold. Do not begin counting until that button has been
	# physically released once.
	if not _preview_poll_armed:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_preview_poll_armed = true
			_preview_poll_elapsed = 0.0
		return

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_preview_poll_elapsed = 0.0
		return

	if preview_surface == null:
		_preview_poll_elapsed = 0.0
		return

	var local_mouse: Vector2 = (
		preview_surface.get_local_mouse_position()
	)

	var inside_card: bool = Rect2(
		Vector2.ZERO,
		preview_surface.size
	).has_point(local_mouse)

	if not inside_card:
		_preview_poll_elapsed = 0.0
		return

	# SHOW/HIDE TEXT is intentionally exempt from the card hold gesture.
	if (
		preview_text_toggle_button != null
		and preview_text_toggle_button.visible
	):
		var toggle_mouse: Vector2 = (
			preview_text_toggle_button.get_local_mouse_position()
		)

		var over_toggle: bool = Rect2(
			Vector2.ZERO,
			preview_text_toggle_button.size
		).has_point(toggle_mouse)

		if over_toggle:
			_preview_poll_elapsed = 0.0
			return

	_preview_poll_elapsed += delta

	if _preview_poll_elapsed < 0.35:
		return

	_preview_poll_elapsed = 0.0
	_preview_poll_armed = false
	_reset_preview_hold_state()

	if preview_popup != null:
		preview_popup.hide()


func _apply_style(border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.012, 0.014, 1.0)
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 1
	style.content_margin_right = 1
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	add_theme_stylebox_override("panel", style)
