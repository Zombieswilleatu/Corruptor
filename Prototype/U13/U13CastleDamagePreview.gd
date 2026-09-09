extends "res://Prototype/U13/U13VisualPreview.gd"

# Retained visual harness. Uses the real board card and artwork renderer.
# No match, rules owner, workers, opponents or foundation suites are started.
const Card = preload("res://Prototype/U13/U13LayoutCard.gd")
const Artwork = preload("res://Prototype/U13/U13CastleArtwork.gd")
const Textures = preload("res://Prototype/U13/U13BoardTextures.gd")
const Castles = preload("res://Prototype/UI2/CastleArtCatalog.gd")
const TYPES: Array[String] = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]
const STEPS: Array[int] = [21, 17, 14, 11, 7, 4, 1, 4, 7, 11, 14, 17]
const MAXIMUM: int = 21

var _large
var _board_size
var _references: Array = []
var _picker: OptionButton
var _slider: HSlider
var _status: Label
var _play: CheckButton
var _timer: Timer
var _image: Texture2D
var _integrity: int = MAXIMUM
var _step: int = 0


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	_label(root, "CASTLE DAMAGE — settled shards preview", 24)
	_label(
		root,
		"Cycles damage and repair every 2 seconds. Same renderer as the board; no game running."
	)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	root.add_child(controls)
	_picker = OptionButton.new()
	for castle_type in TYPES:
		_picker.add_item(
			castle_type.replace("SiegeEngine", "Siege Engine").replace(
				"SummoningCircle", "Summoning Circle"
			)
		)
	controls.add_child(_picker)
	_picker.item_selected.connect(_choose_castle)
	_play = CheckButton.new()
	_play.text = "Auto cycle"
	_play.button_pressed = true
	controls.add_child(_play)
	_play.toggled.connect(_toggle_play)
	_button(controls, "Previous", _previous)
	_button(controls, "Next", _next)
	_button(controls, "Restart cycle", _restart)
	_button(controls, "Back to previews" if embedded else "Exit", _close_preview)
	var slider_row := HBoxContainer.new()
	root.add_child(slider_row)
	_label(slider_row, "Integrity")
	_slider = HSlider.new()
	_slider.min_value = 1
	_slider.max_value = MAXIMUM
	_slider.step = 1
	_slider.value = MAXIMUM
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.add_child(_slider)
	_slider.value_changed.connect(_scrub)
	_status = _label(root, "", 20)
	var samples := HBoxContainer.new()
	samples.add_theme_constant_override("separation", 36)
	root.add_child(samples)
	var enlarged := VBoxContainer.new()
	samples.add_child(enlarged)
	_label(enlarged, "ENLARGED — animated")
	_large = _card(enlarged, Vector2(300, 436))
	var comparisons := VBoxContainer.new()
	comparisons.add_theme_constant_override("separation", 12)
	samples.add_child(comparisons)
	_label(comparisons, "FIXED REFERENCES — same Castle, three damage bands")
	var reference_row := HBoxContainer.new()
	reference_row.add_theme_constant_override("separation", 20)
	comparisons.add_child(reference_row)
	for title in ["Undamaged · 21/21", "Some damage · 11/21", "Heavy damage · 4/21"]:
		var column := VBoxContainer.new()
		reference_row.add_child(column)
		_label(column, title)
		_references.append(_card(column, Vector2(160, 232)))
	_label(comparisons, "BOARD SIZE — animated (124 × 180)")
	_board_size = _card(comparisons, Vector2(124, 180))
	_label(
		root,
		"Wider cracks, lit fracture edges and gravity-settled pieces. Repairs reassemble the card."
	)
	_label(root, "Above 2/3: intact. At 2/3 or below: fractured. At 1/3 or below: heavily damaged.")
	_timer = Timer.new()
	_timer.wait_time = 2.0
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_choose_castle(0)
	_timer.start()


func _label(parent: Node, text: String, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


func _card(parent: Node, dimensions: Vector2):
	var card = Card.new()
	card.custom_minimum_size = dimensions
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(card)
	# Inspection normally shows the original art; disable it in this diagnostic
	# so an enlarged inspection popup cannot be mistaken for the damaged image.
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.input_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _bind(card, integrity: int, previous: Dictionary = {}) -> void:
	card.bind_art(_image, "%d / %d" % [integrity, MAXIMUM], "Castle damage preview")
	card.bind_castle_art(
		{"construction_state": "active", "integrity": integrity, "max_integrity": MAXIMUM}, previous
	)


func _choose_castle(index: int) -> void:
	_image = Textures.texture(Castles.ART_PATHS[TYPES[index]])
	if _image == null:
		push_error("Castle preview could not load " + TYPES[index])
		_close_preview(1)
		return
	for sample in range(_references.size()):
		_bind(_references[sample], [21, 11, 4][sample])
	_show(_integrity, false)


func _show(integrity: int, animate: bool = true) -> void:
	# Capture the actual displayed ratio, including interrupted transitions.
	for card in [_large, _board_size]:
		var previous: Dictionary = {}
		if animate and card.castle_artwork != null:
			previous = {"construction": false, "ratio": card.castle_artwork.display_ratio}
		_bind(card, integrity, previous)
	_integrity = integrity
	_slider.set_value_no_signal(integrity)
	var band: String = ["UNDAMAGED", "SOME DAMAGE", "HEAVILY DAMAGED"][Artwork.damage_band(
		integrity, MAXIMUM
	)]
	_status.text = (
		"%s — %d / %d Integrity — %s" % [TYPES[_picker.selected], integrity, MAXIMUM, band]
	)
	print("CASTLE PREVIEW ", _status.text)


func _toggle_play(enabled: bool) -> void:
	if _timer == null:
		return
	if enabled:
		_timer.start()
	else:
		_timer.stop()


func _scrub(value: float) -> void:
	_play.button_pressed = false
	_show(int(value))


func _previous() -> void:
	_play.button_pressed = false
	_step = posmod(_step - 1, STEPS.size())
	_show(STEPS[_step])


func _next() -> void:
	_play.button_pressed = false
	_tick()


func _tick() -> void:
	_step = (_step + 1) % STEPS.size()
	_show(STEPS[_step])


func _restart() -> void:
	_step = 0
	_show(STEPS[0])
	_play.button_pressed = true
	_timer.start()


func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_play.button_pressed = not _play.button_pressed


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("161719"))
