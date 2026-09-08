class_name U13LordPowerDeclaration
extends RefCounted

const U13RoundTimelineData = preload(
	"res://Scripts/Sim/U13RoundTimeline.gd"
)

# U13_LORD_DECLARATION_V1
#
# Serialized command envelope for every U13 Lord power declaration.
# The schema is deliberately data-only: no Nodes, Resources, Callables, or
# screen-space coordinates belong in a locked submission or delayed effect.

const SCHEMA_VERSION: String = "U13_LORD_DECLARATION_V1"

const VISIBILITY_PUBLIC: String = "public"
const VISIBILITY_HIDDEN: String = "hidden"
const VALID_VISIBILITY: Array[String] = [
	VISIBILITY_PUBLIC,
	VISIBILITY_HIDDEN,
]


static func create(
	declaration_id: String,
	player_id: int,
	lord_id: String,
	power_id: String,
	declared_round: int,
	fire_hook: String,
	fire_round: int = -1,
	queue_index: int = 0,
	visibility: String = VISIBILITY_PUBLIC,
	target: Dictionary = {},
	cost: Dictionary = {},
	parameters: Dictionary = {}
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"declaration_id": declaration_id,
		"player_id": player_id,
		"lord_id": lord_id,
		"power_id": power_id,
		"declared_round": declared_round,
		"fire_round": fire_round,
		"fire_hook": fire_hook,
		"queue_index": queue_index,
		"visibility": visibility,
		"target": target.duplicate(true),
		"cost": cost.duplicate(true),
		"parameters": parameters.duplicate(true),
	}


static func validate(declaration: Dictionary) -> Dictionary:
	var errors: Array[String] = []

	if String(declaration.get("schema_version", "")) != SCHEMA_VERSION:
		errors.append("schema_version_invalid")

	if String(declaration.get("declaration_id", "")).is_empty():
		errors.append("declaration_id_required")

	if int(declaration.get("player_id", -1)) < 0:
		errors.append("player_id_invalid")

	if String(declaration.get("lord_id", "")).is_empty():
		errors.append("lord_id_required")

	if String(declaration.get("power_id", "")).is_empty():
		errors.append("power_id_required")

	if int(declaration.get("declared_round", 0)) < 1:
		errors.append("declared_round_invalid")

	var fire_round: int = int(declaration.get("fire_round", -1))
	if fire_round != -1 and fire_round < int(declaration.get("declared_round", 0)):
		errors.append("fire_round_before_declaration")

	var fire_hook: String = String(declaration.get("fire_hook", ""))
	if not U13RoundTimelineData.is_valid_hook(fire_hook):
		errors.append("fire_hook_invalid")

	if int(declaration.get("queue_index", -1)) < 0:
		errors.append("queue_index_invalid")

	if not VALID_VISIBILITY.has(String(declaration.get("visibility", ""))):
		errors.append("visibility_invalid")

	for dictionary_field: String in ["target", "cost", "parameters"]:
		if typeof(declaration.get(dictionary_field, null)) != TYPE_DICTIONARY:
			errors.append("%s_not_dictionary" % dictionary_field)

	if errors.is_empty():
		_validate_serializable_value(declaration, "declaration", errors)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
	}


# Spatial powers store canonical simulation coordinates as plain fixed-point
# integers. Bounds/meaning are intentionally deferred to the spatial audit.
# This schema proves we never need to serialize screen pixels or Vector2 nodes.
static func canonical_position(x_fp: int, y_fp: int) -> Dictionary:
	return {
		"x_fp": x_fp,
		"y_fp": y_fp,
	}


static func position_is_canonical(raw_position) -> bool:
	if typeof(raw_position) != TYPE_DICTIONARY:
		return false
	var position: Dictionary = raw_position
	return (
		position.has("x_fp")
		and position.has("y_fp")
		and typeof(position.get("x_fp")) == TYPE_INT
		and typeof(position.get("y_fp")) == TYPE_INT
	)


static func to_json(declaration: Dictionary) -> String:
	var validation: Dictionary = validate(declaration)
	if not bool(validation.get("valid", false)):
		return ""
	return JSON.stringify(declaration)


static func from_json(encoded: String) -> Dictionary:
	if encoded.is_empty():
		return {}
	var parsed = JSON.parse_string(encoded)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var declaration: Dictionary = parsed
	var validation: Dictionary = validate(declaration)
	return declaration if bool(validation.get("valid", false)) else {}


static func _validate_serializable_value(
	value,
	path: String,
	errors: Array[String]
) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return
		TYPE_ARRAY:
			var values: Array = value
			for index: int in range(values.size()):
				_validate_serializable_value(
					values[index],
					"%s[%d]" % [path, index],
					errors
				)
		TYPE_DICTIONARY:
			var values: Dictionary = value
			for key in values:
				if typeof(key) != TYPE_STRING:
					errors.append("non_string_key_at_%s" % path)
					continue
				_validate_serializable_value(
					values[key],
					"%s.%s" % [path, String(key)],
					errors
				)
		_:
			errors.append(
				"non_serializable_value_at_%s_type_%d"
				% [path, typeof(value)]
			)
