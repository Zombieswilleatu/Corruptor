# Extracted from UI2 PhasePrompt at 73ad198: retained layout/overlay methods.
# UI2_SLAVER_THEME_V1_1
# UI2_DIALOGUE_BREACH_OVERHAUL_V1
class_name U13PhasePrompt
extends Panel

# UI2_DECISION_PANEL_SKIN_V1
const Textures = preload("res://Prototype/U13/U13BoardTextures.gd")
var UI2_DECISION_PANEL_TEXTURE: Texture2D

signal confirm_requested
signal pass_requested

var eyebrow_label: Label = null
var title_label: Label = null
var copy_label: Label = null
var divider: HSeparator = null
var intro_buttons: HBoxContainer = null
var yes_button: Button = null
var no_button: Button = null
var view_board_button: Button = null
var content_host: VBoxContainer = null
var action_zone = null

var stage_key: String = ""
var detail_open: bool = false
var board_view_collapsed: bool = false
var controller_ref = null
var player_ref = null
var opponent_ref = null
var rules_ref = null
var maintenance_step: String = ""


func _ready() -> void:
	UI2_DECISION_PANEL_TEXTURE = Textures.texture("res://ConceptImages/Menus/DecisionPanel.png")
	call_deferred("_apply_decision_panel_skin_v1")
	# UI2_DECISION_PHASE_SLOT_READABILITY_V17_1
	# Root-overlay header must follow the final PanelContainer rect.
	if not resized.is_connected(_sync_decision_panel_layout_v4):
		resized.connect(_sync_decision_panel_layout_v4)
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	# UI2_BOARD_FIRST_PROMPT_V1
	# UI2_PROMPT_CASTLE_GUTTER_V1
	# Board state is part of the decision interface. Nudge the prompt slightly
	# right so it clears Lord Guards, while the PlayerBoard reserves a matching
	# gutter before the Castle spine.
	anchor_left = 0.258
	anchor_right = 0.258
	anchor_top = 0.5
	anchor_bottom = 0.5
	# UI2_DECISION_PANEL_FIXED_SIZE_V11
	offset_left = -200.0
	offset_right = 200.0
	offset_top = -265.0
	offset_bottom = 265.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.028, 0.034, 0.985)
	style.border_color = Color(0.45, 0.39, 0.26, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 15.0
	style.content_margin_bottom = 16.0
	add_theme_stylebox_override("panel", style)

	var outer := VBoxContainer.new()
	outer.name = "PromptContents"
	outer.position = Vector2(36, 102)
	outer.size = Vector2(328, 285)
	outer.add_theme_constant_override("separation", 10)
	add_child(outer)

	var header_row := HBoxContainer.new()
	header_row.name = "PromptHeader"
	header_row.add_theme_constant_override("separation", 8)
	outer.add_child(header_row)

	eyebrow_label = Label.new()
	eyebrow_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	eyebrow_label.add_theme_font_size_override("font_size", 11)
	eyebrow_label.add_theme_color_override("font_color", Color(0.61, 0.63, 0.69, 1.0))
	header_row.add_child(eyebrow_label)

	view_board_button = Button.new()
	view_board_button.name = "ViewBoardButton"
	view_board_button.text = "VIEW BOARD"
	view_board_button.custom_minimum_size = Vector2(112, 30)
	view_board_button.tooltip_text = ("Collapse this decision temporarily. Current selections stay staged.")
	view_board_button.pressed.connect(_on_view_board_pressed)
	header_row.add_child(view_board_button)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.94, 0.87, 0.72, 1.0))
	outer.add_child(title_label)

	copy_label = Label.new()
	copy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy_label.add_theme_font_size_override("font_size", 14)
	copy_label.add_theme_color_override("font_color", Color(0.84, 0.85, 0.89, 1.0))
	outer.add_child(copy_label)

	divider = HSeparator.new()
	outer.add_child(divider)

	intro_buttons = HBoxContainer.new()
	intro_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	intro_buttons.add_theme_constant_override("separation", 10)
	outer.add_child(intro_buttons)

	yes_button = Button.new()
	yes_button.custom_minimum_size = Vector2(145, 48)
	yes_button.pressed.connect(_on_yes_pressed)
	intro_buttons.add_child(yes_button)

	no_button = Button.new()
	no_button.custom_minimum_size = Vector2(145, 48)
	no_button.pressed.connect(_on_no_pressed)
	intro_buttons.add_child(no_button)

	content_host = VBoxContainer.new()
	content_host.name = "ActionHost"
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_host.visible = false
	outer.add_child(content_host)


func attach_action_zone(zone) -> void:
	action_zone = zone
	if action_zone == null or content_host == null:
		return
	if action_zone.get_parent() != null:
		action_zone.get_parent().remove_child(action_zone)
	content_host.add_child(action_zone)
	action_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_zone.visible = false
	# UI2_DECISION_BOTTOM_ACTIONS_V12_1
	call_deferred("_install_decision_bottom_actions_v12")


func _refresh_mode() -> void:
	var can_view_board: bool = _can_view_board(stage_key)

	if view_board_button != null:
		view_board_button.visible = can_view_board
		view_board_button.text = ("RETURN TO DECISION" if board_view_collapsed else "VIEW BOARD")

	if board_view_collapsed and can_view_board:
		# Collapse to a small persistent decision tab. The ActionZone stays
		# alive, so selected order/target/payment state survives while the
		# player inspects or drags directly on the board.
		title_label.visible = false
		copy_label.visible = false
		divider.visible = false
		intro_buttons.visible = false
		content_host.visible = false
		if action_zone != null:
			action_zone.visible = false

		offset_left = -175.0
		offset_right = 175.0
		offset_top = -34.0
		# UI2_DECISION_BOTTOM_ACTIONS_PARSE_FIX_V12_2
		offset_bottom = 34.0
		call_deferred("_sync_decision_bottom_actions_v12")
		call_deferred("_sync_decision_panel_layout_v4")
		return

	title_label.visible = true
	copy_label.visible = true
	divider.visible = true

	var show_details: bool = detail_open and action_zone != null
	content_host.visible = show_details
	if action_zone != null:
		action_zone.visible = show_details

	# UI2_COMMITMENT_TEXT_WINDOW_EXPAND_V13
	# Use the dead space above the artwork's bottom action windows.
	var commitment_text_window_v13: bool = stage_key == "COMMITMENT" and show_details
	var commitment_text_height_v13: float = 0.0

	if content_host != null:
		content_host.custom_minimum_size.y = (commitment_text_height_v13)

	if action_zone != null:
		action_zone.custom_minimum_size.y = (commitment_text_height_v13)

		var action_scroll_v13 := action_zone.get_node_or_null("ActionScroll") as ScrollContainer
		if action_scroll_v13 != null:
			action_scroll_v13.custom_minimum_size.y = (commitment_text_height_v13)
	# UI2_SLAVER_VISIBLE_OFFERS_V2_4
	# Use the existing dead space above the artwork buttons.
	if stage_key == "MARKET" and show_details:
		var slaver_detail_height_v2_4: float = 225.0
		if content_host != null:
			content_host.custom_minimum_size.y = (slaver_detail_height_v2_4)
		if action_zone != null:
			action_zone.custom_minimum_size.y = (slaver_detail_height_v2_4)
			var slaver_scroll_v2_4 := (
				action_zone.get_node_or_null("ActionScroll") as ScrollContainer
			)
			if slaver_scroll_v2_4 != null:
				slaver_scroll_v2_4.custom_minimum_size.y = (slaver_detail_height_v2_4)
	intro_buttons.visible = not show_details and _has_buttons(stage_key)

	# UI2_DECISION_PANEL_TRUE_FIXED_SIZE_V12
	# Every expanded decision uses one footprint. No phase jumping.
	offset_left = -200.0
	offset_right = 200.0
	offset_top = -265.0
	offset_bottom = 265.0
	call_deferred("_sync_decision_bottom_actions_v12")
	call_deferred("_sync_decision_panel_layout_v4")
	if stage_key == "AFTERMATH" and action_zone != null:
		action_zone.hide()


func _on_view_board_pressed() -> void:
	if not _can_view_board(stage_key):
		return
	board_view_collapsed = not board_view_collapsed
	_refresh_mode()


func _can_view_board(stage_name: String) -> bool:
	# Keep terminal/meta prompts explicit. Every live gameplay decision may be
	# collapsed because the board itself can contain information the player
	# needs before answering.
	return (
		stage_name
		not in [
			"",
			"NO_GAME",
			"TERMINAL",
			"INVALID",
		]
	)


func _apply_decision_panel_skin_v1() -> void:
	if UI2_DECISION_PANEL_TEXTURE == null:
		return

	if not resized.is_connected(_refresh_decision_panel_art_mode_v3):
		resized.connect(_refresh_decision_panel_art_mode_v3)

	_refresh_decision_panel_art_mode_v3()

	if view_board_button != null:
		_skin_view_board_button_v1(view_board_button)

	# UI2_DECISION_PANEL_LAYOUT_V4
	_install_decision_panel_layout_v4()


# UI2_DECISION_PANEL_BREATHING_ROOM_V6
func _refresh_decision_panel_art_mode_v3() -> void:
	var collapsed_now: bool = size.y <= 100.0
	var previous_mode = (
		get_meta("_ui2_decision_panel_collapsed_v3")
		if has_meta("_ui2_decision_panel_collapsed_v3")
		else null
	)

	if previous_mode != null and bool(previous_mode) == collapsed_now:
		return

	set_meta("_ui2_decision_panel_collapsed_v3", collapsed_now)

	if collapsed_now:
		var collapsed_style := StyleBoxFlat.new()
		collapsed_style.bg_color = Color(0.018, 0.017, 0.016, 0.97)
		collapsed_style.border_color = Color(0.48, 0.37, 0.19, 1.0)
		collapsed_style.set_border_width_all(2)
		collapsed_style.set_corner_radius_all(5)
		collapsed_style.content_margin_left = 12.0
		collapsed_style.content_margin_right = 12.0
		collapsed_style.content_margin_top = 8.0
		collapsed_style.content_margin_bottom = 8.0
		add_theme_stylebox_override("panel", collapsed_style)
		return

	# The artwork's native composition is approximately 3:4.
	# PhasePrompt is now sized to the same ratio, so the entire image can
	# simply scale as one coherent painting with no nine-slice assembly.
	var panel_style := StyleBoxTexture.new()
	panel_style.texture = UI2_DECISION_PANEL_TEXTURE
	var compact_decision_layout_v10: bool = (
		stage_key == "COMMITMENT" or (stage_key == "MARKET" and not detail_open)
	)
	panel_style.content_margin_left = (36.0)
	panel_style.content_margin_right = (36.0)
	panel_style.content_margin_top = 92.0
	# UI2_DECISION_BOTTOM_ACTION_AREA_V12
	panel_style.content_margin_bottom = 195.0
	add_theme_stylebox_override("panel", panel_style)


func _skin_view_board_button_v1(button: Button) -> void:
	if button == null:
		return

	button.custom_minimum_size = Vector2(112.0, 32.0)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.72, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.76, 0.68, 0.50, 1.0))

	button.add_theme_stylebox_override(
		"normal",
		_decision_panel_button_style_v1(
			Color(0.025, 0.024, 0.022, 0.94), Color(0.40, 0.31, 0.16, 1.0), 1
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_decision_panel_button_style_v1(
			Color(0.065, 0.052, 0.032, 0.98), Color(0.68, 0.53, 0.25, 1.0), 2
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_decision_panel_button_style_v1(
			Color(0.018, 0.017, 0.016, 1.0), Color(0.48, 0.36, 0.17, 1.0), 2
		)
	)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _decision_panel_button_style_v1(
	background: Color, border: Color, border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style

	# UI2_DECISION_PANEL_TINY_TOGGLE_V5


func _install_decision_panel_layout_v4() -> void:
	if view_board_button == null or title_label == null:
		return

	var header_row := view_board_button.get_parent() as Control
	if header_row == null:
		return

	var content_root := header_row.get_parent() as Control
	if content_root == null:
		return

	content_root.name = "DecisionPanelContentV4"

	# Keep the original overlay positioning for the art plaques and buttons.
	# U13 uses a fixed Panel; its scroll content cannot enlarge the footprint.
	var parent_control := get_parent() as Control
	if parent_control == null:
		return

	var overlay := parent_control.get_node_or_null("DecisionPanelOverlayV5") as Control

	if overlay == null:
		overlay = Control.new()
		overlay.name = "DecisionPanelOverlayV5"
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = z_index + 1
		parent_control.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if title_label.get_parent() != overlay:
		title_label.get_parent().remove_child(title_label)
		overlay.add_child(title_label)

	if view_board_button.get_parent() != overlay:
		view_board_button.get_parent().remove_child(view_board_button)
		overlay.add_child(view_board_button)

	title_label.z_index = 2
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.91, 0.85, 0.68, 1.0))

	view_board_button.z_index = 3
	view_board_button.mouse_filter = Control.MOUSE_FILTER_STOP
	view_board_button.custom_minimum_size = Vector2(88.0, 26.0)
	view_board_button.add_theme_font_size_override("font_size", 11)

	# Capture the exact screen rectangle before the core handler changes the
	# PhasePrompt size/state.
	if not view_board_button.button_down.is_connected(_capture_decision_panel_button_rect_v4):
		view_board_button.button_down.connect(_capture_decision_panel_button_rect_v4)

	if not view_board_button.pressed.is_connected(_queue_decision_panel_layout_sync_v4):
		view_board_button.pressed.connect(_queue_decision_panel_layout_sync_v4)

	if not resized.is_connected(_queue_decision_panel_layout_sync_v4):
		resized.connect(_queue_decision_panel_layout_sync_v4)

	if not visibility_changed.is_connected(_queue_decision_panel_layout_sync_v4):
		visibility_changed.connect(_queue_decision_panel_layout_sync_v4)

	_sync_decision_panel_layout_v4()


func _capture_decision_panel_button_rect_v4() -> void:
	if view_board_button == null:
		return

	set_meta("_ui2_decision_button_global_rect_v4", view_board_button.get_global_rect())


func _queue_decision_panel_layout_sync_v4() -> void:
	call_deferred("_sync_decision_panel_layout_v4")


func _decision_panel_overlay_v5() -> Control:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return null

	return parent_control.get_node_or_null("DecisionPanelOverlayV5") as Control


func _place_decision_overlay_rect_v5(control: Control, global_rect: Rect2) -> void:
	var overlay := _decision_panel_overlay_v5()
	if overlay == null or control == null:
		return

	var local_top_left: Vector2 = (
		overlay.get_global_transform().affine_inverse() * global_rect.position
	)

	control.anchor_left = 0.0
	control.anchor_right = 0.0
	control.anchor_top = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = local_top_left.x
	control.offset_top = local_top_left.y
	control.offset_right = (local_top_left.x + global_rect.size.x)
	control.offset_bottom = (local_top_left.y + global_rect.size.y)


func _sync_decision_panel_layout_v4() -> void:
	if view_board_button == null or title_label == null:
		return

	var overlay := _decision_panel_overlay_v5()
	if overlay == null:
		return
	# UI2_DECISION_PHASE_STALE_RUNTIME_PURGE_V17_6
	# The retired V15 helper has no active callers. Purge any V15 label
	# that survived in the scene tree before drawing the current V16 slot.
	var stale_phase_v15_live := overlay.get_node_or_null("DecisionPhaseSlotV15") as Control
	if stale_phase_v15_live != null:
		stale_phase_v15_live.visible = false
		stale_phase_v15_live.queue_free()

	var phase_slot_v16 := overlay.get_node_or_null("DecisionPhaseSlotV16") as Label
	# UI2_DECISION_OVERLAY_ORPHAN_LABEL_PURGE_V17_7
	# Runtime census found an unnamed opaque Label stranded directly
	# under DecisionPanelOverlayV5. Only title_label and phase_slot_v16
	# are legitimate direct Label children of this header overlay.
	for overlay_child_v17_7 in overlay.get_children():
		var orphan_label_v17_7 := overlay_child_v17_7 as Label
		if orphan_label_v17_7 == null:
			continue
		if orphan_label_v17_7 == title_label:
			continue
		if orphan_label_v17_7 == phase_slot_v16:
			continue
		orphan_label_v17_7.visible = false
		orphan_label_v17_7.queue_free()

	var content_root := get_node_or_null("DecisionPanelContentV4") as Control

	# Because title/button now live outside PhasePrompt, explicitly mirror the
	# prompt's own visibility.
	if not visible:
		title_label.visible = false
		if phase_slot_v16 != null:
			phase_slot_v16.visible = false
		view_board_button.visible = false
		return

	if board_view_collapsed:
		# Exactly one thing remains: the tiny toggle button.
		if content_root != null:
			content_root.visible = false

		title_label.visible = false
		if phase_slot_v16 != null:
			phase_slot_v16.visible = false
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = false

		view_board_button.visible = true
		view_board_button.text = "RETURN"
		view_board_button.tooltip_text = "Return to the current decision."

		var captured: Rect2 = get_meta("_ui2_decision_button_global_rect_v4", Rect2())

		if captured.size.x > 0.0 and captured.size.y > 0.0:
			_place_decision_overlay_rect_v5(view_board_button, captured)

		return

	# Expanded decision window.
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	if content_root != null:
		content_root.visible = true

	view_board_button.visible = true
	view_board_button.text = "VIEW BOARD"
	view_board_button.tooltip_text = ("Collapse this decision temporarily. Current selections stay staged.")

	# Restore the complete painted panel after collapsed mode hid it.
	set_meta("_ui2_decision_panel_collapsed_v3", true)
	_refresh_decision_panel_art_mode_v3()

	var prompt_rect: Rect2 = get_global_rect()

	# UI2_DECISION_HEADER_GLOBAL_RECT_V16_1
	# Keep the original eyebrow alive for state/layout, but render the
	# phase name in the artwork's dedicated cutout instead.
	# UI2_DECISION_PHASE_DUPLICATE_CLEANUP_V17_2
	# Preserve the legacy eyebrow's layout footprint/text source,
	# but make its glyphs impossible to render in the content VBox.
	if eyebrow_label != null:
		eyebrow_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		eyebrow_label.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		eyebrow_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))
		eyebrow_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))

	if phase_slot_v16 == null:
		phase_slot_v16 = Label.new()
		phase_slot_v16.name = "DecisionPhaseSlotV16"
		phase_slot_v16.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phase_slot_v16.z_index = 2
		phase_slot_v16.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		phase_slot_v16.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		phase_slot_v16.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		phase_slot_v16.add_theme_font_size_override("font_size", 11)
		phase_slot_v16.add_theme_color_override("font_color", Color(0.76, 0.67, 0.48, 1.0))
		phase_slot_v16.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
		phase_slot_v16.add_theme_constant_override("shadow_offset_x", 1)
		phase_slot_v16.add_theme_constant_override("shadow_offset_y", 1)
		overlay.add_child(phase_slot_v16)

	phase_slot_v16.text = (eyebrow_label.text if eyebrow_label != null else "")
	phase_slot_v16.visible = true

	# UI2_DECISION_PHASE_SLOT_READABILITY_V17_1
	# Normalize to the live panel rectangle so intro/detail views share
	# the exact same painted phase-window position.
	var phase_rect_v17_1 := Rect2(
		prompt_rect.position + Vector2(prompt_rect.size.x * 0.065, prompt_rect.size.y * 0.118),
		Vector2(prompt_rect.size.x * 0.260, prompt_rect.size.y * 0.052)
	)
	_place_decision_overlay_rect_v5(phase_slot_v16, phase_rect_v17_1)

	# Dynamic title in the artwork's top plaque.
	var title_rect := Rect2(
		prompt_rect.position + Vector2(90.0, 20.0), Vector2(prompt_rect.size.x - 180.0, 44.0)
	)
	title_label.visible = true
	title_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	title_label.add_theme_font_size_override("font_size", 16)
	_place_decision_overlay_rect_v5(title_label, title_rect)

	# Tiny corner toggle. Because it lives in the overlay rather than the
	# PanelContainer, these dimensions stay exactly 88x26.
	var button_rect := Rect2(
		prompt_rect.position + Vector2(prompt_rect.size.x - 102.0, 66.0), Vector2(88.0, 26.0)
	)
	_place_decision_overlay_rect_v5(view_board_button, button_rect)


# UI2_DECISION_BOTTOM_ACTIONS_V12_1
#
# DecisionPanel artwork has three action windows:
#   - one wide upper-bottom window for a single action
#   - two smaller lower windows when two choices are available
#
# Existing Buttons are reparented into a plain sibling overlay so:
#   - Container layout cannot stretch them
#   - existing pressed signals remain untouched
#   - action text always occupies the artwork's intended window
func _install_decision_bottom_actions_v12() -> void:
	if action_zone == null:
		return

	var parent_control := get_parent() as Control
	if parent_control == null:
		return

	var overlay := parent_control.get_node_or_null("DecisionPanelActionOverlayV12") as Control

	if overlay == null:
		overlay = Control.new()
		overlay.name = "DecisionPanelActionOverlayV12"
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = z_index + 2
		parent_control.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var intro_layer := overlay.get_node_or_null("DecisionIntroActionsV12") as Control
	if intro_layer == null:
		intro_layer = Control.new()
		intro_layer.name = "DecisionIntroActionsV12"
		intro_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		intro_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(intro_layer)

	var detail_layer := overlay.get_node_or_null("DecisionDetailActionsV12") as Control
	if detail_layer == null:
		detail_layer = Control.new()
		detail_layer.name = "DecisionDetailActionsV12"
		detail_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		detail_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(detail_layer)

	var confirm_raw = action_zone.get("confirm_button")
	var pass_raw = action_zone.get("pass_button")

	if not (confirm_raw is Button) or not (pass_raw is Button):
		push_warning("DecisionPanel v12: ActionZone confirm/pass Buttons were not found.")
		return

	var confirm_button := confirm_raw as Button
	var pass_button := pass_raw as Button

	_move_decision_action_button_v12(yes_button, intro_layer)
	_move_decision_action_button_v12(no_button, intro_layer)
	_move_decision_action_button_v12(confirm_button, detail_layer)
	_move_decision_action_button_v12(pass_button, detail_layer)

	for button: Button in [
		yes_button,
		no_button,
		confirm_button,
		pass_button,
	]:
		if not button.visibility_changed.is_connected(_queue_decision_bottom_actions_v12):
			button.visibility_changed.connect(_queue_decision_bottom_actions_v12)

	if not resized.is_connected(_queue_decision_bottom_actions_v12):
		resized.connect(_queue_decision_bottom_actions_v12)

	if not visibility_changed.is_connected(_queue_decision_bottom_actions_v12):
		visibility_changed.connect(_queue_decision_bottom_actions_v12)

	if not overlay.resized.is_connected(_queue_decision_bottom_actions_v12):
		overlay.resized.connect(_queue_decision_bottom_actions_v12)

	if (
		view_board_button != null
		and not view_board_button.pressed.is_connected(_queue_decision_bottom_actions_v12)
	):
		view_board_button.pressed.connect(_queue_decision_bottom_actions_v12)

	call_deferred("_sync_decision_bottom_actions_v12")


func _move_decision_action_button_v12(button: Button, layer: Control) -> void:
	if button == null or layer == null:
		return

	if button.get_parent() != layer:
		var old_parent := button.get_parent()
		if old_parent != null:
			old_parent.remove_child(button)
		layer.add_child(button)

	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.custom_minimum_size = Vector2.ZERO
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_skin_decision_action_button_v12(button)


func _skin_decision_action_button_v12(button: Button) -> void:
	if button == null:
		return

	var normal := StyleBoxEmpty.new()
	var disabled := StyleBoxEmpty.new()

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.22, 0.13, 0.035, 0.20)
	hover.border_color = Color(0.65, 0.48, 0.20, 0.55)
	hover.set_border_width_all(1)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.09, 0.045, 0.012, 0.34)

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	focus.border_color = Color(0.70, 0.53, 0.24, 0.72)
	focus.set_border_width_all(1)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)

	button.add_theme_color_override("font_color", Color(0.92, 0.88, 0.76, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.75, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.86, 0.73, 0.47, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.46, 0.41, 0.78))


func _queue_decision_bottom_actions_v12() -> void:
	call_deferred("_sync_decision_bottom_actions_v12")


func _sync_decision_bottom_actions_v12() -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return

	var overlay := parent_control.get_node_or_null("DecisionPanelActionOverlayV12") as Control
	if overlay == null:
		return

	var intro_layer := overlay.get_node_or_null("DecisionIntroActionsV12") as Control
	var detail_layer := overlay.get_node_or_null("DecisionDetailActionsV12") as Control

	if intro_layer == null or detail_layer == null:
		return

	var confirm_raw = action_zone.get("confirm_button") if action_zone != null else null
	var pass_raw = action_zone.get("pass_button") if action_zone != null else null

	var confirm_button := confirm_raw as Button
	var pass_button := pass_raw as Button

	var panel_active: bool = visible and not board_view_collapsed

	overlay.visible = panel_active

	if not panel_active:
		return

	var show_details: bool = detail_open and action_zone != null

	intro_layer.visible = (not show_details and _has_buttons(stage_key))
	detail_layer.visible = show_details

	var panel_global := get_global_rect()
	# UI2_DECISION_BOTTOM_ACTIONS_ALIGN_V12_3
	# Slots are defined in global screen space to match the panel art.
	var panel_origin := panel_global.position
	var panel_size := panel_global.size

	# Coordinates are normalized to the new three-slot artwork so the
	# placement remains correct if the panel footprint is tuned later.
	var wide_slot := Rect2(
		(
			panel_origin
			+ Vector2(
				panel_size.x * 0.09,
				# UI2_DECISION_BOTTOM_ACTIONS_SLOT_TUNE_V12_4
				# UI2_DECISION_BOTTOM_ACTIONS_STRING_FIX_V12_5
				panel_size.y * 0.785
			)
		),
		Vector2(panel_size.x * 0.82, panel_size.y * 0.067)
	)

	var left_slot := Rect2(
		panel_origin + Vector2(panel_size.x * 0.10, panel_size.y * 0.900),
		Vector2(panel_size.x * 0.38, panel_size.y * 0.060)
	)

	var right_slot := Rect2(
		panel_origin + Vector2(panel_size.x * 0.52, panel_size.y * 0.900),
		Vector2(panel_size.x * 0.38, panel_size.y * 0.060)
	)

	_layout_decision_action_pair_v12(yes_button, no_button, wide_slot, left_slot, right_slot)

	_layout_decision_action_pair_v12(confirm_button, pass_button, wide_slot, left_slot, right_slot)


func _layout_decision_action_pair_v12(
	primary: Button, secondary: Button, wide_slot: Rect2, left_slot: Rect2, right_slot: Rect2
) -> void:
	var primary_visible: bool = primary != null and primary.visible
	var secondary_visible: bool = secondary != null and secondary.visible

	var visible_count: int = int(primary_visible) + int(secondary_visible)

	if visible_count == 1:
		var single_button: Button = primary if primary_visible else secondary
		_place_decision_action_button_v12(single_button, wide_slot, true)
		return

	if visible_count == 2:
		_place_decision_action_button_v12(primary, left_slot, false)
		_place_decision_action_button_v12(secondary, right_slot, false)


func _place_decision_action_button_v12(button: Button, slot: Rect2, large: bool) -> void:
	if button == null:
		return

	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.global_position = slot.position
	button.size = slot.size
	button.add_theme_font_size_override("font_size", 16 if large else 14)


# UI2_DECISION_ALIGNMENT_CLEANUP_V15
# UI2_DECISION_PHASE_V15_RETIRE_V17_5
func _sync_decision_header_slots_v15() -> void:
	# Historical compatibility shim only.
	# Never create/render a second phase label again.
	var overlay := _decision_panel_overlay_v5()
	if overlay == null and title_label != null:
		overlay = title_label.get_parent() as Control

	if overlay == null:
		return

	var stale_phase_v15 := overlay.get_node_or_null("DecisionPhaseSlotV15") as Control

	if stale_phase_v15 != null:
		stale_phase_v15.visible = false
		stale_phase_v15.queue_free()

	return


func bind_decision(key: String, title: String, copy: String, phase: String) -> void:
	if stage_key != key:
		board_view_collapsed = false
	stage_key = key
	detail_open = true
	title_label.text = title
	copy_label.text = copy
	eyebrow_label.text = phase
	visible = true
	_refresh_mode()


func set_presenting(enabled: bool) -> void:
	visible = enabled
	call_deferred("_sync_decision_panel_layout_v4")
	call_deferred("_sync_decision_bottom_actions_v12")


func sync_direct_manipulation(_action_name: String = "") -> void:
	detail_open = true
	_refresh_mode()


func _has_buttons(_stage: String) -> bool:
	return false


func _on_yes_pressed() -> void:
	confirm_requested.emit()


func _on_no_pressed() -> void:
	pass_requested.emit()
