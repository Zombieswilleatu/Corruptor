extends Node
const MENU := "res://Prototype/U13/U13MainMenu.tscn"
const BOARD := "res://Prototype/U13/U13PlayableBoard.tscn"
var busy: bool = false
var last_error: String = ""
var curtain: CanvasLayer
var status: Label

func _ready() -> void:
	curtain = CanvasLayer.new()
	curtain.layer = 1500
	add_child(curtain)
	var shade := ColorRect.new()
	shade.color = Color("100f13")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.add_child(shade)
	status = Label.new()
	status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 25)
	status.add_theme_color_override("font_color", Color("ccb991"))
	shade.add_child(status)
	curtain.hide()

func launch(request: Dictionary) -> void:
	if busy: return
	if request.get("action") == "load":
		var file := FileAccess.open(str(request.get("path", "")), FileAccess.READ)
		if file == null:
			_fail("That saved game could not be read. Choose another file.")
			return
		var json := JSON.new()
		var result: Error = json.parse(file.get_as_text())
		file.close()
		if result != OK or not json.data is Dictionary or json.data.get("codec") != "U13_GAME_JSON_SAVE_V1" or not json.data.get("payload") is String:
			_fail("This is not a Corruptor saved game. Choose a u13-playable JSON save.")
			return
	busy = true
	last_error = ""
	status.text = "Opening the development menu…" if request.get("action") == "dev" else "Preparing the battlefield…"
	curtain.show()
	await get_tree().process_frame
	var error: Error = ResourceLoader.load_threaded_request(BOARD)
	if error != OK:
		_fail("Could not open the playable game (error %d)." % error)
		return
	while ResourceLoader.load_threaded_get_status(BOARD) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(BOARD) != ResourceLoader.THREAD_LOAD_LOADED:
		_fail("The playable game could not be loaded. Check the runner log.")
		return
	var scene: PackedScene = ResourceLoader.load_threaded_get(BOARD)
	error = get_tree().change_scene_to_packed(scene)
	if error != OK:
		_fail("Could not enter the playable game (error %d)." % error)
		return
	await get_tree().scene_changed
	var board = get_tree().current_scene
	if not board.has_method("start_loadout") or not board.get("_runtime_ok"):
		_fail("The game could not start. Use the current Godot runner and check its log.")
		await return_to_menu()
		return
	_install_return(board)
	if request.get("action") == "new":
		if request.get("hotseat", false):
			if not board.setup_picker.has_method("hotseat_enabled"):
				_fail("Install the hotseat update before starting a two-player match.")
				await return_to_menu()
				return
			board.setup_picker.play_mode.select(1)
			board.setup_picker.replay_mode.select(int(request.get("replay", 0)))
			board.setup_picker._hotseat_mode_changed()
		board.start_loadout(request.lords, request.castles, true)
	elif request.get("action") == "load":
		board._load_game(request.path)
	if request.get("action") != "dev" and not board.match_started:
		var detail: String = board._busy_label.text
		if detail.is_empty(): detail = "The match could not be opened. Check the save file or selected loadout."
		_fail(detail)
		await return_to_menu()
		return
	if request.get("action") != "dev": stop_theme()
	busy = false
	curtain.hide()

func _fail(message: String) -> void:
	last_error = message
	busy = false
	curtain.hide()
	var current := get_tree().current_scene
	if current != null and current.has_method("show_error"): current.show_error(message)

func return_to_menu() -> void:
	if busy: return
	busy = true
	status.text = "Returning to the Domain…"
	curtain.show()
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(MENU)
	if error == OK: await get_tree().scene_changed
	else: last_error = "Could not return to the main menu (error %d)." % error
	busy = false
	curtain.hide()

func _install_return(board: Node) -> void:
	var button := Button.new()
	button.text = "MAIN MENU"
	button.tooltip_text = "Return to the Domain menu."
	board.setup_picker.cancel_button.get_parent().add_child(button)
	button.pressed.connect(func():
		if board.match_started:
			var confirm := ConfirmationDialog.new()
			confirm.title = "Return to main menu?"
			confirm.dialog_text = "Unsaved progress will be lost. Return to the main menu?"
			board.add_child(confirm)
			confirm.confirmed.connect(return_to_menu)
			confirm.canceled.connect(confirm.queue_free)
			confirm.popup_centered()
		else: return_to_menu())

func ensure_theme() -> void:
	for player in get_tree().get_nodes_in_group("corruptor_setup_theme"):
		if player is AudioStreamPlayer:
			player.stream_paused = false
			if not player.playing: player.play()
			return
	var path := "res://Music/MenuThemeConcept.mp3"
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path): return
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else AudioStreamMP3.load_from_file(path)
	if stream == null: return
	if stream is AudioStreamMP3: stream.loop = true
	var player := AudioStreamPlayer.new()
	player.name = "MainTheme"
	player.stream = stream
	player.volume_db = -6.0
	player.set_meta("corruptor_audio_role", "music")
	player.add_to_group("corruptor_setup_theme")
	get_tree().root.add_child(player)
	player.play()

func stop_theme() -> void:
	for player in get_tree().get_nodes_in_group("corruptor_setup_theme"):
		if player is AudioStreamPlayer:
			player.stop()
			player.remove_from_group("corruptor_setup_theme")
			player.queue_free()

var _click_player: AudioStreamPlayer
func click(back: bool = false) -> void:
	var path: String = "res://Sounds/Cues/modal_back.wav" if back else "res://Sounds/Cues/modal_choose.wav"
	if not FileAccess.file_exists(path): return
	if not is_instance_valid(_click_player):
		_click_player = AudioStreamPlayer.new()
		_click_player.set_meta("corruptor_audio_role", "sfx")
		_click_player.bus = &"CorruptorSFX" if AudioServer.get_bus_index(&"CorruptorSFX") >= 0 else &"Master"
		add_child(_click_player)
	# Read the saved cue, including edits made in the Sound Lab.
	_click_player.stream = AudioStreamWAV.load_from_file(path)
	_click_player.volume_db = -10.0 if back else -9.0
	if _click_player.stream != null: _click_player.play()
