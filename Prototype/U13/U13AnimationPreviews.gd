extends Control

signal closed
const PREVIEWS: Array = [
	{
		"title": "Orias · Web & Snare",
		"note": "Static web, crawling spider, radius and shared Guard-zone markers.",
		"scene": "res://Prototype/U13/U13WebPreview.tscn",
		"size": Vector2(1100, 850)
	},
	{
		"title": "Castle damage & repair",
		"note": "Cycle Castle types and Integrity, or scrub the damage manually.",
		"scene": "res://Prototype/U13/U13CastleDamagePreview.tscn",
		"size": Vector2(1280, 900)
	},
	{
		"title": "Breath of Life",
		"note": "Flower growth, healing sweep, expiration and staggered dying.",
		"scene": "res://Prototype/U13/U13BreathPreview.tscn",
		"size": Vector2(1200, 800)
	},
	{
		"title": "Scorch & combat numbers",
		"note": "Fire, intensity, Pyroclasm and example damage/healing numbers.",
		"scene": "res://Prototype/U13/U13ScorchPreview.tscn",
		"size": Vector2(960, 900)
	}
]
var host: Control
var status: Label
var active_preview: Control
var active_index: int = -1
var _choices: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 110
	var background := ColorRect.new()
	background.color = Color("111211")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	margin.add_child(row)
	var menu := VBoxContainer.new()
	menu.custom_minimum_size.x = 300
	menu.add_theme_constant_override("separation", 16)
	row.add_child(menu)
	_label(menu, "ANIMATION PREVIEWS", 22)
	_label(menu, "Choose an effect to revisit. Your Lord and Castle selections are kept.")
	for index in range(PREVIEWS.size()):
		var choice := Button.new()
		choice.text = PREVIEWS[index].title
		choice.custom_minimum_size.y = 48
		choice.pressed.connect(open_preview.bind(index))
		menu.add_child(choice)
		_choices.append(choice)
		_label(menu, PREVIEWS[index].note)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.add_child(spacer)
	var back := Button.new()
	back.text = "BACK TO LORDS & CASTLES"
	back.custom_minimum_size.y = 48
	back.pressed.connect(dismiss)
	menu.add_child(back)
	host = Control.new()
	host.clip_contents = true
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(host)
	host.resized.connect(_fit_preview)
	status = _label(host, "Select a preview on the left.", 22)
	status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _label(parent: Node, text_value: String, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func present() -> void:
	show()
	_choices[0].grab_focus()


func open_preview(index: int) -> void:
	if index < 0 or index >= PREVIEWS.size():
		return
	close_preview()
	# Lazy load: unopened previews do not load assets or run animation timers.
	var scene := load(PREVIEWS[index].scene) as PackedScene
	if scene == null:
		status.text = "Could not open this preview. You can return to your loadout."
		return
	var instance := scene.instantiate()
	if not instance is Control or not instance.has_signal("close_requested"):
		instance.free()
		status.text = "This preview could not initialize. You can return to your loadout."
		return
	active_index = index
	active_preview = instance
	active_preview.set("embedded", true)
	active_preview.connect("close_requested", close_preview)
	active_preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	active_preview.size = PREVIEWS[index].size
	status.hide()
	host.add_child(active_preview)
	_fit_preview()


func _fit_preview() -> void:
	if active_preview == null or host.size.x <= 0 or host.size.y <= 0:
		return
	var dimensions: Vector2 = PREVIEWS[active_index].size
	var factor: float = minf(host.size.x / dimensions.x, host.size.y / dimensions.y)
	active_preview.size = dimensions
	active_preview.scale = Vector2.ONE * factor
	active_preview.position = (host.size - dimensions * factor) * 0.5


func close_preview() -> void:
	if active_preview != null:
		# Stop processing and input immediately, before deferred deletion.
		var previous: Control = active_preview
		active_preview = null
		previous.process_mode = Node.PROCESS_MODE_DISABLED
		previous.hide()
		previous.queue_free()
	active_index = -1
	status.text = "Select a preview on the left."
	status.show()


func dismiss() -> void:
	close_preview()
	hide()
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or active_preview != null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		dismiss()
