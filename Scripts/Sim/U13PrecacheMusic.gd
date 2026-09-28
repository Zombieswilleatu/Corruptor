extends SceneTree
const Track = preload("res://Prototype/U13/U13GameMusicTrack.gd")
const CACHE_PATH: String = "user://corruptor_game_music_analysis_v1.cfg"
var worker: Thread
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var directory := DirAccess.open("res://Music/GameMusic")
	if directory == null:
		print("Music/GameMusic is missing. Add your saved arrangements there first.")
		quit(1)
		return
	var paths: Array[String] = []
	for filename in directory.get_files():
		if filename.get_extension().to_lower() in ["wav", "mp3", "ogg", "json"]:
			paths.append("res://Music/GameMusic/" + filename)
	paths.sort()
	var cache := ConfigFile.new()
	cache.load(CACHE_PATH)
	var failed: int = 0
	for i in range(paths.size()):
		print("PRECACHE %d / %d · %s" % [i + 1, paths.size(), paths[i].get_file()])
		worker = Thread.new()
		var cached: Dictionary = cache.get_value("tracks", paths[i], {})
		var error := worker.start(Track.prepare.bind(paths[i], cached, AudioServer.get_mix_rate(), func(): return false), Thread.PRIORITY_LOW)
		if error != OK:
			failed += 1
			worker = null
			continue
		while worker.is_alive(): await create_timer(0.1).timeout
		var result: Dictionary = worker.wait_to_finish()
		worker = null
		if result.has("error"):
			failed += 1
			printerr("SKIPPED: ", result.error)
		else:
			cache.set_value("tracks", paths[i], result.analysis)
			if cache.save(CACHE_PATH) != OK:
				failed += 1
				printerr("Could not save volume analysis cache.")
	print("PRECACHE COMPLETE · %d ready · %d skipped" % [paths.size() - failed, failed])
	quit(0 if failed == 0 else 1)
