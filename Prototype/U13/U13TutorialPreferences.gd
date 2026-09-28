extends RefCounted

# Stable IDs are the tutorial boundary; future prompts use this same registry.
const KEEP_LOADOUT: String = "castle_loadout_keep_v1"
const DEFAULT_PATH: String = "user://u13_tutorial_popups.cfg"
var enabled: bool = true
var _path: String
var _dismissed: Dictionary = {}
var _learned: Dictionary = {}
var _automatic: bool = true


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	_load()


func _load() -> void:
	_dismissed.clear()
	_learned.clear()
	_automatic = true
	var config := ConfigFile.new()
	if config.load(_path) == OK:
		_automatic = bool(config.get_value("settings", "automatic", true))
		for id in config.get_section_keys("learned") if config.has_section("learned") else []:
			if config.get_value("learned", id, false) == true: _learned[id] = true
		for id in config.get_section_keys("dismissed") if config.has_section("dismissed") else []:
			if config.get_value("dismissed", id, false) == true:
				_dismissed[id] = true


func should_show(id: String) -> bool:
	# Reload at the rare popup boundary so reset applies to every live consumer.
	_load()
	return enabled and _automatic and not _dismissed.has(id) and not _learned.has(id)


func dismiss(id: String) -> Error:
	_load()
	_dismissed[id] = true
	return _save()


func reset_all() -> Error:
	enabled = true
	_automatic = true
	_learned.clear()
	_dismissed.clear()
	return _save()


func _save() -> Error:
	var config := ConfigFile.new()
	config.set_value("settings", "automatic", _automatic)
	for id in _learned: config.set_value("learned", id, true)
	for id in _dismissed:
		config.set_value("dismissed", id, true)
	return config.save(_path)


func automatic_enabled() -> bool:
	_load()
	return enabled and _automatic

func set_automatic(value: bool) -> Error:
	_load()
	_automatic = value
	return _save()

# Aldric's teaching steps and later unlocks use the same concept IDs as Help.
# Call only for concepts actually taught, never on blanket prologue completion.
func mark_learned(concepts: Array) -> Error:
	_load()
	for concept in concepts:
		if typeof(concept) == TYPE_STRING and not concept.is_empty(): _learned[concept] = true
	return _save()
