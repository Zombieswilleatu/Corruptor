extends Node
## Child of the playable board only: no title/debug autoload or board rewrites.
const Track = preload("res://Prototype/U13/U13GameMusicTrack.gd")
const CACHE_PATH: String = "user://corruptor_game_music_analysis_v1.cfg"
const SETTINGS_PATH: String = "res://Music/GameMusic/settings.cfg"
@export var music_folder: String = "res://Music/GameMusic"
@export var minimum_track_seconds: float = 240.0
@export_range(0.0, 100.0, 1.0) var volume_percent: float = 50.0

var _player: AudioStreamPlayer
var _cache := ConfigFile.new()
var _thread: Thread
var _cancel_mutex := Mutex.new()
var _cancelled: bool = false
var _mix_rate: float = 44100.0
var _bag: Array[String] = []
var _failed: Dictionary = {}
var _prepared: Dictionary = {}
var _current: Dictionary = {}
var _completed_seconds: float = 0.0
var _last_path: String = ""
var _match_token: String = ""
var _started_once: bool = false
var _active: bool = false
var _poll_clock: float = 0.0
var _rescan_clock: float = 0.0
var _board_valid: bool = false
var _has_playtime: bool = false
var _enabled: bool = true
var _audio: Node
var _play_pending: bool = false
var _work_kind: String = ""
var _work_path: String = ""
var _precache_paths: Array[String] = []
var precache_total: int = 0
var precache_done: int = 0
var precache_errors: int = 0
var precache_running: bool = false
var precache_message: String = "Not started"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for prop in get_parent().get_property_list():
		if prop.name == "match_started": _board_valid = true
		if prop.name == "playtime": _has_playtime = true
	if not _board_valid:
		push_warning("Game music requires the U13 playable board as its parent.")
		set_process(false)
		return
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		volume_percent = clampf(float(settings.get_value("music", "volume_percent", volume_percent)), 0.0, 100.0)
		_enabled = bool(settings.get_value("music", "enabled", true))
	_player = AudioStreamPlayer.new()
	_player.name = "BackgroundGameMusic"
	_player.set_meta("corruptor_audio_role", "music")
	_audio = get_node_or_null("/root/CorruptorAudio")
	if _audio != null:
		_audio.register_music(self)
		_player.bus = _audio.MUSIC_BUS
	add_child(_player)
	_player.finished.connect(_on_finished)
	_mix_rate = AudioServer.get_mix_rate()
	_cache.load(CACHE_PATH)
	# Prepare the first song while the loadout screen is open, without playing it.
	if _enabled: _queue_next()
	start_precache()

func _process(delta: float) -> void:
	_collect_prepared()
	_schedule_work()
	_poll_clock += delta
	if _poll_clock >= 0.1:
		_poll_clock = 0.0
		_sync_board()
	if _active and _current.is_empty() and not _prepared.is_empty(): _start_prepared()
	if _enabled and _thread == null and _prepared.is_empty():
		_rescan_clock += delta
		if _rescan_clock >= 10.0:
			_rescan_clock = 0.0
			_queue_next()

func _sync_board() -> void:
	var board := get_parent()
	var started: bool = bool(board.get("match_started"))
	var in_setup: bool = bool(board.get("setup_open"))
	if started:
		var tracker: Object = board.get("playtime") if _has_playtime else null
		# _complete_job replaces session after ordinary action resolution too.
		# The playtime tracker survives those transactions and only changes on
		# start_loadout, restart or a successful _load_game. Use it alone.
		var token := str(tracker.get_instance_id() if tracker != null else board.get_instance_id())
		if token != _match_token:
			if _started_once: _reset_playlist()
			_match_token = token
			_started_once = true
	_active = _enabled and started and not in_setup
	_player.stream_paused = not _active

func set_music_volume(percent: float) -> void:
	volume_percent = clampf(percent, 0.0, 100.0)
	if _audio != null: _audio.set_volume("music", volume_percent)
	_apply_volume()

func _apply_volume() -> void:
	if _player == null: return
	var gain_db: float = float(_current.get("analysis", {}).get("gain_db", 0.0))
	_player.volume_db = gain_db if _audio != null else gain_db + linear_to_db(maxf(volume_percent / 100.0, 0.000001))

func _scan_tracks() -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(music_folder)
	if directory == null: return paths
	for filename in directory.get_files():
		if filename.get_extension().to_lower() not in ["wav", "mp3", "ogg", "json"]: continue
		var path := music_folder.path_join(filename)
		if _failed.has(path) and str(_failed[path]) == Track.fingerprint(path): continue
		paths.append(path)
	paths.sort()
	return paths

func _take_next_path() -> String:
	if _bag.is_empty():
		_bag = _scan_tracks()
		_bag.shuffle()
		# Avoid playing the last song twice across shuffle boundaries.
		if _bag.size() > 1 and _bag.back() == _last_path:
			var swap: String = _bag[0]
			_bag[0] = _bag.back()
			_bag[_bag.size() - 1] = swap
	if _bag.is_empty(): return ""
	return _bag.pop_back()

func start_precache() -> void:
	if precache_running: return
	_precache_paths = _scan_tracks()
	precache_total = _precache_paths.size()
	precache_done = 0
	precache_errors = 0
	precache_running = not _precache_paths.is_empty()
	precache_message = "Preparing music" if precache_running else "No music files found"
	_schedule_work()

func cancel_precache() -> void:
	precache_running = false
	_precache_paths.clear()
	if _work_kind == "cache": _cancel_worker()
	precache_message = "Stopped · completed renders are saved"

func precache_status() -> String:
	var progress := "%d / %d processed" % [precache_done, precache_total]
	if precache_errors > 0: progress += " · %d skipped (see run log)" % precache_errors
	if precache_running: return progress + "\n" + _work_path.get_file()
	return precache_message + " · " + progress

func current_song_text() -> String:
	if not _current.is_empty():
		return str(_current.path).get_file() + (" · paused in setup" if not _active else "")
	if _started_once and _enabled: return "Preparing music…"
	return "Waiting for match" if _enabled else "Game music disabled in settings.cfg"

func _queue_next() -> void:
	if not _enabled or not _prepared.is_empty(): return
	_play_pending = true
	_schedule_work()

func _schedule_work() -> void:
	if _thread != null: return
	var path: String = ""
	if _play_pending and _prepared.is_empty():
		_play_pending = false
		path = _take_next_path()
		_work_kind = "play"
	if path.is_empty() and precache_running and not _precache_paths.is_empty():
		path = _precache_paths[0]
		_work_kind = "cache"
	if path.is_empty(): return
	_work_path = path
	_cancel_mutex.lock()
	_cancelled = false
	_cancel_mutex.unlock()
	var cached: Dictionary = _cache.get_value("tracks", path, {})
	_thread = Thread.new()
	var err := _thread.start(Track.prepare.bind(path, cached, _mix_rate, _is_cancelled), Thread.PRIORITY_LOW)
	if err != OK:
		_thread = null
		_finish_precache_path(path, true)
		push_warning("Could not start game music analysis: %s" % error_string(err))

func _finish_precache_path(path: String, failed: bool) -> void:
	if path not in _precache_paths: return
	_precache_paths.erase(path)
	precache_done += 1
	if failed: precache_errors += 1
	if _precache_paths.is_empty():
		precache_running = false
		precache_message = "Ready" if precache_errors == 0 else "Finished with skipped files"

func _is_cancelled() -> bool:
	_cancel_mutex.lock()
	var result: bool = _cancelled
	_cancel_mutex.unlock()
	return result

func _collect_prepared() -> void:
	if _thread == null or _thread.is_alive(): return
	var result: Dictionary = _thread.wait_to_finish()
	_thread = null
	if result.get("cancelled", false): return
	if result.has("error"):
		_finish_precache_path(str(result.path), true)
		_failed[result.path] = result.stamp
		push_warning("Skipping music %s: %s" % [str(result.path).get_file(), result.error])
		if _work_kind == "play": _queue_next()
		return
	_finish_precache_path(str(result.path), false)
	if _work_kind == "play": _prepared = result
	_cache.set_value("tracks", result.path, result.analysis)
	if not result.get("cached", false): _cache.save(CACHE_PATH)

func _start_prepared() -> void:
	if not _active or _prepared.is_empty(): return
	_current = _prepared
	_prepared = {}
	_completed_seconds = 0.0
	_last_path = str(_current.path)
	_player.stream = _current.stream
	_apply_volume()
	_player.stream_paused = false
	_player.play()
	print("GAME MUSIC · %s · volume matched (%+.1f dB)" % [_last_path.get_file(), float(_current.analysis.gain_db)])
	_queue_next()

func _on_finished() -> void:
	if _current.is_empty(): return
	_completed_seconds += float(_current.length)
	if _completed_seconds + 0.001 < minimum_track_seconds:
		_player.play()
		_player.stream_paused = not _active
		return
	_current = {}
	_player.stream = null
	if not _prepared.is_empty(): _start_prepared()
	else: _queue_next()

func _cancel_worker() -> void:
	if _thread == null: return
	_cancel_mutex.lock()
	_cancelled = true
	_cancel_mutex.unlock()
	_thread.wait_to_finish()
	_thread = null
	_work_kind = ""

func _reset_playlist() -> void:
	_cancel_worker()
	_player.stop()
	_player.stream = null
	_current = {}
	_prepared = {}
	_completed_seconds = 0.0
	_bag.clear()
	_queue_next()

func _exit_tree() -> void:
	_cancel_worker()
	if _player != null:
		_player.stop()
		_player.stream = null
	_current.clear()
	_prepared.clear()
