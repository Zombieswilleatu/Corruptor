extends Node

const Rules = preload("res://Prototype/U13/U13LordRules.gd")
const Textures = preload("res://Prototype/U13/U13BoardTextures.gd")
const HOLD_SECONDS: float = 0.35
const MOVE_CANCEL_DISTANCE: float = 9.0
var source: Control
var card_texture: Texture2D
var hold_timer: Timer
var preview_layer: CanvasLayer
var preview_root: Control
var preview_art: TextureRect
var back_art: TextureRect
var back_margin: MarginContainer
var back_scroll: ScrollContainer
var frame: PanelContainer
var back: VBoxContainer
var passive_label: Label
var breach_label: Label
var state_label: Label
var title_label: Label
var lord: String = ""
var active: bool = true
var in_breach: bool = false
var showing_back: bool = false
var _down: bool = false
var _held: bool = false
var _moved: bool = false
var _big_press: bool = false
var _press_position: Vector2


func configure(p_source: Control, texture: Texture2D) -> void:
	source = p_source
	card_texture = texture
	hold_timer = Timer.new()
	hold_timer.one_shot = true
	hold_timer.wait_time = HOLD_SECONDS
	hold_timer.timeout.connect(_on_hold_timeout)
	add_child(hold_timer)
	preview_layer = CanvasLayer.new()
	preview_layer.layer = 110
	add_child(preview_layer)
	preview_root = Control.new()
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.hide()
	preview_layer.add_child(preview_root)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.65)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_root.add_child(veil)
	frame = PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14120f")
	style.border_color = Color("b3945d")
	style.set_border_width_all(2)
	style.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", style)
	preview_root.add_child(frame)
	preview_art = TextureRect.new()
	preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_art.stretch_mode = TextureRect.STRETCH_SCALE
	preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(preview_art)
	back_art = TextureRect.new()
	back_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back_art.stretch_mode = TextureRect.STRETCH_SCALE
	back_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(back_art)
	back_margin = MarginContainer.new()
	back_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		back_margin.add_theme_constant_override("margin_" + side, 28)
	frame.add_child(back_margin)
	var scroll := ScrollContainer.new()
	back_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	back_margin.add_child(scroll)
	back = VBoxContainer.new()
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_constant_override("separation", 14)
	scroll.add_child(back)
	title_label = _label(back, 25)
	title_label.hide()
	state_label = _label(back, 16)
	passive_label = _label(back, 18)
	breach_label = _label(back, 18)
	for label in [state_label, passive_label, breach_label]:
		var ink_panel := StyleBoxFlat.new()
		ink_panel.bg_color = Color(0.025, 0.02, 0.015, 0.82)
		ink_panel.set_content_margin_all(10)
		label.add_theme_stylebox_override("normal", ink_panel)
	var hint := _label(back, 14)
	hint.text = "Click to flip · Hold either card to close · Esc to close"
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	source.gui_input.connect(_on_source_gui_input)
	set_process_input(false)
	set_texture(texture)
	_render()


func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("ebdab4"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_outline_size", 4)
	parent.add_child(label)
	return label


func set_texture(texture: Texture2D) -> void:
	card_texture = texture
	if preview_art != null:
		preview_art.texture = texture


func bind_lord(name_value: String, alive: bool, breach: bool) -> void:
	if lord != name_value and preview_root.visible:
		_hide_preview()
	lord = name_value
	back_art.texture = Textures.lord_texture(lord, true)
	active = alive
	in_breach = breach
	_render()


func _render() -> void:
	if back == null:
		return
	var rules: Dictionary = Rules.for_lord(lord)
	title_label.text = lord.to_upper()
	state_label.text = "IN THE BREACH" if in_breach else ("ACTIVE LORD" if active else "BANISHED · NOT IN THE BREACH")
	passive_label.text = "PASSIVES\n\n" + rules.passive
	breach_label.text = "BREACH\n\n" + rules.breach
	passive_label.modulate = Color.WHITE if active and not in_breach else Color("858585")
	breach_label.modulate = Color("ffe4a0") if in_breach else Color("858585")
	preview_art.visible = not showing_back
	back_art.visible = showing_back
	back_margin.visible = showing_back
	back.visible = showing_back


func _on_source_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_hold(source.get_global_rect().position + event.position, false)


func _start_hold(position_value: Vector2, big: bool) -> void:
	_down = true
	_held = false
	_moved = false
	_big_press = big
	_press_position = position_value
	hold_timer.start()
	set_process_input(true)


func _on_hold_timeout() -> void:
	if not _down or _moved or lord.is_empty():
		return
	_held = true
	if preview_root.visible:
		_hide_preview()
	else:
		_show_preview()
	if source is BaseButton:
		source.set_pressed_no_signal(false)


func _input(event: InputEvent) -> void:
	if preview_root.visible and showing_back and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		back_scroll.scroll_vertical += 48 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -48
		get_viewport().set_input_as_handled()
		return
	if preview_root.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_hide_preview()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _down:
		if event.position.distance_to(_press_position) > MOVE_CANCEL_DISTANCE:
			_moved = true
			hold_timer.stop()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and preview_root.visible:
			if frame.get_global_rect().has_point(event.position):
				_start_hold(event.position, true)
			elif source.get_global_rect().has_point(event.position):
				_start_hold(event.position, false)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _down:
			hold_timer.stop()
			var consume: bool = _held or preview_root.visible
			if _big_press and not _held and not _moved and frame.get_global_rect().has_point(event.position):
				showing_back = not showing_back
				_render()
			_down = false
			if consume:
				get_viewport().set_input_as_handled()
			set_process_input(preview_root.visible)
	# Inspection must never click through to declarations or drag board cards.
	if preview_root.visible and (event is InputEventMouseButton or event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()


func _show_preview() -> void:
	preview_root.size = source.get_viewport_rect().size
	var ratio: float = float(card_texture.get_width()) / float(card_texture.get_height()) if card_texture != null else 2.0 / 3.0
	var height: float = minf(900, minf(preview_root.size.y - 48, (preview_root.size.x - 40) / ratio))
	frame.size = Vector2(height * ratio, height)
	back_margin.add_theme_constant_override("margin_top", int(height * 0.115))
	frame.position = (preview_root.size - frame.size) * 0.5
	showing_back = false
	_render()
	preview_root.show()
	set_process_input(true)


func _hide_preview() -> void:
	preview_root.hide()
	showing_back = false
	if not _down:
		set_process_input(false)
