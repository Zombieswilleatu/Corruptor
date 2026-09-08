extends RefCounted

# Stable IDs are the tutorial boundary; future prompts use this same registry.
const KEEP_LOADOUT: String = "castle_loadout_keep_v1"
const DEFAULT_PATH: String = "user://u13_tutorial_popups.cfg"
var enabled: bool = true
var _path: String
var _dismissed: Dictionary = {}


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	_load()


func _load() -> void:
	_dismissed.clear()
	var config := ConfigFile.new()
	if config.load(_path) == OK:
		for id in config.get_section_keys("dismissed") if config.has_section("dismissed") else []:
			if config.get_value("dismissed", id, false) == true:
				_dismissed[id] = true


func should_show(id: String) -> bool:
	# Reload at the rare popup boundary so reset applies to every live consumer.
	_load()
	return enabled and not _dismissed.has(id)


func dismiss(id: String) -> Error:
	_load()
	_dismissed[id] = true
	return _save()


func reset_all() -> Error:
	enabled = true
	_dismissed.clear()
	return _save()


func _save() -> Error:
	var config := ConfigFile.new()
	for id in _dismissed:
		config.set_value("dismissed", id, true)
	return config.save(_path)
