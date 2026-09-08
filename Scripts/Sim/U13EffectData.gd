class_name U13EffectData
extends RefCounted

const Declaration = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")
const EventData = preload("res://Scripts/Sim/Events.gd")

# Shared data boundary for U13 effects. Entity IDs in targets remain opaque:
# this layer neither invents entity identities nor decides target legality.
# Integral JSON numbers are accepted; fractions/strings are never truncated.
const MAX_JSON_INTEGER: int = 9007199254740991


static func is_integer(value) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= -MAX_JSON_INTEGER and value <= MAX_JSON_INTEGER
	return (
		typeof(value) == TYPE_FLOAT
		and is_finite(value)
		and abs(value) <= MAX_JSON_INTEGER
		and value == floor(value)
	)


static func is_data(value, depth: int = 0) -> bool:
	if depth > 64:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return true
		TYPE_INT:
			return is_integer(value)
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for child in value:
				if not is_data(child, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING:
					return false
				if key.ends_with("_fp") and not is_integer(value[key]):
					return false
				if not is_data(value[key], depth + 1):
					return false
			return true
	return false


static func copy_data(value):
	# Call only after is_data(). JSON has one numeric kind; canonical U13 data
	# uses integers for every safely representable whole number, including
	# counters in arbitrary payloads/stages/arrays. Apply on creation AND load.
	# Fractional values remain floats; *_fp validation still rejects fractions.
	if typeof(value) == TYPE_FLOAT and is_integer(value):
		return int(value)
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key in value:
			result[key] = int(value[key]) if key.ends_with("_fp") else copy_data(value[key])
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for child in value:
			result.append(copy_data(child))
		return result
	return value


static func declaration_copy(raw) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or not is_data(raw):
		return {}
	for key: String in [
		"schema_version",
		"declaration_id",
		"lord_id",
		"power_id",
		"fire_hook",
		"visibility",
	]:
		if typeof(raw.get(key)) != TYPE_STRING:
			return {}
	for key: String in Declaration.TOP_LEVEL_INTEGER_FIELDS:
		if not is_integer(raw.get(key)):
			return {}
	var result: Dictionary = copy_data(raw)
	for key: String in Declaration.TOP_LEVEL_INTEGER_FIELDS:
		result[key] = int(result[key])
	if not Declaration.validate(result).valid:
		return {}
	if result.player_id not in [0, 1]:
		return {}
	return result


static func instance_id(effect_scope: String, declaration_id: String, effect_key: String) -> String:
	# Length prefixes make keys unambiguous, with no RNG or process-global counter.
	# Distinct children of one declaration must use distinct semantic effect keys.
	return (
		"u13_%s:%d:%s:%d:%s"
		% [
			effect_scope,
			declaration_id.length(),
			declaration_id,
			effect_key.length(),
			effect_key,
		]
	)


static func make_record(
	effect_scope: String,
	declaration: Dictionary,
	effect_key: String,
	payload: Dictionary,
	public_data: Dictionary
) -> Dictionary:
	var source: Dictionary = declaration_copy(declaration)
	if (
		source.is_empty()
		or effect_key.is_empty()
		or not is_data(payload)
		or not is_data(public_data)
	):
		return {}
	return {
		"effect_id": instance_id(effect_scope, source.declaration_id, effect_key),
		"effect_key": effect_key,
		"declaration": source,
		"payload": copy_data(payload),
		"public_data": copy_data(public_data),
	}


static func record_copy(raw, effect_scope: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or not is_data(raw):
		return {}
	if typeof(raw.get("effect_key")) != TYPE_STRING:
		return {}
	for key: String in ["declaration", "payload", "public_data"]:
		if typeof(raw.get(key)) != TYPE_DICTIONARY:
			return {}
	var result: Dictionary = make_record(
		effect_scope, raw.declaration, raw.effect_key, raw.payload, raw.public_data
	)
	if result.is_empty() or raw.get("effect_id") != result.effect_id:
		return {}
	return result


static func public_record(record: Dictionary) -> Dictionary:
	# Hidden means hidden from every normal viewer, INCLUDING its owner.
	# Only explicitly supplied public_data is exposed (e.g. a Price's due notice).
	# Never pass snapshot() or authoritative event results to a player UI.
	if record.declaration.visibility == Declaration.VISIBILITY_PUBLIC:
		return record.duplicate(true)
	var source: Dictionary = record.declaration
	return {
		"effect_id": record.effect_id,
		"player_id": source.player_id,
		"lord_id": source.lord_id,
		"power_id": source.power_id,
		"visibility": Declaration.VISIBILITY_HIDDEN,
		"public_data": record.public_data.duplicate(true),
	}


static func valid_player_order(player_order: Array) -> bool:
	return (
		player_order.size() == 2
		and typeof(player_order[0]) == TYPE_INT
		and typeof(player_order[1]) == TYPE_INT
		and (player_order == [0, 1] or player_order == [1, 0])
	)


static func event(event_type: String, record: Dictionary, details: Dictionary = {}) -> Dictionary:
	var data: Dictionary = details.duplicate(true)
	data["effect_id"] = record.effect_id
	data["declaration_id"] = record.declaration.declaration_id
	data["player_id"] = record.declaration.player_id
	data["power_id"] = record.declaration.power_id
	return EventData.make(event_type, "", data)


static func invalid(reason: String) -> Dictionary:
	return {"action": "invalid", "reason": reason}
