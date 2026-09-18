extends Control

signal confirmed(target: Dictionary)
signal cancelled
const Visuals = preload("res://Prototype/U13/U13WebVisuals.gd")
const SpatialInput = preload("res://Prototype/U13/U13SpatialInput.gd")
var visuals = Visuals.new()
var target: Dictionary = {"lane": "Lord", "field_position": {"x_fp": 1200, "y_fp": 300}}
var radius_fp: int = 270
var confirm_button: Button
var cancel_button: Button
var placed: bool = false
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var battlefield: Control
var board_help: PanelContainer
var board_help_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 120
	mouse_filter = Control.MOUSE_FILTER_STOP
	var actions := HBoxContainer.new()
	add_child(actions)
	actions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	actions.offset_left = -178
	actions.offset_top = -64
	actions.offset_right = 178
	actions.offset_bottom = -22
	actions.add_theme_constant_override("separation", 16)
	confirm_button = Button.new()
	confirm_button.text = "SET THE SNARE"
	confirm_button.custom_minimum_size = Vector2(220, 42)
	confirm_button.pressed.connect(_confirm)
	actions.add_child(confirm_button)
	cancel_button = Button.new()
	cancel_button.text = "CANCEL"
	cancel_button.custom_minimum_size = Vector2(120, 42)
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	actions.add_child(cancel_button)
	hide()
	set_process(false)


func open(initial: Dictionary = {}) -> void:
	placed = not initial.is_empty()
	dragging = false
	drag_offset = Vector2.ZERO
	confirm_button.disabled = not placed
	if placed:
		target = initial.duplicate(true)
	show()
	set_process(true)
	confirm_button.grab_focus()
	queue_redraw()


func close() -> void:
	dragging = false
	hide()
	set_process(false)


func lane_rect(lane: String) -> Rect2:
	if is_instance_valid(battlefield):
		return get_global_transform_with_canvas().affine_inverse() * battlefield.get_global_transform_with_canvas() * battlefield.travel_rect(lane)
	var height: float = maxf(200.0, size.y - 210.0)
	var width: float = height / 4.0
	return Rect2(size.x * 0.5 - width + (width if lane == "Castle" else 0.0), 110, width, height)


func bind_battlefield(field: Control) -> void:
	battlefield = field
	board_help = PanelContainer.new()
	preload("res://Prototype/U13/U13ReconfigurationStyle.gd").apply(board_help)
	add_child(board_help)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	board_help.add_child(column)
	var title := Label.new()
	title.text = "WEB · CHOOSE ITS REACH"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	board_help_text = Label.new()
	board_help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(board_help_text)
	var actions: Control = confirm_button.get_parent()
	actions.reparent(column)
	actions.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	confirm_button.custom_minimum_size.x = 200
	cancel_button.custom_minimum_size.x = 100
	_sync_board_help()


func _sync_board_help() -> void:
	if board_help == null: return
	var field: Rect2 = lane_rect("Lord")
	board_help.size.x = 380
	board_help.position = Vector2(maxf(12, field.position.x - 400), maxf(100, field.position.y))
	board_help_text.text = "Click either marching lane to place the web. Drag it to adjust, then Set the Snare.\n\nEnemy Marchers inside take 1 damage and move at half speed."
	if placed: board_help_text.text += "\n\nSelected: %s lane." % target.lane


func _confirm() -> void:
	if placed and not dragging:
		confirmed.emit(target.duplicate(true))


func _place_at(point: Vector2) -> bool:
	for lane in ["Lord", "Castle"]:
		var proposed: Dictionary = SpatialInput.target_at(point, lane_rect(lane), lane)
		if not proposed.is_empty():
			target = proposed
			placed = true
			confirm_button.disabled = false
			queue_redraw()
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			dragging = false
		elif not placed:
			_place_at(event.position)
		else:
			var area: Rect2 = Visuals.region_rect(
				lane_rect(target.lane), target.field_position, radius_fp
			)
			var offset: Vector2 = event.position - area.get_center()
			if (
				lane_rect(target.lane).has_point(event.position)
				and (offset / (area.size * 0.5)).length_squared() <= 1.0
			):
				dragging = true
				drag_offset = offset
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_place_at(event.position - drag_offset)
			accept_event()
		else:
			dragging = false


func _input(event: InputEvent) -> void:
	# Release can land over a button or outside the lane; always end the drag.
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		dragging = false
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancelled.emit()


func _process(delta: float) -> void:
	_sync_board_help()
	visuals.warm_next()
	visuals.advance(delta)
	queue_redraw()


func _draw() -> void:
	if is_instance_valid(battlefield):
		# Selection uses the live lane rectangles; the board remains visible.
		for lane in ["Lord", "Castle"]:
			draw_rect(lane_rect(lane), Color("b8c89a"), false, 2)
		if placed:
			var selected: Rect2 = lane_rect(target.lane)
			visuals.draw_area(self, Visuals.region_rect(selected, target.field_position, radius_fp), selected)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.045, 0.04, 0.97))
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(30, 38),
		"WEB · CHOOSE ITS REACH",
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 60,
		24,
		Color("e6d5af")
	)
	draw_string(
		font,
		Vector2(30, 70),
		(
			"Drag the web to adjust it, then click Set the Snare."
			if placed
			else "Click a spot in either lane to place the web. Then drag the web to adjust it."
		),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 60,
		16
	)
	for lane in ["Lord", "Castle"]:
		var rect: Rect2 = lane_rect(lane)
		draw_rect(rect, Color("253128") if lane == "Lord" else Color("202d34"))
		draw_rect(rect, Color("786a4a"), false, 2)
		draw_string(
			font,
			rect.position - Vector2(0, 10),
			lane.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			16
		)
	if placed:
		var selected: Rect2 = lane_rect(target.lane)
		visuals.draw_area(
			self, Visuals.region_rect(selected, target.field_position, radius_fp), selected
		)
	draw_string(
		font,
		Vector2(30, size.y - 82),
		(
			(
				"%s lane · enemy Marchers in the Web take 1 damage, then move at half speed."
				% target.lane
			)
			if placed
			else "Choose your ambush."
		),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 60,
		15,
		Color("c9bfa7")
	)
