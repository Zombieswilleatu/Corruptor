extends Control

signal closed

# Standalone audition scene. Catalog entries with no WAV remain visible as plans.
const CATALOG_PATH := "res://Prototype/U13/U13SoundCatalog.json"
const CUE_FOLDER := "res://Sounds/Cues/"
const SOURCE_FOLDER := "res://Sounds/SoundLabSources/"
const RENDERER := "res://Scripts/Sim/u13_sound_lab_render.py"
const DEFAULTS := {"volume": 50.0, "pitch": 1.0, "tempo": 1.0, "lowpass": 12000.0, "highpass": 20.0, "sine_hz": 90.0, "sine_mix": 0.0, "grit": 0.0, "reverb": 0.0, "trim_start": 0.0, "trim_end": 100.0, "fade_out": 0.0}

var cues: Array = []
var selected_id: String = ""
var current_area: String = "All"
var player: AudioStreamPlayer
var category_box: VBoxContainer
var cue_box: VBoxContainer
var search_field: LineEdit
var ready_only: CheckBox
var detail: Label
var playback: Label
var volume_slider: HSlider
var pitch_slider: HSlider
var knobs: Dictionary = {}
var draft_settings: Dictionary = {}
var loading_controls: bool = false
var save_button: Button
var source_button: Button
var game_button: Button
var loop_toggle: CheckBox
var return_button: Button
var playback_mode: String = ""
var preview_dirty: bool = false
var playback_generation: int = 0

func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440, 810)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	player = AudioStreamPlayer.new()
	add_child(player)
	player.finished.connect(_on_finished)
	_build_ui()
	_reload_catalog()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("12110f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	_label(layout, "CORRUPTOR   /   SOUND LAB", 26, Color("d8be88"))
	_label(layout, "Audition, alter and save short WAV cues. Source recordings stay untouched; game saves create backups.", 15)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 12)
	layout.add_child(toolbar)
	search_field = LineEdit.new()
	search_field.placeholder_text = "Find cue or sound direction..."
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_field.text_changed.connect(func(_value): _populate_rows())
	toolbar.add_child(search_field)
	ready_only = CheckBox.new()
	ready_only.text = "Playable only"
	ready_only.toggled.connect(func(_value): _populate_rows())
	toolbar.add_child(ready_only)
	_button(toolbar, "REFRESH FILES", _reload_catalog)
	return_button = _button(toolbar, "RETURN TO LORDS & CASTLES", dismiss)
	return_button.hide()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = 230
	columns.add_child(sidebar)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(side_scroll)
	category_box = VBoxContainer.new()
	category_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_box.add_theme_constant_override("separation", 5)
	side_scroll.add_child(category_box)
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 11)
	columns.add_child(main)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)
	cue_box = VBoxContainer.new()
	cue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cue_box.add_theme_constant_override("separation", 5)
	scroll.add_child(cue_box)
	var footer := PanelContainer.new()
	footer.custom_minimum_size.y = 366
	main.add_child(footer)
	var inspector := VBoxContainer.new()
	inspector.add_theme_constant_override("separation", 10)
	footer.add_child(inspector)
	detail = _label(inspector, "Choose a cue to see its direction.", 15)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	inspector.add_child(controls)
	_button(controls, "PREVIEW EDIT", _play_selected)
	_button(controls, "STOP", _stop)
	loop_toggle = CheckBox.new()
	loop_toggle.text = "LOOP"
	loop_toggle.tooltip_text = "Repeat the current sound while you adjust it. Gain moves live; other changes play on the next repeat."
	controls.add_child(loop_toggle)
	source_button = _button(controls, "RESET TO SOURCE", _reset_to_source)
	game_button = _button(controls, "PLAY SAVED", _play_saved_selected)
	game_button.tooltip_text = "Reload the current game WAV from disk, including your latest save. Source-only cues play their untouched source."
	save_button = _button(controls, "SAVE AS GAME SOUND", _save_to_game)
	playback = _label(controls, "Stopped", 14)
	playback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(inspector, "PLAY uses the current game WAV. PREVIEW EDIT auditions unsaved sliders; in LOOP, edits render for the next repeat.", 12, Color("b8aa91"))
	var settings := GridContainer.new()
	settings.columns = 2
	settings.add_theme_constant_override("h_separation", 22)
	settings.add_theme_constant_override("v_separation", 3)
	inspector.add_child(settings)
	volume_slider = _knob(settings, "Gain", "volume", 0, 200, 50, "%")
	volume_slider.tooltip_text = "Live audition level. 50% starts quieter; 100% is original level. Saving bakes this gain into the WAV."
	pitch_slider = _knob(settings, "Pitch", "pitch", 0.65, 1.6, 1.0, "x")
	_knob(settings, "Tempo", "tempo", 0.65, 1.6, 1.0, "x")
	_knob(settings, "Low pass", "lowpass", 250, 12000, 12000, " Hz")
	_knob(settings, "High pass", "highpass", 20, 2000, 20, " Hz")
	_knob(settings, "Sine Hz", "sine_hz", 40, 800, 90, " Hz")
	_knob(settings, "Sine mix", "sine_mix", 0, 50, 0, "%")
	var grit_slider := _knob(settings, "Distortion", "grit", 0, 100, 0, "%")
	grit_slider.tooltip_text = "Saturation plus increasingly rough bit crush at high settings. Level matched so texture is easier to judge."
	var reverb_slider := _knob(settings, "Reverb", "reverb", 0, 100, 0, "%")
	reverb_slider.tooltip_text = "Short, dark stone-room reflections. Higher settings add a longer tail; 0% stays dry."
	_knob(settings, "Trim start", "trim_start", 0, 80, 0, "%")
	_knob(settings, "Trim end", "trim_end", 20, 100, 100, "%")
	_knob(settings, "Fade out", "fade_out", 0, 250, 0, " ms")
	var trim_start_slider: HSlider = knobs["trim_start"]["slider"]
	var trim_end_slider: HSlider = knobs["trim_end"]["slider"]
	var fade_slider: HSlider = knobs["fade_out"]["slider"]
	trim_start_slider.tooltip_text = "Cut away this percentage of the beginning."
	trim_end_slider.tooltip_text = "Stop at this percentage of the recording."
	fade_slider.tooltip_text = "Soften the end to avoid an abrupt click."
	player.volume_linear = 1.0
	_update_actions()

func _label(parent: Node, value: String, size: int, tint: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 38
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _knob(parent: Node, caption: String, key: String, low: float, high: float, initial: float, suffix: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	parent.add_child(row)
	var name := _label(row, caption, 13)
	name.custom_minimum_size.x = 74
	var slider := HSlider.new()
	slider.custom_minimum_size.x = 145
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01 if key in ["pitch", "tempo"] else 1.0
	slider.value = initial
	row.add_child(slider)
	var value_label := _label(row, "", 13)
	value_label.custom_minimum_size.x = 66
	knobs[key] = {"slider": slider, "readout": value_label, "suffix": suffix}
	slider.value_changed.connect(_setting_changed.bind(key))
	_setting_changed(slider.value, key)
	return slider

func enable_return_to_setup() -> void:
	return_button.show()

func dismiss() -> void:
	_stop()
	closed.emit()

func _reload_catalog() -> void:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		playback.text = "Catalog not found"
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("cues"):
		playback.text = "Invalid catalog"
		return
	cues = parsed["cues"]
	_populate_categories()
	_populate_rows()
	if not selected_id.is_empty(): _select_cue(selected_id)

func _cue_path(cue: Dictionary) -> String:
	return CUE_FOLDER + str(cue.get("file", str(cue.get("id", "")) + ".wav"))

func _source_path(cue: Dictionary) -> String:
	return SOURCE_FOLDER + str(cue.get("file", str(cue.get("id", "")) + ".wav"))

func _ready_for(cue: Dictionary) -> bool:
	return FileAccess.file_exists(_source_path(cue)) or FileAccess.file_exists(_cue_path(cue))

func _input_path(cue: Dictionary) -> String:
	return _source_path(cue) if FileAccess.file_exists(_source_path(cue)) else _cue_path(cue)

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _populate_categories() -> void:
	_clear(category_box)
	var areas: Array[String] = ["All"]
	for cue in cues:
		var area: String = str(cue.get("area", ""))
		if area not in areas: areas.append(area)
	for area in areas:
		var total: int = 0
		var playable: int = 0
		for cue in cues:
			if area == "All" or cue.get("area") == area:
				total += 1
				if _ready_for(cue): playable += 1
		var category := _button(category_box, "%s  %d/%d" % [area, playable, total], _choose_area.bind(area))
		category.alignment = HORIZONTAL_ALIGNMENT_LEFT
		category.modulate = Color("d8be88") if area == current_area else Color("c6c1b6")

func _choose_area(area: String) -> void:
	current_area = area
	_populate_categories()
	_populate_rows()

func _populate_rows() -> void:
	_clear(cue_box)
	var query: String = search_field.text.strip_edges().to_lower()
	var shown: int = 0
	for cue in cues:
		if current_area != "All" and cue.get("area") != current_area: continue
		var summary: String = "%s %s %s %s" % [cue.get("id", ""), cue.get("title", ""), cue.get("direction", ""), cue.get("area", "")]
		if not query.is_empty() and query not in summary.to_lower(): continue
		var available: bool = _ready_for(cue)
		if ready_only.button_pressed and not available: continue
		shown += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		cue_box.add_child(row)
		var title: Button = _button(row, "%s  ·  %s" % [cue.get("title", ""), cue.get("area", "")], _select_cue.bind(str(cue.get("id", ""))))
		title.alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.tooltip_text = str(cue.get("direction", ""))
		title.modulate = Color("e1d3b4") if available else Color("8a8580")
		var status: String = "GAME" if FileAccess.file_exists(_cue_path(cue)) else ("SOURCE" if available else "PLANNED")
		var badge := _label(row, "%s · %s" % [cue.get("priority", "B"), status], 13, Color("b8c59f") if available else Color("847e76"))
		badge.custom_minimum_size.x = 115
		var play := _button(row, "PLAY", _play_saved_cue.bind(str(cue.get("id", ""))))
		play.tooltip_text = "Play the current saved game WAV; before the first save, play the source."
		play.disabled = not available
	if shown == 0: _label(cue_box, "No cues match this filter.", 16)

func _find_cue(id: String) -> Dictionary:
	for cue in cues:
		if cue.get("id") == id: return cue
	return {}

func _select_cue(id: String) -> void:
	var cue: Dictionary = _find_cue(id)
	if cue.is_empty(): return
	if selected_id != id:
		if player.playing: _stop()
		selected_id = id
		_set_controls(draft_settings.get(_cue_path(cue), DEFAULTS))
	var state: String = "Game WAV" if FileAccess.file_exists(_cue_path(cue)) else ("Source only" if _ready_for(cue) else "Planned")
	detail.text = "%s  ·  %s  ·  %s  ·  priority %s\n%s\n%s" % [cue.get("title", ""), cue.get("area", ""), state, cue.get("priority", "B"), cue.get("direction", ""), _cue_path(cue)]
	_update_actions()

func _setting_changed(value: float, key: String) -> void:
	var info: Dictionary = knobs[key]
	var display: String = ("%.2f" % value) if key in ["pitch", "tempo"] else str(roundi(value))
	var readout: Label = info["readout"]
	readout.text = display + str(info["suffix"])
	if not loading_controls and not selected_id.is_empty():
		var cue: Dictionary = _find_cue(selected_id)
		if not cue.is_empty(): draft_settings[_cue_path(cue)] = _settings()
	if key == "volume" and playback_mode == "preview":
		player.volume_linear = value / 100.0
	elif key != "volume" and not loading_controls and playback_mode == "preview":
		preview_dirty = true

func _settings() -> Dictionary:
	var result: Dictionary = {}
	for key in knobs:
		var slider: HSlider = knobs[key]["slider"]
		result[key] = slider.value
	return result

func _set_controls(values: Dictionary) -> void:
	loading_controls = true
	for key in knobs:
		var slider: HSlider = knobs[key]["slider"]
		slider.value = float(values.get(key, DEFAULTS[key]))
		_setting_changed(slider.value, key)
	loading_controls = false

func _update_actions() -> void:
	var cue: Dictionary = _find_cue(selected_id)
	var available: bool = not cue.is_empty() and _ready_for(cue)
	source_button.disabled = not available
	save_button.disabled = not available
	game_button.disabled = not available

func _play_selected() -> void:
	if not selected_id.is_empty(): _preview_cue(selected_id)

func _preview_cue(id: String) -> void:
	_select_cue(id)
	var cue: Dictionary = _find_cue(id)
	if cue.is_empty() or not _ready_for(cue):
		playback.text = "Still planned"
		return
	var preview_path: String = "user://sound_lab_preview.wav"
	if not _render(cue, preview_path, false): return
	_play_file(preview_path, "Preview: " + str(cue.get("title", "")))

func _play_saved_selected() -> void:
	if not selected_id.is_empty(): _play_saved_cue(selected_id)

func _play_saved_cue(id: String) -> void:
	_select_cue(id)
	var cue: Dictionary = _find_cue(id)
	if cue.is_empty() or not _ready_for(cue):
		playback.text = "Still planned"
		return
	var saved_path: String = _cue_path(cue)
	if FileAccess.file_exists(saved_path):
		_play_file(saved_path, "Game WAV: " + str(cue.get("title", "")), "game")
	else:
		_play_file(_source_path(cue), "Source only (not saved): " + str(cue.get("title", "")), "game")

func _play_file(path: String, caption: String, mode: String = "preview") -> void:
	var sound := AudioStreamWAV.load_from_file(path)
	if sound == null:
		playback.text = "Could not load WAV"
		return
	player.stop()
	playback_generation += 1
	playback_mode = mode
	preview_dirty = false
	player.volume_linear = 1.0 if playback_mode == "game" else volume_slider.value / 100.0
	player.stream = sound
	player.play()
	playback.text = caption

func _render(cue: Dictionary, output_path: String, backup: bool) -> bool:
	var python: String = OS.get_environment("CORRUPTOR_SOUND_PYTHON")
	if python.is_empty(): python = "python"
	var values: Dictionary = _settings()
	var args := PackedStringArray([
		ProjectSettings.globalize_path(RENDERER),
		"--source", ProjectSettings.globalize_path(_input_path(cue)),
		"--output", ProjectSettings.globalize_path(output_path),
		"--volume", str(float(values["volume"]) / 100.0) if backup else "1.0",
		"--pitch", str(values["pitch"]),
		"--tempo", str(values["tempo"]),
		"--lowpass", str(values["lowpass"]),
		"--highpass", str(values["highpass"]),
		"--sine-hz", str(values["sine_hz"]),
		"--sine-mix", str(float(values["sine_mix"]) / 100.0),
		"--grit", str(float(values["grit"]) / 100.0),
		"--reverb", str(float(values["reverb"]) / 100.0),
		"--trim-start", str(float(values["trim_start"]) / 100.0),
		"--trim-end", str(float(values["trim_end"]) / 100.0),
		"--fade-out", str(values["fade_out"]),
	])
	if backup: args.append_array(PackedStringArray(["--backup", ProjectSettings.globalize_path("res://Sounds/SoundLabBackups")]))
	var response: Array = []
	var code: int = OS.execute(python, args, response, true)
	if code != 0:
		playback.text = "Render failed; see console"
		push_error("Sound Lab render failed: " + str(response))
		return false
	return true

func _reset_to_source() -> void:
	var cue: Dictionary = _find_cue(selected_id)
	if cue.is_empty() or not _ready_for(cue): return
	draft_settings.erase(_cue_path(cue))
	_set_controls(DEFAULTS)
	# Reload the untouched source from disk, never the most recent preview.
	_play_file(_input_path(cue), "Source: " + str(cue.get("title", "")))

func _save_to_game() -> void:
	var cue: Dictionary = _find_cue(selected_id)
	if cue.is_empty() or not _ready_for(cue): return
	player.stop()
	playback_generation += 1
	playback_mode = ""
	preview_dirty = false
	if not _render(cue, _cue_path(cue), true): return
	playback.text = "Saved game WAV + backup"
	_update_actions()
	_populate_categories()
	_populate_rows()

func _stop() -> void:
	player.stop()
	playback_generation += 1
	playback_mode = ""
	preview_dirty = false
	playback.text = "Stopped"

func _on_finished() -> void:
	if loop_toggle.button_pressed and player.stream != null:
		call_deferred("_repeat_or_refresh", playback_generation)
	else:
		playback.text = "Finished"

func _repeat_or_refresh(generation: int) -> void:
	if generation != playback_generation or not loop_toggle.button_pressed or playback_mode.is_empty() or player.stream == null:
		return
	if preview_dirty and playback_mode == "preview":
		var cue: Dictionary = _find_cue(selected_id)
		if cue.is_empty() or not _ready_for(cue):
			playback.text = "Preview source missing"
			return
		var preview_path: String = "user://sound_lab_preview.wav"
		if not _render(cue, preview_path, false): return
		var sound := AudioStreamWAV.load_from_file(preview_path)
		if sound == null:
			playback.text = "Could not load preview WAV"
			return
		player.stream = sound
		preview_dirty = false
		playback.text = "Preview: " + str(cue.get("title", ""))
	player.play()
