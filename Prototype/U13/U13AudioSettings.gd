extends Node
const MUSIC_BUS: StringName = &"CorruptorMusic"
const SFX_BUS: StringName = &"CorruptorSFX"
const SAVE_PATH: String = "user://corruptor_audio_options.cfg"
const OptionsView = preload("res://Prototype/U13/U13SoundOptions.gd")
var volumes: Dictionary = {"master":100.0, "music":50.0, "sfx":100.0}
var music: Node
var panel: CanvasLayer
var _save_timer: Timer
var _music_players: Array[WeakRef] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		for key in volumes: volumes[key] = clampf(float(config.get_value("audio", key, volumes[key])), 0.0, 100.0)
	else:
		var legacy := ConfigFile.new()
		if legacy.load("res://Music/GameMusic/settings.cfg") == OK:
			volumes.music = clampf(float(legacy.get_value("music", "volume_percent", 50.0)), 0.0, 100.0)
	for key in volumes: _apply(key)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.35
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)
	panel = OptionsView.new()
	panel.audio = self
	add_child(panel)
	get_tree().node_added.connect(_node_added)
	_walk(get_tree().root)

func _walk(node: Node) -> void:
	_node_added(node)
	for child in node.get_children(): _walk(child)

func _node_added(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		_route.call_deferred(node)
	var script: Script = node.get_script()
	if script != null and script.resource_path.ends_with("/TitleScreen.gd"):
		_title_button.call_deferred(node)

func _route(player: Node) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree(): return
	if player.bus != &"Master" and player.bus != MUSIC_BUS and player.bus != SFX_BUS: return
	var role: String = str(player.get_meta("corruptor_audio_role", ""))
	if role.is_empty():
		role = "sfx"
		var ancestor: Node = player.get_parent()
		while ancestor != null:
			var script: Script = ancestor.get_script()
			var path: String = script.resource_path if script != null else ""
			if path.get_file() in ["TitleScreen.gd", "PrologueRunner.gd", "U13MusicLab.gd", "U13GameMusic.gd"]:
				role = "music"
				break
			ancestor = ancestor.get_parent()
		if player.is_in_group("corruptor_setup_theme"): role = "music"
	player.set_meta("corruptor_audio_role", role)
	player.bus = MUSIC_BUS if role == "music" else SFX_BUS
	if role == "music": _music_players.append(weakref(player))

func set_volume(category: String, percent: float) -> void:
	if not volumes.has(category): return
	volumes[category] = clampf(percent, 0.0, 100.0)
	_apply(category)
	_save_timer.start()

func _apply(category: String) -> void:
	var bus: StringName = &"Master" if category == "master" else (MUSIC_BUS if category == "music" else SFX_BUS)
	var index: int = AudioServer.get_bus_index(bus)
	var value: float = float(volumes[category])
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value / 100.0, 0.000001)))

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in volumes: config.set_value("audio", key, volumes[key])
	if config.save(SAVE_PATH) != OK: push_warning("Could not save sound options.")

func register_music(controller: Node) -> void:
	music = controller
	_install_board_buttons.call_deferred(controller.get_parent())

func _button(parent: Node) -> Button:
	var button := Button.new()
	button.name = "SoundOptionsButton"
	button.text = "OPTIONS"
	button.tooltip_text = "Sound options · F10"
	button.custom_minimum_size = Vector2(110, 38)
	button.pressed.connect(open_options)
	parent.add_child(button)
	return button

func _install_board_buttons(board: Node) -> void:
	if not is_instance_valid(board): return
	var header = board.get("header")
	if header != null and header.get("history_box") != null and not header.has_meta("compact_header"): _button(header.history_box)
	var picker = board.get("setup_picker")
	if picker != null:
		var start = picker.get("start_button")
		if start != null: _button(start.get_parent().get_parent())

func _title_button(title: Node) -> void:
	if not is_instance_valid(title) or title.has_node("SoundOptionsButton"): return
	var button := _button(title)
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	button.position = Vector2(24, -66)
	button.size = Vector2(160, 42)

func open_options() -> void:
	panel.open()

func now_playing() -> String:
	if is_instance_valid(music) and not music._current.is_empty() and music._active:
		return music.current_song_text()
	for ref in _music_players:
		var player = ref.get_ref()
		if player != null and player.playing and not player.stream_paused and player.stream != null:
			var filename: String = player.stream.resource_path.get_file()
			return filename if not filename.is_empty() else "Main theme / music preview"
	return music.current_song_text() if is_instance_valid(music) else "No music playing"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			if panel.visible: panel.close()
			else: open_options()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and panel.visible:
			panel.close()
			get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if _save_timer != null: save_settings()
