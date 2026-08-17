class_name PlayableMatchSnapshot
extends RefCounted


const SnapshotSerializerData = preload(
	"res://Scripts/Sim/GoldenSnapshotSerializer.gd"
)


const EXPORT_FOLDER_NAME: String = "Corruptor Debug Snapshots"
const FALLBACK_EXPORT_DIRECTORY: String = "user://debug_snapshots"
const FORMAT_VERSION: String = "corruptor-playable-match-snapshot-v1"


static func export_current_match(
	controller,
	match_seed: int,
	stage_name: String,
	ui_log: Array
) -> Dictionary:
	if controller == null or controller.game == null:
		return {
			"ok": false,
			"reason": "game_not_started",
			"path": "",
		}

	var absolute_directory: String = _export_directory_absolute()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		absolute_directory
	)
	if directory_error != OK:
		return {
			"ok": false,
			"reason": "create_directory_failed_%s" % error_string(directory_error),
			"path": absolute_directory,
		}

	var timestamp: String = Time.get_datetime_string_from_system().replace(
		"-",
		""
	).replace(
		":",
		""
	).replace(
		"T",
		"_"
	)
	var stem: String = "match_%s_seed%d_r%02d_%s" % [
		timestamp,
		match_seed,
		int(controller.game.round),
		stage_name.to_lower(),
	]
	var absolute_path: String = absolute_directory.path_join("%s.json" % stem)
	var file = FileAccess.open(
		absolute_path,
		FileAccess.WRITE
	)
	if file == null:
		return {
			"ok": false,
			"reason": "open_failed_%s" % error_string(FileAccess.get_open_error()),
			"path": absolute_path,
		}

	file.store_string(
		JSON.stringify(
			_snapshot_payload(
				controller,
				match_seed,
				stage_name,
				ui_log
			),
			"\t",
			true
		)
	)
	file.close()

	return {
		"ok": true,
		"reason": "",
		"path": absolute_path,
	}


static func _export_directory_absolute() -> String:
	var documents_directory: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if documents_directory.is_empty():
		return ProjectSettings.globalize_path(FALLBACK_EXPORT_DIRECTORY)
	return documents_directory.path_join(EXPORT_FOLDER_NAME)


static func _snapshot_payload(
	controller,
	match_seed: int,
	stage_name: String,
	ui_log: Array
) -> Dictionary:
	return {
		"format": FORMAT_VERSION,
		"exported_at_local": Time.get_datetime_string_from_system(),
		"match_seed": match_seed,
		"stage": {
			"id": int(controller.stage),
			"name": stage_name,
		},
		"rules": _resource_snapshot(controller.rules),
		"policy": _resource_snapshot(controller.policy),
		"random_source": _random_snapshot(controller.random_source),
		"game": SnapshotSerializerData.snapshot_game(
			controller.game,
			"playable:live",
			controller.rules
		),
		"controller": {
			"phase_results": _json_value(controller.phase_results),
			"events": _json_value(controller.events),
			"summon_choices": _json_value(controller.summon_choices),
			"commitment_choices": _json_value(controller.commitment_choices),
			"pending_market_choices": _json_value(controller.pending_market_choices),
			"pending_market_results": _json_value(controller.pending_market_results),
			"resolution_state": _json_value(controller.resolution_state),
			"kanifous_preview_cards": _json_value(controller.kanifous_preview_cards),
			"kanifous_choice": _json_value(controller.kanifous_choice),
			"guard_locations": _json_value(controller.guard_locations),
			"revealed_guard_ids": _json_value(controller.revealed_guard_ids),
			"guard_reveal_events": _json_value(controller.guard_reveal_events),
			"last_result": _json_value(controller.last_result),
		},
		"ui_log": _json_value(ui_log),
	}


static func _random_snapshot(random_source) -> Dictionary:
	if random_source == null:
		return {
			"available": false,
		}

	if random_source.has_method("snapshot_state"):
		return {
			"available": true,
			"state": _json_value(random_source.snapshot_state()),
		}

	return {
		"available": false,
		"class": random_source.get_class(),
		"reason": "random_source_does_not_expose_snapshot_state",
	}


static func _resource_snapshot(resource) -> Dictionary:
	if resource == null:
		return {}

	var values: Dictionary = {
		"class": resource.get_class(),
	}

	for property_info in resource.get_property_list():
		var property_name: String = String(property_info.get("name", ""))
		var property_usage: int = int(property_info.get("usage", 0))
		if property_name.is_empty() or property_name.begins_with("_"):
			continue
		if (property_usage & PROPERTY_USAGE_STORAGE) == 0:
			continue

		values[property_name] = _json_value(resource.get(property_name))

	return values


static func _json_value(value):
	match typeof(value):
		TYPE_NIL:
			return null
		TYPE_BOOL:
			return bool(value)
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY:
			var values: Array = []
			for entry in value:
				values.append(_json_value(entry))
			return values
		TYPE_DICTIONARY:
			var values: Dictionary = {}
			var keys: Array[String] = []
			var values_by_key: Dictionary = {}
			for raw_key in value.keys():

				var key: String = str(raw_key)
				keys.append(key)
				values_by_key[key] = value[raw_key]
			keys.sort()
			for key: String in keys:
				values[key] = _json_value(values_by_key[key])
			return values
		TYPE_OBJECT:
			if value != null and value.has_method("card_id"):
				return str(value.card_id())
			if value != null:
				return "<%s>" % value.get_class()
			return null
		_:
			return str(value)
