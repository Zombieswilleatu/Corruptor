extends Node
# Small resource queue owned by the intro. Never blocks on an unfinished load.
var _pending: Dictionary = {}
var _ready_resources: Dictionary = {}
var _finished: Dictionary = {}


func _ready() -> void:
	set_process(false)


func request(path: String, type_hint: String) -> void:
	if _pending.has(path) or _finished.has(path):
		return
	var error := ResourceLoader.load_threaded_request(path, type_hint)
	if error != OK:
		_finished[path] = true
		push_error("Intro: resource request failed: " + path)
		return
	_pending[path] = true
	set_process(true)


func get_ready(path: String) -> Resource:
	return _ready_resources.get(path) as Resource


func is_finished(path: String) -> bool:
	return _finished.has(path)


func release(path: String) -> void:
	_ready_resources.erase(path)
	# Drain a pending request when it completes, but do not retain its texture.
	if _pending.has(path):
		_pending[path] = false


func _process(_delta: float) -> void:
	for path: String in _pending.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(path)
			if bool(_pending[path]):
				_ready_resources[path] = resource
		else:
			push_error("Intro: background resource load failed: " + path)
		_finished[path] = true
		_pending.erase(path)
	set_process(not _pending.is_empty())


func _exit_tree() -> void:
	# Godot has no cancellation API for threaded requests. Consume outstanding
	# results on teardown so a quick exit cannot leave a request retaining assets.
	# Normal transitions have already drained them while the title was visible.
	for path: String in _pending.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
	_pending.clear()
	_ready_resources.clear()
