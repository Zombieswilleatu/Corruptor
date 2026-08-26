# UI2_CARD_INTERACTION_STAGING_V2
# UI2_SUBJECT_CARD_ART_V1
# UI2_SUBJECT_CARD_ART_SURFACES_V2
class_name UI2SubjectCardHoldPreview
extends Node


const HOLD_SECONDS: float = 0.28
const MOVE_CANCEL_DISTANCE: float = 9.0
const PREVIEW_SIZE: Vector2 = Vector2(360, 504)


var source: Control = null
var card_texture: Texture2D = null
var hold_timer: Timer = null
var preview_layer: CanvasLayer = null
var preview_root: Control = null
var preview_art: TextureRect = null

var _down: bool = false
var _press_viewport_position: Vector2 = Vector2.ZERO
var _movement_cancelled: bool = false
var _pinned: bool = false


func configure(
	p_source: Control,
	p_texture: Texture2D
) -> void:
	source = p_source
	card_texture = p_texture

	hold_timer = Timer.new()
	hold_timer.one_shot = true
	hold_timer.wait_time = HOLD_SECONDS
	hold_timer.timeout.connect(_on_hold_timeout)
	add_child(hold_timer)

	_build_preview()

	if source != null:
		source.gui_input.connect(_on_source_gui_input)

	set_process_input(false)


func set_texture(
	p_texture: Texture2D
) -> void:
	card_texture = p_texture
	if preview_art != null:
		preview_art.texture = card_texture


func _build_preview() -> void:
	preview_layer = CanvasLayer.new()
	preview_layer.layer = 100
	add_child(preview_layer)

	preview_root = Control.new()
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.visible = false
	preview_layer.add_child(preview_root)

	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.0, 0.0, 0.0, 0.58)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = PREVIEW_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.015, 0.018, 0.98)
	style.border_color = Color(0.58, 0.48, 0.30, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)

	preview_art = TextureRect.new()
	preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_art.texture = card_texture
	frame.add_child(preview_art)


func _on_source_gui_input(
	event: InputEvent
) -> void:
	if card_texture == null:
		return

	if not (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		return

	_down = true
	_movement_cancelled = false
	_press_viewport_position = source.get_viewport().get_mouse_position()

	if hold_timer != null:
		hold_timer.start()

	set_process_input(true)


func _input(
	event: InputEvent
) -> void:
	if _pinned:
		if (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		):
			_pinned = false
			_hide_preview()
			set_process_input(false)
			get_viewport().set_input_as_handled()
		return

	if not _down:
		return

	if event is InputEventMouseMotion:
		var current_position: Vector2 = event.position
		if (
			not _movement_cancelled
			and current_position.distance_to(_press_viewport_position)
			> MOVE_CANCEL_DISTANCE
		):
			_movement_cancelled = true
			if hold_timer != null:
				hold_timer.stop()
			_hide_preview()
		return

	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		var was_hold_preview: bool = (
			preview_root != null
			and preview_root.visible
		)

		_down = false

		if hold_timer != null:
			hold_timer.stop()

		var click_inspect: bool = (
			source != null
			and bool(
				source.get_meta(
					"subject_click_inspect",
					false
				)
			)
			and not _movement_cancelled
			and not was_hold_preview
		)

		if click_inspect:
			_show_preview()
			_pinned = true
			set_process_input(true)
		else:
			_hide_preview()
			set_process_input(false)

func _on_hold_timeout() -> void:
	if (
		not _down
		or _movement_cancelled
		or card_texture == null
	):
		return

	_show_preview()


func _show_preview() -> void:
	if (
		preview_root == null
		or source == null
		or source.get_viewport() == null
	):
		return

	preview_root.position = Vector2.ZERO
	preview_root.size = source.get_viewport_rect().size
	preview_art.texture = card_texture
	preview_root.visible = true


func _hide_preview() -> void:
	if preview_root != null:
		preview_root.visible = false
