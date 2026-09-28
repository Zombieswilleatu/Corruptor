extends CanvasLayer
var audio: Node
var sliders: Dictionary = {}
var labels: Dictionary = {}
var song_label: Label
var cache_label: Label
var cache_button: Button
var _refresh_clock: float = 0.0
var match_actions: GridContainer
var action_sources: Dictionary = {}

func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171511")
	style.border_color = Color("93713d")
	style.set_border_width_all(2)
	style.set_content_margin_all(26)
	box.add_theme_stylebox_override("panel", style)
	preload("res://Prototype/U13/U13MenuSkin.gd").apply(box)
	center.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	box.add_child(column)
	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	for key in ["master", "music", "sfx"]:
		var row := VBoxContainer.new()
		column.add_child(row)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 18)
		row.add_child(label)
		labels[key] = label
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(500, 26)
		slider.value_changed.connect(func(value: float):
			audio.set_volume(key, value)
			_set_label(key, value))
		row.add_child(slider)
		sliders[key] = slider
	song_label = Label.new()
	song_label.custom_minimum_size = Vector2(500, 52)
	song_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(song_label)
	cache_label = Label.new()
	cache_label.custom_minimum_size = Vector2(500, 48)
	cache_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(cache_label)
	cache_button = Button.new()
	cache_button.custom_minimum_size.y = 42
	cache_button.pressed.connect(func():
		if is_instance_valid(audio.music):
			if audio.music.precache_running: audio.music.cancel_precache()
			else: audio.music.start_precache()
		_refresh())
	column.add_child(cache_button)
	match_actions = GridContainer.new()
	match_actions.columns = 3
	match_actions.add_theme_constant_override("h_separation", 8)
	match_actions.add_theme_constant_override("v_separation", 8)
	column.add_child(match_actions)
	var close_button := Button.new()
	close_button.text = "DONE"
	close_button.custom_minimum_size.y = 42
	close_button.pressed.connect(close)
	column.add_child(close_button)
	hide()

func _set_label(key: String, value: float) -> void:
	labels[key].text = ("SFX" if key == "sfx" else key.capitalize()) + " · %d%%" % roundi(value)

func open() -> void:
	_build_match_actions()
	for key in sliders:
		sliders[key].set_value_no_signal(audio.volumes[key])
		_set_label(key, audio.volumes[key])
	_refresh()
	show()
	sliders.master.grab_focus()

func close() -> void:
	audio.save_settings()
	hide()

func _process(delta: float) -> void:
	if not visible: return
	_refresh_clock += delta
	if _refresh_clock >= 0.2:
		_refresh_clock = 0.0
		_refresh()

func _refresh() -> void:
	for proxy in action_sources:
		var source = action_sources[proxy].get_ref()
		proxy.disabled = source == null or source.disabled or not source.visible
	song_label.text = "NOW PLAYING\n" + audio.now_playing()
	var has_music: bool = is_instance_valid(audio.music)
	cache_button.disabled = not has_music
	cache_button.text = "STOP PRECACHE" if has_music and audio.music.precache_running else "PRECACHE ALL MUSIC"
	cache_label.text = audio.music.precache_status() if has_music else "Open game setup to prepare all your music."


func _build_match_actions() -> void:
	for child in match_actions.get_children():
		match_actions.remove_child(child)
		child.queue_free()
	action_sources.clear()
	for layout in get_tree().get_nodes_in_group("corruptor_compact_header"):
		# Ignore hidden layout probes used by the pregame castle selector.
		if layout.get_viewport() != get_viewport() or not layout.header.is_visible_in_tree(): continue
		for source in layout.utility_buttons:
			if not is_instance_valid(source) or not source.visible: continue
			var proxy := Button.new()
			proxy.text = source.text.to_upper()
			proxy.tooltip_text = source.tooltip_text
			proxy.custom_minimum_size.y = 34
			proxy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var ref: WeakRef = weakref(source)
			proxy.pressed.connect(func():
				var original = ref.get_ref()
				if original == null or original.disabled or not original.visible: return
				close()
				original.pressed.emit())
			match_actions.add_child(proxy)
			action_sources[proxy] = ref
		break
	match_actions.visible = not action_sources.is_empty()
